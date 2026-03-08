# frozen_string_literal: true

require 'spec_helper'
require 'time'
require_relative '../../src/backtest/engine'
require_relative '../../src/backtest/pnl_calculator'
require_relative '../../src/execution/engine'
require_relative '../../src/strategies/strategy_base'
require_relative '../../src/market_data/candle'

RSpec.describe Backtest::Engine do
  class MockStrategy < Strategies::StrategyBase
    def initialize
      @step = 0
    end
    def on_candle(_candle, indicators:)
      @step += 1
      return :buy if @step == 1
      return :sell if @step == 2
      :hold
    end
    def signal; :hold; end
  end

  class MockApi
    def place_order(_payload); { orderId: "123" }; end
    def cancel_order(_id); true; end
  end

  before do
    Utils::Config.update(
      capital: 500_000,
      risk_per_trade_pct: 1.0,
      max_daily_loss_pct: 3.0,
      max_positions: 3
    )
  end

  it 'replays candles and calculates pnl without look-ahead' do
    strategy = MockStrategy.new
    execution = Execution::Engine.new(MockApi.new)
    engine = described_class.new(strategy, {}, execution)

    c1 = MarketData::Candle.new(symbol: 'NIFTY', timestamp: Time.parse('2024-01-01T10:00:00+05:30'), open: 100, high: 105, low: 95, close: 100, volume: 100, timeframe: '5m')
    c2 = MarketData::Candle.new(symbol: 'NIFTY', timestamp: Time.parse('2024-01-01T10:05:00+05:30'), open: 100, high: 110, low: 90, close: 105, volume: 100, timeframe: '5m')

    engine.replay([c1, c2])

    pnl = engine.pnl_calculator
    expect(pnl.trades.size).to eq(1)

    trade = pnl.trades.first
    expect(trade.entry_price).to be > 100.0 # because of slippage
    expect(trade.exit_price).to be < 105.0 # because of slippage
    expect(trade.net_pnl).not_to be_nil
  end
end
