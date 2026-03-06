# frozen_string_literal: true

RSpec.describe ClaudeAgentServer::ServerError do
  subject(:error) { described_class.new('something broke') }

  it 'has error_type' do
    expect(error.error_type).to eq('server_error')
  end

  it 'has status_code 500' do
    expect(error.status_code).to eq(500)
  end

  it 'has a URN type' do
    expect(error.urn).to eq('urn:claude-agent-server:error:server_error')
  end

  it 'generates RFC 9457 problem details' do
    problem = error.to_problem_details

    expect(problem[:type]).to eq('urn:claude-agent-server:error:server_error')
    expect(problem[:title]).to eq('Server Error')
    expect(problem[:status]).to eq(500)
    expect(problem[:detail]).to eq('something broke')
  end
end

RSpec.describe ClaudeAgentServer::SessionNotFoundError do
  subject(:error) { described_class.new("Session 'abc' not found") }

  it 'has status_code 404' do
    expect(error.status_code).to eq(404)
  end

  it 'has correct URN' do
    expect(error.urn).to eq('urn:claude-agent-server:error:session_not_found')
  end

  it 'has correct title' do
    expect(error.title).to eq('Session Not Found')
  end
end

RSpec.describe ClaudeAgentServer::SessionAlreadyExistsError do
  it 'has status_code 409' do
    expect(described_class.new('exists').status_code).to eq(409)
  end
end

RSpec.describe ClaudeAgentServer::SessionLimitError do
  it 'has status_code 429' do
    expect(described_class.new('limit').status_code).to eq(429)
  end
end

RSpec.describe ClaudeAgentServer::ConfigError do
  it 'has status_code 400' do
    expect(described_class.new('bad config').status_code).to eq(400)
  end
end

RSpec.describe ClaudeAgentServer::AuthenticationError do
  it 'has status_code 401' do
    expect(described_class.new('no token').status_code).to eq(401)
  end
end
