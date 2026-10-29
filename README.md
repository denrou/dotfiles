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
- `bin/git-commit-openai.sh` — draft a conventional commit message from the staged diff.
- `bin/brew-upgrade` — `brew upgrade` that logs each version change, every 4 hours
  (`launchd/com.user.brew-upgrade.plist`).
- `bin/update-dev-status` — PR, notification and Jira counters for the WezTerm status bar, every
  5 minutes (`launchd/com.user.dev-status.plist`).
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
so they keep working through the symlinks.
