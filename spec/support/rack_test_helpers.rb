# frozen_string_literal: true

module RackTestHelpers
  include Rack::Test::Methods

  def app
    ClaudeAgentServer::App.freeze.app
  end

  def json_response
    JSON.parse(last_response.body, symbolize_names: true)
  end

  def post_json(path, body = {}, headers = {})
    post path, JSON.generate(body), { 'CONTENT_TYPE' => 'application/json' }.merge(headers)
  end

  def auth_header(token = 'test-token')
    { 'HTTP_AUTHORIZATION' => "Bearer #{token}" }
  end
end
