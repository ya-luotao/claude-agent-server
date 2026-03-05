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

    it 'serializes ResultMessage' do
      msg = sample_result_message
      result = described_class.serialize(msg)

      expect(result[:type]).to eq('result')
      expect(result[:durationMs]).to eq(1000)
      expect(result[:isError]).to be false
      expect(result[:numTurns]).to eq(1)
      expect(result[:totalCostUsd]).to eq(0.01)
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
    end

    it 'serializes TaskStartedMessage' do
      msg = sample_task_started_message
      result = described_class.serialize(msg)

      expect(result[:type]).to eq('system')
      expect(result[:subtype]).to eq('task_started')
      expect(result[:taskId]).to eq('task-1')
    end

    it 'serializes ToolUseBlock content' do
      msg = ClaudeAgentSDK::AssistantMessage.new(
        content: [ClaudeAgentSDK::ToolUseBlock.new(id: 'tu-1', name: 'Read', input: { path: '/foo' })],
        model: 'test'
      )
      result = described_class.serialize(msg)
      block = result[:content].first

      expect(block[:type]).to eq('tool_use')
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
    end

    it 'serializes RateLimitEvent' do
      msg = ClaudeAgentSDK::RateLimitEvent.new(data: { retry_after: 30 })
      result = described_class.serialize(msg)

      expect(result[:type]).to eq('rate_limit_event')
    end

    it 'compacts nil values' do
      msg = ClaudeAgentSDK::AssistantMessage.new(
        content: [ClaudeAgentSDK::TextBlock.new(text: 'Hi')],
        model: 'test'
      )
      result = described_class.serialize(msg)

      expect(result).not_to have_key(:parentToolUseId)
      expect(result).not_to have_key(:error)
    end
  end
end
