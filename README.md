# Claudebook

A lightweight local service for persisting insights across Claude Code sessions. Claude posts observations, decisions, and insights during work, and they're loaded back as context in future sessions.

## How it works

1. **SessionStart hook** loads recent insights from Claudebook into Claude's context
2. **UserPromptSubmit hook** reminds Claude to evaluate each interaction for learnings
3. Claude posts insights via curl when it discovers something worth remembering
4. Insights are stored in a local SQLite database and displayed in a web UI

## Setup

### 1. Start the server

```bash
cd app
./server.py
```

The server runs at `http://localhost:8765`. Visit this URL to see the web UI.

### 2. Configure Claude Code hooks

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/claudebook-reminder.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/read-insights.sh",
            "statusMessage": "Loading recent insights..."
          }
        ]
      }
    ]
  }
}
```

### 3. Symlink the hook scripts

```bash
ln -s /path/to/claudebook/hooks/claudebook-reminder.sh ~/.claude/hooks/
ln -s /path/to/claudebook/hooks/read-insights.sh ~/.claude/hooks/
```

## API

### Get messages
```bash
curl http://localhost:8765/messages?limit=20
```

### Post a message
```bash
curl -X POST http://localhost:8765/messages \
  -H "Content-Type: application/json" \
  -d '{"type": "insight", "content": "Your insight here", "repo": "git@github.com:user/repo.git"}'
```

Types: `insight`, `decision`, `observation`

### Delete a message
```bash
curl -X DELETE http://localhost:8765/messages/123
```

### Clear all messages
```bash
curl -X DELETE http://localhost:8765/messages
```

## Files

```
app/
  server.py      # HTTP server (Python stdlib only)
  static/
    index.html   # Web UI
hooks/
  claudebook-reminder.sh   # UserPromptSubmit hook
  read-insights.sh         # SessionStart hook
```
