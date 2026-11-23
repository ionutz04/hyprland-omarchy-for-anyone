#!/usr/bin/env bash
# Remove what these scripts added. Backups (*.bak-*) are left in place; nothing of yours is deleted
# except the managed blocks we wrote. Options: --user-only | --system-only | --purge-omarchy
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DO_USER=1; DO_SYS=1; PURGE=0
for a in "$@"; do case "$a" in --user-only) DO_SYS=0 ;; --system-only) DO_USER=0 ;; --purge-omarchy) PURGE=1 ;; *) die "unknown option $a" ;; esac; done

if [ "$DO_USER" -eq 1 ]; then
  for f in .bashrc .profile .bash_profile .zprofile .zshrc; do remove_block "$HOME/$f" "hyprland-omarchy-for-anyone"; done
  say "removed managed blocks from ~/.bashrc ~/.profile ~/.bash_profile ~/.zprofile ~/.zshrc"
  say "left in place: ~/.config/hypr, ~/.config/starship.toml, $OMARCHY_DIR (delete by hand, or use --purge-omarchy)"
  [ "$PURGE" -eq 1 ] && { rm -rf "$OMARCHY_DIR" "$HOME/.local/state/omarchy/done/first-run-user"; say "removed Omarchy checkout and first-run marker"; }
fi
if [ "$DO_SYS" -eq 1 ]; then
  as_root rm -f "$SESSION_FILE"; as_root rm -rf "$PREFIX"; say "removed $SESSION_FILE and $PREFIX"
fi
