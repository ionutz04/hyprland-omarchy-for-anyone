#!/usr/bin/env bash
# Read-only preflight. Changes nothing. Tells you what is already in place.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ok()   { printf '  [ ok ] %s\n' "$*"; }
miss() { printf '  [miss] %s\n' "$*"; }

say "Distribution"
if [ -r /etc/os-release ]; then . /etc/os-release; echo "  ${PRETTY_NAME:-unknown} (ID=${ID:-?}, ID_LIKE=${ID_LIKE:-})"; fi
case " ${ID:-} ${ID_LIKE:-} " in *arch*) ok "Arch-based: scripts supported" ;; *) warn "not Arch-based: 10-install-deps.sh will not work; build deps manually" ;; esac

say "Privileges"
if sudo -n true 2>/dev/null; then ok "passwordless sudo"; else warn "sudo needs a password (fine, you will be prompted) or is unavailable"; fi

say "Session stack"
for c in git cmake ninja gcc pkg-config uwsm quickshell starship zoxide; do
  command -v "$c" >/dev/null 2>&1 && ok "$c" || miss "$c"
done
for u in lightdm sddm gdm; do systemctl is-enabled "$u" >/dev/null 2>&1 && ok "display manager: $u"; done

say "Seats / GPUs (multiseat machines are the reason the patch exists)"
loginctl list-seats --no-legend 2>/dev/null | sed 's/^/  seat: /'
for c in /dev/dri/card*; do
  [ -e "$c" ] || continue
  s=$(udevadm info -q property -n "$c" 2>/dev/null | sed -n 's/^ID_SEAT=//p'); echo "  $c -> ${s:-seat0}"
done
echo "  this session: XDG_SEAT=${XDG_SEAT:-<unset>} XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-<unset>}"

say "Existing install state"
[ -d "$PREFIX" ]      && ok "$PREFIX present"      || miss "$PREFIX"
[ -f "$SESSION_FILE" ] && ok "$SESSION_FILE present" || miss "$SESSION_FILE"
[ -d "$OMARCHY_DIR" ] && ok "Omarchy at $OMARCHY_DIR" || miss "Omarchy at $OMARCHY_DIR"
