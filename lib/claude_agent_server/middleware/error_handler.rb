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
      rescue ServerError => e
        problem_response(e.status_code, e.to_problem_details)
      rescue ClaudeAgentSDK::CLINotFoundError => e
        problem_response(503, problem(503, 'cli_not_found', 'CLI Not Found', e.message))
      rescue ClaudeAgentSDK::CLIConnectionError => e
        problem_response(502, problem(502, 'cli_connection_error', 'CLI Connection Error', e.message))
      rescue ClaudeAgentSDK::ProcessError => e
        problem_response(502, problem(502, 'cli_process_error', 'CLI Process Error', e.message))
      rescue ClaudeAgentSDK::ClaudeSDKError => e
        problem_response(502, problem(502, 'sdk_error', 'SDK Error', e.message))
      rescue ArgumentError => e
        problem_response(400, problem(400, 'invalid_request', 'Invalid Request', e.message))
      rescue StandardError => e
        problem_response(500, problem(500, 'internal_error', 'Internal Error', e.message))
      end

      private

      def problem(status, error_type, title, detail)
        {
          type: "#{URN_PREFIX}:#{error_type}",
          title: title,
          status: status,
          detail: detail
        }
      end

      def problem_response(status, body)
        [status, { 'content-type' => 'application/problem+json' }, [JSON.generate(body)]]
      end
    end
  end
end
