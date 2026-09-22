#!/usr/bin/env bash

# Thunderbird install script
# URL: https://download.mozilla.org/?product=thunderbird-155.0-SSL&os=linux64&lang=fr
# Version: 155.0

set -euo pipefail

# ---- Configuration ----
# Choose installation type: "system" (requires sudo) or "user"
# Usage: thunderbird.sh [-system | -user | -h]
INSTALL_TYPE="${INSTALL_TYPE:-user}" # change to "system" for /opt

# Parse command-line arguments (override INSTALL_TYPE)
while [[ $# -gt 0 ]]; do
  case "$1" in
    -system|--system) INSTALL_TYPE="system"; shift ;;
    -user|--user)     INSTALL_TYPE="user";   shift ;;
    -h|--help)
      echo "Usage: $0 [-system | -user]"
      echo "  -system  Install to /opt/thunderbird (requires sudo)"
      echo "  -user    Install to ~/.local/thunderbird (default)"
      exit 0
      ;;
    *) echo "ERROR: Unknown option: $1 (use -system or -user)" >&2; exit 1 ;;
  esac
done

# Download URL (already set for French Linux 64-bit)
DOWNLOAD_URL="https://download.mozilla.org/?product=thunderbird-155.0-SSL&os=linux64&lang=fr"

# Temporary file
TMP_DIR="$(mktemp -d)"
TARBALL="${TMP_DIR}/thunderbird.tar.xz" # Mozilla ships .tar.xz since v121+
EXTRACT_DIR="${TMP_DIR}/thunderbird"

# Final installation directories
if [[ "$INSTALL_TYPE" == "system" ]]; then
  INSTALL_DIR="/opt/thunderbird"
  BIN_LINK="/usr/local/bin/thunderbird"
  DESKTOP_DIR="/usr/share/applications"
  SUDO="sudo"
else
  INSTALL_DIR="${HOME}/.local/thunderbird"
  BIN_LINK="${HOME}/.local/bin/thunderbird"
  DESKTOP_DIR="${HOME}/.local/share/applications"
  SUDO=""
fi

# ---- Helper functions ----
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

die() {
  echo "ERROR: $*" >&2
  exit 1
}

check_prerequisites() {
  # Check for download tool
  if command -v curl &>/dev/null; then
    DOWNLOAD_CMD="curl -L --fail -o"
  elif command -v wget &>/dev/null; then
    DOWNLOAD_CMD="wget -O"
  else
    die "Neither curl nor wget found. Please install one of them."
  fi

  # Check for tar
  if ! command -v tar &>/dev/null; then
    die "tar is required but not found."
  fi

  # If system install, ensure sudo works
  if [[ "$INSTALL_TYPE" == "system" ]] && ! command -v sudo &>/dev/null; then
    die "sudo is required for system installation but not found."
  fi
}

create_desktop_entry() {
  local desktop_file="${DESKTOP_DIR}/thunderbird.desktop"
  local icon_path="${INSTALL_DIR}/chrome/icons/default/default128.png"

  cat >"$desktop_file" <<EOF
[Desktop Entry]
Name=Thunderbird
Comment=Email, RSS and newsgroup client
Exec=${INSTALL_DIR}/thunderbird %u
Icon=${icon_path}
Terminal=false
Type=Application
Categories=Network;Email;
MimeType=message/rfc822;
StartupNotify=true
EOF

  if [[ "$INSTALL_TYPE" == "system" ]]; then
    $SUDO chmod 644 "$desktop_file"
  else
    chmod 644 "$desktop_file"
  fi
}

# ---- Main script ----
check_prerequisites

echo "==> Downloading Thunderbird 155.0 (French, Linux 64-bit) ..."
$DOWNLOAD_CMD "$TARBALL" "$DOWNLOAD_URL"

echo "==> Extracting archive ..."
mkdir -p "$EXTRACT_DIR"
tar -xf "$TARBALL" -C "$EXTRACT_DIR" --strip-components=1 # GNU tar auto-detects xz/bz2

echo "==> Installing to ${INSTALL_DIR} ..."
if [[ "$INSTALL_TYPE" == "system" ]]; then
  $SUDO mkdir -p "$(dirname "$INSTALL_DIR")"
  if [[ -d "$INSTALL_DIR" ]]; then
    $SUDO rm -rf "$INSTALL_DIR"
  fi
  $SUDO mv "$EXTRACT_DIR" "$INSTALL_DIR"
else
  mkdir -p "$(dirname "$INSTALL_DIR")"
  if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
  fi
  mv "$EXTRACT_DIR" "$INSTALL_DIR"
fi

echo "==> Creating symbolic link ${BIN_LINK} ..."
mkdir -p "$(dirname "$BIN_LINK")"
if [[ "$INSTALL_TYPE" == "system" ]]; then
  $SUDO ln -sf "${INSTALL_DIR}/thunderbird" "$BIN_LINK"
else
  ln -sf "${INSTALL_DIR}/thunderbird" "$BIN_LINK"
fi

echo "==> Creating desktop entry ..."
mkdir -p "$DESKTOP_DIR"
create_desktop_entry

echo "================================================"
echo "Thunderbird 155.0 successfully installed!"
echo "You can launch it by running: thunderbird"
if [[ "$INSTALL_TYPE" == "user" ]]; then
  echo "Make sure ${HOME}/.local/bin is in your PATH."
fi
echo "================================================"
