# frozen_string_literal: true

# examples/backtest_example.rb
#
# Demonstrates how to run a backtest using the EMA Crossover strategy
# against historical NIFTY data.
#
# Usage:
#   bundle exec ruby examples/backtest_example.rb

require "dotenv/load"
require_relative "../src/utils/config"
require_relative "../src/utils/logger"
require_relative "../src/utils/event_bus"
require_relative "../src/api/dhan_client"
require_relative "../src/market_data/candle_loader"
require_relative "../src/indicators/ema"
require_relative "../src/indicators/rsi"
require_relative "../src/indicators/atr"
require_relative "../src/strategies/ema_crossover"
require_relative "../src/backtest/engine"
require_relative "../src/backtest/report_generator"

# --- Configuration ---
config  = Utils::Config.load("config/settings.yml")
logger  = Utils::Logger.new(level: config.log_level)
client  = Api::DhanClient.new(
  client_id:    ENV.fetch("DHAN_CLIENT_ID"),
  access_token: ENV.fetch("DHAN_ACCESS_TOKEN"),
  logger:       logger
)

# --- Load Historical Candles ---
loader = MarketData::CandleLoader.new(client: client, logger: logger)
candles = loader.load_historical(
  symbol:           "NIFTY",
  security_id:      "13",
  exchange_segment: "IDX_I",
  instrument:       "INDEX",
  from_date:        "2024-01-01",
  to_date:          "2024-03-31",
  timeframe:        "5m"
)

logger.info("candles.loaded", count: candles.size, symbol: "NIFTY")

# --- Build Strategy with Indicators ---
strategy = Strategies::EmaCrossover.new(
  fast_period:           9,
  slow_period:           21,
  rsi_period:            14,
  atr_period:            14,
  target_atr_multiplier: 2.0,
  vix_max:               18
)

# --- Run Backtest ---
engine = Backtest::Engine.new(
  capital:   config.capital,
  risk_pct:  config.risk_per_trade_pct,
  slippage:  0.0005,   # 0.05%
  brokerage: 0.0003,   # 0.03%
  logger:    logger
)

result = engine.run(strategy: strategy, candles: candles)

# --- Print Summary ---
puts "\n=== Backtest Results ==="
puts "Period:         2024-01-01 to 2024-03-31"
puts "Strategy:       EMA Crossover (9/21)"
puts "Symbol:         NIFTY"
puts "Total Trades:   #{result.total_trades}"
puts "Winning Trades: #{result.winning_trades}"
puts "Losing Trades:  #{result.losing_trades}"
puts "Win Rate:       #{result.win_rate.round(1)}%"
puts "Total P&L:      ₹#{result.total_pnl.round(2)}"
puts "Max Drawdown:   ₹#{result.max_drawdown.round(2)}"
puts "========================\n\n"

# --- Export Report ---
reporter = Backtest::ReportGenerator.new
reporter.export_csv(result, path: "backtest_results/ema_crossover_q1_2024.csv")
reporter.export_json(result, path: "backtest_results/ema_crossover_q1_2024.json")

puts "Reports saved to backtest_results/"
