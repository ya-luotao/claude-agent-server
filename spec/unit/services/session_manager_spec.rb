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
    it 'creates a new session with generated UUID' do
      entry = manager.create_session(options: mock_options)

      expect(entry).to be_a(ClaudeAgentServer::Services::SessionEntry)
      expect(entry.id).to match(/\A[0-9a-f-]{36}\z/)
      expect(%i[connected finished]).to include(entry.status)
    end

    it 'creates a session with client-provided ID' do
      entry = manager.create_session(options: mock_options, id: 'my-session')

      expect(entry.id).to eq('my-session')
    end

    it 'rejects duplicate session IDs' do
      manager.create_session(options: mock_options, id: 'dup')

      expect { manager.create_session(options: mock_options, id: 'dup') }.to raise_error(
        ClaudeAgentServer::SessionAlreadyExistsError, /already exists/
      )
    end

    it 'connects the client without prompt' do
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
        ClaudeAgentServer::SessionLimitError, /Maximum session limit/
      )
    end

    it 'passes options to SDK Client' do
      expect(ClaudeAgentSDK::Client).to receive(:new).with(options: mock_options).and_return(mock_client)
      manager.create_session(options: mock_options)
    end

    it 'creates unique IDs for concurrent sessions' do
      e1 = manager.create_session(options: mock_options)
      e2 = manager.create_session(options: mock_options)

      expect(e1.id).not_to eq(e2.id)
    end
  end

  describe '#get_session' do
    it 'returns existing session' do
      entry = manager.create_session(options: mock_options)
      found = manager.get_session(entry.id)

      expect(found.id).to eq(entry.id)
    end

    it 'raises SessionNotFoundError for missing session' do
      expect { manager.get_session('nonexistent') }.to raise_error(
        ClaudeAgentServer::SessionNotFoundError, /nonexistent/
      )
    end
  end

  describe '#destroy_session' do
    it 'removes and disconnects session' do
      entry = manager.create_session(options: mock_options)
      expect(mock_client).to receive(:disconnect)

      result = manager.destroy_session(entry.id)
      expect(result.id).to eq(entry.id)
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

    it 'returns a snapshot (not live reference)' do
      manager.create_session(options: mock_options)
      list = manager.list_sessions
      manager.create_session(options: mock_options)

      expect(list.size).to eq(1)
      expect(manager.list_sessions.size).to eq(2)
    end
  end

  describe '#shutdown' do
    it 'disconnects all sessions and clears registry' do
      manager.create_session(options: mock_options)
      manager.create_session(options: mock_options)

      expect(mock_client).to receive(:disconnect).twice
      manager.shutdown
      expect(manager.sessions).to be_empty
    end

    it 'is safe to call when no sessions exist' do
      expect { manager.shutdown }.not_to raise_error
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

  describe '#initialize' do
    it 'starts with status :connected' do
      expect(entry.status).to eq(:connected)
    end

    it 'starts with empty events' do
      expect(entry.events).to eq([])
    end

    it 'starts with message_count 0' do
      expect(entry.message_count).to eq(0)
    end

    it 'sets created_at' do
      expect(entry.created_at).to be_a(Time)
    end
  end

  describe '#broadcast' do
    it 'stores events with monotonic index' do
      entry.broadcast('msg-1')
      entry.broadcast('msg-2')
      entry.broadcast('msg-3')

      expect(entry.message_count).to eq(3)
      expect(entry.events.map(&:index)).to eq([0, 1, 2])
      expect(entry.events.map(&:message)).to eq(%w[msg-1 msg-2 msg-3])
    end

    it 'assigns timestamps to events' do
      entry.broadcast('msg')

      expect(entry.events.first.timestamp).to be_a(Time)
    end

    it 'updates last_activity' do
      original_time = entry.last_activity
      sleep(0.01)
      entry.broadcast('test-message')

      expect(entry.last_activity).to be > original_time
    end
  end

  describe '#get_events' do
    before do
      entry.broadcast('a')
      entry.broadcast('b')
      entry.broadcast('c')
      entry.broadcast('d')
      entry.broadcast('e')
    end

    it 'returns all events from offset 0' do
      events = entry.get_events(offset: 0)

      expect(events.size).to eq(5)
      expect(events.first.message).to eq('a')
      expect(events.last.message).to eq('e')
    end

    it 'returns events from a specific offset' do
      events = entry.get_events(offset: 2)

      expect(events.size).to eq(3)
      expect(events.map(&:message)).to eq(%w[c d e])
    end

    it 'respects limit' do
      events = entry.get_events(offset: 0, limit: 2)

      expect(events.size).to eq(2)
      expect(events.map(&:message)).to eq(%w[a b])
    end

    it 'combines offset and limit' do
      events = entry.get_events(offset: 1, limit: 3)

      expect(events.size).to eq(3)
      expect(events.map(&:message)).to eq(%w[b c d])
    end

    it 'returns empty for offset beyond events' do
      events = entry.get_events(offset: 100)

      expect(events).to eq([])
    end

    it 'handles limit larger than remaining events' do
      events = entry.get_events(offset: 3, limit: 100)

      expect(events.size).to eq(2)
      expect(events.map(&:message)).to eq(%w[d e])
    end

    it 'returns empty with limit 0' do
      events = entry.get_events(offset: 0, limit: 0)

      expect(events).to eq([])
    end
  end

  describe '#disconnect' do
    it 'disconnects the client' do
      expect(mock_client).to receive(:disconnect)
      entry.disconnect

      expect(entry.status).to eq(:disconnected)
    end
  end

  describe '#finish' do
    it 'sets status to :finished' do
      entry.finish

      expect(entry.status).to eq(:finished)
    end
  end
end

RSpec.describe ClaudeAgentServer::Services::SessionEvent do
  it 'stores index, message, and timestamp' do
    event = described_class.new(index: 5, message: 'hello')

    expect(event.index).to eq(5)
    expect(event.message).to eq('hello')
    expect(event.timestamp).to be_a(Time)
  end

  it 'freezes timestamp at creation time' do
    event = described_class.new(index: 0, message: 'test')
    created_at = event.timestamp
    sleep(0.01)

    expect(event.timestamp).to eq(created_at)
  end
end
