# frozen_string_literal: true

RSpec.describe ClaudeAgentServer::Config do
  subject(:config) { described_class.new }

  describe 'defaults' do
    it 'has default host' do
      expect(config.host).to eq('0.0.0.0')
    end

    it 'has default port' do
      expect(config.port).to eq(9292)
    end

    it 'has no auth token by default' do
      expect(config.auth_token).to be_nil
    end

    it 'has default cors origins' do
      expect(config.cors_origins).to eq('*')
    end

    it 'has default session TTL' do
      expect(config.session_ttl).to eq(3600)
    end

    it 'has default max sessions' do
      expect(config.max_sessions).to eq(100)
    end

    it 'has empty default SDK options' do
      expect(config.default_sdk_options).to eq({})
    end
  end

  describe '#auth_enabled?' do
    it 'returns false when no token' do
      expect(config.auth_enabled?).to be false
    end

    it 'returns false when token is empty' do
      config.auth_token = ''
      expect(config.auth_enabled?).to be false
    end

    it 'returns true when token is set' do
      config.auth_token = 'secret'
      expect(config.auth_enabled?).to be true
    end
  end

  describe '#allowed_origins' do
    it 'returns wildcard array by default' do
      expect(config.allowed_origins).to eq(['*'])
    end

    it 'splits comma-separated origins' do
      config.cors_origins = 'http://localhost:3000,http://example.com'
      expect(config.allowed_origins).to eq(['http://localhost:3000', 'http://example.com'])
    end
  end
end
