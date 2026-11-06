#!/usr/bin/env bash
# Menu bar count of what waits on me, visible while WezTerm is in the background.
# Same rule as the WezTerm footer badges: the "act" metrics of the dev status
# payload, written every 5 min by ~/.local/bin/update-dev-status. Posts a
# notification when one of those counts goes up, except for a group that
# notifies by itself (the slack screen, while it is open).
#
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/bin:/bin"

STATUS="$HOME/.cache/devstatus/status.json"
SEEN="$HOME/.cache/devstatus/notified.json"
# Same threshold as the footer: past two missed refreshes, a count is not trustworthy.
STALE_AFTER=900

# {label: count} of the act metrics; a metric at zero is not "act", so it is absent.
acts="$(jq -c --argjson now "$(date +%s)" --argjson stale "$STALE_AFTER" '
  if (.epoch // 0) < ($now - $stale) then error("stale") else . end
  | [.groups[] | select(.product != "jira") | .metrics[] | select(.level == "act") | {(.label): (.value | tonumber)}]
  | add // {}' "$STATUS" 2>/dev/null)"

if [[ -z "$acts" ]]; then
  echo "? | sfimage=bell.slash"
  echo "---"
  echo "Dev status is stale or unreadable"
  echo "Refresh now | bash=$HOME/.local/bin/update-dev-status terminal=false refresh=true"
  exit 0
fi

describe() {
  case "$1" in
    PR) echo "Pull requests to review or ship" ;;
    @ME) echo "Slack DMs and mentions" ;;
    *) echo "$1" ;;
  esac
}

link() {
  case "$1" in
    PR) echo "https://github.com/pulls" ;;
    @ME) echo "slack://open" ;;
  esac
}

total="$(jq '[.[]] | add // 0' <<<"$acts")"

# Labels whose rise was already notified by their own tool: still counted and
# remembered, so closing that tool does not replay them.
covered="$(jq -c '[.groups[] | select(.notifying == true) | .metrics[].label]' "$STATUS" 2>/dev/null || echo '[]')"

# Notify about the counts that went up since the last run; a drop just lowers the bar.
risen="$(jq -r --argjson seen "$(cat "$SEEN" 2>/dev/null || echo '{}')" --argjson covered "$covered" '
  to_entries[] | select(.value > ($seen[.key] // 0))
  | select(.key as $key | $covered | index($key) | not) | "\(.key)\t\(.value)"' <<<"$acts")"
if [[ -n "$risen" ]] && pgrep -xq SwiftBar; then
  body=""
  href=""
  while IFS=$'\t' read -r label count; do
    body+="${body:+ · }$(describe "$label"): $count"
    href="$(link "$label")"
  done <<<"$risen"
  url="$(jq -rn --arg t "$total waiting on you" --arg b "$body" --arg h "$href" '
    "swiftbar://notify?plugin=devstatus&title=\($t | @uri)&body=\($b | @uri)&href=\($h | @uri)"')"
  open -g "$url"
fi
printf '%s\n' "$acts" >"$SEEN"

# Title and dropdown share one grouping, by the kind of attention a count asks
# for: what waits on me, then the inbox (read when convenient). Deliberate: Jira
# is left out, the /work skills move tickets by themselves and its counts were
# noise here; the WezTerm footer still shows them.
JQ_COMMON='
  def n: (.value | tonumber? // 0);
  def section: if .label == "PR" or .label == "@ME" then "wait" else "inbox" end;
  [.groups[] | select(.product != "jira") | .product as $p | (.metrics // [])[] | . + {product: $p}] as $m
'

# Menu bar: two counts, zeros hidden. Only the icons are coloured: ansi=true
# would colour the numbers too, but it turns off the :symbol: substitution.
# Fixed colours sit in the middle of the Catppuccin palettes so they read on a
# light and a dark menu bar alike; the inbox keeps the system colour on
# purpose, it is never alarming.
jq -r "$JQ_COMMON"'
  | ($m | map(select(section == "wait") | n) | add // 0) as $wait
  | ($m | map(select(section == "inbox") | n) | add // 0) as $inbox
  | [ (if $wait > 0 then {text: ":bell.badge.fill: \($wait)", color: "#fe640b"} else {text: ":bell:"} end),
      (if $inbox > 0 then {text: ":envelope: \($inbox)"} else empty end) ] as $segs
  | ($segs | map(.text) | join("  ")) + " | symbolize=true"
    + ([range($segs | length) | select($segs[.].color) | " sfcolor\(. + 1)=\($segs[.].color)"] | join(""))
' "$STATUS"

# Dropdown. Each colour pair is Catppuccin Latte for a light menu, then Mocha
# for a dark one.
jq -r "$JQ_COMMON"'
  | def desc: {PR: "Pull requests to review or ship", GH: "GitHub notifications",
      SLACK: "Slack conversations with unreads",
      "@ME": "Slack DMs and mentions"}[.] // .;
    def icon: {PR: "arrow.triangle.pull", GH: "bell", SLACK: "bubble.left.and.bubble.right",
      "@ME": "at"}[.] // "circle";
    def link: {PR: "https://github.com/pulls", GH: "https://github.com/notifications",
      SLACK: "slack://open", "@ME": "slack://open"}[.] // "";
    def color: {good: "#40a02b,#a6e3a1", warn: "#fe640b,#fab387", bad: "#d20f39,#f38ba8",
      unknown: "#fe640b,#fab387", act: "#fe640b,#fab387"}[.] // "#6c6f85,#a6adc8";
    def row:
      # Deliberate: a plain zero is dimmed, as in the old footer, so the counts that matter stand out.
      (if .level == "none" and .value == "0" then "#9ca0b0,#6c7086" else (.level | color) end) as $c
      | (.label | link) as $href
      | "\(.label | desc): \(.value) | sfimage=\(.label | icon) sfcolor=\($c) color=\($c)"
        + (if $href != "" then " href=\($href)" else "" end);
    def block($s; $header):
      ($m | map(select(section == $s))) as $rows
      | if ($rows | length) > 0 then "---", $header, ($rows[] | row) else empty end;
    ($m | map(select(section == "wait") | n) | add // 0) as $wait
  | block("wait"; if $wait > 0 then "Waiting on you" else "Nothing waits on you" end),
    block("inbox"; "Inbox")
' "$STATUS"
echo "---"
echo "Refresh now | bash=$HOME/.local/bin/update-dev-status terminal=false refresh=true"
