#!/usr/bin/env bash

detect_os() {

    if [ -n "$TERMUX_VERSION" ]; then
        OS="termux"
    else
        OS="linux"
    fi

}

clear
echo "===================================="
echo " 🚀 MediaMatrix Installer"
echo "===================================="

# =========================
# CONFIG
# =========================
# Deteksi platform
if [ -n "$TERMUX_VERSION" ]; then
    OS="termux"
else
    OS="linux"
fi
# Repository (Base64)
ENC_REPO_TERMUX="aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2UycGhyZWFrZXIvbXlyZXBvL21haW4="
ENC_REPO_LINUX="aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2UycGhyZWFrZXIvbXl0b29scy9tYWlu"

# Pilih repository sesuai platform
if [ "$OS" = "termux" ]; then
    ENC_REPO="$ENC_REPO_TERMUX"
else
    ENC_REPO="$ENC_REPO_LINUX"
fi

# Decode repository
REPO=$(printf '%s' "$ENC_REPO" | base64 -d 2>/dev/null)

# Validasi hasil decode
if [ -z "$REPO" ]; then
    echo "❌ Repo decode gagal"
    exit 1
fi

WORKDIR="$HOME/MediaMatrix"
LICENSE_URL="$REPO/licenses.json"
LICENSE_FILE="$HOME/.mediamatrix_license"

# =========================
# LICENSE CHECK
# =========================
echo ""
echo "🔐 License Required"

if [ ! -f "$LICENSE_FILE" ] || [ ! -s "$LICENSE_FILE" ]; then
    read -p "Masukkan license key: " USER_KEY
    echo "$USER_KEY" > "$LICENSE_FILE"
else
    USER_KEY=$(cat "$LICENSE_FILE")
fi

# validasi kosong
if [ -z "$USER_KEY" ]; then
    echo "❌ License kosong!"
    rm -f "$LICENSE_FILE"
    exit 1
fi

echo "🔍 Validating license..."

MAX_RETRY=3
COUNT=0

while true; do
    DATA=$(curl -s "$LICENSE_URL")

    [ -z "$DATA" ] && echo "❌ Tidak bisa konek ke server" && exit 1

    KEY_DATA=$(echo "$DATA" | awk "/\"$USER_KEY\"/,/}/")

    if [ -z "$KEY_DATA" ]; then
    echo "❌ License tidak valid"
    rm -f "$LICENSE_FILE"
    COUNT=$((COUNT+1))

    if [ "$COUNT" -ge "$MAX_RETRY" ]; then
        echo "❌ Gagal 3x. Keluar."
        exit 1
    fi

    read -p "Masukkan license key lagi: " USER_KEY

    echo "$USER_KEY" > "$LICENSE_FILE"   # ← TAMBAHKAN INI

    continue
fi

    break
done

STATUS=$(echo "$KEY_DATA" | grep status | cut -d '"' -f4)
EXPIRY=$(echo "$KEY_DATA" | grep expiry | cut -d '"' -f4)

TODAY=$(date +%Y-%m-%d)

[ "$STATUS" != "active" ] && echo "🚫 License revoked" && exit 1

if [[ "$TODAY" > "$EXPIRY" ]]; then
    echo "⛔ License expired ($EXPIRY)"
    exit 1
fi

echo "✅ License valid"

# =========================
# STORAGE PERMISSION
# =========================
if [ "$OS" = "termux" ]; then

    if [ ! -d "$HOME/storage" ]; then
        echo "📂 Setup storage permission..."
        termux-setup-storage
    fi

fi

# =========================
# UPDATE SYSTEM
# =========================
echo ""
echo "📦 Updating system..."
if [ "$OS" = "termux" ]; then

    apt update -y
    apt upgrade -y

else

    sudo apt update
    sudo apt upgrade -y

fi

# =========================
# INSTALL DEPENDENCIES
# =========================
echo ""
echo "📦 Installing dependencies..."
if [ "$OS" = "termux" ]; then

    apt install -y python ffmpeg curl bc

else

    sudo apt install -y python3 python3-pip ffmpeg curl bc

fi

# =========================
# INSTALL YT-DLP
# =========================
if ! command -v yt-dlp >/dev/null 2>&1; then

    if [ "$OS" = "termux" ]; then
        pip install -U yt-dlp
    else
        python3 -m pip install -U yt-dlp
    fi

fi

# =========================
# CREATE WORKDIR
# =========================
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit

# =========================
# DOWNLOAD SCRIPT
# =========================
echo ""
echo "⬇️ Downloading MediaMatrix tools..."

curl -fLo audio "$REPO/audio" || { echo "❌ Gagal download audio"; exit 1; }
curl -fLo video "$REPO/video" || { echo "❌ Gagal download video"; exit 1; }
curl -fLo yt "$REPO/yt" || { echo "❌ Gagal download yt-dlp"; exit 1; }
curl -fLo loop "$REPO/loop" || { echo "❌ Gagal download loop"; exit 1; }
curl -fLo matrix "$REPO/matrix" || { echo "❌ Gagal download launcher"; exit 1; }

# =========================
# FIX LINE ENDING
# =========================
sed -i 's/\r$//' audio video yt loop matrix

# cek apakah download berhasil
for f in audio video yt loop matrix; do
    [ ! -f "$f" ] && echo "❌ Gagal download $f" && exit 1
done

# kasih permission execute
chmod +x audio video yt loop matrix

echo "✅ Permission berhasil di-set"

# version awal
echo "1.0" > "$WORKDIR/.version"

# =========================
# SET ALIAS
# =========================
echo ""
echo "⚙️ Setting alias..."

SHELL_NAME=$(basename "$SHELL")

case "$SHELL_NAME" in
    bash)
        SHELL_RC="$HOME/.bashrc"
        ;;
    zsh)
        SHELL_RC="$HOME/.zshrc"
        ;;
    *)
        SHELL_RC="$HOME/.profile"
        ;;
esac

touch "$SHELL_RC"

sed -i '/^alias matrix=/d' "$SHELL_RC"
echo "alias matrix='$WORKDIR/matrix'" >> "$SHELL_RC"

# =========================
# DONE
# =========================
clear
echo "===================================="
echo " ✅ INSTALLATION COMPLETE"
echo "===================================="
echo ""
echo "📦 MediaMatrix berhasil diinstall!"
echo ""
echo "👉 Jalankan dengan perintah:"
echo ""
echo "   matrix"
echo ""
echo "===================================="
