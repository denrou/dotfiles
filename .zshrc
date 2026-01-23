
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$($users).zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$($users).zsh"
fi

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.

# --- p10k custom segment: shows AWS_PROFILE if set ---
prompt_aws_profile() {
  [[ -n "$AWS_PROFILE" ]] || return
  p10k segment -i '☁️' -t "$AWS_PROFILE"
}
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

plugins=(git aws brew docker)

# User configuration

# --- AWS profile helpers ---
_prod() {
  export AWS_PROFILE="dsir-saas-prod"
  aws sso login --profile "$AWS_PROFILE"
}

_qual() {
  export AWS_PROFILE="rd-saas-test"
  aws sso login --profile "$AWS_PROFILE"
}

_docker() {
  cat /Users/denisroussel/.config/docker_centreon_secret.txt | docker login -u droussel --password-stdin docker.centreon.com
}


# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.

ulimit -c unlimited && ulimit -f unlimited

if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

zstyle ':completion:*' menu select

export ZSH="$HOME/.oh-my-zsh"
: ${ZSH_CUSTOM:="$ZSH/custom"}
fpath=("$ZSH_CUSTOM/completions" "$HOME/.zsfunc" $fpath)

source $ZSH/oh-my-zsh.sh

export GPG_TTY=$(tty)
export PATH="/usr/local/bin:$PATH"
export PATH="/usr/local/opt/openjdk/bin:/usr/local/sbin:$PATH"
eval "$(direnv hook zsh)"

# Usage:
#   git log --help | h how to get only the last commit messages
#   man git-log | col -bx | h what's the option for ...
#
# Requires: openai CLI configured + OPENAI_API_KEY set (or equivalent)

h() {
  # Fail fast if nothing is piped
  if [[ -t 0 ]]; then
    echo "Usage: <command producing help> | h <your question>" >&2
    echo "Example: git log --help | h how to show only last commit messages" >&2
    return 2
  fi

  # Question = all args
  local question="$*"
  if [[ -z "$question" ]]; then
    echo "Error: please provide a question." >&2
    return 2
  fi

  # Read piped content
  local help_text
  help_text="$(cat)"

  # (Optional) protect yourself from huge inputs: keep last N chars
  # local max_chars=20000
  # if (( ${#help_text} > max_chars )); then
  #   help_text="${help_text: -max_chars}"
  # fi

  # Build prompt in a temp file to avoid escaping issues
  local tmp
  tmp="$(mktemp -t zsh-h-XXXXXX)" || return 1
  trap 'rm -f "$tmp"' RETURN

  cat > "$tmp" <<EOF
Given the help here, provide an answer to the question.

--- HELP (stdin) ---
$help_text
--- END HELP ---

--- QUESTION ---
$question
--- END QUESTION ---
EOF

  # Send to OpenAI CLI (streaming)
  # Note: you wrote "-g user $PROMPT"; here we pass the prompt as one string.
  openai api chat.completions.create \
    -m gpt-5-mini \
    --stream \
    -g user "$(cat "$tmp")"
}

. "$HOME/.cargo/env"


fpath+=~/.zfunc; autoload -Uz compinit; compinit
