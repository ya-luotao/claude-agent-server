# frozen_string_literal: true

require 'securerandom'
require 'claude_agent_sdk'
require 'async'
require 'async/queue'

module ClaudeAgentServer
  module Services
    class SessionEntry
      attr_reader :id, :client, :created_at, :status, :messages
      attr_accessor :last_activity

      def initialize(id:, client:)
        @id = id
        @client = client
        @created_at = Time.now
        @last_activity = Time.now
        @status = :connected
        @messages = []
        @subscribers = []
        @mutex = Mutex.new
        @reader_task = nil
      end

      def message_count
        @messages.size
      end

      def subscribe(&block)
        queue = Async::Queue.new
        @mutex.synchronize { @subscribers << queue }

        begin
          loop do
            message = queue.dequeue
            break if message == :done

            block.call(message)
          end
        ensure
          @mutex.synchronize { @subscribers.delete(queue) }
        end
      end

      def broadcast(message)
        @mutex.synchronize do
          @messages << message
          @last_activity = Time.now
          @subscribers.each { |q| q.enqueue(message) }
        end
      end

      def finish
        @mutex.synchronize do
          @status = :finished
          @subscribers.each { |q| q.enqueue(:done) }
        end
      end

      def start_message_reader
        @reader_task = Thread.new do
          Async do
            client.receive_messages do |message|
              broadcast(message)
              break if message.is_a?(ClaudeAgentSDK::ResultMessage)
            end
          rescue StandardError
            # Reader ended (disconnect or error)
          ensure
            finish
          end
        end
      end

      def disconnect
        @status = :disconnected
        @reader_task&.kill
        @client.disconnect
        @mutex.synchronize do
          @subscribers.each { |q| q.enqueue(:done) }
          @subscribers.clear
        end
      end
    end

    class SessionManager
      attr_reader :sessions

      def initialize
        @sessions = {}
        @mutex = Mutex.new
        @reaper_task = nil
      end

      def create_session(options:, prompt: nil)
        config = ClaudeAgentServer.config

        @mutex.synchronize do
          if @sessions.size >= config.max_sessions
            raise SessionLimitError, "Maximum session limit (#{config.max_sessions}) reached"
          end
        end

        id = SecureRandom.uuid
        client = ClaudeAgentSDK::Client.new(options: options)
        client.connect(prompt)

        entry = SessionEntry.new(id: id, client: client)
        @mutex.synchronize { @sessions[id] = entry }

        entry.start_message_reader
        entry
      end

      def get_session(id)
        @mutex.synchronize { @sessions[id] } || raise(SessionNotFoundError, "Session '#{id}' not found")
      end

      def destroy_session(id)
        entry = @mutex.synchronize { @sessions.delete(id) }
        raise SessionNotFoundError, "Session '#{id}' not found" unless entry

        entry.disconnect
        entry
      end

      def list_sessions
        @mutex.synchronize { @sessions.values.dup }
      end

      def start_reaper
        @reaper_task = Async do |task|
          loop do
            task.sleep(60)
            reap_expired_sessions
          end
        end
      end

      def stop_reaper
        @reaper_task&.stop
      end

      def shutdown
        stop_reaper
        @mutex.synchronize do
          @sessions.each_value(&:disconnect)
          @sessions.clear
        end
      end

      private

      def reap_expired_sessions
        ttl = ClaudeAgentServer.config.session_ttl
        now = Time.now

        expired_ids = @mutex.synchronize do
          @sessions.select { |_, entry| now - entry.last_activity > ttl }.keys
        end

        expired_ids.each do |id|
          entry = @mutex.synchronize { @sessions.delete(id) }
          entry&.disconnect
        end
      end
    end
  end
end
