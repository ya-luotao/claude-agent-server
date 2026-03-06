# frozen_string_literal: true

RSpec.describe ClaudeAgentServer::Middleware::ErrorHandler do
  def build_app(error)
    inner = ->(_env) { raise error }
    described_class.new(inner)
  end

  def parse_problem(body)
    JSON.parse(body.first)
  end

  it 'maps SessionNotFoundError to 404 with RFC 9457 format' do
    app = build_app(ClaudeAgentServer::SessionNotFoundError.new('not found'))
    status, headers, body = app.call(Rack::MockRequest.env_for('/'))

    expect(status).to eq(404)
    expect(headers['content-type']).to eq('application/problem+json')

    problem = parse_problem(body)
    expect(problem['type']).to eq('urn:claude-agent-server:error:session_not_found')
    expect(problem['title']).to eq('Session Not Found')
    expect(problem['status']).to eq(404)
    expect(problem['detail']).to eq('not found')
  end

  it 'maps SessionAlreadyExistsError to 409' do
    app = build_app(ClaudeAgentServer::SessionAlreadyExistsError.new('exists'))
    status, _, body = app.call(Rack::MockRequest.env_for('/'))

    expect(status).to eq(409)
    problem = parse_problem(body)
    expect(problem['type']).to include('session_already_exists')
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
    status, _, body = app.call(Rack::MockRequest.env_for('/'))

    expect(status).to eq(400)
    problem = parse_problem(body)
    expect(problem['type']).to include('invalid_request')
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
