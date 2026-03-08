# frozen_string_literal: true

require_relative '../src/utils/config'
require_relative '../src/utils/event_bus'
require_relative '../src/market_data/candle_loader'
require_relative '../src/indicators/ema'
require_relative '../src/indicators/rsi'
require_relative '../src/strategies/ema_crossover'
require_relative '../src/execution/engine'
require_relative '../src/backtest/engine'
require_relative '../src/backtest/report_generator'

Utils::Config.load!

class MockApiClient
  def place_order(_payload)
    { orderId: "BT_#{Time.now.to_i}_#{rand(1000)}" }
  end
  def cancel_order(_id); true; end
end

symbol = 'NIFTY'
from_time = Time.parse('2024-01-01T09:15:00+05:30')
to_time = Time.parse('2024-01-31T15:30:00+05:30')

candles = MarketData::CandleLoader.load_history(symbol: symbol, from_time: from_time, to_time: to_time)
if candles.empty?
  puts "No candle data found for #{symbol}. Using dummy data."
  candles = [
    MarketData::Candle.new(symbol: symbol, timestamp: from_time, open: 100, high: 105, low: 95, close: 102, volume: 1000, timeframe: '5m'),
    MarketData::Candle.new(symbol: symbol, timestamp: from_time + 300, open: 102, high: 110, low: 100, close: 108, volume: 1000, timeframe: '5m')
  ]
end

params = Utils::Config.config.respond_to?(:ema_crossover) ? Utils::Config.config.ema_crossover : { fast_period: 9, slow_period: 21, rsi_threshold: 60 }
strategy = Strategies::EmaCrossover.new(params)
indicators = {
  ema_fast: Indicators::Ema.new(period: 9),
  ema_slow: Indicators::Ema.new(period: 21),
  rsi: Indicators::Rsi.new(period: 14)
}

execution_engine = Execution::Engine.new(MockApiClient.new)
backtest_engine = Backtest::Engine.new(strategy, indicators, execution_engine)

backtest_engine.replay(candles)

Backtest::ReportGenerator.generate(backtest_engine.pnl_calculator, format: :json, filename: 'ema_crossover_nifty')
puts "Backtest completed. Net PnL: #{backtest_engine.pnl_calculator.net_pnl}"
