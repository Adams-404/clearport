#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

REPO="Adams-404/clearport"
BRANCH="main"
RAW="https://raw.githubusercontent.com/$REPO/$BRANCH"
BIN_DIR="${PREFIX:-/data/data/com.termux/files/usr}/bin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ -z "${PREFIX:-}" ] || [ ! -d "$PREFIX/bin" ]; then
  echo "This installer is for Termux on Android." >&2
  exit 1
fi

command -v pkg >/dev/null 2>&1 || { echo "Termux package manager not found." >&2; exit 1; }

echo "Installing Clearport CLI dependencies..."
pkg update -y
pkg install -y bash curl jq procps coreutils termux-tools llama-cpp nano

echo "Downloading Clearport CLI..."
curl -fsSL "$RAW/scripts/clearport" -o "$TMP/clearport"
curl -fsSL "$RAW/scripts/clearport-server" -o "$TMP/clearport-server"
chmod 755 "$TMP/clearport" "$TMP/clearport-server"
mkdir -p "$BIN_DIR"
cp "$TMP/clearport" "$BIN_DIR/clearport"
cp "$TMP/clearport-server" "$BIN_DIR/clearport-server"
chmod 755 "$BIN_DIR/clearport" "$BIN_DIR/clearport-server"

mkdir -p "$HOME/models" "$HOME/.config/clearport"
echo
echo "Clearport CLI installed."
echo
echo "Next:"
echo "  clearport local-models     # list GGUF files in ~/models"
echo "  clearport use <model.gguf> # choose your model"
echo "  clearport start            # start the local server"
echo "  clearport chat             # chat directly in Termux"
echo
echo "No model is downloaded automatically. GGUF files can be large."
