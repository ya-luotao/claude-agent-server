# Changelog

## [0.1.0] - 2026-03-05

### Added
- Initial release
- REST API for one-shot queries (`POST /query`, `POST /query/stream`)
- Interactive session management (`POST /sessions`, `DELETE /sessions/:id`)
- Session messaging (`POST /sessions/:id/messages`)
- SSE streaming for session messages (`GET /sessions/:id/messages/stream`)
- Session interrupt (`POST /sessions/:id/interrupt`)
- Model switching (`POST /sessions/:id/model`)
- MCP status (`GET /sessions/:id/mcp-status`)
- Session history (`GET /sessions/:id/history`)
- CLI session browsing (`GET /cli-sessions`, `GET /cli-sessions/:id/messages`)
- Health check (`GET /health`) and server info (`GET /info`)
- Bearer token authentication with timing-safe comparison
- CORS support with origin validation
- Request ID propagation
- Error handling middleware (SDK errors mapped to HTTP status codes)
- CLI executable (`claude-agent-server`) with Falcon
- Docker support
- Session TTL with automatic reaper
- Configurable session limits
