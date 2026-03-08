# frozen_string_literal: true

require 'spec_helper'
require_relative '../src/live_runner'

RSpec.describe 'End-to-end integration' do
  it 'initializes the system in paper trading mode' do
    expect {
      runner = AlgoTradingSystem::LiveRunner.new(strategy_name: 'ema_crossover', symbol: 'NIFTY', env: 'paper')
      expect(runner).to be_a(AlgoTradingSystem::LiveRunner)
    }.not_to raise_error
  end
end
