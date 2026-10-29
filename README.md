# dotfiles

My shell config and the small scripts I keep in `~/.local/bin`. Claude Code rules and skills live
in `claude-config`, not here.

## Contents

- `.zshrc` — shell config (not installed by `install.sh`).
- `bin/gh-review` — `gh review <PR>`: check out a PR and start a background Claude review of it,
  with `--context` for what the reviewer should know.
- `bin/gh-fix` — `gh fix <PR>`: start a background Claude session running the `fix-pr` skill.
- `bin/gh-merges` — approve and squash-merge a batch of PRs.
- `bin/gh-review-time` — hours from PR creation to a reviewer's first activity and first approval,
  over a period.
- `bin/spellcheck` — correct the spelling and grammar of a text through the Claude API.
- `bin/showmd` — live HTML preview of Markdown files with pandoc.
- `bin/git-commit-openai.sh` — draft a conventional commit message from the staged diff.
- `bin/cron-brew.sh` — scheduled `brew upgrade` that logs each version change.
- `bin/update-dev-status` — PR, notification and Jira counters for the WezTerm status bar (launchd).
- `bin/update-slack-status` — set the Slack status from the calendar (launchd).

## Install

```bash
./install.sh
```

Symlinks every `bin/*` into `~/.local/bin` and prunes symlinks whose target left the repo. Safe to
re-run. The `gh review` and `gh fix` aliases call `~/.local/bin/gh-review` and `~/.local/bin/gh-fix`,
so they keep working through the symlinks.
