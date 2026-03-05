# frozen_string_literal: true

RSpec.describe ClaudeAgentServer::Middleware::Cors do
  let(:inner_app) { ->(_env) { [200, {}, ['ok']] } }
  let(:middleware) { described_class.new(inner_app) }

  context 'with wildcard origins' do
    it 'adds wildcard CORS header' do
      env = Rack::MockRequest.env_for('/', 'HTTP_ORIGIN' => 'http://example.com')
      _, headers, = middleware.call(env)

      expect(headers['access-control-allow-origin']).to eq('*')
    end
  end

  context 'with specific origins' do
    before do
      ClaudeAgentServer.config.cors_origins = 'http://localhost:3000,http://example.com'
    end

    it 'allows matching origin' do
      env = Rack::MockRequest.env_for('/', 'HTTP_ORIGIN' => 'http://example.com')
      _, headers, = middleware.call(env)

      expect(headers['access-control-allow-origin']).to eq('http://example.com')
      expect(headers['vary']).to eq('Origin')
    end

    it 'does not set CORS header for non-matching origin' do
      env = Rack::MockRequest.env_for('/', 'HTTP_ORIGIN' => 'http://evil.com')
      _, headers, = middleware.call(env)

      expect(headers['access-control-allow-origin']).to be_nil
    end
  end

  context 'with preflight request' do
    it 'returns 204 with CORS headers' do
      env = Rack::MockRequest.env_for('/', method: 'OPTIONS', 'HTTP_ORIGIN' => 'http://example.com')
      status, headers, = middleware.call(env)

      expect(status).to eq(204)
      expect(headers['access-control-allow-methods']).to include('GET')
      expect(headers['access-control-allow-methods']).to include('POST')
      expect(headers['access-control-allow-headers']).to include('Authorization')
      expect(headers['access-control-max-age']).to eq('86400')
    end
  end

  it 'exposes X-Request-Id header' do
    env = Rack::MockRequest.env_for('/')
    _, headers, = middleware.call(env)

    expect(headers['access-control-expose-headers']).to eq('X-Request-Id')
  end
end
