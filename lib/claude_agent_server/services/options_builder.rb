# frozen_string_literal: true

require 'claude_agent_sdk'

module ClaudeAgentServer
  module Services
    module OptionsBuilder
      # Map of camelCase JSON keys to snake_case ClaudeAgentOptions kwargs
      CAMEL_TO_SNAKE = {
        'allowedTools' => :allowed_tools,
        'disallowedTools' => :disallowed_tools,
        'systemPrompt' => :system_prompt,
        'mcpServers' => :mcp_servers,
        'permissionMode' => :permission_mode,
        'continueConversation' => :continue_conversation,
        'resume' => :resume,
        'maxTurns' => :max_turns,
        'model' => :model,
        'cwd' => :cwd,
        'cliPath' => :cli_path,
        'env' => :env,
        'maxBudgetUsd' => :max_budget_usd,
        'maxThinkingTokens' => :max_thinking_tokens,
        'fallbackModel' => :fallback_model,
        'outputFormat' => :output_format,
        'includePartialMessages' => :include_partial_messages,
        'forkSession' => :fork_session,
        'enableFileCheckpointing' => :enable_file_checkpointing,
        'effort' => :effort,
        'appendAllowedTools' => :append_allowed_tools
      }.freeze

      module_function

      def build(params)
        kwargs = {}

        params.each do |key, value|
          snake_key = CAMEL_TO_SNAKE[key.to_s] || key.to_s.gsub(/([A-Z])/, '_\1').downcase.to_sym
          kwargs[snake_key] = value
        end

        # Merge with server-level defaults
        defaults = ClaudeAgentServer.config.default_sdk_options
        merged = defaults.merge(kwargs)

        # Force bypassPermissions for HTTP usage (no interactive terminal)
        merged[:permission_mode] ||= 'bypassPermissions'

        ClaudeAgentSDK::ClaudeAgentOptions.new(**merged)
      end
    end
  end
end
