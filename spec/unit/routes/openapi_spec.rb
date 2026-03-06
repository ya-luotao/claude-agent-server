# frozen_string_literal: true

RSpec.describe 'OpenAPI spec route', type: :request do
  describe 'GET /v1/openapi.json' do
    it 'returns the OpenAPI spec' do
      get '/v1/openapi.json'

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')

      spec = JSON.parse(last_response.body)
      expect(spec['openapi']).to start_with('3.')
      expect(spec['info']['title']).to eq('Claude Agent Server API')
      expect(spec['info']['version']).to eq('0.1.0')
    end

    it 'contains all expected paths' do
      get '/v1/openapi.json'
      spec = JSON.parse(last_response.body)
      paths = spec['paths'].keys

      expect(paths).to include('/health')
      expect(paths).to include('/v1/health')
      expect(paths).to include('/v1/info')
      expect(paths).to include('/v1/query')
      expect(paths).to include('/v1/query/stream')
      expect(paths).to include('/v1/sessions')
      expect(paths).to include('/v1/sessions/{sessionId}')
      expect(paths).to include('/v1/sessions/{sessionId}/messages')
      expect(paths).to include('/v1/sessions/{sessionId}/events')
      expect(paths).to include('/v1/sessions/{sessionId}/events/sse')
      expect(paths).to include('/v1/sessions/{sessionId}/interrupt')
      expect(paths).to include('/v1/sessions/{sessionId}/model')
      expect(paths).to include('/v1/sessions/{sessionId}/mcp-status')
      expect(paths).to include('/v1/sessions/{sessionId}/history')
      expect(paths).to include('/v1/cli-sessions')
      expect(paths).to include('/v1/cli-sessions/{sessionId}/messages')
    end

    it 'defines ProblemDetails schema' do
      get '/v1/openapi.json'
      spec = JSON.parse(last_response.body)
      schemas = spec.dig('components', 'schemas')

      expect(schemas).to have_key('ProblemDetails')
      pd = schemas['ProblemDetails']
      expect(pd['properties']).to have_key('type')
      expect(pd['properties']).to have_key('title')
      expect(pd['properties']).to have_key('status')
      expect(pd['properties']).to have_key('detail')
    end

    it 'defines bearer auth security scheme' do
      get '/v1/openapi.json'
      spec = JSON.parse(last_response.body)
      auth = spec.dig('components', 'securitySchemes', 'bearerAuth')

      expect(auth['type']).to eq('http')
      expect(auth['scheme']).to eq('bearer')
    end
  end
end
