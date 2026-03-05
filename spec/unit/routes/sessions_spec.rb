# frozen_string_literal: true

RSpec.describe 'Sessions routes', type: :request do
  let(:manager) { ClaudeAgentServer::App.session_manager }
  let(:mock_client) { instance_double(ClaudeAgentSDK::Client) }
  let(:mock_entry) { mock_session_entry }

  before do
    allow(ClaudeAgentSDK::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:connect)
    allow(mock_client).to receive(:disconnect)
    allow(mock_client).to receive(:receive_messages)
    allow(mock_client).to receive(:query)
    allow(mock_client).to receive(:interrupt)
    allow(mock_client).to receive(:set_model)
    allow(mock_client).to receive(:get_mcp_status).and_return({ mcpServers: [] })
  end

  describe 'GET /sessions' do
    it 'returns empty sessions list' do
      get '/sessions'

      expect(last_response.status).to eq(200)
      expect(json_response[:sessions]).to eq([])
    end
  end

  describe 'POST /sessions' do
    it 'creates a new session' do
      post_json '/sessions', { prompt: 'hello' }

      expect(last_response.status).to eq(201)
      expect(json_response[:id]).to match(/\A[0-9a-f-]{36}\z/)
      expect(%w[connected finished]).to include(json_response[:status])
    end

    it 'creates session without prompt' do
      post_json '/sessions', {}

      expect(last_response.status).to eq(201)
    end
  end

  describe 'GET /sessions/:id' do
    it 'returns session info' do
      post_json '/sessions', {}
      session_id = json_response[:id]

      get "/sessions/#{session_id}"

      expect(last_response.status).to eq(200)
      expect(json_response[:id]).to eq(session_id)
    end

    it 'returns 404 for missing session' do
      get '/sessions/nonexistent'

      expect(last_response.status).to eq(404)
    end
  end

  describe 'DELETE /sessions/:id' do
    it 'deletes a session' do
      post_json '/sessions', {}
      session_id = json_response[:id]

      delete "/sessions/#{session_id}"

      expect(last_response.status).to eq(200)
      expect(json_response[:status]).to eq('disconnected')
    end

    it 'returns 404 for missing session' do
      delete '/sessions/nonexistent'

      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /sessions/:id/messages' do
    it 'sends a message to session' do
      post_json '/sessions', {}
      session_id = json_response[:id]

      expect(mock_client).to receive(:query).with('hello')
      post_json "/sessions/#{session_id}/messages", { prompt: 'hello' }

      expect(last_response.status).to eq(200)
      expect(json_response[:status]).to eq('sent')
    end

    it 'returns 400 without prompt' do
      post_json '/sessions', {}
      session_id = json_response[:id]

      post_json "/sessions/#{session_id}/messages", {}

      expect(last_response.status).to eq(400)
    end
  end

  describe 'POST /sessions/:id/interrupt' do
    it 'interrupts a session' do
      post_json '/sessions', {}
      session_id = json_response[:id]

      expect(mock_client).to receive(:interrupt)
      post "/sessions/#{session_id}/interrupt"

      expect(last_response.status).to eq(200)
      expect(json_response[:status]).to eq('interrupted')
    end
  end

  describe 'POST /sessions/:id/model' do
    it 'changes the model' do
      post_json '/sessions', {}
      session_id = json_response[:id]

      expect(mock_client).to receive(:set_model).with('claude-opus-4-20250514')
      post_json "/sessions/#{session_id}/model", { model: 'claude-opus-4-20250514' }

      expect(last_response.status).to eq(200)
      expect(json_response[:model]).to eq('claude-opus-4-20250514')
    end

    it 'returns 400 without model' do
      post_json '/sessions', {}
      session_id = json_response[:id]

      post_json "/sessions/#{session_id}/model", {}

      expect(last_response.status).to eq(400)
    end
  end

  describe 'GET /sessions/:id/mcp-status' do
    it 'returns MCP status' do
      post_json '/sessions', {}
      session_id = json_response[:id]

      get "/sessions/#{session_id}/mcp-status"

      expect(last_response.status).to eq(200)
      expect(json_response[:sessionId]).to eq(session_id)
    end
  end

  describe 'GET /sessions/:id/history' do
    it 'returns empty history' do
      post_json '/sessions', {}
      session_id = json_response[:id]

      get "/sessions/#{session_id}/history"

      expect(last_response.status).to eq(200)
      expect(json_response[:messages]).to eq([])
    end
  end

  after(:each) do
    # Clean up sessions
    manager.shutdown
  end
end
