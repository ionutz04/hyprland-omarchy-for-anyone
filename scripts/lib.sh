#!/usr/bin/env bash
# Shared settings and helpers. Sourced by the other scripts; not run directly.

# ---- Pinned versions (the combination that was actually tested) -------------
HYPRLAND_REF="${HYPRLAND_REF:-v0.57.2}"
AQUAMARINE_REF="${AQUAMARINE_REF:-v0.16.0}"
OMARCHY_REF="${OMARCHY_REF:-7df5d4f8f36922f537dfe6cda4161a01f4d8b227}"

# ---- Locations ----------------------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# System-wide install prefix. Hyprland bakes this path into the binary at build
# time, so changing it means rebuilding (scripts/20-build.sh does that for you).
PREFIX="${PREFIX:-/opt/hyprland-fork}"
BUILD_DIR="${BUILD_DIR:-$REPO_DIR/build}"
OMARCHY_DIR="${OMARCHY_DIR:-$HOME/.local/share/omarchy}"
SESSION_FILE="/usr/share/wayland-sessions/hyprland-fork.desktop"

# ---- Helpers ------------------------------------------------------------------
say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

# Run a command as root, via sudo. Refuses to run as root itself so that user
# files never end up owned by root.
as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    die "run this script as your normal user (it calls sudo where needed)"
  fi
  need_cmd sudo
  sudo "$@"
}

# Back a file up once, next to itself, with a timestamp. No-op if it doesn't exist.
backup() {
  local f="$1"
  [ -e "$f" ] || return 0
  local b="$f.bak-$(date +%Y%m%d-%H%M%S)"
  cp -a "$f" "$b" && say "backed up $f -> $b"
}

# Insert or replace a managed block in a file:  put_block <file> <name> <content>
# Blocks are delimited by "# >>> name >>>" / "# <<< name <<<" so re-running is safe
# and uninstall.sh can remove exactly what we added.
put_block() {
  local file="$1" name="$2" content="$3"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  remove_block "$file" "$name"
  { printf '\n# >>> %s >>>\n%s\n# <<< %s <<<\n' "$name" "$content" "$name"; } >> "$file"
}

remove_block() {
  local file="$1" name="$2"
  [ -f "$file" ] || return 0
  local tmp
  tmp="$(mktemp)"
  awk -v s="# >>> $name >>>" -v e="# <<< $name <<<" '
    $0==s {skip=1; next}
    $0==e {skip=0; next}
    !skip {print}
  ' "$file" > "$tmp" && cat "$tmp" > "$file"
  rm -f "$tmp"
}
