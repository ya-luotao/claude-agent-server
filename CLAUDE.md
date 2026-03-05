# CLAUDE.md

## Project Overview

HTTP server wrapping `claude-agent-sdk` as a REST + SSE API (gem: `claude-agent-server`). Uses Falcon (async-native) + Roda (micro-router). Requires Ruby 3.2+, Claude Code CLI 2.0.0+.

Runtime dependencies: `claude-agent-sdk` (~0.8), `falcon` (~0.48), `roda` (~3.85).

## Common Commands

```bash
bundle install                              # Install dependencies
bundle exec rspec                           # Run all unit tests
bundle exec rspec spec/unit/routes/health_spec.rb  # Run a single spec
bundle exec rubocop                         # Run linter
bundle exec rake                            # Run default task (spec + rubocop)
RUN_INTEGRATION=1 bundle exec rspec         # Include integration tests
bundle exec ruby exe/claude-agent-server    # Start server
```

## Architecture

```
HTTP Request
  ├── Middleware stack (RequestId → Cors → Authentication → ErrorHandler)
  └── Roda App (hash_routes)
        ├── /health, /info           → Routes::Health
        ├── /query, /query/stream    → Routes::Query → Services::QueryExecutor
        ├── /sessions/*              → Routes::Sessions → Services::SessionManager
        └── /cli-sessions/*          → Routes::SessionHistory → ClaudeAgentSDK.list_sessions
```

### Key Components

- **App** (`app.rb`) — Roda application with middleware stack and hash_routes
- **SessionManager** — In-memory registry of `Client` sessions with reaper task
- **SessionEntry** — Wraps `ClaudeAgentSDK::Client` with broadcast queue for SSE subscribers
- **QueryExecutor** — One-shot query wrapper around `ClaudeAgentSDK.query`
- **MessageSerializer** — SDK typed objects → JSON-serializable hashes (camelCase)
- **OptionsBuilder** — camelCase JSON → snake_case `ClaudeAgentOptions`
- **SseStream** — Rack 3 streaming body that bridges SDK messages to SSE format

### SSE Streaming

- One-shot (`POST /query/stream`): Calls `ClaudeAgentSDK.query` with block, writes SSE events
- Session (`GET /sessions/:id/messages/stream`): Subscribes to `SessionEntry` broadcast queue

## Key Conventions

- `frozen_string_literal: true` in all files
- Ruby 3.2+ required
- RuboCop: max method 30, max class 250, line 120, Style/Documentation disabled
- RSpec: `expect` syntax only, `disable_monkey_patching!`, random order, `:integration` tag
- Plain Ruby classes with `attr_accessor` + keyword args
- `module_function` for stateless service modules
- camelCase in JSON responses, snake_case internally
