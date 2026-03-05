FROM ruby:3.2-slim

# Install Node.js for Claude Code CLI
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl gnupg && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /app

COPY Gemfile claude-agent-server.gemspec ./
COPY lib/claude_agent_server/version.rb lib/claude_agent_server/version.rb
RUN bundle install --without development test

COPY . .

EXPOSE 9292

ENV CLAUDE_SERVER_HOST=0.0.0.0
ENV CLAUDE_SERVER_PORT=9292

CMD ["bundle", "exec", "ruby", "exe/claude-agent-server"]
