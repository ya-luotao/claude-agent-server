# frozen_string_literal: true

require_relative 'claude_agent_server/version'
require_relative 'claude_agent_server/errors'
require_relative 'claude_agent_server/config'
require_relative 'claude_agent_server/services/options_builder'
require_relative 'claude_agent_server/services/message_serializer'
require_relative 'claude_agent_server/services/query_executor'
require_relative 'claude_agent_server/services/sse_stream'
require_relative 'claude_agent_server/services/session_manager'
require_relative 'claude_agent_server/middleware/request_id'
require_relative 'claude_agent_server/middleware/error_handler'
require_relative 'claude_agent_server/middleware/authentication'
require_relative 'claude_agent_server/middleware/cors'
require_relative 'claude_agent_server/app'

module ClaudeAgentServer
  @config = Config.new

  class << self
    attr_reader :config

    def configure
      yield @config if block_given?
      @config
    end

    def reset_config!
      @config = Config.new
    end

    def app
      App.freeze.app
    end
  end
end
