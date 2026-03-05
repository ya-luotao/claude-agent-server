# frozen_string_literal: true

RSpec.describe ClaudeAgentServer::Middleware::RequestId do
  let(:inner_app) { ->(env) { [200, {}, [env['claude_agent_server.request_id']]] } }
  let(:middleware) { described_class.new(inner_app) }

  it 'generates a request ID when none provided' do
    env = Rack::MockRequest.env_for('/')
    status, headers, body = middleware.call(env)

    expect(status).to eq(200)
    expect(headers['x-request-id']).to match(/\A[0-9a-f-]{36}\z/)
    expect(body.first).to eq(headers['x-request-id'])
  end

  it 'propagates existing X-Request-Id' do
    env = Rack::MockRequest.env_for('/', 'HTTP_X_REQUEST_ID' => 'custom-id-123')
    _, headers, body = middleware.call(env)

    expect(headers['x-request-id']).to eq('custom-id-123')
    expect(body.first).to eq('custom-id-123')
  end
end
