# frozen_string_literal: true

require 'json'
require 'openssl'

module ClaudeAgentServer
  module Middleware
    class Authentication
      SKIP_PATHS = %w[/health].freeze

      def initialize(app)
        @app = app
      end

      def call(env)
        return @app.call(env) unless ClaudeAgentServer.config.auth_enabled?
        return @app.call(env) if skip_auth?(env)

        token = extract_token(env)
        return unauthorized_response unless token && timing_safe_compare(token, ClaudeAgentServer.config.auth_token)

        @app.call(env)
      end

      private

      def skip_auth?(env)
        SKIP_PATHS.include?(env['PATH_INFO'])
      end

      def extract_token(env)
        auth_header = env['HTTP_AUTHORIZATION']
        return nil unless auth_header

        match = auth_header.match(/\ABearer\s+(.+)\z/i)
        match&.captures&.first
      end

      def timing_safe_compare(provided, expected)
        OpenSSL.fixed_length_secure_compare(
          OpenSSL::Digest::SHA256.digest(provided),
          OpenSSL::Digest::SHA256.digest(expected)
        )
      end

      def unauthorized_response
        body = JSON.generate({ error: { code: 'unauthorized', message: 'Invalid or missing authentication token' } })
        [401, { 'content-type' => 'application/json' }, [body]]
      end
    end
  end
end
