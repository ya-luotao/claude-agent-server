# frozen_string_literal: true

require 'roda'
require 'json'
require 'claude_agent_sdk'

module ClaudeAgentServer
  class App < Roda
    plugin :request_headers
    plugin :all_verbs

    @session_manager = Services::SessionManager.new

    class << self
      attr_reader :session_manager
    end

    use Middleware::RequestId
    use Middleware::Cors
    use Middleware::Authentication
    use Middleware::ErrorHandler

    route do |r| # rubocop:disable Metrics/BlockLength
      # GET /health (outside /v1 — always accessible)
      r.on 'health' do
        r.get do
          json_response({ status: 'ok' })
        end
      end

      # All API routes under /v1
      r.on 'v1' do # rubocop:disable Metrics/BlockLength
        # GET /v1/health
        r.on 'health' do
          r.get do
            json_response({ status: 'ok' })
          end
        end

        # GET /v1/info
        r.on 'info' do
          r.get do
            manager = self.class.session_manager
            json_response({
                            version: ClaudeAgentServer::VERSION,
                            sdkVersion: ClaudeAgentSDK::VERSION,
                            activeSessions: manager.sessions.size
                          })
          end
        end

        # /v1/query routes
        r.on 'query' do
          # POST /v1/query/stream
          r.on 'stream' do
            r.post do
              params = parse_json_body(request)
              prompt = params['prompt'] || params[:prompt]
              raise ArgumentError, 'Missing required field: prompt' unless prompt

              sdk_options = params['options'] || params[:options] || {}
              options = Services::OptionsBuilder.build(sdk_options)

              response['content-type'] = 'text/event-stream'
              response['cache-control'] = 'no-cache'
              response['x-accel-buffering'] = 'no'

              body = Services::SseStream.stream_query(prompt: prompt, options: options)
              r.halt [200, response.headers, body]
            end
          end

          # POST /v1/query
          r.is do
            r.post do
              params = parse_json_body(request)
              prompt = params['prompt'] || params[:prompt]
              raise ArgumentError, 'Missing required field: prompt' unless prompt

              sdk_options = params['options'] || params[:options] || {}
              options = Services::OptionsBuilder.build(sdk_options)

              messages = Services::QueryExecutor.execute(prompt: prompt, options: options)
              json_response({ messages: messages })
            end
          end
        end

        # /v1/cli-sessions routes (read-only CLI session browsing)
        r.on 'cli-sessions' do # rubocop:disable Metrics/BlockLength
          r.is do
            r.get do
              params = r.params
              directory = params['directory']
              limit = params['limit']&.to_i
              include_worktrees = params['includeWorktrees'] != 'false'

              sessions = ClaudeAgentSDK.list_sessions(
                directory: directory, limit: limit, include_worktrees: include_worktrees
              )
              json_response({ sessions: sessions.map { |s| serialize_sdk_session(s) } })
            end
          end

          r.on String do |session_id|
            r.on 'messages' do
              r.get do
                params = r.params
                messages = ClaudeAgentSDK.get_session_messages(
                  session_id: session_id,
                  directory: params['directory'],
                  limit: params['limit']&.to_i,
                  offset: (params['offset'] || '0').to_i
                )
                json_response({
                                sessionId: session_id,
                                messages: messages.map { |m| serialize_session_message(m) }
                              })
              end
            end
          end
        end

        # /v1/sessions routes
        r.on 'sessions' do # rubocop:disable Metrics/BlockLength
          manager = self.class.session_manager

          r.is do
            r.get do
              entries = manager.list_sessions
              json_response({ sessions: entries.map { |e| serialize_session_info(e) } })
            end

            r.post do
              params = parse_json_body(request)
              prompt = params['prompt'] || params[:prompt]
              session_id = params['id'] || params[:id]
              sdk_options = params['options'] || params[:options] || {}
              options = Services::OptionsBuilder.build(sdk_options)

              entry = manager.create_session(options: options, prompt: prompt, id: session_id)
              response.status = 201
              json_response(serialize_session_info(entry))
            end
          end

          r.on String do |session_id| # rubocop:disable Metrics/BlockLength
            r.is do
              r.get do
                entry = manager.get_session(session_id)
                json_response(serialize_session_info(entry))
              end

              r.delete do
                manager.destroy_session(session_id)
                json_response({ status: 'disconnected', id: session_id })
              end
            end

            # /v1/sessions/:id/events — offset-based polling
            r.on 'events' do
              # GET /v1/sessions/:id/events/sse — SSE stream with resume
              r.on 'sse' do
                r.get do
                  entry = manager.get_session(session_id)
                  last_event_id = env['HTTP_LAST_EVENT_ID']

                  response['content-type'] = 'text/event-stream'
                  response['cache-control'] = 'no-cache'
                  response['x-accel-buffering'] = 'no'

                  body = Services::SseStream.stream_session(entry, last_event_id: last_event_id)
                  r.halt [200, response.headers, body]
                end
              end

              # GET /v1/sessions/:id/events?offset=N&limit=M
              r.is do
                r.get do
                  entry = manager.get_session(session_id)
                  params = r.params
                  offset = (params['offset'] || '0').to_i
                  limit = params['limit']&.to_i

                  events = entry.get_events(offset: offset, limit: limit)
                  json_response({
                                  sessionId: session_id,
                                  events: events.map { |e| serialize_event(e) },
                                  nextOffset: events.empty? ? offset : events.last.index + 1
                                })
                end
              end
            end

            # POST /v1/sessions/:id/messages
            r.on 'messages' do
              # GET /v1/sessions/:id/messages/stream (legacy SSE)
              r.on 'stream' do
                r.get do
                  entry = manager.get_session(session_id)
                  last_event_id = env['HTTP_LAST_EVENT_ID']

                  response['content-type'] = 'text/event-stream'
                  response['cache-control'] = 'no-cache'
                  response['x-accel-buffering'] = 'no'

                  body = Services::SseStream.stream_session(entry, last_event_id: last_event_id)
                  r.halt [200, response.headers, body]
                end
              end

              r.is do
                r.post do
                  entry = manager.get_session(session_id)
                  params = parse_json_body(request)
                  prompt = params['prompt'] || params[:prompt]
                  raise ArgumentError, 'Missing required field: prompt' unless prompt

                  entry.last_activity = Time.now
                  entry.client.query(prompt)
                  json_response({ status: 'sent', sessionId: session_id })
                end
              end
            end

            r.on 'interrupt' do
              r.post do
                entry = manager.get_session(session_id)
                entry.client.interrupt
                entry.last_activity = Time.now
                json_response({ status: 'interrupted', sessionId: session_id })
              end
            end

            r.on 'model' do
              r.post do
                entry = manager.get_session(session_id)
                params = parse_json_body(request)
                model = params['model'] || params[:model]
                raise ArgumentError, 'Missing required field: model' unless model

                entry.client.set_model(model)
                entry.last_activity = Time.now
                json_response({ status: 'model_changed', model: model, sessionId: session_id })
              end
            end

            r.on 'mcp-status' do
              r.get do
                entry = manager.get_session(session_id)
                mcp_status = entry.client.get_mcp_status
                json_response({ sessionId: session_id, mcpStatus: mcp_status })
              end
            end

            r.on 'history' do
              r.get do
                entry = manager.get_session(session_id)
                events = entry.events
                json_response({
                                sessionId: session_id,
                                messages: events.map { |e| serialize_event(e) }
                              })
              end
            end
          end
        end
      end
    end

    private

    def json_response(data)
      response['content-type'] = 'application/json'
      JSON.generate(data)
    end

    def parse_json_body(request)
      body = request.body.read
      return {} if body.nil? || body.empty?

      JSON.parse(body)
    rescue JSON::ParserError => e
      raise ArgumentError, "Invalid JSON body: #{e.message}"
    end

    def serialize_session_info(entry)
      {
        id: entry.id,
        status: entry.status.to_s,
        createdAt: entry.created_at.iso8601,
        lastActivity: entry.last_activity.iso8601,
        messageCount: entry.message_count
      }
    end

    def serialize_event(event)
      {
        index: event.index,
        timestamp: event.timestamp.iso8601,
        message: Services::MessageSerializer.serialize(event.message)
      }
    end

    def serialize_sdk_session(session)
      {
        sessionId: session.session_id,
        summary: session.summary,
        lastModified: session.last_modified,
        fileSize: session.file_size,
        customTitle: session.custom_title,
        firstPrompt: session.first_prompt,
        gitBranch: session.git_branch,
        cwd: session.cwd
      }.compact
    end

    def serialize_session_message(msg)
      {
        type: msg.type,
        uuid: msg.uuid,
        sessionId: msg.session_id,
        message: msg.message,
        parentToolUseId: msg.parent_tool_use_id
      }.compact
    end
  end
end
