#!/usr/bin/env bash

# Get diff (staged preferred)
DIFF=$(git diff --cached)
if [ -z "$DIFF" ]; then
  DIFF=$(git diff)
fi

if [ -z "$DIFF" ]; then
  echo "No changes to commit."
  exit 1
fi

# Compose prompt
PROMPT=$(cat <<EOF
Generate a concise git commit message using the conventional commits format.
Use max 50 characters for the subject line.
Wrap body lines at 72 characters.
Use bullet points for multiple changes when applicable.
Here is the diff:

$DIFF
EOF
)

# If no API key, fallback to clipboard
if [[ -z "$OPENAI_API_KEY" ]]; then
echo "⚠️ OPENAI_API_KEY not set. Copying diff to clipboard instead..."
echo "$PROMPT" | pbcopy
echo "✅ Diff copied to clipboard. Paste it into ChatGPT or Copilot manually."
exit 0
fi

# Ask OpenAI
echo "🧠 Asking OpenAI to generate a commit message..."
RESPONSE=$(openai api chat.completions.create \
  -m gpt-5-mini \
  -g user "$PROMPT")

# Basic error check
if [ $? -ne 0 ]; then
  echo "❌ OpenAI returned an error:"
  echo "$RESPONSE"
  exit 1
fi

TMPFILE=$(mktemp /tmp/ai-commit-msg.$(date +%Y%m%d_%H%M%S))
echo "$RESPONSE" > "$TMPFILE"

# Open your default git commit editor with the AI message
GIT_COMMIT_ERR=$(mktemp /tmp/ai-commit-err.$(date +%Y%m%d_%H%M%S))
git commit --edit -F "$TMPFILE" "$@" 
GIT_COMMIT_STATUS=$?

if [ $GIT_COMMIT_STATUS -ne 0 ]; then
  echo "❌ git commit failed."
  echo "ℹ️ Response message:"
  cat "$TMPFILE"
fi

# Clean up
rm "$TMPFILE"
rm "$GIT_COMMIT_ERR"

exit $GIT_COMMIT_STATUS
