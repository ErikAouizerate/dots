# zsh configuration, symlinked from the dots repository.
# Machine-specific settings go in ~/.zshrc.local (not versioned).

# Oh My Zsh. Its theme is the prompt of the vps profile: starship is
# installed by the workstation profile only, is initialised below when present
# and takes the prompt over.
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
# The fzf plugin loads fzf's shell integration (`fzf --zsh`, fzf >= 0.48):
# Ctrl-R searches the history, Ctrl-T inserts a file path, Alt-C jumps to a
# directory. Fedora ships fzf without any zsh init, so the plugin is what
# wires the key bindings.
plugins=(git fzf)
source "$ZSH/oh-my-zsh.sh"

# Prompt on the workstation profile (see ~/.config/starship.toml)
command -v starship >/dev/null && eval "$(starship init zsh)"

# Per-directory environments (a .envrc in the project)
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# Runtime versions: node, python, rust, uv, yarn, pnpm
# (see ~/.config/mise/config.toml)
command -v mise >/dev/null && eval "$(mise activate zsh)"

# Machine-specific settings: secrets, extra aliases, tools installed by hand.
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
