# frozen_string_literal: true

RSpec.describe 'Query routes', type: :request do
  describe 'POST /v1/query' do
    it 'returns 400 when prompt is missing' do
      post_json '/v1/query', {}

      expect(last_response.status).to eq(400)
      parsed = JSON.parse(last_response.body)
      expect(parsed['type']).to include('invalid_request')
      expect(parsed['detail']).to include('prompt')
    end

    it 'returns 400 for invalid JSON' do
      post '/v1/query', '{bad', { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(400)
    end

    it 'returns RFC 9457 error format' do
      post_json '/v1/query', {}

      expect(last_response.content_type).to include('application/problem+json')
      parsed = JSON.parse(last_response.body)
      expect(parsed).to have_key('type')
      expect(parsed).to have_key('title')
      expect(parsed).to have_key('status')
      expect(parsed).to have_key('detail')
    end

    it 'executes a query and returns messages' do
      messages = [
        { type: 'assistant', content: [{ type: 'text', text: 'Hello!' }], model: 'test' },
        { type: 'result', subtype: 'result', durationMs: 100 }
      ]

      allow(ClaudeAgentServer::Services::QueryExecutor).to receive(:execute).and_return(messages)

      post_json '/v1/query', { prompt: 'say hi' }

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')
      expect(json_response[:messages]).to be_an(Array)
      expect(json_response[:messages].size).to eq(2)
    end

    it 'passes options to OptionsBuilder' do
      allow(ClaudeAgentServer::Services::QueryExecutor).to receive(:execute).and_return([])

      expect(ClaudeAgentServer::Services::OptionsBuilder).to receive(:build).with(
        hash_including('model' => 'claude-sonnet-4-20250514')
      ).and_call_original

      post_json '/v1/query', { prompt: 'hi', options: { 'model' => 'claude-sonnet-4-20250514' } }
    end

    it 'uses empty options when none provided' do
      allow(ClaudeAgentServer::Services::QueryExecutor).to receive(:execute).and_return([])

      expect(ClaudeAgentServer::Services::OptionsBuilder).to receive(:build).with({}).and_call_original

      post_json '/v1/query', { prompt: 'hi' }
    end
  end

  describe 'POST /v1/query/stream' do
    it 'returns 400 when prompt is missing' do
      post_json '/v1/query/stream', {}

      expect(last_response.status).to eq(400)
    end

    it 'returns SSE content type' do
      stream_body = ClaudeAgentServer::Services::SseStream::StreamBody.new { |_s| nil }
      allow(ClaudeAgentServer::Services::SseStream).to receive(:stream_query).and_return(stream_body)

      post_json '/v1/query/stream', { prompt: 'say hi' }

      expect(last_response.status).to eq(200)
      expect(last_response.headers['content-type']).to include('text/event-stream')
    end

    it 'sets cache-control no-cache' do
      stream_body = ClaudeAgentServer::Services::SseStream::StreamBody.new { |_s| nil }
      allow(ClaudeAgentServer::Services::SseStream).to receive(:stream_query).and_return(stream_body)

      post_json '/v1/query/stream', { prompt: 'say hi' }

      expect(last_response.headers['cache-control']).to eq('no-cache')
    end
  end
end
