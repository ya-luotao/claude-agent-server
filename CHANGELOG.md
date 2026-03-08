# Changelog

## [0.1.1] - 2026-03-08

### Fixed
- Multi-turn sessions: reader thread no longer exits after first turn's `ResultMessage`, keeping sessions alive across turns
- TOCTOU race in `create_session`: slot reservation now happens atomically under mutex, preventing duplicate IDs and max_sessions bypass under concurrency
- Session reaper wired up: converted from Async to Thread, started from `config.ru`, also sweeps finished sessions
- Executable rackup path: `File.expand_path('../../config.ru', __dir__)` resolved outside the repo; corrected to `../config.ru`
- Late SSE subscriber hang: `subscribe` now sends `:done` immediately if the session is already finished
- SSE error handling: SDK errors inside stream body are emitted as SSE `error` events instead of breaking the stream after 200 is committed

### Changed
- Default bind address from `0.0.0.0` to `127.0.0.1` (localhost-only)
- Default `permission_mode` from `bypassPermissions` to `acceptEdits` (safer for headless usage)
- Executable now warns when running without authentication or when binding to all interfaces
- History endpoint uses thread-safe `get_events` instead of raw `events` array access

### Fixed (Documentation)
- README: added `/v1` prefix to all API examples and reference table
- README: updated error format from legacy `{ error: { code, message } }` to RFC 9457 problem details
- README: documented `/v1/sessions/:id/events` and `/v1/sessions/:id/events/sse` endpoints
- README: updated default host in configuration table

## [0.1.0] - 2026-03-05

### Added
- Initial release
- REST API for one-shot queries (`POST /v1/query`, `POST /v1/query/stream`)
- Interactive session management (`POST /v1/sessions`, `DELETE /v1/sessions/:id`)
- Session messaging (`POST /v1/sessions/:id/messages`)
- SSE streaming for session messages (`GET /v1/sessions/:id/messages/stream`)
- Session interrupt (`POST /v1/sessions/:id/interrupt`)
- Model switching (`POST /v1/sessions/:id/model`)
- MCP status (`GET /v1/sessions/:id/mcp-status`)
- Session history (`GET /v1/sessions/:id/history`)
- CLI session browsing (`GET /v1/cli-sessions`, `GET /v1/cli-sessions/:id/messages`)
- Health check (`GET /health`) and server info (`GET /v1/info`)
- Bearer token authentication with timing-safe comparison
- CORS support with origin validation
- Request ID propagation
- Error handling middleware (SDK errors mapped to HTTP status codes)
- CLI executable (`claude-agent-server`) with Falcon
- Docker support
- Session TTL with automatic reaper
- Configurable session limits
