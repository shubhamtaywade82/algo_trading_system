# frozen_string_literal: true

require 'date'
require 'json'
require_relative '../utils/logger'

module Backtest
  # Options Backtesting Engine
  # Simulates intraday CE/PE trades with bracket orders and risk management
  class OptionsBacktestEngine
    # Trade states
    STATES = {
      idle: 'IDLE',
      signal_detected: 'SIGNAL_DETECTED',
      entry_pending: 'ENTRY_PENDING',
      position_open: 'POSITION_OPEN',
      risk_management_active: 'RISK_MANAGEMENT_ACTIVE',
      exit_pending: 'EXIT_PENDING',
      position_closed: 'POSITION_CLOSED'
    }.freeze

    # Constants
    STT_RATE = 0.0005  # 0.05% on contract value
    MARGIN_REQUIREMENT = 0.30  # 30% for index options
    MIN_STOP_LOSS_PCT = 0.015  # 1.5% minimum
    DEFAULT_POSITION_SIZE_PCT = 0.025  # 2.5% max per trade
    NSE_CLOSE_TIME = 15 * 3600 + 30 * 60  # 3:30 PM IST in seconds from midnight
    ENTRY_BUFFER_SECONDS = 2 * 60  # 2 min after signal before exit consideration

    def initialize(capital:, logger: nil)
      @capital = capital
      @logger = logger || Utils::Logger
      @state = STATES[:idle]
      @trades = []
      @current_position = nil
      @equity = capital.to_f
      @peak_equity = capital.to_f
    end

    # Run backtest on options data
    # @param symbol [String] e.g., 'NIFTY-26500-CE'
    # @param bars [Array<Hash>] Array of OHLCV bars with timestamps
    # @param strategy [Proc] Signal generation function
    # @return [Hash] Backtest results
    def backtest(symbol:, bars:, strategy:)
      validate_bars(bars)
      
      @logger.info("system.backtest_start", symbol: symbol, bar_count: bars.length)
      
      bars.each_with_index do |bar, idx|
        process_bar(bar, symbol, strategy, bars, idx)
      end

      # Close any open position at end
      close_position_at_market(bars.last, symbol) if @current_position

      generate_report
    end

    private

    # Process single bar
    def process_bar(bar, symbol, strategy, bars, idx)
      current_time_seconds = bar[:timestamp].to_i % 86400  # Seconds from midnight

      # Auto-exit at market close
      if current_time_seconds >= NSE_CLOSE_TIME
        close_position_at_market(bar, symbol) if @current_position
        return
      end

      case @state
      when STATES[:idle]
        check_for_signal(bar, symbol, strategy)
      when STATES[:signal_detected]
        execute_entry(bar, symbol)
      when STATES[:position_open]
        manage_open_position(bar, symbol, bars, idx)
      when STATES[:risk_management_active]
        manage_stop_loss(bar, symbol)
      when STATES[:exit_pending]
        execute_exit(bar, symbol)
      end
    end

    # Check for entry signal
    def check_for_signal(bar, symbol, strategy)
      signal = strategy.call(bar)
      return unless signal && (signal == :buy || signal[:action] == 'BUY')

      @logger.info("strategy.signal_detected", time: format_time(bar[:timestamp]), action: signal[:action], symbol: symbol)
      @state = STATES[:signal_detected]
      @current_position = {
        symbol: symbol,
        signal: signal,
        entry_time: bar[:timestamp],
        bar_index: 0
      }
    end

    # Execute entry order
    def execute_entry(bar, symbol)
      signal = @current_position[:signal]
      entry_price = bar[:close]
      
      # Calculate position size
      position_size_amount = @equity * DEFAULT_POSITION_SIZE_PCT
      quantity = (position_size_amount / entry_price).floor
      
      if quantity <= 0
        @state = STATES[:idle]
        @current_position = nil
        return
      end

      # Calculate stop-loss
      direction = signal[:direction] || 'LONG'
      stop_loss = calculate_stop_loss(entry_price, direction)
      stop_loss_distance = (entry_price - stop_loss).abs
      max_loss = (stop_loss_distance * quantity).round(2)

      # Validate stop-loss
      if stop_loss_distance < entry_price * MIN_STOP_LOSS_PCT
        @state = STATES[:idle]
        @current_position = nil
        return
      end

      # Calculate costs
      contract_value = entry_price * quantity
      stt = contract_value * STT_RATE
      margin_required = contract_value * MARGIN_REQUIREMENT
      total_cost = margin_required + stt

      if total_cost > @equity
        @logger.warn("risk.insufficient_capital", required: total_cost.round(2), available: @equity.round(2))
        @state = STATES[:idle]
        @current_position = nil
        return
      end

      # Record trade entry
      @current_position.merge!(
        state: STATES[:position_open],
        entry_price: entry_price,
        quantity: quantity,
        stop_loss: stop_loss,
        max_loss: max_loss,
        stt: stt,
        margin_required: margin_required,
        entry_bar_time: bar[:timestamp]
      )

      @equity -= (margin_required + stt)
      @logger.info("trade.entry", time: format_time(bar[:timestamp]), symbol: symbol, price: entry_price, quantity: quantity, sl: stop_loss)
      @state = STATES[:position_open]
    end

    # Manage open position
    def manage_open_position(bar, symbol, bars, idx)
      entry_price = @current_position[:entry_price]
      entry_time = @current_position[:entry_bar_time]
      stop_loss = @current_position[:stop_loss]
      quantity = @current_position[:quantity]
      
      # Check if entry buffer expired (2 minutes)
      time_elapsed = bar[:timestamp].to_i - entry_time.to_i
      
      # Hit stop-loss?
      if bar[:low] <= stop_loss
        @logger.info("trade.stop_loss_hit", time: format_time(bar[:timestamp]), price: bar[:low])
        realize_pnl(stop_loss, symbol, bar)
        return
      end

      # Take-profit logic (20% gain)
      profit_target = entry_price * 1.20
      if bar[:high] >= profit_target
        @logger.info("trade.target_hit", time: format_time(bar[:timestamp]), price: bar[:high])
        realize_pnl(profit_target, symbol, bar)
        return
      end

      # Theta decay exit: If 2 mins elapsed and price moving against position, exit
      if time_elapsed >= ENTRY_BUFFER_SECONDS && bar[:close] < entry_price * 0.98
        @logger.info("trade.theta_exit", time: format_time(bar[:timestamp]), price: bar[:close])
        realize_pnl(bar[:close], symbol, bar)
        return
      end
    end

    # Realize P&L and close position
    def realize_pnl(exit_price, symbol, bar)
      entry_price = @current_position[:entry_price]
      quantity = @current_position[:quantity]
      stt_entry = @current_position[:stt]
      margin_required = @current_position[:margin_required]

      # Exit STT
      stt_exit = (exit_price * quantity) * STT_RATE
      total_stt = stt_entry + stt_exit

      gross_pnl = (exit_price - entry_price) * quantity
      net_pnl = gross_pnl - total_stt
      pnl_pct = (net_pnl / (entry_price * quantity)) * 100

      # Update equity
      @equity += margin_required + gross_pnl - stt_exit
      @peak_equity = [@peak_equity, @equity].max

      # Record trade
      trade = {
        symbol: symbol,
        entry_price: entry_price,
        exit_price: exit_price,
        quantity: quantity,
        entry_time: @current_position[:entry_time],
        exit_time: bar[:timestamp],
        pnl: net_pnl.round(2),
        pnl_pct: pnl_pct.round(2),
        max_loss: @current_position[:max_loss],
        status: net_pnl.positive? ? 'WIN' : 'LOSS'
      }

      @trades << trade
      @logger.info("trade.exit", time: format_time(bar[:timestamp]), symbol: symbol, price: exit_price, pnl: net_pnl.round(2))

      @state = STATES[:idle]
      @current_position = nil
    end

    # Close position at market close
    def close_position_at_market(bar, symbol)
      @logger.info("trade.market_close_exit", time: format_time(bar[:timestamp]))
      realize_pnl(bar[:close], symbol, bar)
    end

    # Calculate stop-loss based on direction
    def calculate_stop_loss(entry_price, direction)
      case direction.to_s.upcase
      when 'LONG'
        entry_price * (1 - MIN_STOP_LOSS_PCT)
      when 'SHORT'
        entry_price * (1 + MIN_STOP_LOSS_PCT)
      else
        entry_price * (1 - MIN_STOP_LOSS_PCT)
      end
    end

    # Validate bar data
    def validate_bars(bars)
      raise ArgumentError, 'bars array is empty' if bars.nil? || bars.empty?

      required_fields = %i[timestamp open high low close volume]
      bars.each do |bar|
        required_fields.each do |field|
          raise ArgumentError, "Bar missing field: #{field}" unless bar.key?(field)
        end
      end

      # Check timestamp continuity
      bars.each_cons(2) do |prev, curr|
        if curr[:timestamp].to_i <= prev[:timestamp].to_i
          @logger.warn("data.non_monotonic_timestamps", prev: prev[:timestamp], curr: curr[:timestamp])
        end
      end
    end

    # Generate backtest report
    def generate_report
      total_trades = @trades.length
      winning_trades = @trades.count { |t| t[:status] == 'WIN' }
      losing_trades = total_trades - winning_trades
      
      win_rate = total_trades.positive? ? (winning_trades.to_f / total_trades * 100).round(2) : 0
      total_pnl = @trades.sum { |t| t[:pnl] }
      total_pnl_pct = ((total_pnl / @capital) * 100).round(2)

      avg_win = winning_trades.positive? ? (@trades.select { |t| t[:status] == 'WIN' }.sum { |t| t[:pnl] } / winning_trades).round(2) : 0
      avg_loss = losing_trades.positive? ? (@trades.select { |t| t[:status] == 'LOSS' }.sum { |t| t[:pnl] } / losing_trades).round(2) : 0

      max_drawdown = calculate_max_drawdown
      sharpe_ratio = calculate_sharpe_ratio

      {
        summary: {
          total_trades: total_trades,
          winning_trades: winning_trades,
          losing_trades: losing_trades,
          win_rate: "#{win_rate}%",
          total_pnl: "₹#{total_pnl.round(2)}",
          total_pnl_pct: "#{total_pnl_pct}%",
          avg_win: "₹#{avg_win.round(2)}",
          avg_loss: "₹#{avg_loss.round(2)}",
          max_drawdown: "#{max_drawdown.round(2)}%",
          sharpe_ratio: sharpe_ratio.round(2),
          starting_capital: "₹#{@capital.round(2)}",
          ending_capital: "₹#{@equity.round(2)}"
        },
        trades: @trades
      }
    end

    # Calculate max drawdown
    def calculate_max_drawdown
      equity_curve = [@capital]
      current = @capital
      @trades.each do |trade|
        current += trade[:pnl]
        equity_curve << current
      end

      max_peak = equity_curve.first
      max_dd = 0

      equity_curve.each do |equity|
        max_peak = [max_peak, equity].max
        dd = ((max_peak - equity) / max_peak) * 100
        max_dd = [max_dd, dd].max
      end

      max_dd
    end

    # Calculate Sharpe ratio
    def calculate_sharpe_ratio
      return 0 if @trades.length < 2

      returns = @trades.map { |t| t[:pnl_pct] }
      mean_return = returns.sum / returns.length
      variance = returns.sum { |r| (r - mean_return)**2 } / (returns.length - 1)
      std_dev = Math.sqrt(variance)

      return 0 if std_dev.zero?
      (mean_return / std_dev) * Math.sqrt(252)  # Annualized
    end

    # Format unix timestamp to readable time
    def format_time(timestamp)
      Time.at(timestamp.to_i).strftime('%H:%M:%S')
    end
  end
end
