# frozen_string_literal: true

RSpec.describe ClaudeAgentServer::Services::SseStream do
  describe '.format_sse' do
    it 'formats event with data and no ID' do
      result = described_class.format_sse('assistant', { type: 'assistant' })

      expect(result).to start_with('event: assistant')
      expect(result).to include('data: ')
      expect(result).to end_with("\n\n")
      expect(result).not_to include('id:')
    end

    it 'includes event ID when provided' do
      result = described_class.format_sse('assistant', { type: 'assistant' }, id: 42)

      lines = result.strip.split("\n")
      expect(lines[0]).to eq('id: 42')
      expect(lines[1]).to eq('event: assistant')
      expect(lines[2]).to start_with('data: ')
    end

    it 'produces valid SSE format' do
      result = described_class.format_sse('done', { status: 'complete' })

      lines = result.strip.split("\n")
      expect(lines[0]).to eq('event: done')
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
