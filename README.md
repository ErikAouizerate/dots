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
├── ansible.cfg
├── ansible/
│   ├── inventory.yml           localhost
│   ├── playbook.yml            the four roles, and the profile switch
│   └── roles/
│       ├── base/               CLI packages, mise, zsh/oh-my-zsh, Incus, login shell
│       ├── dotfiles/           the symlinks from both home trees into $HOME
│       ├── workstation/        the Fedora desktop layer (workstation only)
│       └── user_tools/         mise runtimes, opencode, plugin dependencies
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
change, it needs a new session: log out and back in after the first run.

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

miracle-wm and libinput-gestures exec the commands of their bindings without a
shell, so they expand neither `~` nor `$HOME`, and the compositor's PATH does not
contain `~/.local/bin`. The `wm-*` helpers are therefore linked into
`/usr/local/bin` as well and called by their bare name. No configuration file in
`home/` or `home-workstation/` carries a home path: they all resolve through
`~`, `$HOME` or a PATH lookup, so a machine where the user is not `riko` works
the same.

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
shellcheck -x install-fedora.sh home-workstation/.local/bin/wm-* home/.config/git/hooks/pre-push
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
  `opencode service set env <NAME> <value>`.
- VSCode extensions other than the ones listed in the `workstation` role.
- Flatpaks other than Bitwarden.
- The first `mise install` downloads the runtimes (around 1 GB).
