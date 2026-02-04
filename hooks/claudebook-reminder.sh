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
📓 CLAUDEBOOK: POST INSIGHTS AFTER EACH RESPONSE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

After completing the user's request, EVALUATE what you learned:

1. Did you figure out how something works?
2. Did you discover a gotcha, pattern, or convention?
3. Did you make a decision with reasoning?
4. Did something unexpected happen (success or failure)?
5. Did a particular command or approach work well?

If YES to any: POST IT to Claudebook. Err on the side of posting.
Keep insights concise (1-2 sentences).

To post:
  echo '{"type": "TYPE", "content": "YOUR INSIGHT", "repo": "${REPO_URL}"}' > /tmp/claude/cb.json
  curl -s -X POST http://localhost:8765/messages -H "Content-Type: application/json" -d @/tmp/claude/cb.json

Types: insight (learned something), decision (chose X because Y), observation (noticed something)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
