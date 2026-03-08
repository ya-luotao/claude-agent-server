# frozen_string_literal: true

module ClaudeAgentServer
  class Config
    attr_accessor :host, :port, :auth_token, :cors_origins, :session_ttl,
                  :max_sessions, :default_sdk_options, :log_level

    def initialize
      @host = ENV.fetch('CLAUDE_SERVER_HOST', '127.0.0.1')
      @port = ENV.fetch('CLAUDE_SERVER_PORT', '9292').to_i
      @auth_token = ENV.fetch('CLAUDE_SERVER_AUTH_TOKEN', nil)
      @cors_origins = ENV.fetch('CLAUDE_SERVER_CORS_ORIGINS', '*')
      @session_ttl = ENV.fetch('CLAUDE_SERVER_SESSION_TTL', '3600').to_i
      @max_sessions = ENV.fetch('CLAUDE_SERVER_MAX_SESSIONS', '100').to_i
      @default_sdk_options = {}
      @log_level = ENV.fetch('CLAUDE_SERVER_LOG_LEVEL', 'info')
    end

    def auth_enabled?
      !@auth_token.nil? && !@auth_token.empty?
    end

    def allowed_origins
      return ['*'] if @cors_origins == '*'

      @cors_origins.split(',').map(&:strip)
    end
  end
end
