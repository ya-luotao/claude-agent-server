# frozen_string_literal: true

module ClaudeAgentServer
  class ServerError < StandardError; end
  class ConfigError < ServerError; end
  class SessionNotFoundError < ServerError; end
  class SessionLimitError < ServerError; end
  class AuthenticationError < ServerError; end
end
