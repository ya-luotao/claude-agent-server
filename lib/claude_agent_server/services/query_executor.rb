# frozen_string_literal: true

require 'claude_agent_sdk'

module ClaudeAgentServer
  module Services
    module QueryExecutor
      module_function

      def execute(prompt:, options:)
        messages = []

        ClaudeAgentSDK.query(prompt: prompt, options: options) do |message|
          messages << MessageSerializer.serialize(message)
        end

        messages
      end

      def stream(prompt:, options:, &block)
        ClaudeAgentSDK.query(prompt: prompt, options: options) do |message|
          block.call(message)
        end
      end
    end
  end
end
