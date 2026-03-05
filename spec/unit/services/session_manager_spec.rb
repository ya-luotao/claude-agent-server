# frozen_string_literal: true

RSpec.describe ClaudeAgentServer::Services::SessionManager do
  subject(:manager) { described_class.new }

  let(:mock_client) { instance_double(ClaudeAgentSDK::Client) }
  let(:mock_options) { instance_double(ClaudeAgentSDK::ClaudeAgentOptions) }

  before do
    allow(ClaudeAgentSDK::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:connect)
    allow(mock_client).to receive(:disconnect)
    allow(mock_client).to receive(:receive_messages)
  end

  describe '#create_session' do
    it 'creates a new session' do
      entry = manager.create_session(options: mock_options)

      expect(entry).to be_a(ClaudeAgentServer::Services::SessionEntry)
      expect(entry.id).to match(/\A[0-9a-f-]{36}\z/)
      # Status may be :connected or :finished (mock reader completes immediately)
      expect(%i[connected finished]).to include(entry.status)
    end

    it 'connects the client' do
      expect(mock_client).to receive(:connect).with(nil)
      manager.create_session(options: mock_options)
    end

    it 'connects with prompt when provided' do
      expect(mock_client).to receive(:connect).with('hello')
      manager.create_session(options: mock_options, prompt: 'hello')
    end

    it 'enforces max sessions limit' do
      ClaudeAgentServer.config.max_sessions = 1
      manager.create_session(options: mock_options)

      expect { manager.create_session(options: mock_options) }.to raise_error(
        ClaudeAgentServer::SessionLimitError
      )
    end
  end

  describe '#get_session' do
    it 'returns existing session' do
      entry = manager.create_session(options: mock_options)
      found = manager.get_session(entry.id)

      expect(found.id).to eq(entry.id)
    end

    it 'raises for missing session' do
      expect { manager.get_session('nonexistent') }.to raise_error(
        ClaudeAgentServer::SessionNotFoundError
      )
    end
  end

  describe '#destroy_session' do
    it 'removes and disconnects session' do
      entry = manager.create_session(options: mock_options)
      expect(mock_client).to receive(:disconnect)

      manager.destroy_session(entry.id)
      expect { manager.get_session(entry.id) }.to raise_error(
        ClaudeAgentServer::SessionNotFoundError
      )
    end

    it 'raises for missing session' do
      expect { manager.destroy_session('nonexistent') }.to raise_error(
        ClaudeAgentServer::SessionNotFoundError
      )
    end
  end

  describe '#list_sessions' do
    it 'returns all sessions' do
      manager.create_session(options: mock_options)
      manager.create_session(options: mock_options)

      expect(manager.list_sessions.size).to eq(2)
    end

    it 'returns empty array when no sessions' do
      expect(manager.list_sessions).to eq([])
    end
  end

  describe '#shutdown' do
    it 'disconnects all sessions' do
      manager.create_session(options: mock_options)
      manager.create_session(options: mock_options)

      expect(mock_client).to receive(:disconnect).twice
      manager.shutdown
      expect(manager.sessions).to be_empty
    end
  end
end

RSpec.describe ClaudeAgentServer::Services::SessionEntry do
  let(:mock_client) { instance_double(ClaudeAgentSDK::Client) }

  subject(:entry) do
    described_class.new(id: 'test-id', client: mock_client)
  end

  before do
    allow(mock_client).to receive(:disconnect)
    allow(mock_client).to receive(:receive_messages)
  end

  describe '#message_count' do
    it 'returns 0 initially' do
      expect(entry.message_count).to eq(0)
    end
  end

  describe '#broadcast' do
    it 'stores message and updates last_activity' do
      original_time = entry.last_activity
      sleep(0.01)
      entry.broadcast('test-message')

      expect(entry.message_count).to eq(1)
      expect(entry.last_activity).to be > original_time
    end
  end

  describe '#disconnect' do
    it 'disconnects the client' do
      expect(mock_client).to receive(:disconnect)
      entry.disconnect

      expect(entry.status).to eq(:disconnected)
    end
  end
end
