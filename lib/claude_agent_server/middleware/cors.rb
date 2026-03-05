# frozen_string_literal: true

module ClaudeAgentServer
  module Middleware
    class Cors
      def initialize(app)
        @app = app
      end

      def call(env)
        origin = env['HTTP_ORIGIN']

        return preflight_response(origin) if env['REQUEST_METHOD'] == 'OPTIONS'

        status, headers, body = @app.call(env)
        add_cors_headers(headers, origin)
        [status, headers, body]
      end

      private

      def preflight_response(origin)
        headers = {
          'content-type' => 'text/plain',
          'access-control-max-age' => '86400'
        }
        add_cors_headers(headers, origin)
        headers['access-control-allow-methods'] = 'GET, POST, DELETE, OPTIONS'
        headers['access-control-allow-headers'] = 'Content-Type, Authorization, X-Request-Id'
        [204, headers, []]
      end

      def add_cors_headers(headers, origin)
        allowed = ClaudeAgentServer.config.allowed_origins

        if allowed.include?('*')
          headers['access-control-allow-origin'] = '*'
        elsif origin && allowed.include?(origin)
          headers['access-control-allow-origin'] = origin
          headers['vary'] = 'Origin'
        end

        headers['access-control-expose-headers'] = 'X-Request-Id'
      end
    end
  end
end
