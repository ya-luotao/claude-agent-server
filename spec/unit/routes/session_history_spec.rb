# frozen_string_literal: true

RSpec.describe 'Session history routes', type: :request do
  describe 'GET /cli-sessions' do
    it 'returns sessions list' do
      allow(ClaudeAgentSDK).to receive(:list_sessions).and_return([])

      get '/cli-sessions'

      expect(last_response.status).to eq(200)
      expect(json_response[:sessions]).to eq([])
    end

    it 'passes query parameters' do
      expect(ClaudeAgentSDK).to receive(:list_sessions).with(
        directory: '/tmp',
        limit: 10,
        include_worktrees: true
      ).and_return([])

      get '/cli-sessions?directory=/tmp&limit=10'
    end

    it 'handles includeWorktrees=false' do
      expect(ClaudeAgentSDK).to receive(:list_sessions).with(
        hash_including(include_worktrees: false)
      ).and_return([])

      get '/cli-sessions?includeWorktrees=false'
    end

    it 'serializes session info' do
      session = ClaudeAgentSDK::SDKSessionInfo.new(
        session_id: 'abc-123',
        summary: 'Test session',
        last_modified: 1_700_000_000,
        file_size: 1024,
        custom_title: 'My Session',
        first_prompt: 'hello',
        git_branch: 'main',
        cwd: '/tmp'
      )
      allow(ClaudeAgentSDK).to receive(:list_sessions).and_return([session])

      get '/cli-sessions'

      result = json_response[:sessions].first
      expect(result[:sessionId]).to eq('abc-123')
      expect(result[:summary]).to eq('Test session')
      expect(result[:customTitle]).to eq('My Session')
    end
  end

  describe 'GET /cli-sessions/:id/messages' do
    it 'returns session messages' do
      allow(ClaudeAgentSDK).to receive(:get_session_messages).and_return([])

      get '/cli-sessions/abc-123/messages'

      expect(last_response.status).to eq(200)
      expect(json_response[:sessionId]).to eq('abc-123')
      expect(json_response[:messages]).to eq([])
    end

    it 'passes pagination params' do
      expect(ClaudeAgentSDK).to receive(:get_session_messages).with(
        session_id: 'abc-123',
        directory: nil,
        limit: 50,
        offset: 10
      ).and_return([])

      get '/cli-sessions/abc-123/messages?limit=50&offset=10'
    end

    it 'serializes messages' do
      msg = ClaudeAgentSDK::SessionMessage.new(
        type: 'user',
        uuid: 'uuid-1',
        session_id: 'session-1',
        message: { role: 'user', content: 'hello' }
      )
      allow(ClaudeAgentSDK).to receive(:get_session_messages).and_return([msg])

      get '/cli-sessions/abc-123/messages'

      result = json_response[:messages].first
      expect(result[:type]).to eq('user')
      expect(result[:uuid]).to eq('uuid-1')
    end
  end
end
