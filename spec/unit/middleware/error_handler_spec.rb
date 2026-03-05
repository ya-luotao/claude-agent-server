# frozen_string_literal: true

RSpec.describe ClaudeAgentServer::Middleware::ErrorHandler do
  def build_app(error)
    inner = ->(_env) { raise error }
    described_class.new(inner)
  end

  it 'maps SessionNotFoundError to 404' do
    app = build_app(ClaudeAgentServer::SessionNotFoundError.new('not found'))
    status, _, body = app.call(Rack::MockRequest.env_for('/'))

    expect(status).to eq(404)
    parsed = JSON.parse(body.first)
    expect(parsed['error']['code']).to eq('session_not_found')
  end

  it 'maps SessionLimitError to 429' do
    app = build_app(ClaudeAgentServer::SessionLimitError.new('too many'))
    status, = app.call(Rack::MockRequest.env_for('/'))

    expect(status).to eq(429)
  end

  it 'maps AuthenticationError to 401' do
    app = build_app(ClaudeAgentServer::AuthenticationError.new('bad token'))
    status, = app.call(Rack::MockRequest.env_for('/'))

    expect(status).to eq(401)
  end

  it 'maps ArgumentError to 400' do
    app = build_app(ArgumentError.new('bad input'))
    status, = app.call(Rack::MockRequest.env_for('/'))

    expect(status).to eq(400)
  end

  it 'maps CLINotFoundError to 503' do
    app = build_app(ClaudeAgentSDK::CLINotFoundError.new)
    status, = app.call(Rack::MockRequest.env_for('/'))

    expect(status).to eq(503)
  end

  it 'maps CLIConnectionError to 502' do
    app = build_app(ClaudeAgentSDK::CLIConnectionError.new('failed'))
    status, = app.call(Rack::MockRequest.env_for('/'))

    expect(status).to eq(502)
  end

  it 'maps ProcessError to 502' do
    app = build_app(ClaudeAgentSDK::ProcessError.new('exit'))
    status, = app.call(Rack::MockRequest.env_for('/'))

    expect(status).to eq(502)
  end

  it 'maps unknown errors to 500' do
    app = build_app(RuntimeError.new('oops'))
    status, = app.call(Rack::MockRequest.env_for('/'))

    expect(status).to eq(500)
  end

  it 'passes through successful responses' do
    inner = ->(_env) { [200, {}, ['ok']] }
    app = described_class.new(inner)
    status, _, body = app.call(Rack::MockRequest.env_for('/'))

    expect(status).to eq(200)
    expect(body).to eq(['ok'])
  end
end
