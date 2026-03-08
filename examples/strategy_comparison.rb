# frozen_string_literal: true

require_relative '../src/backtest/orchestrator'
require_relative '../src/strategies/trading_strategies'
require 'time'
require 'ostruct'
require 'terminal-table' # Added for nice console output

# Mock client to avoid real API calls during comparison test
class ComparisonMockClient < Api::DhanApiClient
  def fetch_expired_options(underlying:, from_date:, to_date:, **_opts)
    start_time = Time.parse("#{from_date} 09:15:00 +0530")
    data = {}
    
    ['ATM', 'ATM+1', 'ATM-1'].each do |strike|
      strike_data = {
        timestamp: [], open: [], high: [], low: [], close: [],
        iv: [], oi: [], volume: [], spot: [], strike: []
      }
      current_price = 350.0 + rand(50)
      
      (0...375).each do |i|
        ts = (start_time + (i * 60)).to_i
        bias = i < 150 ? -1.5 : 1.0 # Create some trends
        change = (rand - 0.5) * 4.0 + bias
        open = current_price
        close = open + change
        high = [open, close].max + rand * 1.5
        low = [open, close].min - rand * 1.5
        current_price = close

        strike_data[:timestamp] << ts
        strike_data[:open] << open.round(2)
        strike_data[:high] << high.round(2)
        strike_data[:low] << low.round(2)
        strike_data[:close] << close.round(2)
        strike_data[:volume] << (5000 + rand(10000))
        strike_data[:iv] << (20.0 + rand(10.0))
        strike_data[:oi] << (100000 + rand(50000))
        strike_data[:spot] << (22000.0 + (i * 0.5))
        strike_data[:strike] << 22000.0
      end
      data["#{strike}_CALL"] = strike_data
    end
    data
  end
end

puts "╔════════════════════════════════════════════════════════════════════════════╗"
puts "║          NSE OPTIONS STRATEGY COMPARISON ENGINE - PRODUCTION               ║"
puts "╚════════════════════════════════════════════════════════════════════════════╝"

# 1. Configuration
CONFIG = {
  underlying: 'nifty',
  from_date: '2024-01-01',
  to_date: '2024-01-01',
  capital: 1_000_000,
  strikes: ['ATM', 'ATM+1', 'ATM-1']
}.freeze

# 2. Get all available strategies
strategies = TradingStrategies::StrategyFactory.available_strategies

# 3. Initialize Orchestrator with Mock Client
orchestrator = Backtest::Orchestrator.new(
  access_token: 'MOCK',
  capital: CONFIG[:capital],
  output_dir: './backtest_results/comparisons'
)
mock_client = ComparisonMockClient.new(access_token: 'MOCK')
orchestrator.instance_variable_set(:@api_client, mock_client)

comparison_results = []

# 4. Run Backtest for each strategy
strategies.each do |strategy_name|
  puts "\n🧪 Testing Strategy: #{strategy_name.to_s.upcase}..."
  
  begin
    results = orchestrator.run_backtest(config: CONFIG.merge(strategy: strategy_name))
    
    total_trades = results[:total_trades]
    total_pnl = results[:total_pnl]
    
    # Calculate aggregate win rate
    all_trades = results[:trades]
    wins = all_trades.count { |t| t[:status] == 'WIN' }
    win_rate = total_trades.positive? ? (wins.to_f / total_trades * 100).round(2) : 0
    
    # Get representative metrics from summary
    # Using ATM_CALL as benchmark for individual strategy performance
    atm_results = results[:by_strike]["ATM_CALL"][:summary]
    
    comparison_results << {
      name: strategy_name.to_s.upcase,
      trades: total_trades,
      win_rate: "#{win_rate}%",
      pnl: "₹#{total_pnl}",
      max_dd: atm_results[:max_drawdown],
      sharpe: atm_results[:sharpe_ratio]
    }
  rescue StandardError => e
    puts "  ❌ Error: #{e.message}"
  end
end

# 5. Generate Comparison Table
rows = comparison_results.map do |res|
  [res[:name], res[:trades], res[:win_rate], res[:pnl], res[:max_dd], res[:sharpe]]
end

table = Terminal::Table.new do |t|
  t.headings = ['Strategy', 'Trades', 'Win Rate', 'Total P&L', 'Max DD', 'Sharpe']
  t.rows = rows
  t.style = { border_i: 'x', border_y: '│', border_x: '─' }
end

puts "\n📊 FINAL COMPARISON REPORT:"
puts table

# 6. Recommendation
best_pnl = comparison_results.max_by { |r| r[:pnl].gsub(/[^\d.-]/, '').to_f }
puts "\n🏆 RECOMMENDATION: Based on Total P&L, '#{best_pnl[:name]}' performed best in this session."
puts "📂 Detailed reports for all strategies saved in ./backtest_results/comparisons/"
