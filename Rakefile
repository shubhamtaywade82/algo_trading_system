# frozen_string_literal: true

require 'rspec/core/rake_task'

desc 'Run all tests'
RSpec::Core::RakeTask.new(:spec)

desc 'Run a backtest'
task :backtest do
  sh 'bundle exec ruby bin/backtest'
end

desc 'Run live trading (paper mode default)'
task :trade do
  sh 'bundle exec ruby bin/trade'
end

desc 'Run code quality checks'
task :quality do
  sh 'bundle exec ruby_mastery analyze src/ || echo "ruby_mastery not available"'
end

task default: :spec
