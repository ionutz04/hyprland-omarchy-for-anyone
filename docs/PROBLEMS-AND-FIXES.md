# Problems we hit, and what fixed them

Each entry: **symptom -> evidence -> fix -> confidence**. "Confidence" is honest: some fixes were
applied together, so we could not always tell which one mattered.

---

## 1. Hyprland crashes at login: `CBackend::create() failed!`

**Symptom.** Pick Hyprland at the login screen, get bounced back to the greeter. No useful message.
`~/.xsession-errors` only says `terminate called ... CBackend::create() failed!`.

**Evidence.**
- Hyprland's own log is empty after the crash. The *crash report* in `~/.cache/hyprland/` contains a
  "Log tail" with the real error. Read that first.
- Early on the failure was `libseat: Could not take control of session: Device or resource busy`.
- After pinning the GPU to the seat, the log showed the seat opened fine and aquamarine's seat
  filtering worked (it skipped the other seats' cards), then:
  `libseat/backend/logind.c: Could not take device: Device or resource busy` on the seat's own card.
  logind returns `EBUSY` when something else still holds DRM master on the device.
- Upstream aquamarine **already** filters DRM devices by seat (`src/backend/drm/DRM.cpp`), so a
  "use the seat's GPU by default" patch would be a no-op. The failure is later, when opening the device.

**Fix.** `patches/aquamarine/0001-...patch`: on `EBUSY`, retry `libseat_open_device` every 100 ms for up
to 15 s (dispatching libseat events meanwhile), logging `... is busy, waiting` and
`... became available after ~Nms`. The launcher also sets `AQ_DRM_DEVICES` to the seat's own card(s).

**Confidence: medium.** Login worked after the patch and the other fixes landed together; we did not
test each alone. Our reading is a timing race: Hyprland starts instantly after the greeter hands the GPU
over, whereas Plasma needs seconds before kwin asks for it. We never *observed* the holder. If the
retry log lines appear in your crash report/log, that confirms the race on your machine.

## 2. Environment variables never reached the session (zsh login shell)

**Symptom.** `AQ_DRM_DEVICES` and `OMARCHY_PATH` set in `~/.profile` had no effect.

**Evidence.** `/etc/lightdm/Xsession` does `exec $SHELL --login`. For zsh that branch reads
`~/.zprofile` and **never `~/.profile`**.

**Fix.** `40-install-user.sh` puts the variables in `~/.profile` and bridges `~/.zprofile` (and an
existing `~/.bash_profile`) to it. The launcher additionally computes `AQ_DRM_DEVICES` itself, so GPU
selection does not depend on dotfiles at all.

**Confidence: high** for the diagnosis (read from the wrapper); which fix mattered for login is entangled with #1.

## 3. Session file works only without quotes in `Exec=`

**Symptom.** Instant bounce to the greeter; `~/.xsession-errors` shows
`uwsm: error: unrecognized arguments: fork via uwsm"`.

**Evidence.** `-C "Hyprland fork via uwsm"` in `Exec=`: lightdm splits on spaces and ignores quotes.

**Fix.** No quoted arguments in `files/hyprland-fork.desktop.in` (the cosmetic `-N`/`-C` are dropped).

**Confidence: high.**

## 4. Can log in, but cannot open apps or log out: `uwsm` missing

**Symptom.** Hyprland and the Omarchy bar are up, but `SUPER+RETURN` does nothing and "Logout" does nothing.

**Evidence.** Omarchy's `o.launch()` is literally `"uwsm-app -- " .. command`
(`default/hypr/helpers.lua`), and `omarchy system logout` runs `uwsm stop`. 41 of its scripts reference
uwsm. `which uwsm` found nothing.

**Fix.** Install `uwsm` and start the compositor through it (`uwsm start ... -F -- <launcher>`).
Readiness: uwsm's compositor unit is `Type=notify`; Omarchy's autostart runs
`dbus-update-activation-environment --systemd --all`, which puts `WAYLAND_DISPLAY` in the systemd
environment, which is what uwsm waits for, so no `uwsm finalize` is needed (and `-g -1` disables the
wait warning, as Omarchy's own session does).

**Confidence: high.** After installing uwsm and fixing #3, apps opened and logout worked.

Switching between KDE and this session: uwsm refuses to start if `graphical-session.target` is still
active (e.g. a leftover session keeps your user manager alive). Log out fully first.

## 5. Hyprland has its install prefix compiled in

A binary built with `-DCMAKE_INSTALL_PREFIX=$HOME/...` and then copied elsewhere still looks for its
data under the old prefix. `20-build.sh` therefore builds with the **final** prefix (`/opt/hyprland-fork`)
and stages with `DESTDIR`.

## 6. Omarchy's first-run provisioning rewrites unrelated files in your home

**Symptom.** After the first Hyprland login, files you never asked about had changed.

**Evidence** (files newer than the login): `~/.XCompose`, `~/.config/alacritty/alacritty.toml`,
`~/.config/xdg-terminals.list`, `~/.config/user-dirs.dirs`, GTK bookmarks, KDE `ksmserverrc`,
`~/.claude|.codex|.hermes|.pi|.agents` skill folders, Chromium/Chrome native-messaging host files,
`~/.config/btop/themes`, ... Triggered by `omarchy-provision-first-run` in Omarchy's Hyprland autostart.

**Fix.** The script is once-per-user and checks the marker `~/.local/state/omarchy/done/first-run-user`
(via `omarchy-done`). `40-install-user.sh` creates that marker. It prints
"One or more first-run steps failed; first-run will retry next login" in its log when a step fails,
so without the marker it can keep re-running every login.

**Confidence: high** that the script made those changes; **untested** that pre-marking it first on a
brand-new account leaves nothing important undone.

## 7. `~/.XCompose` points at a path that does not exist

First-run writes `include "/usr/share/omarchy/default/xcompose"`. Omarchy is not installed system-wide
here, so KDE and other apps log `failed to open included Compose file`. Only matters if first-run ran.
Fix: edit that line to point at `~/.local/share/omarchy/default/xcompose`, or delete `~/.XCompose`.

## Notes for LDAP / pam_mount setups

`uwsm` runs after login inside the systemd user manager and does not touch PAM, LDAP or mounts. Things
to keep in mind: the user manager is per user (not per seat), and `pam_mount` cannot unmount folders
that something still holds open at logout.

## Where to look when it breaks

| What | Where |
|---|---|
| Real Hyprland error | the "Log tail" in `~/.cache/hyprland/hyprlandCrashReport*.txt` |
| What lightdm ran | `~/.xsession-errors` and `~/.xsession-errors.old` (previous session) |
| uwsm units | `journalctl --user -u 'wayland-wm@*'` |
| Omarchy shell | `journalctl --user -t omarchy-shell` |
| Which seat/GPU | `loginctl list-seats`, `udevadm info -q property -n /dev/dri/card0 \| grep ID_SEAT` |

Tip: Hyprland disables stdout logging after the config loads. For debugging, put
`hl.config({ debug = { enable_stdout_logs = true } })` in `~/.config/hypr/hyprland.lua`.
