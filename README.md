# hyprland-omarchy-for-anyone

Run **Hyprland with Omarchy's look, keybinds, themes and bash setup** on a machine that is *not* an
Omarchy install, as a normal user, without turning the machine (or your account) into an Omarchy
machine.

You get:

- Omarchy's **Hyprland config**: keybinds, gaps/borders, window rules, themes
- Omarchy's **shell** (Quickshell bar, menus, OSD, notifications, lock) and its helper scripts
- Omarchy's **bash config**: aliases, starship prompt, `z` (zoxide), fzf bindings
- A login-screen session, **"Hyprland (fork, uwsm)"**, that works for any user on the machine

You do **not** get Omarchy's bundled apps, its package set, or its installer.

## What is actually "forked"

| Component | State |
|---|---|
| **Hyprland** `v0.57.2` | **Unmodified upstream**, built from source only so it can live under its own prefix |
| **aquamarine** `v0.16.0` (Hyprland's backend library) | **One patch**: wait for the GPU instead of failing on `EBUSY` (`patches/aquamarine/`) |
| **Omarchy** `7df5d4f` | Cloned, unmodified, into `~/.local/share/omarchy` |

So this repo is a *patch set + install scripts + notes*, not a copy of Hyprland's source. If you want
real GitHub forks, fork `hyprwm/aquamarine`, apply the patch there, and point `20-build.sh` at it.

## Quick start (Arch-based distros)

```bash
scripts/00-check.sh            # read-only: what is already here?
scripts/10-install-deps.sh     # sudo pacman: build + runtime deps (incl. uwsm, quickshell)
scripts/20-build.sh            # no root: builds patched aquamarine + Hyprland into build/stage
scripts/30-install-system.sh   # sudo: installs to /opt/hyprland-fork, registers the login session
scripts/40-install-user.sh     # no root: Omarchy config + bash for THIS user only
# log out, pick "Hyprland (fork, uwsm)"
```

`40-install-user.sh` appends clearly-marked blocks to your dotfiles (it never replaces them), backs
up everything it touches, and is safe to re-run. `scripts/uninstall.sh` removes what was added.
Everything system-wide lives in `/opt/hyprland-fork` plus one file in `/usr/share/wayland-sessions/`.

Options: `40-install-user.sh --bash-handoff` (zsh users who cannot `chsh`), `--force-hypr`,
`--no-skip-first-run`. See the script header.

## Why each piece exists

Short version; the evidence is in [docs/PROBLEMS-AND-FIXES.md](docs/PROBLEMS-AND-FIXES.md).

1. **patched aquamarine**: on a multiseat / display-manager machine Hyprland died at login with
   `CBackend::create() failed!` because logind answered `EBUSY` for the seat's GPU.
2. **`uwsm`**: Omarchy launches every app with `uwsm-app` and logs out with `uwsm stop`. Without it you
   can log in but cannot open apps or log out.
3. **`uwsm start ...` session file**: lightdm ignores quotes in `Exec=`, so it has no quoted arguments.
4. **`~/.profile` bridged from `~/.zprofile`**: lightdm runs your login shell as a login shell; zsh never reads `~/.profile`.
5. **first-run marked done**: Omarchy's first-run provisioning edits many unrelated files in your home.

## What was tested, and what was not

Tested on **one machine**: CachyOS, lightdm, KDE Plasma as an alternative session, **multiseat**
(three seats, Intel Arc GPUs), LDAP login via PAM with `pam_mount` bind mounts, Hyprland 0.57.2.
On it: login works, apps open, logout works, the bash theme/`z`/fzf work.

Be aware of these gaps:

- **`20-build.sh` and `30-install-system.sh` have not been run end to end on a clean machine.** They
  automate steps that were done by hand on the tested machine. What *was* checked: the patch applies
  cleanly to upstream `v0.16.0`; every package name in the dependency list exists in the repos; all
  scripts pass `bash -n`; `40-install-user.sh` and `uninstall.sh` were run in a throwaway `$HOME`
  (twice, to check idempotence).
- **The aquamarine patch was never isolated.** Login started working after several changes landed
  together (patch, environment fixes, session file). The `EBUSY`-race explanation fits the logs but
  the process that held the GPU was never observed. On a normal single-seat machine you may not need the patch.
- **Marking first-run done *before* the first login is untested.** On the tested machine first-run had
  already run once. If something Omarchy-y is missing, delete
  `~/.local/state/omarchy/done/first-run-user`; be aware that it then edits files in your home.
- **Not Arch?** `10-install-deps.sh` is pacman-only. Everything else is distro-neutral.
- **Not tried:** stock distro `hyprland` package plus only the patched aquamarine via `LD_LIBRARY_PATH`
  (would avoid building Hyprland). The ABI should match; it is unverified.
- **`brightnessctl` / `playerctl`** were not installed on the tested machine, so brightness and media
  keys are unverified.

## Licensing

Hyprland and aquamarine are BSD-3-Clause; Omarchy is MIT. This repo contains only a patch against
aquamarine, scripts and notes. Licence for this repo is AGPL.

## Layout

```
scripts/   00-check  10-install-deps  20-build  30-install-system  40-install-user  uninstall  lib
files/     launcher + session-file templates (@PREFIX@ is substituted at install time)
patches/   aquamarine patch(es), applied by 20-build.sh
docs/      PROBLEMS-AND-FIXES.md  (symptom -> evidence -> fix -> how sure we are)
```
