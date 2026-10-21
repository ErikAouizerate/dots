#!/usr/bin/env bash
#
# Set up the Kali VM: the command line toolchain (mise, node, pi), the directory
# shared with the host, and the two desktop tweaks that keep the host usable
# while the VM console has the focus.
#
#   curl -fsSL https://github.com/ErikAouizerate/dots/raw/main/kali/kali-install.sh | bash
#   ./kali/kali-install.sh            # from a checkout of the repository
#   ./kali/kali-install.sh --no-gui   # toolchain and share only
#
# Run it as the desktop user of the VM: sudo is used where it is needed.
# Re-running it converges the VM again, so it is also the update command.
set -euo pipefail

# virtiofs tag the host exports to this VM (see the virtiofs share script the
# host runs, or the README); the directory is mounted at ~/host.
SHARE_TAG="host"
NODE_VERSION="24"

usage() {
  cat <<'EOF'
Usage: kali-install.sh [--no-gui]

  --no-gui   Skip the two desktop tweaks (host Super key, Alt+Enter terminal).
             They need a running X11 session inside the VM, so this is for a
             machine configured over SSH.

Re-running the script is how the VM is updated: every step is idempotent.
EOF
}

say() { printf '\n==> %s\n' "$*"; }

gui=1
case "${1:-}" in
  --no-gui) gui=0 ;;
  -h | --help)
    usage
    exit 0
    ;;
  "") ;;
  *)
    echo "Unknown argument: $1" >&2
    usage >&2
    exit 2
    ;;
esac

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this script as your normal user: sudo is used where needed." >&2
  exit 1
fi

# Piped through curl, stdin is the script itself, so sudo would have no
# terminal to ask its password on. /dev/tty keeps the one-line install working.
if [ ! -t 0 ] && [ -c /dev/tty ]; then
  exec </dev/tty
fi

if [ ! -r /etc/os-release ]; then
  echo "Cannot read /etc/os-release: unsupported system." >&2
  exit 1
fi
distro_id="$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"')"
if [ "$distro_id" != "kali" ]; then
  echo "Unsupported distribution: ${distro_id:-unknown} (this script configures the Kali VM)." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Toolchain
# ---------------------------------------------------------------------------
say "Toolchain: mise, node $NODE_VERSION, pi"

sudo apt-get update
sudo apt-get install -y --no-install-recommends ca-certificates curl git jq

# mise installs into ~/.local/bin and is not packaged by Kali. It owns node the
# same way the Fedora machines use it (home/.config/mise/config.toml), but this
# VM is left independent of the dotfiles: the version is pinned here instead.
export PATH="$HOME/.local/bin:$PATH"
if ! command -v mise >/dev/null 2>&1; then
  curl -fsSL https://mise.run | sh
fi

mise use --global --yes "node@$NODE_VERSION" >/dev/null

# pi has a managed install under ~/.pi that links ~/.local/bin/pi, which is the
# installation its own quickstart documents for Linux.
if [ ! -x "$HOME/.local/bin/pi" ]; then
  curl -fsSL https://pi.dev/install.sh | sh
fi

# Neither ~/.local/bin nor mise's shims reach a shell that does not activate
# mise, so the PATH entry goes into the shell's own rc file. A shell opened
# before this run does not have it yet.
shell_rc="$HOME/.bashrc"
case "$(basename "${SHELL:-}")" in
  zsh) shell_rc="$HOME/.zshrc" ;;
esac
if ! grep -qF "dots: kali toolchain" "$shell_rc" 2>/dev/null; then
  cat >>"$shell_rc" <<'EOF'

# dots: kali toolchain (mise shims, and ~/.local/bin for mise and pi)
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
EOF
  echo "    PATH block added to $shell_rc (new shells only)"
fi

# ---------------------------------------------------------------------------
# Directory shared with the host
# ---------------------------------------------------------------------------
say "Shared directory ~/host (virtiofs tag '$SHARE_TAG')"

# The host side lives in the VM definition (a <filesystem> device), the guest
# side is this fstab entry: nofail so that a VM started without the share still
# boots, and the tag rather than a device path because virtiofs has no /dev
# node to point at.
share_entry="$SHARE_TAG $HOME/host virtiofs defaults,nofail 0 0"
if ! grep -qxF "$share_entry" /etc/fstab 2>/dev/null; then
  printf '%s\n' "$share_entry" | sudo tee -a /etc/fstab >/dev/null
  echo "    fstab entry added"
fi
mkdir -p "$HOME/host"
if mountpoint -q "$HOME/host"; then
  echo "    already mounted"
elif ! sudo mount "$HOME/host"; then
  echo "    mount failed: does the host VM definition export the '$SHARE_TAG' tag?" >&2
fi

# ---------------------------------------------------------------------------
# Desktop tweaks
# ---------------------------------------------------------------------------
if [ "$gui" -eq 0 ]; then
  printf '\n==> Desktop tweaks skipped (--no-gui)\n'
  exit 0
fi

if [ "${XDG_SESSION_TYPE:-}" != "x11" ]; then
  echo >&2
  echo "==> No X11 session: run this script again from the VM desktop to apply" >&2
  echo "    the Super key and the Alt+Enter terminal." >&2
  exit 0
fi

# The Super key belongs to the host: leaving it to the VM makes the compositor
# of the host lose it entirely, because virt-manager forwards the key but the
# guest answers first. Dropping the keysym is not enough on its own, the keycode
# stays in the mod4 modifier list where any "Mod4+key" binding still fires.
say "Host keeps the Super key"
super_code="$(xmodmap -pk | awk '/Super_L/ {print $1; exit}')"
if [ -n "$super_code" ]; then
  xmodmap -e "keycode $super_code = NoSymbol"
  xmodmap -e "clear mod4"

  # The session's keymap is rewritten at login, so the same two commands are
  # replayed by an XFCE autostart entry.
  autostart="$HOME/.config/autostart/host-super-key.desktop"
  mkdir -p "$(dirname "$autostart")"
  cat >"$autostart" <<EOF
[Desktop Entry]
Type=Application
Name=Let the host handle the Super key
Comment=Super_L becomes NoSymbol and mod4 is cleared, so the host compositor sees Super again
Exec=sh -c 'xmodmap -e "keycode $super_code = NoSymbol"; xmodmap -e "clear mod4"'
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
  echo "    Super neutralized (keycode $super_code, replayed at login)"
else
  echo "    Super_L not found in the current keymap, nothing to do" >&2
fi

# Alt is not bound by the host compositor, so Alt+Enter is a free shortcut for
# the VM's own terminal, alongside the Super shortcuts the VM no longer has.
say "Alt+Enter opens a terminal"
shortcut="/commands/custom/<Alt>Return"
# -n fails when the property already exists, in which case it is just updated.
if ! xfconf-query -c xfce4-keyboard-shortcuts -p "$shortcut" -n -t string \
  -s "exo-open --launch TerminalEmulator" 2>/dev/null; then
  xfconf-query -c xfce4-keyboard-shortcuts -p "$shortcut" \
    -s "exo-open --launch TerminalEmulator"
fi
echo "    Alt+Enter -> $(xfconf-query -c xfce4-keyboard-shortcuts -p "$shortcut" -v)"

printf '\n==> Done\n'
echo "    Super does nothing inside this VM any more: it is the host's key."
echo "    Alt+Enter opens the VM terminal; the host does not bind Alt."
echo "    Open a new shell to pick up the PATH block."
