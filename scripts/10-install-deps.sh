#!/usr/bin/env bash
# Install build + runtime dependencies with pacman (needs sudo). Arch-based only.
#   --build-only   only what is needed to compile
#   --no-extras    skip the optional CLI tools Omarchy's bash config uses
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BUILD_ONLY=0; EXTRAS=1
for a in "$@"; do case "$a" in --build-only) BUILD_ONLY=1 ;; --no-extras) EXTRAS=0 ;; *) die "unknown option $a" ;; esac; done

# Compile-time tools + the libraries Hyprland 0.57.x links against
# (this list is `pacman -Si hyprland` "Depends On", minus the soname entries).
BUILD_PKGS=(
  base-devel git cmake ninja pkgconf
  hyprwayland-scanner hyprland-protocols glaze
  aquamarine hyprutils hyprlang hyprcursor hyprgraphics hyprwire hyprland-guiutils
  cairo glib2 glslang lcms2 libcanberra libdrm libei libglvnd libinput libx11 libxcb
  libxcomposite libxcursor libxfixes libxkbcommon libxrender lua mesa muparser pango pixman
  re2 sdbus-cpp tomlplusplus util-linux-libs wayland wayland-protocols xorg-xwayland
  xcb-proto xcb-util xcb-util-errors xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm
)
# Needed at runtime for the Omarchy-style desktop (shell, launching, logout).
RUNTIME_PKGS=( uwsm quickshell foot grim slurp wl-clipboard wireplumber )
# Prompt theme, `z`, and the aliases in Omarchy's bash config.
EXTRA_PKGS=( starship zoxide eza bat fd fzf ripgrep )

PKGS=("${BUILD_PKGS[@]}")
if [ "$BUILD_ONLY" -eq 0 ]; then PKGS+=("${RUNTIME_PKGS[@]}"); [ "$EXTRAS" -eq 1 ] && PKGS+=("${EXTRA_PKGS[@]}"); fi

say "Installing ${#PKGS[@]} packages (already-installed ones are skipped)"
as_root pacman -S --needed "${PKGS[@]}"
say "done"
