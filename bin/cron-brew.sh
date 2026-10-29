#!/usr/bin/env bash

brew() {
  if [[ "$1" == "upgrade" ]]; then
    brew list --versions > /tmp/brew-versions.before
    command /opt/homebrew/bin/brew "$@"
    brew list --versions > /tmp/brew-versions.after

    diff /tmp/brew-versions.before /tmp/brew-versions.after |
      /opt/homebrew/bin/gawk '
        /^</ { old[$2]=$3 }
        /^>/ { print strftime("%Y-%m-%d %H:%M:%S"), $2, old[$2], $3 }
      ' >> ~/.cache/brew-upgrade-history.log
    sort -k3,3 -k1,2 ~/.cache/brew-upgrade-history.log -o ~/.cache/brew-upgrade-history.log

  else
    command /opt/homebrew/bin/brew "$@"
  fi
}

brew update > /dev/null && brew upgrade > /dev/null
