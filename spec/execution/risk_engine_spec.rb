# frozen_string_literal: true

require 'spec_helper'
require 'time'
require_relative '../../src/execution/risk_engine'
require_relative '../../src/execution/position_tracker'
require_relative '../../src/execution/order'

RSpec.describe Execution::RiskEngine do
  let(:tracker) { Execution::PositionTracker.new }
  let(:engine) { described_class.new(tracker) }
  let(:valid_time) { Time.parse('2024-01-01T10:00:00+05:30') }
  let(:valid_order) do
    Execution::Order.new(
      symbol: 'NIFTY',
      transaction_type: 'BUY',
      quantity: 50,
      price: 100.0,
      trigger_price: 90.0
    )
  end

  before do
    Utils::Config.update(
      capital: 500_000,
      risk_per_trade_pct: 1.0,
      max_daily_loss_pct: 3.0,
      max_positions: 3
    )
  end

  it 'allows valid order' do
    expect(engine.validate!(valid_order, current_time: valid_time)).to be true
  end

  it 'rejects order without stop loss' do
    invalid_order = valid_order.dup
    invalid_order.trigger_price = nil
    expect { engine.validate!(invalid_order, current_time: valid_time) }
      .to raise_error(Execution::RiskEngine::RiskViolation, /stop-loss/)
  end

  it 'rejects order outside market hours' do
    early_time = Time.parse('2024-01-01T09:10:00+05:30')
    expect { engine.validate!(valid_order, current_time: early_time) }
      .to raise_error(Execution::RiskEngine::RiskViolation, /market hours/)
  end

  it 'rejects order during first 5 minutes' do
    first_min_time = Time.parse('2024-01-01T09:16:00+05:30')
    expect { engine.validate!(valid_order, current_time: first_min_time) }
      .to raise_error(Execution::RiskEngine::RiskViolation, /09:20 and 15:20/)
  end

  it 'rejects order when max positions reached' do
    3.times do |i|
      tracker.instance_variable_get(:@open_positions)["SYM#{i}"] = true
    end
    expect { engine.validate!(valid_order, current_time: valid_time) }
      .to raise_error(Execution::RiskEngine::RiskViolation, /Max open positions/)
  end

  it 'rejects order when daily loss limit breached' do
    tracker.instance_variable_set(:@daily_pnl, -16000.0) # > 3% of 500k (15000)
    expect { engine.validate!(valid_order, current_time: valid_time) }
      .to raise_error(Execution::RiskEngine::RiskViolation, /Daily loss limit/)
  end

  it 'rejects order if position size exceeds risk per trade' do
    # 1% of 500k = 5000 risk
    # order buys 500 qty, entry 100, SL 80 -> risk per unit = 20, total risk = 10000
    risky_order = valid_order.dup
    risky_order.quantity = 500
    risky_order.price = 100.0
    risky_order.trigger_price = 80.0
    expect { engine.validate!(risky_order, current_time: valid_time) }
      .to raise_error(Execution::RiskEngine::RiskViolation, /Position size exceeds max risk/)
  end
end
