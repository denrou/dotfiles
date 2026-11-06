#!/usr/bin/env bash
# Menu bar count of the background Claude sessions (claude agents) that need me:
# a question or a permission, or a finished turn I have not checked yet. Running
# sessions do not count. The notifications come from the
# ~/.local/bin/claude-agent-notify hook, which also refreshes this plugin.
#
# Clicking a session parks it: read, but nothing to do right now. A parked session
# leaves the count until it moves again (the hook removes the mark on its next
# turn end or question). Clicking a parked session brings it back.
#
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
set -uo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin"

# Same directory as in bin/claude-agent-notify.
seen_dir="$HOME/.cache/claude-agents/seen"
self="${SWIFTBAR_PLUGIN_PATH:-$0}"

case "${1:-}" in
  park) mkdir -p "$seen_dir" && touch "$seen_dir/$2"; exit 0 ;;
  unpark) rm -f "$seen_dir/$2"; exit 0 ;;
esac

agents="$(claude agents --json 2>/dev/null | jq -c 'map(select(.kind == "background"))' 2>/dev/null)"

if [[ -z "$agents" ]]; then
  echo ":sparkle: ? | symbolize=true"
  echo "---"
  echo "claude agents --json failed"
  exit 0
fi

# Marks of sessions that no longer exist go, so a reused id does not start parked.
mkdir -p "$seen_dir"
for f in "$seen_dir"/*; do
  [[ -e "$f" ]] || continue
  jq -e --arg id "${f##*/}" 'any(.[]; .id == $id)' <<<"$agents" >/dev/null || rm -f "$f"
done

# id -> time it was parked.
seen="$(for f in "$seen_dir"/*; do [[ -e "$f" ]] && stat -f '%N %m' "$f"; done |
  jq -Rn '[inputs | split(" ") | {key: (.[0] | split("/") | last), value: (.[1] | tonumber)}] | from_entries')"

# What each session asks or answered, which claude agents --json leaves out.
details="$(jq -s 'map({(.daemonShort // ""): (.needs // .output.result // .detail // "")}) | add // {}' \
  "$HOME"/.claude/jobs/*/state.json 2>/dev/null || echo '{}')"

# Deliberate: a session can say it is blocked on me while a task of its own still
# runs, and the agents view calls that working. The count follows the view; the
# working submenu still flags it, since it may really wait for something I do elsewhere.
JQ_COMMON='
  def column:
    if .state == "blocked" and .status != "busy" then "question"
    elif .state == "blocked" or .state == "working" then "working"
    else "result" end;
  def claims: .state == "blocked" and .status == "busy";
  def parked: $seen[.id] != null;
  def needs_me: column != "working" and (parked | not);
'

# Same colour as the devstatus "waiting on you" bell: both mean act now.
jq -r --argjson seen "$seen" "$JQ_COMMON"'
  (map(select(needs_me)) | length) as $n
  | if $n > 0 then ":sparkle: \($n) | symbolize=true sfcolor=#fe640b"
    else ":sparkle: | symbolize=true" end
' <<<"$agents"

jq -r --argjson seen "$seen" --argjson details "$details" --arg self "$self" \
  --argjson now "$(date +%s)" "$JQ_COMMON"'
  def tip: ($details[.id] // "" | if . == "" then null else . end) // .cwd | gsub("[\"|\n]"; " ");
  def ago: ($now - $seen[.id]) as $s
    | if $s < 3600 then "\($s / 60 | floor)m"
      elif $s < 86400 then "\($s / 3600 | floor)h"
      else "\($s / 86400 | floor)d" end;
  def action($verb): "bash=\"\($self)\" param1=\($verb) param2=\(.id) terminal=false refresh=true";
  def row($prefix; $icon; $extra):
    "\($prefix)\(.name // .id)\($extra) | sfimage=\($icon) length=70 tooltip=\"\(tip)\"";
  def section($header; $rows; line):
    if ($rows | length) > 0 then "---", $header, ($rows[] | line) else empty end;

  section("Questions"; map(select(needs_me and column == "question"));
    row(""; "hand.raised"; "") + " sfcolor=#fe640b,#fab387 " + action("park")),
  section("Results to check"; map(select(needs_me and column == "result"));
    row(""; "checkmark.circle"; "") + " " + action("park")),
  section("Parked"; map(select(column != "working" and parked)) | sort_by(-$seen[.id]);
    row(""; "moon.zzz"; " (\(ago))") + " sfcolor=#9ca0b0 " + action("unpark")),
  (map(select(column == "working")) as $w
    | if ($w | length) > 0 then
        "---",
        "\($w | length) working | sfimage=gearshape sfcolor=#9ca0b0",
        ($w[] | if claims then row("--"; "hand.raised"; " (says it waits on you)")
                else row("--"; "gearshape"; "") end)
      else empty end)
' <<<"$agents"
echo "---"
echo "Click a session to park it, a parked one to bring it back | size=11 sfcolor=#9ca0b0"
echo "Open with: claude agents"
