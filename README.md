# dots

Sets up a Fedora machine from scratch: command line tools, zsh, the user's
configuration files and the MiracleWM desktop, with one command and an Ansible
playbook.

## Quick start

```sh
curl -fsSL https://github.com/ErikAouizerate/dots/raw/main/install-fedora.sh | bash
```

The default profile is `workstation` (graphical desktop). For a command line
only machine:

```sh
curl -fsSL https://github.com/ErikAouizerate/dots/raw/main/install-fedora.sh | bash -s -- vps
```

The `vps` profile installs the same command line tools but none of the
graphical layer: no package, no configuration for the compositor or the
desktop, and no starship, so the prompt is oh-my-zsh's own theme.

The script installs `ansible-core` and `git`, clones this repository into
`~/dots` and runs the playbook. Re-running it is the update command: the
playbook is idempotent and converges the machine again.

## How it works

- `home/` mirrors the home directory on every machine, and `home-workstation/`
  mirrors it on the workstation profile only. The `dotfiles` role walks both
  trees and symlinks **every** file it finds to the same relative path in
  `$HOME`, so `home-workstation/.config/starship.toml` becomes
  `~/.config/starship.toml`.
- A file that this repository does not manage yet (a hand-written `~/.zshrc`,
  for instance) is moved to `<file>.bak.<YYYYMMDD-HHMM>` before the link is
  created. Nothing is deleted.
- Configuration drifts between machines, and that is accepted: editing
  `~/.zshrc` edits the file in the repository, and the change can be committed
  from there.
- Everything else is Ansible: packages, third-party repositories, `dconf`
  settings, VSCode extensions.

## Layout

```
dots/
├── install-fedora.sh           bootstrap: Ansible, checkout, playbook
├── CHEATSHEET.md               the installed CLI tools, one page
├── kali/kali-install.sh        the Kali VM: toolchain, share, desktop tweaks
├── ansible.cfg
├── ansible/
│   ├── inventory.yml           localhost
│   ├── playbook.yml            the four roles, and the profile switch
│   └── roles/
│       ├── base/               CLI packages, mise, zsh/oh-my-zsh, Incus, login shell
│       ├── dotfiles/           the symlinks from both home trees into $HOME
│       ├── workstation/        the Fedora desktop layer (workstation only)
│       └── user_tools/         mise runtimes, opencode, coi, plugin dependencies
├── home/                       mirrors $HOME on every machine, file by file
│   ├── .zshrc
│   ├── .zshenv
│   ├── .gitconfig
│   └── .config/
│       ├── mise/config.toml    python, uv, node, yarn, pnpm, rust, ouch
│       ├── git/hooks/pre-push  secret guardrail, wired by core.hooksPath
│       └── opencode/           agents, skills, local plugin
└── home-workstation/           mirrors $HOME on the workstation profile only
    ├── .config/
    │   ├── starship.toml       prompt
    │   ├── miracle-wm/         compositor keybindings
    │   ├── miracle-wm.config   Mir configuration
    │   ├── libinput-gestures.conf
    │   ├── xdg-terminals.list  default terminal (ptyxis)
    │   └── Code/User/          VSCode settings and keybindings
    └── .local/
        ├── bin/                wm-* compositor helpers
        └── share/applications/ baobab desktop entry
```

`CHEATSHEET.md` is the page to keep at hand: what each CLI tool is for and the
few commands that cover most of the usage — `tldr`, `rg`, `bat`, `tree`, `eza`,
`htop`, `fd`, `fzf`, `zoxide`, `ouch`, `jq`, `direnv` and `gitleaks`. The tools
that this repository does not install (`eza`, `zoxide`) are marked as such.

## Profiles

| Profile | What it adds |
| --- | --- |
| `workstation` | the MiracleWM desktop layer: Brave, Chrome, Sublime Text, VLC, ptyxis, wtype, baobab, Virtual Machine Manager (KVM/QEMU), FiraCode Nerd Font, libinput-gestures, starship, Bitwarden (Flatpak), the Ptyxis `dconf` settings, the DankMaterialShell layout and the VSCode extensions |
| `vps` | nothing beyond `base`, `dotfiles` and `user_tools`: no graphical package and none of the configuration in `home-workstation/`. starship is not installed either, so the prompt is the plain oh-my-zsh theme |

The `workstation` profile expects the **Fedora MiracleWM spin** as its base: it
installs everything around the desktop but not the compositor, DankMaterialShell
or their session scripts. The spin's shell therefore keeps its own look unless
the role patches it: `~/.config/DankMaterialShell/settings.json` is DMS's file,
rewritten by the shell as it is used, so it is not symlinked from the repository
but adjusted with `jq` on every run (`files/dms-settings.jq`): dock off, bar glued
to the screen edges, numbered workspaces, window title in the centre, disk usage
next to memory, 24-hour clock with a short date at the far right. DMS watches
that file and reloads it, so the layout applies without a relogin, and re-running
the playbook is how it is re-applied. The same goes for the clipboard history
(`clsettings.json`, 500 entries). A machine whose session has not started yet
has no `settings.json`: the run says so and skips, and the playbook can be run
again from the session.

Virtual Machine Manager comes with KVM/QEMU and the default libvirt network
(nat on `virbr0`), and the user is added to the `libvirt` group, so virt-manager
manages the system VMs without asking for the root password. Like any group
change, it needs a new session: log out and back in after the first run. The role
also patches the viewer so that the console leaves the keyboard to the desktop
(see [The Kali VM](#the-kali-vm)).

Incus is installed on every profile, `vps` included: the `base` role installs
it, enables its socket and instance startup, gives root the subordinate UID/GID
range containers are mapped to, and adds the user to `incus-admin`, which is
what makes `incus` work without `sudo`. On the first run it is initialised with
`incus admin init --minimal`: a `default` storage pool (btrfs when
`/var/lib/incus` sits on btrfs, the `dir` driver otherwise) and the `incusbr0`
bridge, attached to the default profile. A machine that already has a storage
pool is left alone, so a pool created by hand is never replaced. Group changes
need a new session, and the first login after the run is also the first time
`incus` can be used without `sudo`.

coi (Code on Incus) runs a coding agent in a disposable system container on top
of that Incus daemon, so it comes with `user_tools` and both profiles have it.
The role runs the project's installer unattended and as root: the installer
drives `sudo` for its system steps and reads the Incus version through it, which
an unattended run cannot do as a plain user. The binary therefore lands in
`/usr/local/bin`, like the `wm-*` helpers, and the storage step the installer
performs without asking applies too — a loop-backed `btrfs-pool` of half the
disk becomes the root device of the default Incus profile, which is what makes
its containers start in a fraction of a second. The one step left to the user is
the passwordless rule for `nft`: it is security-relevant, the installer asks
before adding it, and `coi health --fix` installs it — with the
`cap_linux_immutable` capability on the binary — when network isolation is
wanted. `coi build` builds the container image, `coi shell` starts a session,
`coi --help` lists the rest.

miracle-wm and libinput-gestures exec the commands of their bindings without a
shell, so they expand neither `~` nor `$HOME`, and the compositor's PATH does not
contain `~/.local/bin`. The `wm-*` helpers are therefore linked into
`/usr/local/bin` as well and called by their bare name. No configuration file in
`home/` or `home-workstation/` carries a home path: they all resolve through
`~`, `$HOME` or a PATH lookup, so a machine where the user is not `riko` works
the same.

## The Kali VM

The pentest VM runs on the workstation's libvirt and is deliberately outside this
playbook: it is Debian-based (every role here is `dnf`'s) and it does not read the
dotfiles. What it needs comes from `kali/kali-install.sh`, which is idempotent and
is also its update command:

```sh
curl -fsSL https://github.com/ErikAouizerate/dots/raw/main/kali/kali-install.sh | bash
./kali/kali-install.sh --no-gui     # from a checkout, without the desktop tweaks
```

It installs the toolchain (`mise`, node through mise, `pi`), mounts the directory
the host shares over virtiofs at `~/host`, and applies the two desktop tweaks
below. The share itself is declared on the host, in the VM definition: a
`<filesystem>` device of type `virtiofs` with the tag `host`, which is the tag the
script writes in `/etc/fstab`.

### Super belongs to the host

virt-manager's SPICE console grabs the keyboard while it has the focus, and that
grab is what makes the compositor ignore its own shortcuts. No preference exposes
it, so the `workstation` role inserts two lines into the viewer
(`/usr/share/virt-manager/virtManager/details/viewers.py`):

```python
display.set_property("grab-keyboard", False)
```

A virt-manager upgrade restores that file, and the next run of the playbook
patches it again. With the grab off, a key reaches the host **and** the guest, so
`Mod+Enter` opens the host terminal while the VM console has the focus. Two
consequences, both handled by `kali-install.sh` for the first and worth knowing
for the second:

- the guest has to give Super up, otherwise it answers its own `Mod4` bindings
  first. The script maps `Super_L` to `NoSymbol` **and** clears the `mod4`
  modifier (dropping the keysym alone leaves `Mod4+key` bindings working), then
  replays both at login from an XFCE autostart entry;
- the host's shortcuts stay live inside the VM window: `Mod+a` kills the focused
  window, which can be the console, and `Mod+1..9` switches workspaces.

The VM gets `Alt+Enter` for its own terminal instead: the host binds no `Alt`.

### Console scaling and the pointer

Three keys of virt-manager's `org.virt-manager.virt-manager.console` schema decide
how the console is drawn. They are preferences, so they are documented here and
not enforced by the role:

| Key | Values | Meaning |
| --- | --- | --- |
| `grab-keys` | string, empty by default | sequence that releases the keyboard (`Ctrl+Alt` when empty); not needed any more with the viewer patched |
| `scaling` | `0` never, `1` fullscreen only, `2` always | whether the framebuffer is scaled to fit the console window |
| `resize-guest` | `0` off, `1` on | whether the guest resolution follows the console window |

The workstation's panel is a 2880x1800 `eDP-1` at sway's scale 1.5, and that
fraction is what makes `scaling = 2` a bad trade here: GTK3 cannot express 1.5,
sway announces 2 to it and scales the surface itself, and spice-gtk rounds the
pointer coordinates of the windowed console — clicks land a few pixels off, and
are exact in fullscreen. The console is therefore used in fullscreen, with
`resize-guest` on so the guest keeps matching the window.

## Adding a configuration file

Put it in `home/` at the path it should have in `$HOME`. A file that only makes
sense on the graphical profile (the compositor, the terminal, VSCode) goes in
`home-workstation/` instead, and the vps profile never sees it. Nothing else to
do: the next run links it.

Packages and repositories go in `ansible/roles/*/defaults/main.yml`, which is
also where the VSCode extension list lives.

## Machine-specific settings

`~/.zshrc.local`, sourced by `~/.zshrc` when it exists, is not versioned. That
is where secrets, extra aliases and tools installed by hand belong.

## Working on the repository

```sh
shellcheck -x install-fedora.sh kali/kali-install.sh home-workstation/.local/bin/wm-* home/.config/git/hooks/pre-push
ansible-lint ansible/
ansible-playbook ansible/playbook.yml --syntax-check
```

Run from a checkout, `install-fedora.sh` configures **that** checkout instead of
cloning into `~/dots`, and everything after the profile is forwarded to
`ansible-playbook`, which makes a dry run easy:

```sh
./install-fedora.sh workstation --check --diff
./install-fedora.sh workstation --diff --tags dotfiles
```

## Not managed

- `~/.config/opencode/service.json`, which holds the service password. The
  tokens referenced as `{env:...}` in `opencode.json` are set per machine with
  `opencode service set env <NAME> <value>`.- VSCode extensions other than the ones listed in the `workstation` role.
- The Kali VM itself: `kali/kali-install.sh` sets it up, the playbook never
  touches it.
- Flatpaks other than Bitwarden.
- The first `mise install` downloads the runtimes (around 1 GB).
