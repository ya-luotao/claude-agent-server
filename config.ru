# frozen_string_literal: true

require_relative 'lib/claude_agent_server'

# Configure from environment variables (already defaults in Config)
ClaudeAgentServer.configure do |config|
  # Override defaults here if needed
end

# Start the session reaper so expired/finished sessions are cleaned up
ClaudeAgentServer::App.session_manager.start_reaper

run ClaudeAgentServer.app
