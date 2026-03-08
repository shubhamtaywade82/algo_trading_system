# frozen_string_literal: true

source "https://rubygems.org"

ruby ">= 3.2.0"

# HTTP client with middleware support
gem "faraday", "~> 2.9"
gem "faraday-retry", "~> 2.2"

# WebSocket client for live market data feed
gem "websocket-client-simple", "~> 0.6"

# Environment variable loading
gem "dotenv", "~> 3.1"

# Config objects with type coercion and validation
gem "dry-configurable", "~> 1.1"

# Lightweight event bus (pub/sub)
gem "dry-events", "~> 1.0"

# Autoloading
gem "zeitwerk", "~> 2.6"

# YAML config parsing
gem "psych", "~> 5.1"

group :development do
  # Static analysis, refactoring engine, and architecture monitoring
  gem "ruby_mastery", github: "shubhamtaywade82/ruby_mastery"
  gem "tty-table", "~> 0.12.0"
end

group :development, :test do
  # Testing framework
  gem "rspec", "~> 3.13"

  # HTTP interaction recording for tests
  gem "vcr", "~> 6.3"
  gem "webmock", "~> 3.23"

  # Time manipulation in tests
  gem "timecop", "~> 0.9"

  # Code coverage
  gem "simplecov", require: false

  # Linting
  gem "rubocop", "~> 1.65", require: false
  gem "rubocop-rspec", "~> 3.0", require: false
end
