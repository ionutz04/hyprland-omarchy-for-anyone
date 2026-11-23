#!/usr/bin/env bash
# Per-user setup: Omarchy's Hyprland config + bash config, for THIS user only. No sudo.
#
# Deliberately does NOT install Omarchy's apps/packages. It takes only:
#   * the Hyprland config (keybinds, look, window rules)  -> ~/.config/hypr
#   * the shell (bar, menus, themes) and helper scripts    -> ~/.local/share/omarchy (a clone)
#   * the bash config (aliases, prompt, zoxide, fzf)       -> block in ~/.bashrc
#
# Options:
#   --bash-handoff     make interactive zsh start bash (for accounts where `chsh` is not allowed)
#   --no-skip-first-run  let Omarchy's own first-run provisioning run (see docs/PROBLEMS-AND-FIXES.md #6)
#   --force-hypr       replace an existing ~/.config/hypr (it is backed up first)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

HANDOFF=0; SKIP_FIRST_RUN=1; FORCE_HYPR=0
for a in "$@"; do case "$a" in
  --bash-handoff) HANDOFF=1 ;; --no-skip-first-run) SKIP_FIRST_RUN=0 ;; --force-hypr) FORCE_HYPR=1 ;;
  *) die "unknown option $a" ;; esac; done
[ "$(id -u)" -ne 0 ] || die "run as your normal user, not root"
need_cmd git

# ---- 1. Omarchy checkout (pinned) ------------------------------------------------
if [ -d "$OMARCHY_DIR/.git" ]; then
  have="$(git -C "$OMARCHY_DIR" rev-parse HEAD)"
  [ "$have" = "$OMARCHY_REF" ] && say "Omarchy already at pinned $OMARCHY_REF" \
    || warn "Omarchy at $have, not the tested $OMARCHY_REF (leaving it alone)"
else
  say "cloning Omarchy @ $OMARCHY_REF -> $OMARCHY_DIR"
  mkdir -p "$OMARCHY_DIR"
  git -C "$OMARCHY_DIR" init -q
  git -C "$OMARCHY_DIR" remote add origin https://github.com/basecamp/omarchy
  git -C "$OMARCHY_DIR" fetch -q --depth 1 origin "$OMARCHY_REF"
  git -C "$OMARCHY_DIR" checkout -q FETCH_HEAD
fi

# ---- 2. Hyprland config -----------------------------------------------------------
HYPR="$HOME/.config/hypr"
if [ -e "$HYPR/hyprland.lua" ] && [ "$FORCE_HYPR" -eq 0 ]; then
  warn "$HYPR/hyprland.lua exists; keeping it (use --force-hypr to replace)"
else
  [ -e "$HYPR" ] && { backup "$HYPR"; rm -rf "$HYPR"; }
  mkdir -p "$HYPR"
  cp -r "$OMARCHY_DIR/config/hypr/." "$HYPR/"
  say "Hyprland config -> $HYPR"
fi

# ---- 3. bash config (managed block; your existing ~/.bashrc stays) ---------------------
backup "$HOME/.bashrc"
put_block "$HOME/.bashrc" "hyprland-omarchy-for-anyone" 'if [[ $- == *i* ]]; then
  export OMARCHY_PATH="$HOME/.local/share/omarchy"
  export PATH="$OMARCHY_PATH/bin:$HOME/.local/bin:$PATH"
  source "$OMARCHY_PATH/default/bash/envs"
  source "$OMARCHY_PATH/default/bash/shell"
  source "$OMARCHY_PATH/default/bash/aliases"
  source "$OMARCHY_PATH/default/bash/functions"
  source "$OMARCHY_PATH/default/bash/init"
  bind -f "$OMARCHY_PATH/default/bash/inputrc"
fi'

# ---- 4. login environment ---------------------------------------------------------------
# lightdm's Xsession runs your login shell as a LOGIN shell. bash reads ~/.profile (if there is
# no ~/.bash_profile); zsh reads ONLY ~/.zprofile and never ~/.profile. So bridge them.
PROFILE_BODY='export OMARCHY_PATH="$HOME/.local/share/omarchy"
case ":$PATH:" in *":$OMARCHY_PATH/bin:"*) ;; *) export PATH="$OMARCHY_PATH/bin:$HOME/.local/bin:$PATH" ;; esac'
backup "$HOME/.profile"; put_block "$HOME/.profile" "hyprland-omarchy-for-anyone" "$PROFILE_BODY"
BRIDGE='[ -f "$HOME/.profile" ] && . "$HOME/.profile"'
[ -f "$HOME/.bash_profile" ] && { backup "$HOME/.bash_profile"; put_block "$HOME/.bash_profile" "hyprland-omarchy-for-anyone" "$BRIDGE"; }
case "${SHELL:-}" in */zsh) backup "$HOME/.zprofile"; put_block "$HOME/.zprofile" "hyprland-omarchy-for-anyone" "$BRIDGE" ;; esac

# ---- 5. optional: zsh -> bash -----------------------------------------------------------
if [ "$HANDOFF" -eq 1 ]; then
  backup "$HOME/.zshrc"
  put_block "$HOME/.zshrc" "hyprland-omarchy-for-anyone" '# Use bash as the effective shell when chsh is unavailable. NO_BASH_HANDOFF=1 zsh to bypass.
if [[ -o interactive && -z "$BASH_VERSION" && -z "$NO_BASH_HANDOFF" && -x /usr/bin/bash ]]; then
  exec /usr/bin/bash -l
fi'
fi

# ---- 6. prompt theme ----------------------------------------------------------------------
if [ -e "$HOME/.config/starship.toml" ]; then warn "~/.config/starship.toml exists; keeping it"
else mkdir -p "$HOME/.config"; cp "$OMARCHY_DIR/config/starship.toml" "$HOME/.config/starship.toml"; say "starship theme installed"; fi

# ---- 7. stop Omarchy's first-run provisioning from rewriting your home ------------------------
if [ "$SKIP_FIRST_RUN" -eq 1 ]; then
  mkdir -p "$HOME/.local/state/omarchy/done"; touch "$HOME/.local/state/omarchy/done/first-run-user"
  say "marked Omarchy first-run as done (it would otherwise edit XCompose, terminal configs, agent folders, ...)"
fi

say "done. Log out, choose \"Hyprland (fork, uwsm)\" at the login screen."
