# frozen_string_literal: true

RSpec.describe 'Health routes', type: :request do
  describe 'GET /health' do
    it 'returns ok status' do
      get '/health'

      expect(last_response.status).to eq(200)
      expect(json_response[:status]).to eq('ok')
    end
  end

  describe 'GET /v1/health' do
    it 'returns ok status' do
      get '/v1/health'

      expect(last_response.status).to eq(200)
      expect(json_response[:status]).to eq('ok')
    end
  end

  describe 'GET /v1/info' do
    it 'returns server and SDK version' do
      get '/v1/info'

      expect(last_response.status).to eq(200)
      expect(json_response[:version]).to eq(ClaudeAgentServer::VERSION)
      expect(json_response[:sdkVersion]).to eq(ClaudeAgentSDK::VERSION)
      expect(json_response[:activeSessions]).to be_a(Integer)
    end
  end
end
