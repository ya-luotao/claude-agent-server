# frozen_string_literal: true

require_relative 'lib/claude_agent_server/version'

Gem::Specification.new do |spec|
  spec.name = 'claude-agent-server'
  spec.version = ClaudeAgentServer::VERSION
  spec.authors = ['Community Contributors']
  spec.email = []

  spec.summary = 'HTTP server wrapping the Claude Agent Ruby SDK'
  spec.description = 'REST + SSE HTTP wrapper for claude-agent-sdk. ' \
                     'Exposes Claude Code as a network service with ' \
                     'session management, streaming, and authentication.'
  spec.homepage = 'https://github.com/ya-luotao/claude-agent-server-ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/ya-luotao/claude-agent-server-ruby'
  spec.metadata['changelog_uri'] = 'https://github.com/ya-luotao/claude-agent-server-ruby/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*', 'exe/*', 'README.md', 'LICENSE', 'CHANGELOG.md', 'config.ru']
  spec.bindir = 'exe'
  spec.executables = ['claude-agent-server']
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'claude-agent-sdk', '~> 0.8'
  spec.add_dependency 'falcon', '~> 0.48'
  spec.add_dependency 'roda', '~> 3.85'
end
