# dotfiles

My shell config and the small scripts I keep in `~/.local/bin`. Claude Code rules and skills live
in `claude-config`, not here.

## Contents

- `.zshrc` — shell config. Secrets stay in `~/.zshenv`, which is deliberately not versioned: the
  repository is public.
- `bin/gh-review` — `gh review <PR>`: check out a PR and start a background Claude review of it,
  with `--context` for what the reviewer should know.
- `bin/gh-fix` — `gh fix <PR>`: start a background Claude session running the `fix-pr` skill.
- `bin/gh-merges` — approve and squash-merge a batch of PRs.
- `bin/gh-review-time` — hours from PR creation to a reviewer's first activity and first approval,
  over a period.
- `bin/spellcheck` — correct the spelling and grammar of a text through the Claude API.
- `bin/showmd` — live HTML preview of Markdown files with pandoc.
- `bin/brew-upgrade` — `brew upgrade` that logs each version change, every 4 hours
  (`launchd/com.user.brew-upgrade.plist`).
- `bin/update-dev-status` — PR, notification, Jira and Slack counters for the WezTerm status bar
  and the SwiftBar menu, every 5 minutes (`launchd/com.user.dev-status.plist`).
- `bin/dev-status-refresh` — rerun `update-dev-status` now, after a command that changed a count
  (`gh merges`, and the `prs` alias below).
- `bin/update-slack-status` — set the Slack status from the calendar, every minute
  (`launchd/com.user.slack-status.plist`).

## Install

```bash
./install.sh
```

Symlinks `.zshrc` into `~` and every `bin/*` into `~/.local/bin`, and prunes symlinks whose target
left the repo. The launchd agents are copied into `~/Library/LaunchAgents` instead, because launchd
does not reliably follow a symlinked agent, and reloaded when they change. Safe to re-run.

The other scheduled jobs on this Mac, the `work-*` agents, live in `work-tooling`. The `gh review` and `gh fix` aliases call `~/.local/bin/gh-review` and `~/.local/bin/gh-fix`,
so they keep working through the symlinks. The `prs` alias refreshes the status bars after a
gh-prs command that changes the PR count:

```bash
gh alias set --clobber prs '!gh-prs "$@"; s=$?; case "$1" in merge|snooze|unsnooze|hide|unhide) ~/.local/bin/dev-status-refresh;; esac; exit $s'
```
