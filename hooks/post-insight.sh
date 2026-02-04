#!/bin/bash
# Post Insight Hook for Claude Code
# Triggered on Stop event - posts significant insights to a local server
#
# This hook reads the transcript to extract the last assistant message
# and posts it if it contains keywords indicating a significant insight.

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract transcript path from hook input
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
    exit 0
fi

# Get the last assistant message from the transcript
# The transcript is a JSONL file with message entries
LAST_ASSISTANT_MSG=$(tac "$TRANSCRIPT_PATH" 2>/dev/null | while read -r line; do
    # Look for assistant messages (type: assistant or role: assistant)
    if echo "$line" | jq -e '.type == "assistant" or .role == "assistant"' >/dev/null 2>&1; then
        # Extract content - handle both string and array formats
        CONTENT=$(echo "$line" | jq -r '
            if .message.content then
                if (.message.content | type) == "array" then
                    [.message.content[] | select(.type == "text") | .text] | join("\n")
                else
                    .message.content
                end
            elif .content then
                if (.content | type) == "array" then
                    [.content[] | select(.type == "text") | .text] | join("\n")
                else
                    .content
                end
            else
                ""
            end
        ' 2>/dev/null)
        if [[ -n "$CONTENT" && "$CONTENT" != "null" ]]; then
            echo "$CONTENT"
            break
        fi
    fi
done)

# Exit if no message found
if [[ -z "$LAST_ASSISTANT_MSG" ]]; then
    exit 0
fi

# Check if message contains significant keywords (case insensitive)
SIGNIFICANT_KEYWORDS="found|discovered|decision|because|insight|important|note|learned|realized|notice|issue|problem|solution|fix|root cause|key point|takeaway"

if ! echo "$LAST_ASSISTANT_MSG" | grep -qiE "$SIGNIFICANT_KEYWORDS"; then
    exit 0
fi

# Truncate message if too long (keep first 2000 chars)
TRUNCATED_MSG=$(echo "$LAST_ASSISTANT_MSG" | head -c 2000)

# Get git repo URL from cwd (extract cwd from hook input or use current directory)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
if [[ -z "$CWD" ]]; then
    CWD="$(pwd)"
fi

REPO_URL=""
if [[ -d "$CWD" ]]; then
    REPO_URL=$(git -C "$CWD" remote get-url origin 2>/dev/null || echo "")
fi

# Build JSON payload
PAYLOAD=$(jq -n \
    --arg type "insight" \
    --arg content "$TRUNCATED_MSG" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg session_id "$(echo "$INPUT" | jq -r '.session_id // "unknown"')" \
    --arg repo "$REPO_URL" \
    '{type: $type, content: $content, timestamp: $timestamp, session_id: $session_id, repo: $repo}')

# Post to server, fail silently if server is not running
curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    --connect-timeout 2 \
    --max-time 5 \
    "http://localhost:8765/messages" >/dev/null 2>&1 || true

exit 0
