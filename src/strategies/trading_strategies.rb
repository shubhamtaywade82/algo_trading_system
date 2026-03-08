# frozen_string_literal: true

require 'enumerable/statistics'
require 'ostruct'

# Trading Strategies for Intraday Options
module TradingStrategies
  # Base strategy class
  class BaseStrategy
    def initialize(lookback_period: 14)
      @lookback_period = lookback_period
      @history = []
    end

    # Add bar to history
    def add_bar(bar)
      @history << bar
      @history = @history.last(@lookback_period + 30) if @history.length > @lookback_period + 30
    end

    # Get signal
    # Returns: { action: 'BUY'/'SELL'/'HOLD', direction: 'LONG'/'SHORT', confidence: 0-10, reason: String }
    def signal
      raise NotImplementedError, 'Subclass must implement signal method'
    end

    protected

    # Calculate RSI
    def rsi(period = @lookback_period)
      return nil if @history.length < period + 1

      closes = @history.map { |bar| bar[:close] }
      changes = closes.each_cons(2).map { |a, b| b - a }
      
      gains = changes.map { |c| c.positive? ? c : 0 }
      losses = changes.map { |c| c.negative? ? -c : 0 }

      avg_gain = gains.last(period).sum / period.to_f
      avg_loss = losses.last(period).sum / period.to_f

      return 50 if avg_loss == 0

      rs = avg_gain / avg_loss
      100 - (100 / (1 + rs))
    end

    # Calculate MACD
    def macd(fast: 12, slow: 26, signal_period: 9)
      return nil if @history.length < slow + signal_period

      closes = @history.map { |bar| bar[:close] }
      
      ema_fast = calculate_ema(closes, fast)
      ema_slow = calculate_ema(closes, slow)
      
      macd_line_history = []
      min_len = [ema_fast.length, ema_slow.length].min
      
      # Align EMA histories
      aligned_fast = ema_fast.last(min_len)
      aligned_slow = ema_slow.last(min_len)
      
      macd_line_history = aligned_fast.zip(aligned_slow).map { |f, s| f - s }
      
      return nil if macd_line_history.length < signal_period
      
      macd_line = macd_line_history.last
      signal_line = calculate_ema(macd_line_history, signal_period).last
      histogram = macd_line - signal_line

      { macd: macd_line, signal: signal_line, histogram: histogram }
    end

    # Calculate EMA
    def calculate_ema(values, period)
      return values if values.length < period

      multiplier = 2.0 / (period + 1)
      ema = values.first(period).sum / period.to_f
      result = [ema]

      values.drop(period).each do |value|
        ema = (value * multiplier) + (ema * (1 - multiplier))
        result << ema
      end

      result
    end

    # Calculate Bollinger Bands
    def bollinger_bands(period = 20, std_dev = 2)
      return nil if @history.length < period

      closes = @history.last(period).map { |bar| bar[:close] }
      sma = closes.sum / period.to_f
      variance = closes.sum { |c| (c - sma) ** 2 } / period
      std = Math.sqrt(variance)

      {
        upper: sma + (std_dev * std),
        middle: sma,
        lower: sma - (std_dev * std)
      }
    end

    # Calculate Average True Range
    def atr(period = 14)
      return nil if @history.length < period

      tr_values = @history.map.with_index do |bar, idx|
        if idx == 0
          bar[:high] - bar[:low]
        else
          prev = @history[idx - 1]
          [
            bar[:high] - bar[:low],
            (bar[:high] - prev[:close]).abs,
            (bar[:low] - prev[:close]).abs
          ].max
        end
      end

      tr_values.last(period).sum / period.to_f
    end

    # Volume analysis
    def avg_volume(period = 20)
      return nil if @history.length < period
      @history.last(period).map { |bar| bar[:volume] }.sum / period.to_f
    end

    def volume_spike?(threshold = 1.2)
      return false if @history.length < 20
      current_volume = @history.last[:volume]
      avg = avg_volume(20)
      current_volume > (avg * threshold)
    end

    # IV analysis
    def current_iv
      @history.last&.dig(:iv) || 0
    end

    def avg_iv(period = 20)
      return nil if @history.length < period
      @history.last(period).map { |bar| bar[:iv] || 0 }.sum / period.to_f
    end

    def iv_spike?(threshold = 1.5)
      current = current_iv
      avg = avg_iv(20) || current
      return false if avg.nil? || avg.zero?
      current > (avg * threshold)
    end

    # Spot price
    def spot_price
      @history.last&.dig(:spot) || @history.last[:close]
    end

    def last_n_bars(n)
      @history.last(n)
    end
  end

  # Strategy 1: RSI + MACD Reversal (Buy oversold, sell overbought)
  class RSIMACDReversal < BaseStrategy
    def signal
      return { action: 'HOLD', confidence: 0 } if @history.length < 30

      rsi_value = rsi(14)
      macd_data = macd
      
      return { action: 'HOLD', confidence: 0 } if rsi_value.nil? || macd_data.nil?

      # Oversold conditions (buy)
      if rsi_value < 30 && macd_data[:histogram].positive?
        {
          action: 'BUY',
          direction: 'LONG',
          confidence: 8,
          reason: "RSI oversold (#{rsi_value.round(2)}) + MACD bullish histogram"
        }
      # Overbought conditions (sell)
      elsif rsi_value > 70 && macd_data[:histogram].negative?
        {
          action: 'SELL',
          direction: 'SHORT',
          confidence: 7,
          reason: "RSI overbought (#{rsi_value.round(2)}) + MACD bearish histogram"
        }
      else
        { action: 'HOLD', confidence: 0 }
      end
    end
  end

  # Strategy 2: Bollinger Bands + Volume (Breakout)
  class BollingerBandsBreakout < BaseStrategy
    def signal
      return { action: 'HOLD', confidence: 0 } if @history.length < 30

      bb = bollinger_bands(20, 2)
      current_close = @history.last[:close]
      volume_spike = volume_spike?(1.2)

      return { action: 'HOLD', confidence: 0 } if bb.nil?

      # Upper band breakout with volume
      if current_close > bb[:upper] && volume_spike
        {
          action: 'BUY',
          direction: 'LONG',
          confidence: 8,
          reason: "Upper BB breakout (#{current_close.round(2)} > #{bb[:upper].round(2)}) + Volume spike"
        }
      # Lower band breakout with volume
      elsif current_close < bb[:lower] && volume_spike
        {
          action: 'SELL',
          direction: 'SHORT',
          confidence: 8,
          reason: "Lower BB breakout (#{current_close.round(2)} < #{bb[:lower].round(2)}) + Volume spike"
        }
      else
        { action: 'HOLD', confidence: 0 }
      end
    end
  end

  # Strategy 3: IV Spike + ATM Volume (Momentum)
  class IVSpikeVolumeMomentum < BaseStrategy
    def signal
      return { action: 'HOLD', confidence: 0 } if @history.length < 20

      iv_value = current_iv
      iv_avg = avg_iv(20)
      volume_spike = volume_spike?(1.5)
      rsi_value = rsi(14)

      return { action: 'HOLD', confidence: 0 } if iv_avg.nil? || iv_value.zero?

      iv_ratio = iv_value / iv_avg

      # High IV + High volume + RSI neutral = Momentum buy
      if iv_ratio > 1.4 && volume_spike && (rsi_value > 40 && rsi_value < 60)
        {
          action: 'BUY',
          direction: 'LONG',
          confidence: 9,
          reason: "IV spike (#{(iv_ratio * 100).round(0)}%) + Volume spike + RSI neutral (#{rsi_value.round(2)})"
        }
      # High IV + High volume + RSI neutral = Momentum short
      elsif iv_ratio > 1.4 && volume_spike && rsi_value > 60
        {
          action: 'SELL',
          direction: 'SHORT',
          confidence: 8,
          reason: "IV spike with strong RSI (#{rsi_value.round(2)}) + Volume surge"
        }
      else
        { action: 'HOLD', confidence: 0 }
      end
    end
  end

  # Strategy 4: VWAP Breakout (Volume-Weighted Average Price)
  class VWAPBreakout < BaseStrategy
    def signal
      return { action: 'HOLD', confidence: 0 } if @history.length < 10

      vwap_value = calculate_vwap
      current_close = @history.last[:close]
      current_volume = @history.last[:volume]
      avg_vol = avg_volume(10)

      return { action: 'HOLD', confidence: 0 } if vwap_value.nil?

      volume_ratio = avg_vol.to_f.positive? ? current_volume / avg_vol : 1.0

      # Close above VWAP with volume
      if current_close > vwap_value && volume_ratio > 1.0
        {
          action: 'BUY',
          direction: 'LONG',
          confidence: 7,
          reason: "Above VWAP (#{current_close.round(2)} > #{vwap_value.round(2)}) + Volume (#{volume_ratio.round(2)}x)"
        }
      # Close below VWAP with volume
      elsif current_close < vwap_value && volume_ratio > 1.0
        {
          action: 'SELL',
          direction: 'SHORT',
          confidence: 7,
          reason: "Below VWAP (#{current_close.round(2)} < #{vwap_value.round(2)}) + Volume (#{volume_ratio.round(2)}x)"
        }
      else
        { action: 'HOLD', confidence: 0 }
      end
    end

    private

    def calculate_vwap
      return nil if @history.length < 1

      total_pv = 0.0
      total_vol = 0

      @history.each do |bar|
        typical_price = (bar[:high] + bar[:low] + bar[:close]) / 3.0
        pv = typical_price * bar[:volume]
        total_pv += pv
        total_vol += bar[:volume]
      end

      total_vol.positive? ? total_pv / total_vol : nil
    end
  end

  # Strategy Factory
  class StrategyFactory
    STRATEGIES = {
      rsi_macd: RSIMACDReversal,
      bollinger_breakout: BollingerBandsBreakout,
      iv_spike_momentum: IVSpikeVolumeMomentum,
      vwap_breakout: VWAPBreakout
    }.freeze

    def self.create(strategy_type)
      strategy_class = STRATEGIES[strategy_type.to_sym]
      raise ArgumentError, "Unknown strategy: #{strategy_type}" unless strategy_class
      
      strategy_class.new
    end

    def self.available_strategies
      STRATEGIES.keys
    end
  end
end
