#!/usr/bin/env bash
# Symlink the personal scripts into ~/.local/bin. Idempotent; never overwrites a real file.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"

link() {
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then
    [ "$(readlink "$dst")" = "$src" ] && { echo "ok      $dst"; return; }
    ln -sfn "$src" "$dst"; echo "relink  $dst"; return
  fi
  if [ -e "$dst" ]; then
    echo "SKIP    $dst exists and is not a symlink — move it aside, then re-run" >&2; return
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"; echo "link    $dst"
}

for f in "$REPO"/bin/*; do
  [ -e "$f" ] || continue
  link "$f" "$BIN/$(basename "$f")"
done

# Prune symlinks left behind by scripts removed from the repo: only symlinks, only
# those pointing into this repo, only when the target is gone.
for l in "$BIN"/*; do
  [[ -L "$l" ]] || continue
  target="$(readlink "$l")"
  case "$target" in "$REPO"/*) ;; *) continue ;; esac
  [[ -e "$target" ]] && continue
  rm "$l"; echo "prune   $l (target gone)"
done

echo "done"
