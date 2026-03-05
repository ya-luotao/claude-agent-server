# frozen_string_literal: true

require 'claude_agent_server'
require 'rack/test'

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include TestHelpers
  config.include RackTestHelpers, type: :request

  config.color = true
  config.tty = true
  config.formatter = :documentation if ENV['CI']
  config.order = :random
  Kernel.srand config.seed

  config.filter_run_excluding :integration unless ENV['RUN_INTEGRATION']
  config.profile_examples = 10 if ENV['PROFILE']

  config.before(:each) do
    ClaudeAgentServer.reset_config!
  end
end
