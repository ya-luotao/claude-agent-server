# frozen_string_literal: true

RSpec.describe 'Sessions routes', type: :request do
  let(:manager) { ClaudeAgentServer::App.session_manager }
  let(:mock_client) { instance_double(ClaudeAgentSDK::Client) }

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

  describe 'GET /v1/sessions' do
    it 'returns empty sessions list' do
      get '/v1/sessions'

      expect(last_response.status).to eq(200)
      expect(json_response[:sessions]).to eq([])
    end
  end

  describe 'POST /v1/sessions' do
    it 'creates a new session' do
      post_json '/v1/sessions', { prompt: 'hello' }

      expect(last_response.status).to eq(201)
      expect(json_response[:id]).to match(/\A[0-9a-f-]{36}\z/)
      expect(%w[connected finished]).to include(json_response[:status])
    end

    it 'creates session without prompt' do
      post_json '/v1/sessions', {}

      expect(last_response.status).to eq(201)
    end

    it 'accepts client-provided session ID' do
      post_json '/v1/sessions', { id: 'my-custom-id' }

      expect(last_response.status).to eq(201)
      expect(json_response[:id]).to eq('my-custom-id')
    end

    it 'rejects duplicate session ID' do
      post_json '/v1/sessions', { id: 'dup-id' }
      expect(last_response.status).to eq(201)

      post_json '/v1/sessions', { id: 'dup-id' }
      expect(last_response.status).to eq(409)

      parsed = JSON.parse(last_response.body)
      expect(parsed['type']).to include('session_already_exists')
    end
  end

  describe 'GET /v1/sessions/:id' do
    it 'returns session info' do
      post_json '/v1/sessions', {}
      session_id = json_response[:id]

      get "/v1/sessions/#{session_id}"

      expect(last_response.status).to eq(200)
      expect(json_response[:id]).to eq(session_id)
    end

    it 'returns 404 for missing session' do
      get '/v1/sessions/nonexistent'

      expect(last_response.status).to eq(404)
    end
  end

  describe 'DELETE /v1/sessions/:id' do
    it 'deletes a session' do
      post_json '/v1/sessions', {}
      session_id = json_response[:id]

      delete "/v1/sessions/#{session_id}"

      expect(last_response.status).to eq(200)
      expect(json_response[:status]).to eq('disconnected')
    end

    it 'returns 404 for missing session' do
      delete '/v1/sessions/nonexistent'

      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /v1/sessions/:id/messages' do
    it 'sends a message to session' do
      post_json '/v1/sessions', {}
      session_id = json_response[:id]

      expect(mock_client).to receive(:query).with('hello')
      post_json "/v1/sessions/#{session_id}/messages", { prompt: 'hello' }

      expect(last_response.status).to eq(200)
      expect(json_response[:status]).to eq('sent')
    end

    it 'returns 400 without prompt' do
      post_json '/v1/sessions', {}
      session_id = json_response[:id]

      post_json "/v1/sessions/#{session_id}/messages", {}

      expect(last_response.status).to eq(400)
    end
  end

  describe 'GET /v1/sessions/:id/events' do
    it 'returns events with offset-based pagination' do
      post_json '/v1/sessions', {}
      session_id = json_response[:id]

      get "/v1/sessions/#{session_id}/events?offset=0&limit=10"

      expect(last_response.status).to eq(200)
      expect(json_response[:events]).to be_an(Array)
      expect(json_response[:nextOffset]).to be_a(Integer)
    end

    it 'defaults offset to 0' do
      post_json '/v1/sessions', {}
      session_id = json_response[:id]

      get "/v1/sessions/#{session_id}/events"

      expect(last_response.status).to eq(200)
      expect(json_response[:nextOffset]).to eq(0)
    end
  end

  describe 'POST /v1/sessions/:id/interrupt' do
    it 'interrupts a session' do
      post_json '/v1/sessions', {}
      session_id = json_response[:id]

      expect(mock_client).to receive(:interrupt)
      post "/v1/sessions/#{session_id}/interrupt"

      expect(last_response.status).to eq(200)
      expect(json_response[:status]).to eq('interrupted')
    end
  end

  describe 'POST /v1/sessions/:id/model' do
    it 'changes the model' do
      post_json '/v1/sessions', {}
      session_id = json_response[:id]

      expect(mock_client).to receive(:set_model).with('claude-opus-4-20250514')
      post_json "/v1/sessions/#{session_id}/model", { model: 'claude-opus-4-20250514' }

      expect(last_response.status).to eq(200)
      expect(json_response[:model]).to eq('claude-opus-4-20250514')
    end

    it 'returns 400 without model' do
      post_json '/v1/sessions', {}
      session_id = json_response[:id]

      post_json "/v1/sessions/#{session_id}/model", {}

      expect(last_response.status).to eq(400)
    end
  end

  describe 'GET /v1/sessions/:id/mcp-status' do
    it 'returns MCP status' do
      post_json '/v1/sessions', {}
      session_id = json_response[:id]

      get "/v1/sessions/#{session_id}/mcp-status"

      expect(last_response.status).to eq(200)
      expect(json_response[:sessionId]).to eq(session_id)
    end
  end

  describe 'GET /v1/sessions/:id/history' do
    it 'returns empty history' do
      post_json '/v1/sessions', {}
      session_id = json_response[:id]

      get "/v1/sessions/#{session_id}/history"

      expect(last_response.status).to eq(200)
      expect(json_response[:messages]).to eq([])
    end
  end

  after(:each) do
    manager.shutdown
  end
end
