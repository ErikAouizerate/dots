# zsh configuration, symlinked from the dots repository.
# Machine-specific settings go in ~/.zshrc.local (not versioned).

# Oh My Zsh. Its theme only shows up if starship is missing: starship is
# initialised below and takes the prompt over.
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source "$ZSH/oh-my-zsh.sh"

# Prompt (see ~/.config/starship.toml)
command -v starship >/dev/null && eval "$(starship init zsh)"

# Per-directory environments (a .envrc in the project)
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# Runtime versions: node, python, rust, uv, yarn, pnpm
# (see ~/.config/mise/config.toml)
command -v mise >/dev/null && eval "$(mise activate zsh)"

# Machine-specific settings: secrets, extra aliases, tools installed by hand.
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
