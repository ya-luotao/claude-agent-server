# frozen_string_literal: true

require 'json'

module ClaudeAgentServer
  module Middleware
    class ErrorHandler
      def initialize(app)
        @app = app
      end

      def call(env)
        @app.call(env)
      rescue SessionNotFoundError => e
        error_response(404, 'session_not_found', e.message)
      rescue SessionLimitError => e
        error_response(429, 'session_limit_reached', e.message)
      rescue AuthenticationError => e
        error_response(401, 'unauthorized', e.message)
      rescue ConfigError => e
        error_response(400, 'config_error', e.message)
      rescue ClaudeAgentSDK::CLINotFoundError => e
        error_response(503, 'cli_not_found', e.message)
      rescue ClaudeAgentSDK::CLIConnectionError => e
        error_response(502, 'cli_connection_error', e.message)
      rescue ClaudeAgentSDK::ProcessError => e
        error_response(502, 'cli_process_error', e.message)
      rescue ClaudeAgentSDK::ClaudeSDKError => e
        error_response(502, 'sdk_error', e.message)
      rescue ArgumentError => e
        error_response(400, 'bad_request', e.message)
      rescue ServerError => e
        error_response(500, 'server_error', e.message)
      rescue StandardError => e
        error_response(500, 'internal_error', e.message)
      end

      private

      def error_response(status, code, message)
        body = JSON.generate({ error: { code: code, message: message } })
        [status, { 'content-type' => 'application/json' }, [body]]
      end
    end
  end
end
