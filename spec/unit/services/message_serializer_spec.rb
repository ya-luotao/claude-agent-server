# frozen_string_literal: true

RSpec.describe ClaudeAgentServer::Services::MessageSerializer do
  describe '.serialize' do
    it 'serializes AssistantMessage with text content' do
      msg = sample_assistant_message(text: 'Hello world')
      result = described_class.serialize(msg)

      expect(result[:type]).to eq('assistant')
      expect(result[:content]).to be_an(Array)
      expect(result[:content].first[:type]).to eq('text')
      expect(result[:content].first[:text]).to eq('Hello world')
    end

    it 'serializes AssistantMessage with model field' do
      msg = sample_assistant_message(model: 'claude-opus-4-20250514')
      result = described_class.serialize(msg)

      expect(result[:model]).to eq('claude-opus-4-20250514')
    end

    it 'serializes UserMessage with string content' do
      msg = ClaudeAgentSDK::UserMessage.new(content: 'Hi there')
      result = described_class.serialize(msg)

      expect(result[:type]).to eq('user')
      expect(result[:content]).to eq('Hi there')
    end

    it 'serializes UserMessage with block content' do
      msg = ClaudeAgentSDK::UserMessage.new(
        content: [ClaudeAgentSDK::TextBlock.new(text: 'Hello')]
      )
      result = described_class.serialize(msg)

      expect(result[:content]).to be_an(Array)
      expect(result[:content].first[:text]).to eq('Hello')
    end

    it 'serializes UserMessage with uuid' do
      msg = ClaudeAgentSDK::UserMessage.new(content: 'hi', uuid: 'uuid-123')
      result = described_class.serialize(msg)

      expect(result[:uuid]).to eq('uuid-123')
    end

    it 'serializes UserMessage with parent_tool_use_id' do
      msg = ClaudeAgentSDK::UserMessage.new(content: 'hi', parent_tool_use_id: 'tu-1')
      result = described_class.serialize(msg)

      expect(result[:parentToolUseId]).to eq('tu-1')
    end

    it 'serializes ResultMessage with all fields' do
      msg = sample_result_message
      result = described_class.serialize(msg)

      expect(result[:type]).to eq('result')
      expect(result[:subtype]).to eq('result')
      expect(result[:durationMs]).to eq(1000)
      expect(result[:durationApiMs]).to eq(800)
      expect(result[:isError]).to be false
      expect(result[:numTurns]).to eq(1)
      expect(result[:sessionId]).to eq('test-session')
      expect(result[:totalCostUsd]).to eq(0.01)
      expect(result[:usage]).to eq({ input_tokens: 100, output_tokens: 50 })
    end

    it 'serializes ResultMessage with error' do
      msg = sample_result_message(is_error: true)
      result = described_class.serialize(msg)

      expect(result[:isError]).to be true
    end

    it 'serializes SystemMessage' do
      msg = sample_system_message(subtype: 'init')
      result = described_class.serialize(msg)

      expect(result[:type]).to eq('system')
      expect(result[:subtype]).to eq('init')
    end

    it 'serializes StreamEvent' do
      msg = sample_stream_event
      result = described_class.serialize(msg)

      expect(result[:type]).to eq('stream_event')
      expect(result[:uuid]).to eq('evt-123')
      expect(result[:sessionId]).to eq('test-session')
    end

    it 'serializes TaskStartedMessage' do
      msg = sample_task_started_message
      result = described_class.serialize(msg)

      expect(result[:type]).to eq('system')
      expect(result[:subtype]).to eq('task_started')
      expect(result[:taskId]).to eq('task-1')
      expect(result[:description]).to eq('Test task')
    end

    it 'serializes TaskProgressMessage' do
      msg = ClaudeAgentSDK::TaskProgressMessage.new(
        subtype: 'task_progress', data: {},
        task_id: 'task-1', description: 'Working',
        usage: { tokens: 100 }, uuid: 'uuid-1',
        session_id: 'session-1', last_tool_name: 'Read'
      )
      result = described_class.serialize(msg)

      expect(result[:type]).to eq('system')
      expect(result[:subtype]).to eq('task_progress')
      expect(result[:lastToolName]).to eq('Read')
    end

    it 'serializes TaskNotificationMessage' do
      msg = ClaudeAgentSDK::TaskNotificationMessage.new(
        subtype: 'task_notification', data: {},
        task_id: 'task-1', status: 'completed',
        output_file: '/tmp/out', summary: 'Done',
        uuid: 'uuid-1', session_id: 'session-1'
      )
      result = described_class.serialize(msg)

      expect(result[:type]).to eq('system')
      expect(result[:subtype]).to eq('task_notification')
      expect(result[:status]).to eq('completed')
      expect(result[:summary]).to eq('Done')
    end

    it 'serializes ToolUseBlock content' do
      msg = ClaudeAgentSDK::AssistantMessage.new(
        content: [ClaudeAgentSDK::ToolUseBlock.new(id: 'tu-1', name: 'Read', input: { path: '/foo' })],
        model: 'test'
      )
      result = described_class.serialize(msg)
      block = result[:content].first

      expect(block[:type]).to eq('tool_use')
      expect(block[:id]).to eq('tu-1')
      expect(block[:name]).to eq('Read')
      expect(block[:input]).to eq({ path: '/foo' })
    end

    it 'serializes ToolResultBlock content' do
      msg = ClaudeAgentSDK::UserMessage.new(
        content: [ClaudeAgentSDK::ToolResultBlock.new(tool_use_id: 'tu-1', content: 'result')]
      )
      result = described_class.serialize(msg)
      block = result[:content].first

      expect(block[:type]).to eq('tool_result')
      expect(block[:toolUseId]).to eq('tu-1')
      expect(block[:content]).to eq('result')
    end

    it 'serializes ToolResultBlock with error flag' do
      msg = ClaudeAgentSDK::UserMessage.new(
        content: [ClaudeAgentSDK::ToolResultBlock.new(tool_use_id: 'tu-1', is_error: true)]
      )
      result = described_class.serialize(msg)
      block = result[:content].first

      expect(block[:isError]).to be true
    end

    it 'serializes ThinkingBlock' do
      msg = ClaudeAgentSDK::AssistantMessage.new(
        content: [ClaudeAgentSDK::ThinkingBlock.new(thinking: 'hmm', signature: 'sig')],
        model: 'test'
      )
      result = described_class.serialize(msg)
      block = result[:content].first

      expect(block[:type]).to eq('thinking')
      expect(block[:thinking]).to eq('hmm')
      expect(block[:signature]).to eq('sig')
    end

    it 'serializes UnknownBlock preserving raw data' do
      msg = ClaudeAgentSDK::AssistantMessage.new(
        content: [ClaudeAgentSDK::UnknownBlock.new(type: 'image', data: { type: 'image', url: 'http://...' })],
        model: 'test'
      )
      result = described_class.serialize(msg)
      block = result[:content].first

      expect(block[:type]).to eq('image')
    end

    it 'serializes RateLimitEvent' do
      msg = ClaudeAgentSDK::RateLimitEvent.new(data: { retry_after: 30 })
      result = described_class.serialize(msg)

      expect(result[:type]).to eq('rate_limit_event')
      expect(result[:data]).to eq({ retry_after: 30 })
    end

    it 'compacts nil values from AssistantMessage' do
      msg = ClaudeAgentSDK::AssistantMessage.new(
        content: [ClaudeAgentSDK::TextBlock.new(text: 'Hi')],
        model: 'test'
      )
      result = described_class.serialize(msg)

      expect(result).not_to have_key(:parentToolUseId)
      expect(result).not_to have_key(:error)
    end

    it 'compacts nil values from UserMessage' do
      msg = ClaudeAgentSDK::UserMessage.new(content: 'hi')
      result = described_class.serialize(msg)

      expect(result).not_to have_key(:uuid)
      expect(result).not_to have_key(:parentToolUseId)
    end

    it 'returns unknown type for unrecognized objects' do
      result = described_class.serialize('unexpected')

      expect(result[:type]).to eq('unknown')
    end

    it 'serializes AssistantMessage with error field' do
      msg = ClaudeAgentSDK::AssistantMessage.new(
        content: [ClaudeAgentSDK::TextBlock.new(text: 'error')],
        model: 'test',
        error: 'rate_limit'
      )
      result = described_class.serialize(msg)

      expect(result[:error]).to eq('rate_limit')
    end
  end
end
