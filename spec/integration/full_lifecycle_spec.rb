# frozen_string_literal: true

RSpec.describe 'Full lifecycle', :integration, type: :request do
  describe 'query lifecycle' do
    it 'executes a one-shot query' do
      post_json '/v1/query', { prompt: 'Say exactly: hello world' }

      expect(last_response.status).to eq(200)
      messages = json_response[:messages]
      expect(messages).to be_an(Array)
      expect(messages.any? { |m| m[:type] == 'result' }).to be true
    end
  end

  describe 'session lifecycle' do
    it 'creates, messages, polls events, and destroys a session' do
      # Create session with client-provided ID
      post_json '/v1/sessions', { id: 'test-lifecycle', prompt: 'Say exactly: hi' }
      expect(last_response.status).to eq(201)
      expect(json_response[:id]).to eq('test-lifecycle')

      # Get session info
      get '/v1/sessions/test-lifecycle'
      expect(last_response.status).to eq(200)

      # Wait briefly for response
      sleep(5)

      # Poll events with offset
      get '/v1/sessions/test-lifecycle/events?offset=0'
      expect(last_response.status).to eq(200)
      expect(json_response[:events].size).to be >= 1
      expect(json_response[:nextOffset]).to be > 0

      # Get history
      get '/v1/sessions/test-lifecycle/history'
      expect(last_response.status).to eq(200)
      expect(json_response[:messages].size).to be >= 1

      # Destroy session
      delete '/v1/sessions/test-lifecycle'
      expect(last_response.status).to eq(200)

      # Verify session is gone
      get '/v1/sessions/test-lifecycle'
      expect(last_response.status).to eq(404)
    end
  end
end
