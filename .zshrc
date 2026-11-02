# Source a tool's init script from a cache instead of running the tool on every
# new shell. Keyed on the resolved binary path, not its date: Homebrew keeps the
# bottle's mtimes, so an upgrade shows up as a new Cellar path.
_cached_eval() {  # name, binary, init command...
  local cache=~/.cache/zsh/$1.zsh bin=${commands[$2]:A} line; shift 2
  [[ -r $cache ]] && read -r line < $cache
  if [[ $line != "# $bin" ]]; then
    mkdir -p ${cache:h}
    { print -r -- "# $bin"; "$@" } >| $cache
  fi
  source $cache
}
_cached_eval starship starship starship init zsh --print-full-init
_cached_eval direnv direnv direnv hook zsh
_cached_eval zoxide zoxide zoxide init zsh

# Deliberate: shims only, no `rbenv init`, which runs `rbenv rehash` on every new
# shell. Run `rbenv rehash` after a `gem install` that adds a command.
export PATH="$HOME/.rbenv/shims:$PATH"

export PATH="$HOME/.local/bin:/opt/homebrew/opt/rustup/bin:$HOME/.cargo/bin:$PATH"

# Deliberate: -C trusts the dump as is; bin/brew-upgrade rebuilds it every 4 hours.
autoload -Uz compinit && compinit -C
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
