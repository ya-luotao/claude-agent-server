# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

# Use local SDK during development (skip in CI)
gem 'claude-agent-sdk', path: '../claude-agent-sdk-ruby' unless ENV['CI']

group :development, :test do
  gem 'bundler', '~> 2.0'
  gem 'rack-test', '~> 2.1'
  gem 'rake', '~> 13.0'
  gem 'rspec', '~> 3.0'
  gem 'rubocop', '~> 1.0'
end
