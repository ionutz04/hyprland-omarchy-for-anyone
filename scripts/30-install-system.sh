#!/usr/bin/env bash
# Install the staged build system-wide and register the login-screen session (needs sudo).
# System-wide on purpose: the session is meant to work for ANY user on the machine.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STAGE="$BUILD_DIR/stage"
[ -x "$STAGE$PREFIX/bin/Hyprland" ] || die "nothing staged; run scripts/20-build.sh first"
command -v uwsm >/dev/null 2>&1 || die "uwsm is required (Omarchy launches apps and logs out through it): scripts/10-install-deps.sh"
[ -d /usr/share/wayland-sessions ] || die "/usr/share/wayland-sessions missing: is a display manager installed?"

say "installing to $PREFIX"
as_root install -d "$PREFIX"
as_root cp -a --no-preserve=ownership "$STAGE$PREFIX/." "$PREFIX/"

say "installing launcher $PREFIX/bin/start-hyprland-fork"
tmp="$(mktemp)"; sed "s#@PREFIX@#$PREFIX#g" "$REPO_DIR/files/start-hyprland-fork.in" > "$tmp"
as_root install -m 755 "$tmp" "$PREFIX/bin/start-hyprland-fork"

say "registering session $SESSION_FILE"
sed "s#@PREFIX@#$PREFIX#g" "$REPO_DIR/files/hyprland-fork.desktop.in" > "$tmp"
as_root install -m 644 "$tmp" "$SESSION_FILE"
rm -f "$tmp"

"$PREFIX/bin/Hyprland" --version | head -1
say "done. Log out and pick \"Hyprland (fork, uwsm)\" at the login screen."
say "per-user setup (Omarchy config, bash): scripts/40-install-user.sh"
