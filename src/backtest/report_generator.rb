# frozen_string_literal: true

require 'csv'
require 'json'

module Backtest
  # Generates CSV and JSON reports
  class ReportGenerator
    def self.generate(calculator, format: :csv, filename: 'report')
      dir = 'backtest_results'
      Dir.mkdir(dir) unless Dir.exist?(dir)

      if format == :csv
        generate_csv(calculator, "#{dir}/#{filename}.csv")
      elsif format == :json
        generate_json(calculator, "#{dir}/#{filename}.json")
      end
    end

    def self.generate_csv(calculator, path)
      CSV.open(path, 'w') do |csv|
        csv << ['Symbol', 'Entry Time', 'Exit Time', 'Entry Price', 'Exit Price', 'Qty', 'Side', 'Gross PnL', 'Net PnL']
        calculator.trades.each do |t|
          csv << [t.symbol, t.entry_time, t.exit_time, t.entry_price, t.exit_price, t.quantity, t.side, t.pnl, t.net_pnl]
        end
      end
      Utils::Logger.info("backtest.report_generated", path: path) if defined?(Utils::Logger)
    end

    def self.generate_json(calculator, path)
      data = {
        total_trades: calculator.trades.size,
        gross_pnl: calculator.gross_pnl,
        net_pnl: calculator.net_pnl,
        trades: calculator.trades.map(&:to_h)
      }
      File.write(path, JSON.pretty_generate(data))
      Utils::Logger.info("backtest.report_generated", path: path) if defined?(Utils::Logger)
    end
  end
end
