# frozen_string_literal: true

require 'claude_agent_sdk'

module ClaudeAgentServer
  module Services
    module MessageSerializer
      module_function

      def serialize(message)
        case message
        when ClaudeAgentSDK::UserMessage
          serialize_user_message(message)
        when ClaudeAgentSDK::AssistantMessage
          serialize_assistant_message(message)
        when ClaudeAgentSDK::ResultMessage
          serialize_result_message(message)
        when ClaudeAgentSDK::TaskStartedMessage
          serialize_task_started_message(message)
        when ClaudeAgentSDK::TaskProgressMessage
          serialize_task_progress_message(message)
        when ClaudeAgentSDK::TaskNotificationMessage
          serialize_task_notification_message(message)
        when ClaudeAgentSDK::SystemMessage
          serialize_system_message(message)
        when ClaudeAgentSDK::StreamEvent
          serialize_stream_event(message)
        when ClaudeAgentSDK::RateLimitEvent
          serialize_rate_limit_event(message)
        else
          { type: 'unknown', data: message.to_s }
        end
      end

      def serialize_user_message(msg)
        {
          type: 'user',
          content: serialize_content(msg.content),
          uuid: msg.uuid,
          parentToolUseId: msg.parent_tool_use_id
        }.compact
      end

      def serialize_assistant_message(msg)
        {
          type: 'assistant',
          content: serialize_content(msg.content),
          model: msg.model,
          parentToolUseId: msg.parent_tool_use_id,
          error: msg.error
        }.compact
      end

      def serialize_result_message(msg)
        {
          type: 'result',
          subtype: msg.subtype,
          durationMs: msg.duration_ms,
          durationApiMs: msg.duration_api_ms,
          isError: msg.is_error,
          numTurns: msg.num_turns,
          sessionId: msg.session_id,
          stopReason: msg.stop_reason,
          totalCostUsd: msg.total_cost_usd,
          usage: msg.usage,
          result: msg.result,
          structuredOutput: msg.structured_output
        }.compact
      end

      def serialize_task_started_message(msg)
        {
          type: 'system',
          subtype: 'task_started',
          taskId: msg.task_id,
          description: msg.description,
          uuid: msg.uuid,
          sessionId: msg.session_id,
          toolUseId: msg.tool_use_id,
          taskType: msg.task_type
        }.compact
      end

      def serialize_task_progress_message(msg)
        {
          type: 'system',
          subtype: 'task_progress',
          taskId: msg.task_id,
          description: msg.description,
          usage: msg.usage,
          uuid: msg.uuid,
          sessionId: msg.session_id,
          toolUseId: msg.tool_use_id,
          lastToolName: msg.last_tool_name
        }.compact
      end

      def serialize_task_notification_message(msg)
        {
          type: 'system',
          subtype: 'task_notification',
          taskId: msg.task_id,
          status: msg.status,
          outputFile: msg.output_file,
          summary: msg.summary,
          uuid: msg.uuid,
          sessionId: msg.session_id,
          toolUseId: msg.tool_use_id,
          usage: msg.usage
        }.compact
      end

      def serialize_system_message(msg)
        {
          type: 'system',
          subtype: msg.subtype,
          data: msg.data
        }.compact
      end

      def serialize_stream_event(msg)
        {
          type: 'stream_event',
          uuid: msg.uuid,
          sessionId: msg.session_id,
          event: msg.event,
          parentToolUseId: msg.parent_tool_use_id
        }.compact
      end

      def serialize_rate_limit_event(msg)
        {
          type: 'rate_limit_event',
          data: msg.data
        }.compact
      end

      def serialize_content(content)
        return content.map { |block| serialize_content_block(block) } if content.is_a?(Array)

        content
      end

      def serialize_content_block(block)
        case block
        when ClaudeAgentSDK::TextBlock
          { type: 'text', text: block.text }
        when ClaudeAgentSDK::ThinkingBlock
          { type: 'thinking', thinking: block.thinking, signature: block.signature }
        when ClaudeAgentSDK::ToolUseBlock
          { type: 'tool_use', id: block.id, name: block.name, input: block.input }
        when ClaudeAgentSDK::ToolResultBlock
          result = { type: 'tool_result', toolUseId: block.tool_use_id }
          result[:content] = block.content if block.content
          result[:isError] = block.is_error unless block.is_error.nil?
          result
        when ClaudeAgentSDK::UnknownBlock
          block.data
        else
          block
        end
      end
    end
  end
end
