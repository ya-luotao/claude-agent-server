# frozen_string_literal: true

RSpec.describe ClaudeAgentServer::Middleware::Authentication do
  let(:inner_app) { ->(_env) { [200, {}, ['ok']] } }
  let(:middleware) { described_class.new(inner_app) }

  context 'when auth is disabled' do
    before { ClaudeAgentServer.config.auth_token = nil }

    it 'passes all requests through' do
      env = Rack::MockRequest.env_for('/')
      status, = middleware.call(env)

      expect(status).to eq(200)
    end
  end

  context 'when auth is enabled' do
    before { ClaudeAgentServer.config.auth_token = 'secret-token' }

    it 'allows /health without auth' do
      env = Rack::MockRequest.env_for('/health')
      status, = middleware.call(env)

      expect(status).to eq(200)
    end

    it 'allows /v1/health without auth' do
      env = Rack::MockRequest.env_for('/v1/health')
      status, = middleware.call(env)

      expect(status).to eq(200)
    end

    it 'rejects requests without token' do
      env = Rack::MockRequest.env_for('/v1/sessions')
      status, headers, body = middleware.call(env)

      expect(status).to eq(401)
      expect(headers['content-type']).to eq('application/problem+json')
      parsed = JSON.parse(body.first)
      expect(parsed['type']).to include('unauthorized')
    end

    it 'rejects requests with wrong token' do
      env = Rack::MockRequest.env_for('/v1/sessions', 'HTTP_AUTHORIZATION' => 'Bearer wrong-token')
      status, = middleware.call(env)

      expect(status).to eq(401)
    end

    it 'allows requests with correct token' do
      env = Rack::MockRequest.env_for('/v1/sessions', 'HTTP_AUTHORIZATION' => 'Bearer secret-token')
      status, = middleware.call(env)

      expect(status).to eq(200)
    end

    it 'handles case-insensitive Bearer prefix' do
      env = Rack::MockRequest.env_for('/v1/sessions', 'HTTP_AUTHORIZATION' => 'bearer secret-token')
      status, = middleware.call(env)

      expect(status).to eq(200)
    end
  end
end
