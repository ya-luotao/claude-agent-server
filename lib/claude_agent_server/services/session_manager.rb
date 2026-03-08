# frozen_string_literal: true

require 'securerandom'
require 'claude_agent_sdk'
require 'async'
require 'async/queue'

module ClaudeAgentServer
  module Services
    # An indexed event wrapping an SDK message with a monotonic index
    class SessionEvent
      attr_reader :index, :message, :timestamp

      def initialize(index:, message:)
        @index = index
        @message = message
        @timestamp = Time.now
      end
    end

    class SessionEntry
      attr_reader :id, :client, :created_at, :status, :events
      attr_accessor :last_activity

      def initialize(id:, client:)
        @id = id
        @client = client
        @created_at = Time.now
        @last_activity = Time.now
        @status = :connected
        @events = []
        @next_index = 0
        @subscribers = []
        @mutex = Mutex.new
        @reader_task = nil
      end

      def message_count
        @events.size
      end

      # Retrieve events by offset and limit (for polling)
      def get_events(offset: 0, limit: nil)
        @mutex.synchronize do
          slice = @events[offset..] || []
          limit ? slice.first(limit) : slice
        end
      end

      def subscribe(offset: 0, &block)
        queue = Async::Queue.new

        # Replay missed events from offset, and send :done immediately if already finished
        @mutex.synchronize do
          @subscribers << queue
          @events[offset..]&.each { |evt| queue.enqueue(evt) }
          queue.enqueue(:done) if @status == :finished || @status == :disconnected
        end

        begin
          loop do
            event = queue.dequeue
            break if event == :done

            block.call(event)
          end
        ensure
          @mutex.synchronize { @subscribers.delete(queue) }
        end
      end

      def broadcast(message)
        @mutex.synchronize do
          event = SessionEvent.new(index: @next_index, message: message)
          @next_index += 1
          @events << event
          @last_activity = Time.now
          @subscribers.each { |q| q.enqueue(event) }
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

      def create_session(options:, prompt: nil, id: nil)
        id ||= SecureRandom.uuid
        reserve_slot(id)

        begin
          client = ClaudeAgentSDK::Client.new(options: options)
          client.connect(prompt)

          entry = SessionEntry.new(id: id, client: client)
          @mutex.synchronize { @sessions[id] = entry }

          entry.start_message_reader
          entry
        rescue StandardError
          @mutex.synchronize { @sessions.delete(id) }
          raise
        end
      end

      def get_session(id)
        entry = @mutex.synchronize { @sessions[id] }
        raise SessionNotFoundError, "Session '#{id}' not found" unless entry.is_a?(SessionEntry)

        entry
      end

      def destroy_session(id)
        entry = @mutex.synchronize { @sessions.delete(id) }
        raise SessionNotFoundError, "Session '#{id}' not found" unless entry

        entry.disconnect
        entry
      end

      def list_sessions
        @mutex.synchronize { @sessions.values.grep(SessionEntry) }
      end

      def start_reaper
        return if @reaper_task&.alive?

        @reaper_task = Thread.new do
          loop do
            sleep(60)
            reap_expired_sessions
          rescue StandardError
            # Don't crash the reaper on transient errors
          end
        end
        @reaper_task.name = 'session-reaper'
      end

      def stop_reaper
        @reaper_task&.kill
        @reaper_task = nil
      end

      def shutdown
        stop_reaper
        @mutex.synchronize do
          @sessions.each_value { |v| v.disconnect if v.is_a?(SessionEntry) }
          @sessions.clear
        end
      end

      private

      def reserve_slot(id)
        config = ClaudeAgentServer.config

        @mutex.synchronize do
          raise SessionAlreadyExistsError, "Session '#{id}' already exists" if @sessions.key?(id)

          if @sessions.size >= config.max_sessions
            raise SessionLimitError, "Maximum session limit (#{config.max_sessions}) reached"
          end

          @sessions[id] = :reserved
        end
      end

      def session_expired?(entry, now, ttl)
        entry.status == :finished || (now - entry.last_activity > ttl)
      end

      def reap_expired_sessions
        ttl = ClaudeAgentServer.config.session_ttl
        now = Time.now

        expired_ids = @mutex.synchronize do
          @sessions.select { |_, e| e.is_a?(SessionEntry) && session_expired?(e, now, ttl) }.keys
        end

        expired_ids.each do |id|
          entry = @mutex.synchronize { @sessions.delete(id) }
          entry&.disconnect if entry.is_a?(SessionEntry)
        end
      end
    end
  end
end
