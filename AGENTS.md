# Project instructions

## Testing

- The user has a dedicated VM and runs `install-fedora.sh` there himself to test it.
- Do not execute `install-fedora.sh` or the Ansible playbook on the user's own machine.
  Validate changes with static checks instead and let the user confirm the result in the VM:

  ```sh
  shellcheck -x install-fedora.sh kali/kali-install.sh home/.local/bin/wm-* home/.config/git/hooks/pre-push
  ansible-lint ansible/
  ansible-playbook ansible/playbook.yml --syntax-check
  ```

- `--check --diff` runs are safe: they change nothing. Ansible must be installed first
  (the machine has no `ansible-core`), for example with `uv venv`.
