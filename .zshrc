eval "$(starship init zsh)"
eval "$(direnv hook zsh)"
eval "$(zoxide init zsh)"
eval "$(rbenv init - zsh)"

export PATH="$HOME/.local/bin:/opt/homebrew/opt/rustup/bin:$HOME/.cargo/bin:$PATH"

autoload bashcompinit && bashcompinit
autoload -Uz compinit && compinit

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

oiwjdfnwoeijfn() {
  cat /Users/droussel/.config/docker_centreon_secret.txt | docker login -u droussel --password-stdin docker.centreon.com
}

# Word navigation with Option + arrows
bindkey "^[f" forward-word
bindkey "^[b" backward-word

# Beginning / end of line (optional overrides)
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line

# ── Planning ──────────────────────────────────────────────────────────────────
WORKBOOK="$HOME/planning/workbook.md"
TASKS="$HOME/planning/tasks.md"

# plan: prepend a new dated entry to the workbook and open it
plan() {
  local header="## $(date +%Y-%m-%d) — $(date +%A)"
  local block="${header}\n\n### Focus\n\n\n### In progress\n\n\n### Notes\n\n"
  local tmp=$(mktemp)
  { printf '%s\n\n---\n\n' "$block"; tail -n +3 "$WORKBOOK"; } > "$tmp" && mv "$tmp" "$WORKBOOK"
  nvim +4 "$WORKBOOK"
}

alias tmux-keybindings=$(comm -23 <(tmux list-keys | sort) <(tmux -L test -f /dev/null list-keys | sort))

