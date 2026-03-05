# frozen_string_literal: true

RSpec.describe ClaudeAgentServer::Services::OptionsBuilder do
  describe '.build' do
    it 'converts camelCase keys to snake_case' do
      options = described_class.build({ 'allowedTools' => %w[Read Bash], 'maxTurns' => 5 })

      expect(options.allowed_tools).to eq(%w[Read Bash])
      expect(options.max_turns).to eq(5)
    end

    it 'defaults permission_mode to bypassPermissions' do
      options = described_class.build({})

      expect(options.permission_mode).to eq('bypassPermissions')
    end

    it 'preserves explicitly set permission_mode' do
      options = described_class.build({ 'permissionMode' => 'acceptEdits' })

      expect(options.permission_mode).to eq('acceptEdits')
    end

    it 'merges with server default options' do
      ClaudeAgentServer.config.default_sdk_options = { model: 'claude-sonnet-4-20250514' }
      options = described_class.build({ 'maxTurns' => 3 })

      expect(options.model).to eq('claude-sonnet-4-20250514')
      expect(options.max_turns).to eq(3)
    end

    it 'handles symbol keys' do
      options = described_class.build({ model: 'claude-sonnet-4-20250514' })

      expect(options.model).to eq('claude-sonnet-4-20250514')
    end

    it 'returns a ClaudeAgentOptions instance' do
      options = described_class.build({})

      expect(options).to be_a(ClaudeAgentSDK::ClaudeAgentOptions)
    end
  end
end
