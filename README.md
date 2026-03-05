# claude-agent-server

HTTP server wrapping the [Claude Agent Ruby SDK](https://github.com/ya-luotao/claude-agent-sdk-ruby) as a REST + SSE API. Expose Claude Code as a network service with session management, streaming, and authentication.

## Requirements

- Ruby 3.2+
- Claude Code CLI 2.0.0+ (`npm install -g @anthropic-ai/claude-code`)
- `ANTHROPIC_API_KEY` environment variable

## Installation

```bash
gem install claude-agent-server
```

Or add to your Gemfile:

```ruby
gem 'claude-agent-server'
```

## Quick Start

```bash
# Start the server
claude-agent-server --port 9292

# One-shot query
curl -X POST http://localhost:9292/query \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Say hello"}'

# Streaming query (SSE)
curl -N -X POST http://localhost:9292/query/stream \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Say hello"}'

# Interactive session
curl -X POST http://localhost:9292/sessions \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Hello"}'

# Send message to session
curl -X POST http://localhost:9292/sessions/<id>/messages \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"What is 2+2?"}'

# Stream session messages (SSE)
curl -N http://localhost:9292/sessions/<id>/messages/stream
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_SERVER_HOST` | `0.0.0.0` | Bind address |
| `CLAUDE_SERVER_PORT` | `9292` | Listen port |
| `CLAUDE_SERVER_AUTH_TOKEN` | (none) | Bearer token for authentication |
| `CLAUDE_SERVER_CORS_ORIGINS` | `*` | Comma-separated allowed origins |
| `CLAUDE_SERVER_SESSION_TTL` | `3600` | Session idle timeout (seconds) |
| `CLAUDE_SERVER_MAX_SESSIONS` | `100` | Maximum concurrent sessions |
| `CLAUDE_SERVER_LOG_LEVEL` | `info` | Log level |

### CLI Options

```
Usage: claude-agent-server [options]
    -p, --port PORT          Port to listen on (default: 9292)
    -b, --bind HOST          Host to bind to (default: 0.0.0.0)
    -t, --token TOKEN        Authentication token
        --session-ttl SECONDS Session TTL in seconds (default: 3600)
        --max-sessions N     Maximum concurrent sessions (default: 100)
        --cors-origins ORIGINS Comma-separated CORS origins
    -v, --version            Show version
    -h, --help               Show help
```

### Ruby Configuration

```ruby
require 'claude_agent_server'

ClaudeAgentServer.configure do |config|
  config.auth_token = 'my-secret-token'
  config.max_sessions = 50
  config.default_sdk_options = { model: 'claude-sonnet-4-20250514' }
end

run ClaudeAgentServer.app
```

## API Reference

### Health

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/health` | No | Health check |
| GET | `/info` | Yes | Server version, SDK version, active sessions |

### One-Shot Query

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/query` | Yes | Execute query, return JSON array of messages |
| POST | `/query/stream` | Yes | Execute query, return SSE stream |

**Request body:**
```json
{
  "prompt": "Your prompt here",
  "options": {
    "model": "claude-sonnet-4-20250514",
    "maxTurns": 5,
    "allowedTools": ["Read", "Bash"]
  }
}
```

### Interactive Sessions

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/sessions` | Yes | List active sessions |
| POST | `/sessions` | Yes | Create session (optionally with initial prompt) |
| GET | `/sessions/:id` | Yes | Get session info |
| DELETE | `/sessions/:id` | Yes | Disconnect and cleanup |
| POST | `/sessions/:id/messages` | Yes | Send message to session |
| GET | `/sessions/:id/messages/stream` | Yes | SSE stream of session messages |
| POST | `/sessions/:id/interrupt` | Yes | Interrupt current turn |
| POST | `/sessions/:id/model` | Yes | Switch model mid-session |
| GET | `/sessions/:id/mcp-status` | Yes | Get MCP server status |
| GET | `/sessions/:id/history` | Yes | Get session transcript |

### CLI Session Browsing

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/cli-sessions` | Yes | List past CLI sessions (read-only) |
| GET | `/cli-sessions/:id/messages` | Yes | Get session transcript |

## SSE Event Format

```
event: assistant
data: {"type":"assistant","content":[{"type":"text","text":"Hello!"}],"model":"claude-sonnet-4-20250514"}

event: result
data: {"type":"result","subtype":"result","durationMs":1200,"isError":false}

event: done
data: {"status":"complete"}
```

## Authentication

When `CLAUDE_SERVER_AUTH_TOKEN` is set, all routes except `/health` require a Bearer token:

```bash
curl -H 'Authorization: Bearer your-token' http://localhost:9292/info
```

Uses timing-safe comparison to prevent timing attacks.

## Error Responses

All errors return JSON:

```json
{
  "error": {
    "code": "session_not_found",
    "message": "Session 'abc-123' not found"
  }
}
```

| HTTP Status | Code | Description |
|-------------|------|-------------|
| 400 | `bad_request` | Invalid input |
| 401 | `unauthorized` | Missing or invalid auth token |
| 404 | `session_not_found` | Session does not exist |
| 429 | `session_limit_reached` | Max sessions exceeded |
| 502 | `cli_connection_error` | Claude CLI failed |
| 503 | `cli_not_found` | Claude CLI not installed |
| 500 | `internal_error` | Unexpected error |

## Docker

```bash
docker build -t claude-agent-server .
docker run -p 9292:9292 \
  -e ANTHROPIC_API_KEY=your-key \
  -e CLAUDE_SERVER_AUTH_TOKEN=your-token \
  claude-agent-server
```

## Development

```bash
bundle install
bundle exec rspec                  # Run unit tests
bundle exec rubocop                # Run linter
bundle exec rake                   # Run both
RUN_INTEGRATION=1 bundle exec rspec  # Include integration tests
```

## License

MIT
