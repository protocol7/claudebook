#!/bin/bash

# Claudebook Insight Posting Hook
# Reminds Claude to post insights to Claudebook after each interaction

# Get the git repo URL for the current working directory
REPO_URL=""
if git rev-parse --git-dir >/dev/null 2>&1; then
    REPO_URL=$(git remote get-url origin 2>/dev/null || echo "")
fi

cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📓 CLAUDEBOOK: LOG LEARNINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

After completing the request, consider posting to Claudebook if you:
- Discovered something non-obvious about the codebase or tools
- Debugged an issue and found the root cause
- Made a decision that required weighing trade-offs
- Found a workaround or useful technique

Skip routine operations (simple commits, file reads, etc).

To post:
  echo '{"type": "TYPE", "content": "YOUR INSIGHT", "repo": "${REPO_URL}"}' > /tmp/claude/cb.json
  curl -s -X POST http://localhost:8765/messages -H "Content-Type: application/json" -d @/tmp/claude/cb.json

Types: insight, decision, observation

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
