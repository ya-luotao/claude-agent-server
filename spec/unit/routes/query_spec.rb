# frozen_string_literal: true

RSpec.describe 'Query routes', type: :request do
  describe 'POST /query' do
    it 'returns 400 when prompt is missing' do
      post_json '/query', {}

      expect(last_response.status).to eq(400)
      expect(json_response[:error][:code]).to eq('bad_request')
    end

    it 'executes a query and returns messages' do
      messages = [
        { type: 'assistant', content: [{ type: 'text', text: 'Hello!' }], model: 'test' },
        { type: 'result', subtype: 'result', durationMs: 100 }
      ]

      allow(ClaudeAgentServer::Services::QueryExecutor).to receive(:execute).and_return(messages)

      post_json '/query', { prompt: 'say hi' }

      expect(last_response.status).to eq(200)
      expect(json_response[:messages]).to be_an(Array)
      expect(json_response[:messages].size).to eq(2)
    end

    it 'passes options to OptionsBuilder' do
      allow(ClaudeAgentServer::Services::QueryExecutor).to receive(:execute).and_return([])

      expect(ClaudeAgentServer::Services::OptionsBuilder).to receive(:build).with(
        hash_including('model' => 'claude-sonnet-4-20250514')
      ).and_call_original

      post_json '/query', { prompt: 'hi', options: { 'model' => 'claude-sonnet-4-20250514' } }
    end
  end

  describe 'POST /query/stream' do
    it 'returns 400 when prompt is missing' do
      post_json '/query/stream', {}

      expect(last_response.status).to eq(400)
    end

    it 'returns SSE content type' do
      stream_body = ClaudeAgentServer::Services::SseStream::StreamBody.new { |_s| nil }
      allow(ClaudeAgentServer::Services::SseStream).to receive(:stream_query).and_return(stream_body)

      post_json '/query/stream', { prompt: 'say hi' }

      expect(last_response.status).to eq(200)
      expect(last_response.headers['content-type']).to include('text/event-stream')
    end
  end
end
