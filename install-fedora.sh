#!/usr/bin/env bash
#
# Bootstrap a Fedora machine from the dots repository.
#
#   curl -fsSL https://github.com/ErikAouizerate/dots/raw/main/install-fedora.sh | bash
#   curl -fsSL https://github.com/ErikAouizerate/dots/raw/main/install-fedora.sh | bash -s -- vps
#
# The script only prepares the machine (Ansible and a checkout of this
# repository); Ansible does the actual configuration. Re-running it converges
# the machine again, so it is also the update command.
set -euo pipefail

REPO_URL="https://github.com/ErikAouizerate/dots.git"
DOTFILES_DIR="$HOME/.dotfiles"

usage() {
  cat <<'EOF'
Usage: install-fedora.sh [PROFILE] [ANSIBLE ARGS...]

PROFILE is one of:
  workstation   Graphical desktop (default)
  vps           Command line only

Everything after PROFILE is forwarded to ansible-playbook, which is handy on a
machine being tested:

  ./install-fedora.sh workstation --check --diff

Run from a checkout, the script configures that checkout instead of cloning
the repository into ~/.dotfiles.
EOF
}

profile="workstation"
if [ "$#" -gt 0 ]; then
  profile="$1"
  shift
fi

case "$profile" in
  workstation | vps) ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown profile: $profile" >&2
    usage >&2
    exit 2
    ;;
esac

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this script as your normal user: sudo is used where needed." >&2
  exit 1
fi

if [ ! -r /etc/os-release ]; then
  echo "Cannot read /etc/os-release: unsupported system." >&2
  exit 1
fi
distro_id="$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"')"
if [ "$distro_id" != "fedora" ]; then
  echo "Unsupported distribution: ${distro_id:-unknown} (this script supports Fedora only)." >&2
  exit 1
fi

echo "==> Installing Ansible and git"
sudo dnf install -y ansible-core git

# The script runs either from a checkout or piped through curl. When it is
# piped there is no path to the checkout, and the repository has to be cloned.
script_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -n "$script_dir" ] && [ -f "$script_dir/ansible/playbook.yml" ]; then
  repo_dir="$script_dir"
else
  repo_dir="$DOTFILES_DIR"
  if [ -d "$repo_dir/.git" ]; then
    echo "==> Updating $repo_dir"
    git -C "$repo_dir" pull --ff-only
  else
    echo "==> Cloning the repository into $repo_dir"
    git clone "$REPO_URL" "$repo_dir"
  fi
fi

ansible_args=(-e "profile=$profile" -e "dotfiles_repo_dir=$repo_dir")

# Ansible's become runs without a terminal, so it cannot reuse the sudo
# timestamp the dnf step above just cached: ask for the password again when
# the machine needs one. -K makes Ansible prompt on /dev/tty, which is why the
# script can still be piped into bash.
if ! sudo -k -n true 2>/dev/null; then
  ansible_args+=(-K)
fi

echo "==> Configuring the machine (profile: $profile)"
cd "$repo_dir"
ansible-playbook ansible/playbook.yml "${ansible_args[@]}" "$@"
