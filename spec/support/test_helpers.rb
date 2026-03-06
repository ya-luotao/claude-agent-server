# frozen_string_literal: true

module TestHelpers
  def sample_assistant_message(text: 'Hello!', model: 'claude-sonnet-4-20250514')
    ClaudeAgentSDK::AssistantMessage.new(
      content: [ClaudeAgentSDK::TextBlock.new(text: text)],
      model: model
    )
  end

  def sample_user_message(content: 'Hi there')
    ClaudeAgentSDK::UserMessage.new(content: content)
  end

  def sample_result_message(is_error: false)
    ClaudeAgentSDK::ResultMessage.new(
      subtype: 'result',
      duration_ms: 1000,
      duration_api_ms: 800,
      is_error: is_error,
      num_turns: 1,
      session_id: 'test-session',
      total_cost_usd: 0.01,
      usage: { input_tokens: 100, output_tokens: 50 }
    )
  end

  def sample_stream_event
    ClaudeAgentSDK::StreamEvent.new(
      uuid: 'evt-123',
      session_id: 'test-session',
      event: { type: 'content_block_delta' }
    )
  end

  def sample_system_message(subtype: 'init')
    ClaudeAgentSDK::SystemMessage.new(subtype: subtype, data: {})
  end

  def sample_task_started_message
    ClaudeAgentSDK::TaskStartedMessage.new(
      subtype: 'task_started',
      data: {},
      task_id: 'task-1',
      description: 'Test task',
      uuid: 'uuid-1',
      session_id: 'session-1'
    )
  end

  def mock_session_entry(id: 'test-session-id', status: :connected, message_count: 0)
    entry = instance_double(
      ClaudeAgentServer::Services::SessionEntry,
      id: id,
      status: status,
      created_at: Time.now,
      last_activity: Time.now,
      message_count: message_count,
      events: []
    )
    allow(entry).to receive(:last_activity=)
    entry
  end
end
