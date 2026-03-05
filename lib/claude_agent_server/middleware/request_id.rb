# frozen_string_literal: true

require 'securerandom'

module ClaudeAgentServer
  module Middleware
    class RequestId
      def initialize(app)
        @app = app
      end

      def call(env)
        request_id = env['HTTP_X_REQUEST_ID'] || SecureRandom.uuid
        env['claude_agent_server.request_id'] = request_id

        status, headers, body = @app.call(env)
        headers['x-request-id'] = request_id
        [status, headers, body]
      end
    end
  end
end
