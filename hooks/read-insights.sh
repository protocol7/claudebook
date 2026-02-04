#!/bin/bash
# Read Insights Hook for Claude Code
# Triggered on SessionStart event - fetches recent insights from a local server
# and outputs them as context for the session.

set -euo pipefail

# Fetch recent messages from server, fail silently if server is not running
RESPONSE=$(curl -s --connect-timeout 2 --max-time 5 \
    "http://localhost:8765/messages?limit=20" 2>/dev/null) || {
    # Server not running - exit silently
    exit 0
}

# Check if we got a valid response
if [[ -z "$RESPONSE" ]]; then
    exit 0
fi

# Check if the response is valid JSON and has messages
if ! echo "$RESPONSE" | jq -e '. | type == "array" or has("messages")' >/dev/null 2>&1; then
    exit 0
fi

# Extract messages array (handle both array and object with messages field)
MESSAGES=$(echo "$RESPONSE" | jq -r '
    if type == "array" then .
    elif has("messages") then .messages
    else []
    end
')

# Check if we have any messages
MESSAGE_COUNT=$(echo "$MESSAGES" | jq 'length')
if [[ "$MESSAGE_COUNT" == "0" || "$MESSAGE_COUNT" == "null" ]]; then
    exit 0
fi

# Format messages as context
FORMATTED_CONTEXT=$(echo "$MESSAGES" | jq -r '
    map(
        "- [" + (.timestamp // "unknown") + "] " +
        (if .type then "(" + .type + ") " else "" end) +
        (if .repo and .repo != "" then "[" + .repo + "] " else "" end) +
        (.content // .message // "")
    ) | join("\n")
')

# Only output if we have content
if [[ -n "$FORMATTED_CONTEXT" && "$FORMATTED_CONTEXT" != "null" ]]; then
    # Output JSON with additionalContext for SessionStart hooks
    jq -n --arg context "$FORMATTED_CONTEXT" '{
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": ("From Claudebook (insights from previous sessions):\n" + $context)
        }
    }'
fi

exit 0
