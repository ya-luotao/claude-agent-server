# frozen_string_literal: true

RSpec.describe 'Full lifecycle', :integration, type: :request do
  describe 'query lifecycle' do
    it 'executes a one-shot query' do
      post_json '/query', { prompt: 'Say exactly: hello world' }

      expect(last_response.status).to eq(200)
      messages = json_response[:messages]
      expect(messages).to be_an(Array)
      expect(messages.any? { |m| m[:type] == 'result' }).to be true
    end
  end

  describe 'session lifecycle' do
    it 'creates, messages, and destroys a session' do
      # Create session
      post_json '/sessions', { prompt: 'Say exactly: hi' }
      expect(last_response.status).to eq(201)
      session_id = json_response[:id]

      # Get session info
      get "/sessions/#{session_id}"
      expect(last_response.status).to eq(200)

      # Wait briefly for response
      sleep(5)

      # Get history
      get "/sessions/#{session_id}/history"
      expect(last_response.status).to eq(200)
      expect(json_response[:messages].size).to be >= 1

      # Destroy session
      delete "/sessions/#{session_id}"
      expect(last_response.status).to eq(200)

      # Verify session is gone
      get "/sessions/#{session_id}"
      expect(last_response.status).to eq(404)
    end
  end
end
