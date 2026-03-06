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

  after(:each) do
    manager.shutdown
  end

  # --- GET /v1/sessions ---

  describe 'GET /v1/sessions' do
    it 'returns empty sessions list' do
      get '/v1/sessions'

      expect(last_response.status).to eq(200)
      expect(json_response[:sessions]).to eq([])
    end

    it 'returns multiple sessions' do
      post_json '/v1/sessions', { id: 'a' }
      post_json '/v1/sessions', { id: 'b' }

      get '/v1/sessions'

      expect(last_response.status).to eq(200)
      expect(json_response[:sessions].size).to eq(2)
      ids = json_response[:sessions].map { |s| s[:id] }
      expect(ids).to contain_exactly('a', 'b')
    end

    it 'includes all session info fields' do
      post_json '/v1/sessions', { id: 'info-test' }

      get '/v1/sessions'

      session = json_response[:sessions].first
      expect(session).to have_key(:id)
      expect(session).to have_key(:status)
      expect(session).to have_key(:createdAt)
      expect(session).to have_key(:lastActivity)
      expect(session).to have_key(:messageCount)
    end
  end

  # --- POST /v1/sessions ---

  describe 'POST /v1/sessions' do
    it 'creates a new session with generated UUID' do
      post_json '/v1/sessions', { prompt: 'hello' }

      expect(last_response.status).to eq(201)
      expect(json_response[:id]).to match(/\A[0-9a-f-]{36}\z/)
      expect(%w[connected finished]).to include(json_response[:status])
    end

    it 'creates session without prompt' do
      post_json '/v1/sessions', {}

      expect(last_response.status).to eq(201)
    end

    it 'creates session with empty body' do
      post '/v1/sessions', '', { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(201)
    end

    it 'accepts client-provided session ID' do
      post_json '/v1/sessions', { id: 'my-custom-id' }

      expect(last_response.status).to eq(201)
      expect(json_response[:id]).to eq('my-custom-id')
    end

    it 'rejects duplicate session ID with 409' do
      post_json '/v1/sessions', { id: 'dup-id' }
      expect(last_response.status).to eq(201)

      post_json '/v1/sessions', { id: 'dup-id' }
      expect(last_response.status).to eq(409)

      parsed = JSON.parse(last_response.body)
      expect(parsed['type']).to include('session_already_exists')
      expect(parsed['title']).to eq('Session Already Exists')
      expect(parsed['status']).to eq(409)
    end

    it 'returns 429 when session limit reached' do
      ClaudeAgentServer.config.max_sessions = 1
      post_json '/v1/sessions', {}
      expect(last_response.status).to eq(201)

      post_json '/v1/sessions', {}
      expect(last_response.status).to eq(429)

      parsed = JSON.parse(last_response.body)
      expect(parsed['type']).to include('session_limit_reached')
    end

    it 'returns 400 for invalid JSON body' do
      post '/v1/sessions', 'not json', { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(400)
      parsed = JSON.parse(last_response.body)
      expect(parsed['type']).to include('invalid_request')
    end

    it 'returns content-type application/json' do
      post_json '/v1/sessions', {}

      expect(last_response.content_type).to include('application/json')
    end

    it 'returns ISO8601 timestamps' do
      post_json '/v1/sessions', {}

      expect(json_response[:createdAt]).to match(/\d{4}-\d{2}-\d{2}T/)
      expect(json_response[:lastActivity]).to match(/\d{4}-\d{2}-\d{2}T/)
    end

    it 'starts with messageCount 0' do
      post_json '/v1/sessions', {}

      expect(json_response[:messageCount]).to eq(0)
    end
  end

  # --- GET /v1/sessions/:id ---

  describe 'GET /v1/sessions/:id' do
    it 'returns session info' do
      post_json '/v1/sessions', { id: 'get-test' }

      get '/v1/sessions/get-test'

      expect(last_response.status).to eq(200)
      expect(json_response[:id]).to eq('get-test')
    end

    it 'returns 404 for missing session' do
      get '/v1/sessions/nonexistent'

      expect(last_response.status).to eq(404)
      parsed = JSON.parse(last_response.body)
      expect(parsed['type']).to include('session_not_found')
      expect(parsed['detail']).to include('nonexistent')
    end

    it 'returns problem+json content type for errors' do
      get '/v1/sessions/nonexistent'

      expect(last_response.content_type).to include('application/problem+json')
    end
  end

  # --- DELETE /v1/sessions/:id ---

  describe 'DELETE /v1/sessions/:id' do
    it 'deletes a session' do
      post_json '/v1/sessions', { id: 'del-test' }

      delete '/v1/sessions/del-test'

      expect(last_response.status).to eq(200)
      expect(json_response[:status]).to eq('disconnected')
      expect(json_response[:id]).to eq('del-test')
    end

    it 'returns 404 for missing session' do
      delete '/v1/sessions/nonexistent'

      expect(last_response.status).to eq(404)
    end

    it 'session is gone after delete' do
      post_json '/v1/sessions', { id: 'gone-test' }
      delete '/v1/sessions/gone-test'

      get '/v1/sessions/gone-test'
      expect(last_response.status).to eq(404)
    end

    it 'no longer appears in list after delete' do
      post_json '/v1/sessions', { id: 'list-del' }
      delete '/v1/sessions/list-del'

      get '/v1/sessions'
      ids = json_response[:sessions].map { |s| s[:id] }
      expect(ids).not_to include('list-del')
    end
  end

  # --- POST /v1/sessions/:id/messages ---

  describe 'POST /v1/sessions/:id/messages' do
    it 'sends a message to session' do
      post_json '/v1/sessions', { id: 'msg-test' }

      expect(mock_client).to receive(:query).with('hello')
      post_json '/v1/sessions/msg-test/messages', { prompt: 'hello' }

      expect(last_response.status).to eq(200)
      expect(json_response[:status]).to eq('sent')
      expect(json_response[:sessionId]).to eq('msg-test')
    end

    it 'returns 400 without prompt' do
      post_json '/v1/sessions', { id: 'msg-400' }

      post_json '/v1/sessions/msg-400/messages', {}

      expect(last_response.status).to eq(400)
    end

    it 'returns 404 for missing session' do
      post_json '/v1/sessions/no-such-session/messages', { prompt: 'hi' }

      expect(last_response.status).to eq(404)
    end
  end

  # --- GET /v1/sessions/:id/events ---

  describe 'GET /v1/sessions/:id/events' do
    it 'returns empty events with nextOffset 0' do
      post_json '/v1/sessions', { id: 'evt-empty' }

      get '/v1/sessions/evt-empty/events'

      expect(last_response.status).to eq(200)
      expect(json_response[:events]).to eq([])
      expect(json_response[:nextOffset]).to eq(0)
      expect(json_response[:sessionId]).to eq('evt-empty')
    end

    it 'returns events with offset and limit' do
      post_json '/v1/sessions', { id: 'evt-page' }

      get '/v1/sessions/evt-page/events?offset=0&limit=10'

      expect(last_response.status).to eq(200)
      expect(json_response[:events]).to be_an(Array)
    end

    it 'returns 404 for missing session' do
      get '/v1/sessions/nonexistent/events'

      expect(last_response.status).to eq(404)
    end
  end

  # --- GET /v1/sessions/:id/events/sse ---

  describe 'GET /v1/sessions/:id/events/sse' do
    it 'returns 404 for missing session' do
      get '/v1/sessions/nonexistent/events/sse'

      expect(last_response.status).to eq(404)
    end
  end

  # --- POST /v1/sessions/:id/interrupt ---

  describe 'POST /v1/sessions/:id/interrupt' do
    it 'interrupts a session' do
      post_json '/v1/sessions', { id: 'int-test' }

      expect(mock_client).to receive(:interrupt)
      post '/v1/sessions/int-test/interrupt'

      expect(last_response.status).to eq(200)
      expect(json_response[:status]).to eq('interrupted')
      expect(json_response[:sessionId]).to eq('int-test')
    end

    it 'returns 404 for missing session' do
      post '/v1/sessions/nonexistent/interrupt'

      expect(last_response.status).to eq(404)
    end
  end

  # --- POST /v1/sessions/:id/model ---

  describe 'POST /v1/sessions/:id/model' do
    it 'changes the model' do
      post_json '/v1/sessions', { id: 'model-test' }

      expect(mock_client).to receive(:set_model).with('claude-opus-4-20250514')
      post_json '/v1/sessions/model-test/model', { model: 'claude-opus-4-20250514' }

      expect(last_response.status).to eq(200)
      expect(json_response[:status]).to eq('model_changed')
      expect(json_response[:model]).to eq('claude-opus-4-20250514')
      expect(json_response[:sessionId]).to eq('model-test')
    end

    it 'returns 400 without model' do
      post_json '/v1/sessions', { id: 'model-400' }
      post_json '/v1/sessions/model-400/model', {}

      expect(last_response.status).to eq(400)
    end

    it 'returns 404 for missing session' do
      post_json '/v1/sessions/nonexistent/model', { model: 'foo' }

      expect(last_response.status).to eq(404)
    end
  end

  # --- GET /v1/sessions/:id/mcp-status ---

  describe 'GET /v1/sessions/:id/mcp-status' do
    it 'returns MCP status' do
      post_json '/v1/sessions', { id: 'mcp-test' }

      get '/v1/sessions/mcp-test/mcp-status'

      expect(last_response.status).to eq(200)
      expect(json_response[:sessionId]).to eq('mcp-test')
      expect(json_response).to have_key(:mcpStatus)
    end

    it 'returns 404 for missing session' do
      get '/v1/sessions/nonexistent/mcp-status'

      expect(last_response.status).to eq(404)
    end
  end

  # --- GET /v1/sessions/:id/history ---

  describe 'GET /v1/sessions/:id/history' do
    it 'returns empty history for new session' do
      post_json '/v1/sessions', { id: 'hist-test' }

      get '/v1/sessions/hist-test/history'

      expect(last_response.status).to eq(200)
      expect(json_response[:sessionId]).to eq('hist-test')
      expect(json_response[:messages]).to eq([])
    end

    it 'returns 404 for missing session' do
      get '/v1/sessions/nonexistent/history'

      expect(last_response.status).to eq(404)
    end
  end
end
