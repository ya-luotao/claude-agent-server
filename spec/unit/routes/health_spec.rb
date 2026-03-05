# frozen_string_literal: true

RSpec.describe 'Health routes', type: :request do
  describe 'GET /health' do
    it 'returns ok status' do
      get '/health'

      expect(last_response.status).to eq(200)
      expect(json_response[:status]).to eq('ok')
    end

    it 'returns JSON content type' do
      get '/health'

      expect(last_response.content_type).to include('application/json')
    end
  end

  describe 'GET /info' do
    it 'returns server and SDK version' do
      get '/info'

      expect(last_response.status).to eq(200)
      expect(json_response[:version]).to eq(ClaudeAgentServer::VERSION)
      expect(json_response[:sdkVersion]).to eq(ClaudeAgentSDK::VERSION)
      expect(json_response[:activeSessions]).to be_a(Integer)
    end
  end
end
