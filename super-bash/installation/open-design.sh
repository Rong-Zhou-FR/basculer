#!/usr/bin/env bash
#
# Open Design — one-click installer for Debian-based Linux.
#
# Sets up everything required to run Open Design's local dev stack with the
# OpenCode agent, then installs an `open-design` launcher on PATH.
#
#   ./open-design.sh            # user install (default)
#   ./open-design.sh -system    # system install (needs sudo)
#   ./open-design.sh -h
#
# Environment overrides:
#   OD_DIR           checkout directory      (default: ~/open-design)
#   OD_REPO_URL      git remote              (default: https://github.com/nexu-io/open-design.git)
#   OD_BRANCH        branch to install       (default: main)
#   OD_NODE_VERSION  Node major version      (default: 24)
#   OD_PNPM_VERSION  pnpm version            (default: 10.33.2)
#   OD_AGENT         agent preselected in app-config (default: opencode)
#   OD_BIN_DIR       launcher directory override (mainly for testing)
#   OD_DESKTOP_DIR   desktop-entry directory override (mainly for testing)
#
set -euo pipefail

INSTALL_TYPE="${INSTALL_TYPE:-user}"
OD_DIR="${OD_DIR:-$HOME/open-design}"
OD_REPO_URL="${OD_REPO_URL:-https://github.com/nexu-io/open-design.git}"
OD_BRANCH="${OD_BRANCH:-main}"
OD_NODE_VERSION="${OD_NODE_VERSION:-24}"
OD_PNPM_VERSION="${OD_PNPM_VERSION:-10.33.2}"
OD_AGENT="${OD_AGENT:-opencode}"
NVM_INSTALL_TAG="v0.40.8"

usage() {
  sed -n '2,21p' "$0" | sed 's/^#\{1,2\} \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -system|--system) INSTALL_TYPE="system"; shift ;;
    -user|--user)     INSTALL_TYPE="user";   shift ;;
    -h|--help)        usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1 (use -user, -system, or -h)" >&2; exit 1 ;;
  esac
done

if [[ "$INSTALL_TYPE" == "system" ]]; then
  BIN_DIR="${OD_BIN_DIR:-/usr/local/bin}"
  DESKTOP_DIR="${OD_DESKTOP_DIR:-/usr/share/applications}"
else
  BIN_DIR="${OD_BIN_DIR:-$HOME/.local/bin}"
  DESKTOP_DIR="${OD_DESKTOP_DIR:-$HOME/.local/share/applications}"
fi

SUDO=""
[[ $EUID -ne 0 ]] && SUDO="sudo"

log()  { printf '[open-design] %s\n' "$*"; }
warn() { printf '[open-design] warning: %s\n' "$*" >&2; }
die()  { printf '[open-design] error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---- System prerequisites --------------------------------------------------

require_debian() {
  [[ -f /etc/debian_version ]] || have apt-get \
    || die "this installer targets Debian-based Linux (apt-get not found)"
}

ensure_system_packages() {
  local pkg missing=()
  for pkg in git curl ca-certificates build-essential python3; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    log "system packages already present"
    return 0
  fi
  log "installing system packages: ${missing[*]}"
  $SUDO apt-get update
  $SUDO apt-get install -y "${missing[@]}"
}

# ---- Toolchain: Node 24, pnpm, OpenCode ------------------------------------

ensure_node() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    log "installing nvm $NVM_INSTALL_TAG"
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_INSTALL_TAG/install.sh" | bash
  fi
  # shellcheck disable=SC1090
  . "$NVM_DIR/nvm.sh"

  log "installing Node $OD_NODE_VERSION"
  nvm install "$OD_NODE_VERSION" >/dev/null
  nvm alias default "$OD_NODE_VERSION" >/dev/null

  # `nvm use` can silently no-op when ~/.npmrc sets a prefix, so resolve the
  # bin directory directly instead of trusting the active PATH.
  local node_bin
  node_bin="$(dirname "$(nvm which "$OD_NODE_VERSION")")"
  [[ -x "$node_bin/node" ]] || die "could not resolve the Node $OD_NODE_VERSION bin directory"
  export PATH="$node_bin:$PATH"
  log "Node $(node --version) ready"
}

ensure_pnpm() {
  export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
  if have corepack; then
    corepack enable >/dev/null 2>&1 || warn "corepack enable failed; will fall back to npm"
    corepack prepare "pnpm@$OD_PNPM_VERSION" --activate >/dev/null 2>&1 || warn "corepack prepare failed"
  fi
  if have pnpm; then
    log "pnpm $(pnpm --version 2>/dev/null) ready"
    return 0
  fi
  log "installing pnpm $OD_PNPM_VERSION via npm"
  npm install -g "pnpm@$OD_PNPM_VERSION"
  have pnpm || die "pnpm installation failed"
  log "pnpm $(pnpm --version) ready"
}

ensure_opencode() {
  export PATH="$HOME/.opencode/bin:$PATH"
  if have opencode; then
    log "OpenCode $(opencode --version 2>/dev/null || echo '?') already installed"
    return 0
  fi
  log "installing OpenCode CLI"
  curl -fsSL https://opencode.ai/install | bash
  export PATH="$HOME/.opencode/bin:$PATH"
  have opencode || die "OpenCode install failed; see https://opencode.ai/docs"
  log "OpenCode $(opencode --version 2>/dev/null || echo '?') ready"
}

# ---- Checkout and dependencies ---------------------------------------------

ensure_repo() {
  if [[ -d "$OD_DIR/.git" ]]; then
    log "updating existing checkout at $OD_DIR"
    git -C "$OD_DIR" fetch --quiet origin "$OD_BRANCH" || warn "git fetch failed; using local checkout"
    git -C "$OD_DIR" merge --ff-only FETCH_HEAD >/dev/null 2>&1 \
      || warn "checkout is not fast-forwardable; using local state"
  elif [[ -e "$OD_DIR" ]]; then
    die "$OD_DIR exists but is not a git checkout"
  else
    log "cloning Open Design into $OD_DIR"
    git clone --depth 1 --branch "$OD_BRANCH" "$OD_REPO_URL" "$OD_DIR"
  fi
}

ensure_node_pty() {
  if ( cd "$OD_DIR/apps/daemon" && node -e "require('node-pty')" >/dev/null 2>&1 ); then
    return 0
  fi
  local pty_dir
  pty_dir="$(cd "$OD_DIR" && node -e 'try{process.stdout.write(require("path").dirname(require.resolve("node-pty/package.json")))}catch{}' 2>/dev/null || true)"
  if [[ -z "$pty_dir" ]]; then
    warn "node-pty is not installed; the interactive Terminal feature will be unavailable"
    return 0
  fi
  log "building node-pty for the interactive Terminal feature"
  if ( cd "$pty_dir" && { node scripts/prebuild.js || npx --yes node-gyp rebuild; } ) >/dev/null 2>&1; then
    log "node-pty built"
  else
    warn "node-pty build failed; the interactive Terminal feature will be unavailable"
  fi
}

install_dependencies() {
  log "installing workspace dependencies (pnpm install)"
  ( cd "$OD_DIR" && pnpm install )
  log "building native dependencies for Node $(node --version)"
  ( cd "$OD_DIR" && pnpm --filter @open-design/daemon rebuild better-sqlite3 --pending )
  ensure_node_pty
}

preselect_agent() {
  local config="$OD_DIR/.od/app-config.json"
  if [[ -f "$config" ]]; then
    return 0
  fi
  mkdir -p "$OD_DIR/.od"
  printf '{\n  "agentId": "%s"\n}\n' "$OD_AGENT" > "$config"
  log "preselected agent: $OD_AGENT"
}

# ---- Launcher and desktop entry --------------------------------------------

install_launcher() {
  mkdir -p "$BIN_DIR"
  cat > "$BIN_DIR/open-design" <<LAUNCHER
#!/usr/bin/env bash
# Generated by super-bash/installation/open-design.sh
set -euo pipefail
OD_DIR="\${OD_DIR:-$OD_DIR}"
export NVM_DIR="\${NVM_DIR:-\$HOME/.nvm}"

if ! { command -v node >/dev/null 2>&1 && [ "\$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null)" = "$OD_NODE_VERSION" ]; }; then
  for candidate in "\$NVM_DIR"/versions/node/v$OD_NODE_VERSION.*/bin "\$HOME"/.local/share/fnm/node-versions/v$OD_NODE_VERSION.*/installation/bin; do
    if [ -x "\$candidate/node" ]; then PATH="\$candidate:\$PATH"; export PATH; break; fi
  done
fi
command -v node >/dev/null 2>&1 || { echo "Open Design requires Node $OD_NODE_VERSION on PATH" >&2; exit 1; }

export PATH="\$HOME/.opencode/bin:\$HOME/.local/bin:\$PATH"
cd "\$OD_DIR"

# Open the web UI once the dev server is ready (unless OD_NO_OPEN=1).
if [ "\${OD_NO_OPEN:-0}" != "1" ] && [ -n "\${DISPLAY:-}\${WAYLAND_DISPLAY:-}" ]; then
  (
    for _ in \$(seq 1 120); do
      web="\$(pnpm tools-dev status --json 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const i=s.indexOf("{");if(i<0)return;try{process.stdout.write(JSON.parse(s.slice(i)).apps?.web?.url||"")}catch{}})')"
      if [ -n "\$web" ]; then xdg-open "\$web" >/dev/null 2>&1 || true; break; fi
      sleep 1
    done
  ) &
fi

pnpm tools-dev run web "\$@"
LAUNCHER
  chmod +x "$BIN_DIR/open-design"
  log "installed launcher: $BIN_DIR/open-design"
}

install_desktop_entry() {
  mkdir -p "$DESKTOP_DIR"
  cat > "$DESKTOP_DIR/open-design.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Open Design
Comment=Local-first design product powered by OpenCode
Exec=$BIN_DIR/open-design
Terminal=true
Categories=Development;Graphics;
DESKTOP
  if [[ "$INSTALL_TYPE" == "system" ]]; then
    $SUDO chmod 644 "$DESKTOP_DIR/open-design.desktop"
  else
    chmod 644 "$DESKTOP_DIR/open-design.desktop"
  fi
  if have update-desktop-database; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi
  log "installed desktop entry: $DESKTOP_DIR/open-design.desktop"
}

# ---- Main ------------------------------------------------------------------

# Testing hook: source the file with OD_LIB_ONLY=1 to load the functions
# without running the install.
if [[ "${OD_LIB_ONLY:-0}" == "1" ]]; then return 0 2>/dev/null || exit 0; fi

require_debian
ensure_system_packages
ensure_node
ensure_pnpm
ensure_opencode
ensure_repo
install_dependencies
preselect_agent
install_launcher
install_desktop_entry

cat <<EOF

============================================================
Open Design is installed.

  checkout : $OD_DIR
  launcher : $BIN_DIR/open-design

Next steps:
  1. Sign in to OpenCode (one time):
       opencode auth login
     or run 'opencode' and use the /connect command.
  2. Launch Open Design:
       open-design
============================================================
EOF

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "NOTE: add $BIN_DIR to your PATH to run 'open-design'."
fi
