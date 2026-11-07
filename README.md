# dotfiles

My shell and Hammerspoon configs, the small scripts I keep in `~/.local/bin`, and my SwiftBar
plugins. Claude Code rules and skills live in `claude-config`, not here.

## Contents

- `.zshrc` — shell config. Secrets stay in `~/.zshenv`, which is deliberately not versioned: the
  repository is public.
- `hammerspoon/init.lua` — global keys: Cmd-G corrects the selected text with `bin/spellcheck`,
  Cmd-J/K/X move between and close browser tabs, Cmd-Alt-S swaps windows between the displays,
  Cmd-Alt-C and Cmd-Alt-N open the Claude agents and dev status SwiftBar menus.
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
  (`gh merges`, the `prs` and `notifications` aliases below, and `jira`).
- `bin/dev-status-claude-hook` — the same from Claude sessions, as a Claude Code hook: after a Jira
  write through the Atlassian MCP, or a PR reviewed, merged, closed or marked ready with `gh`.
- `bin/claude-agent-notify` — a SwiftBar notification when a session of `claude agents` ends its
  turn or waits on a permission or a question, as a Claude Code hook. Foreground sessions are
  skipped. It also refreshes `swiftbar/claude-agents.30s.sh` and clears the park mark that plugin
  leaves in `~/.cache/claude-agents/seen/`.
- `bin/update-slack-status` — set the Slack status from the calendar, every minute
  (`launchd/com.user.slack-status.plist`).
- `swiftbar/devstatus.1m.sh` — the SwiftBar menu of what waits on me, read from the
  `update-dev-status` payload, with a notification when a count goes up.
- `swiftbar/claude-agents.30s.sh` — the SwiftBar count of the `claude agents` sessions that need
  me: a question, or a result not checked yet. Clicking one I have read but cannot act on yet parks
  it out of the count until the session moves again.

## Install

```bash
./install.sh
```

Symlinks `.zshrc` into `~`, `hammerspoon/init.lua` into `~/.hammerspoon`, every `bin/*` into
`~/.local/bin` and every `swiftbar/*` into `~/.config/swiftbar` (the plugin directory set in
SwiftBar's preferences), and prunes symlinks whose target left the repo. The launchd agents are
copied into `~/Library/LaunchAgents` instead, because launchd does not reliably follow a symlinked
agent, and reloaded when they change. Safe to re-run.

The other scheduled jobs on this Mac, the `work-*` agents, live in `work-tooling`. The `gh review` and `gh fix` aliases call `~/.local/bin/gh-review` and `~/.local/bin/gh-fix`,
so they keep working through the symlinks. The `prs` and `notifications` aliases refresh the status
bars after a command that changes a count (`--on-change` needs gh-notifications 0.3.0 or later):

```bash
gh alias set --clobber prs '!gh-prs "$@"; s=$?; case "$1" in merge|snooze|unsnooze|hide|unhide) ~/.local/bin/dev-status-refresh;; esac; exit $s'
gh alias set --clobber notifications '!gh-notifications --on-change ~/.local/bin/dev-status-refresh "$@"'
```

`jira` (denrou/jira 0.5.0 or later) does the same after a move or an assignment, through this key in
`~/.config/jira/config.json`:

```json
"on_change": "~/.local/bin/dev-status-refresh"
```

Claude sessions (`/work`, `/work-sync`, a review posted by `gh review`'s session) go through this
hook in `~/.claude/settings.json`, under `hooks`:

```json
"PostToolUse": [
  {
    "matcher": "Bash|mcp__claude_ai_Atlassian_MCP__.*",
    "hooks": [
      { "type": "command", "command": "~/.local/bin/dev-status-claude-hook", "timeout": 10 }
    ]
  }
]
```

The agent notifications go through these two hooks, in the same place. `idle_prompt` is left out
on purpose: it fires a minute after `Stop` and would notify the same turn twice.

```json
"Stop": [
  { "hooks": [{ "type": "command", "command": "~/.local/bin/claude-agent-notify", "timeout": 10 }] }
],
"Notification": [
  {
    "matcher": "permission_prompt|elicitation_dialog",
    "hooks": [{ "type": "command", "command": "~/.local/bin/claude-agent-notify", "timeout": 10 }]
  }
]
```
