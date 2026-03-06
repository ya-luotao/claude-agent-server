# frozen_string_literal: true

module ClaudeAgentServer
  URN_PREFIX = 'urn:claude-agent-server:error'

  class ServerError < StandardError
    def error_type = 'server_error'
    def status_code = 500
    def title = 'Server Error'
    def urn = "#{URN_PREFIX}:#{error_type}"

    def to_problem_details
      {
        type: urn,
        title: title,
        status: status_code,
        detail: message
      }
    end
  end

  class ConfigError < ServerError
    def error_type = 'config_error'
    def status_code = 400
    def title = 'Configuration Error'
  end

  class SessionNotFoundError < ServerError
    def error_type = 'session_not_found'
    def status_code = 404
    def title = 'Session Not Found'
  end

  class SessionAlreadyExistsError < ServerError
    def error_type = 'session_already_exists'
    def status_code = 409
    def title = 'Session Already Exists'
  end

  class SessionLimitError < ServerError
    def error_type = 'session_limit_reached'
    def status_code = 429
    def title = 'Session Limit Reached'
  end

  class AuthenticationError < ServerError
    def error_type = 'unauthorized'
    def status_code = 401
    def title = 'Unauthorized'
  end
end
