#!/usr/bin/env bash
# Build patched aquamarine + Hyprland from upstream sources. No root needed.
# Output is staged under build/stage (nothing is installed yet; see 30-install-system.sh).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

for c in git cmake ninja g++ pkg-config; do need_cmd "$c"; done
pkg-config --exists hyprwayland-scanner 2>/dev/null || [ -e /usr/lib/cmake/hyprwayland-scanner ] || [ -e /usr/lib64/cmake/hyprwayland-scanner ] \
  || warn "hyprwayland-scanner not found; run scripts/10-install-deps.sh first"

SRC="$BUILD_DIR/src"; STAGE="$BUILD_DIR/stage"; JOBS="${JOBS:-$(nproc)}"
mkdir -p "$SRC" "$STAGE"

clone() { # clone <url> <ref> <dir> [extra git args...]
  local url="$1" ref="$2" dir="$3"; shift 3
  if [ -d "$dir/.git" ]; then
    say "reusing $dir (resetting to $ref)"
    git -C "$dir" fetch --depth 1 origin "refs/tags/$ref:refs/tags/$ref" 2>/dev/null || true
    git -C "$dir" checkout -q --force "$ref"
    git -C "$dir" clean -fdxq
    git -C "$dir" submodule update --init --depth 1 2>/dev/null || true
  else
    git clone --branch "$ref" --depth 1 "$@" "$url" "$dir"
  fi
}

# ---- aquamarine (patched) -----------------------------------------------------
say "aquamarine $AQUAMARINE_REF"
clone https://github.com/hyprwm/aquamarine "$AQUAMARINE_REF" "$SRC/aquamarine"
for p in "$REPO_DIR"/patches/aquamarine/*.patch; do
  say "applying $(basename "$p")"
  git -C "$SRC/aquamarine" apply "$p"
done
cmake -S "$SRC/aquamarine" -B "$SRC/aquamarine/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
cmake --build "$SRC/aquamarine/build" -j "$JOBS"
DESTDIR="$STAGE" cmake --install "$SRC/aquamarine/build" >/dev/null

# ---- Hyprland (unmodified upstream) --------------------------------------------
say "Hyprland $HYPRLAND_REF (this takes a while)"
clone https://github.com/hyprwm/Hyprland "$HYPRLAND_REF" "$SRC/Hyprland" --recurse-submodules --shallow-submodules
# The prefix is compiled into the binary (asset paths), so it must be the FINAL one.
cmake -S "$SRC/Hyprland" -B "$SRC/Hyprland/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
cmake --build "$SRC/Hyprland/build" -j "$JOBS"
DESTDIR="$STAGE" cmake --install "$SRC/Hyprland/build" >/dev/null

say "staged into $STAGE$PREFIX"
ls "$STAGE$PREFIX/bin" "$STAGE$PREFIX/lib" | sed 's/^/  /'
say "next: scripts/30-install-system.sh"
