# frozen_string_literal: true

require 'json'

module ClaudeAgentServer
  module Services
    module SseStream
      module_function

      def stream_query(prompt:, options:)
        StreamBody.new do |stream|
          QueryExecutor.stream(prompt: prompt, options: options) do |message|
            serialized = MessageSerializer.serialize(message)
            event_type = serialized[:type] || 'message'
            stream.write(format_sse(event_type, serialized))
          end
          stream.write(format_sse('done', { status: 'complete' }))
        rescue IOError, Errno::EPIPE
          # Client disconnected — exit cleanly
        end
      end

      def stream_session(session_entry)
        StreamBody.new do |stream|
          session_entry.subscribe do |message|
            serialized = MessageSerializer.serialize(message)
            event_type = serialized[:type] || 'message'
            stream.write(format_sse(event_type, serialized))
          end
          stream.write(format_sse('done', { status: 'complete' }))
        rescue IOError, Errno::EPIPE
          # Client disconnected — session stays alive
        end
      end

      def format_sse(event, data)
        "event: #{event}\ndata: #{JSON.generate(data)}\n\n"
      end

      # Rack 3 streaming body that yields chunks via a fiber
      class StreamBody
        def initialize(&block)
          @block = block
        end

        def each(&chunk_block)
          stream = StreamWriter.new(chunk_block)
          @block.call(stream)
        end
      end

      class StreamWriter
        def initialize(chunk_block)
          @chunk_block = chunk_block
        end

        def write(data)
          @chunk_block.call(data)
        end
      end
    end
  end
end
