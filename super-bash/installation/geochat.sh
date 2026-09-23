#!/usr/bin/env bash
#
# GeoChat Desktop — build & install script for Debian-based Linux.
#
# GeoChat publishes macOS and Windows installers only. On Linux the app is
# built from source, so this script installs the Tauri build dependencies, a
# Bun runtime and a stable Rust toolchain, checks out the repository, builds
# the Debian package, then installs it.
#
#   ./geochat.sh            # user install (default): build .deb, extract to
#                           #   ~/.local/opt/geochat, add a launcher
#   ./geochat.sh -system    # system install: build .deb then apt-get install
#   ./geochat.sh -h
#
# Environment overrides:
#   GEOCHAT_DIR          checkout directory       (default: ~/geochat)
#   GEOCHAT_REPO_URL     git remote               (default: https://github.com/tiwe0/GeoChat.git)
#   GEOCHAT_BRANCH       branch to build          (default: master)
#   GEOCHAT_BUN_VERSION  minimum Bun version      (default: 1.3.11)
#   GEOCHAT_BUNDLES      Tauri bundle targets     (default: deb)
#   GEOCHAT_PREFIX       user install prefix      (default: ~/.local/opt/geochat)
#   GEOCHAT_BIN_DIR      launcher directory       (default: ~/.local/bin)
#   GEOCHAT_DESKTOP_DIR  desktop-entry directory  (default: ~/.local/share/applications)
#   GEOCHAT_SUDO         command for root tasks   (default: sudo)
#
set -euo pipefail

INSTALL_TYPE="${INSTALL_TYPE:-user}"
GEOCHAT_DIR="${GEOCHAT_DIR:-$HOME/geochat}"
GEOCHAT_REPO_URL="${GEOCHAT_REPO_URL:-https://github.com/tiwe0/GeoChat.git}"
GEOCHAT_BRANCH="${GEOCHAT_BRANCH:-master}"
GEOCHAT_BUN_VERSION="${GEOCHAT_BUN_VERSION:-1.3.11}"
GEOCHAT_BUNDLES="${GEOCHAT_BUNDLES:-deb}"

usage() {
  sed -n '2,25p' "$0" | sed 's/^#\{1,2\} \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -system|--system) INSTALL_TYPE="system"; shift ;;
    -user|--user)     INSTALL_TYPE="user";   shift ;;
    -h|--help)        usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1 (use -user, -system, or -h)" >&2; exit 1 ;;
  esac
done

# Root privileges are needed for the build dependencies in both modes. The
# application itself only lands in a shared location for -system.
if [[ $EUID -eq 0 ]]; then
  SUDO=""
else
  SUDO="${GEOCHAT_SUDO:-sudo}"
fi

if [[ "$INSTALL_TYPE" == "system" ]]; then
  GEOCHAT_PREFIX="${GEOCHAT_PREFIX:-/opt/geochat}"
else
  GEOCHAT_PREFIX="${GEOCHAT_PREFIX:-$HOME/.local/opt/geochat}"
fi
GEOCHAT_BIN_DIR="${GEOCHAT_BIN_DIR:-$HOME/.local/bin}"
GEOCHAT_DESKTOP_DIR="${GEOCHAT_DESKTOP_DIR:-$HOME/.local/share/applications}"
GEOCHAT_ICON_DIR="${GEOCHAT_ICON_DIR:-$HOME/.local/share/icons/hicolor}"

log()  { printf '[geochat] %s\n' "$*"; }
warn() { printf '[geochat] warning: %s\n' "$*" >&2; }
die()  { printf '[geochat] error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Returns success when $1 is a version >= $2 (both plain dotted versions).
version_ge() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

# ---- System prerequisites --------------------------------------------------

require_debian() {
  have apt-get || die "this installer targets Debian-based Linux (apt-get not found)"
}

# Tauri 2 Linux prerequisites, plus the base tools needed to fetch sources and
# run the Bun/Rust toolchains. webkit2gtk-4.1 pulls libsoup-3.0 and
# javascriptcoregtk-4.1 with it.
ensure_system_packages() {
  local pkg missing=()
  for pkg in git curl ca-certificates file wget \
             build-essential pkg-config \
             libwebkit2gtk-4.1-dev libgtk-3-dev \
             libayatana-appindicator3-dev libxdo-dev libssl-dev librsvg2-dev; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    log "system build dependencies already present"
    return 0
  fi
  log "installing system build dependencies: ${missing[*]}"
  # A broken third-party repository makes `apt-get update` exit non-zero even
  # though the Debian/Ubuntu indexes we need were fetched; keep going and let
  # the install below surface any package that is genuinely unavailable.
  $SUDO apt-get update \
    || warn "apt-get update reported errors (a configured repository may be broken); continuing"
  $SUDO apt-get install -y "${missing[@]}"
}

# ---- Toolchains: Bun and Rust ----------------------------------------------

ensure_bun() {
  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:$PATH"
  if have bun && version_ge "$(bun --version)" "$GEOCHAT_BUN_VERSION"; then
    log "Bun $(bun --version) ready"
    return 0
  fi
  log "installing Bun $GEOCHAT_BUN_VERSION"
  curl -fsSL https://bun.sh/install | bash -s "bun-v$GEOCHAT_BUN_VERSION"
  export PATH="$BUN_INSTALL/bin:$PATH"
  have bun || die "Bun installation failed; see https://bun.sh/docs/installation"
  log "Bun $(bun --version) ready"
}

ensure_rust() {
  export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
  export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
  export PATH="$CARGO_HOME/bin:$PATH"
  if have cargo && have rustc; then
    log "Rust $(rustc --version) ready"
    return 0
  fi
  log "installing stable Rust toolchain via rustup"
  curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
  export PATH="$CARGO_HOME/bin:$PATH"
  have cargo || die "Rust installation failed; see https://rustup.rs"
  log "Rust $(rustc --version) ready"
}

# ---- Checkout and build ----------------------------------------------------

ensure_repo() {
  if [[ -d "$GEOCHAT_DIR/.git" ]]; then
    log "updating existing checkout at $GEOCHAT_DIR"
    git -C "$GEOCHAT_DIR" fetch --quiet origin "$GEOCHAT_BRANCH" \
      || warn "git fetch failed; using the local checkout"
    git -C "$GEOCHAT_DIR" merge --ff-only FETCH_HEAD >/dev/null 2>&1 \
      || warn "checkout is not fast-forwardable; using local state"
  elif [[ -e "$GEOCHAT_DIR" ]]; then
    die "$GEOCHAT_DIR exists but is not a git checkout"
  else
    log "cloning GeoChat into $GEOCHAT_DIR"
    git clone --depth 1 --branch "$GEOCHAT_BRANCH" "$GEOCHAT_REPO_URL" "$GEOCHAT_DIR"
  fi
}

install_js_deps() {
  log "installing JavaScript dependencies (bun install)"
  ( cd "$GEOCHAT_DIR" && bun install )
}

build_bundle() {
  local tauri_bin="$GEOCHAT_DIR/node_modules/.bin/tauri"
  log "building GeoChat bundle(s) '$GEOCHAT_BUNDLES'; the first Rust build can take 10-30 minutes"
  if [[ -x "$tauri_bin" ]]; then
    ( cd "$GEOCHAT_DIR" && "$tauri_bin" build --bundles "$GEOCHAT_BUNDLES" )
  else
    ( cd "$GEOCHAT_DIR" && bunx tauri build --bundles "$GEOCHAT_BUNDLES" )
  fi
}

locate_deb() {
  local deb_dir="$GEOCHAT_DIR/src-tauri/target/release/bundle/deb" found
  [[ -d "$deb_dir" ]] || die "no Debian bundle produced in $deb_dir"
  found="$(find "$deb_dir" -maxdepth 1 -name '*.deb' -printf '%T@ %p\n' \
    | sort -nr | head -n1 | cut -d' ' -f2-)"
  [[ -n "$found" && -f "$found" ]] || die "no .deb file found in $deb_dir"
  GEOCHAT_DEB="$found"
  log "built $GEOCHAT_DEB"
}

# ---- Installation ----------------------------------------------------------

install_user() {
  log "extracting the package into $GEOCHAT_PREFIX"
  rm -rf "$GEOCHAT_PREFIX"
  mkdir -p "$GEOCHAT_PREFIX"
  dpkg-deb -x "$GEOCHAT_DEB" "$GEOCHAT_PREFIX"

  local exe
  exe="$(find "$GEOCHAT_PREFIX/usr/bin" -maxdepth 1 -type f -perm -u+x 2>/dev/null | head -n1 || true)"
  [[ -n "$exe" && -x "$exe" ]] || die "no application executable found in the .deb payload"

  mkdir -p "$GEOCHAT_BIN_DIR"
  ln -sf "$exe" "$GEOCHAT_BIN_DIR/geochat"

  if [[ -d "$GEOCHAT_PREFIX/usr/share/icons/hicolor" ]]; then
    mkdir -p "$(dirname "$GEOCHAT_ICON_DIR")"
    cp -r "$GEOCHAT_PREFIX/usr/share/icons/hicolor/." "$GEOCHAT_ICON_DIR/"
  fi

  # Point Exec at the extracted binary so the relative resource lookup
  # ("../lib/GeoChat/_up_/dist") resolves. The Tauri-generated entry is not
  # reused because it carries the Cargo spike description and an empty
  # Categories field. On Linux Tauri names both the WM class and the installed
  # icon after the binary, so reuse that single name for both keys.
  local app_name
  app_name="$(basename "$exe")"
  mkdir -p "$GEOCHAT_DESKTOP_DIR"
  cat > "$GEOCHAT_DESKTOP_DIR/geochat.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GeoChat
Comment=Local-first AI math visualization workbench
Exec=$exe
Icon=$app_name
Terminal=false
Categories=Education;Science;Math;
StartupWMClass=$app_name
EOF
  chmod 644 "$GEOCHAT_DESKTOP_DIR/geochat.desktop"
  have update-desktop-database && update-desktop-database "$GEOCHAT_DESKTOP_DIR" >/dev/null 2>&1 || true

  log "installed application: $exe"
  log "installed launcher:    $GEOCHAT_BIN_DIR/geochat"
  log "installed desktop entry: $GEOCHAT_DESKTOP_DIR/geochat.desktop"
}

install_system() {
  log "installing the Debian package system-wide"
  $SUDO apt-get install -y "$GEOCHAT_DEB"
}

# ---- Main ------------------------------------------------------------------

# Testing hook: source the file with GEOCHAT_LIB_ONLY=1 to load the functions
# without running the install.
if [[ "${GEOCHAT_LIB_ONLY:-0}" == "1" ]]; then return 0 2>/dev/null || exit 0; fi

require_debian
ensure_system_packages
ensure_bun
ensure_rust
ensure_repo
install_js_deps
build_bundle
locate_deb

if [[ "$INSTALL_TYPE" == "system" ]]; then
  install_system
  cat <<EOF

============================================================
GeoChat is installed.

  checkout : $GEOCHAT_DIR
  package  : $GEOCHAT_DEB

Launch it from your application menu or by running:
  GeoChat
============================================================
EOF
else
  install_user
  cat <<EOF

============================================================
GeoChat is installed.

  checkout : $GEOCHAT_DIR
  package  : $GEOCHAT_DEB
  app      : $GEOCHAT_PREFIX
  launcher : $GEOCHAT_BIN_DIR/geochat

Launch it from your application menu or by running:
  geochat

Model provider API keys are configured inside the app's settings.
============================================================
EOF
  if [[ ":$PATH:" != *":$GEOCHAT_BIN_DIR:"* ]]; then
    echo "NOTE: add $GEOCHAT_BIN_DIR to your PATH to run 'geochat'."
  fi
fi
