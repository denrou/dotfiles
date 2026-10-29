eval "$(starship init zsh)"
eval "$(direnv hook zsh)"
eval "$(zoxide init zsh)"
eval "$(rbenv init - zsh)"

export PATH="$HOME/.local/bin:/opt/homebrew/opt/rustup/bin:$HOME/.cargo/bin:$PATH"

autoload -Uz compinit && compinit
autoload -Uz bashcompinit && bashcompinit

complete -C '/usr/local/bin/aws_completer' aws

# --- AWS profile helpers ---
_prod() {
  export AWS_PROFILE="dsir-saas-prod"
  aws sso login --profile "$AWS_PROFILE"
}

_qual() {
  export AWS_PROFILE="rd-saas-test"
  aws sso login --profile "$AWS_PROFILE"
}

# Deliberate: not `_docker`, which is the name of zsh's docker completion function.
docker-login-centreon() {
  docker login -u droussel --password-stdin docker.centreon.com < "$HOME/.config/docker_centreon_secret.txt"
}

# Word navigation with Option + arrows
bindkey "^[f" forward-word
bindkey "^[b" backward-word

# Beginning / end of line (optional overrides)
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line

# Key bindings that differ from tmux's defaults.
tmux-keybindings() {
  comm -23 <(tmux list-keys | sort) <(tmux -L defaults -f /dev/null list-keys | sort)
}
