# frozen_string_literal: true

RSpec.describe ClaudeAgentServer::Services::SseStream do
  describe '.format_sse' do
    it 'formats event with data' do
      result = described_class.format_sse('assistant', { type: 'assistant', content: 'hi' })

      expect(result).to start_with('event: assistant')
      expect(result).to include('data: ')
      expect(result).to end_with("\n\n")
    end

    it 'produces valid SSE format' do
      result = described_class.format_sse('done', { status: 'complete' })

      lines = result.strip.split("\n")
      expect(lines[0]).to eq('event: done')
      expect(lines[1]).to start_with('data: ')
      data = JSON.parse(lines[1].sub('data: ', ''))
      expect(data['status']).to eq('complete')
    end
  end

  describe ClaudeAgentServer::Services::SseStream::StreamBody do
    it 'yields chunks via each' do
      body = described_class.new do |stream|
        stream.write('chunk1')
        stream.write('chunk2')
      end

      chunks = body.enum_for(:each).to_a
      expect(chunks).to eq(%w[chunk1 chunk2])
    end
  end
end
