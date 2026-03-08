# frozen_string_literal: true

require_relative 'strategy_base'

module Strategies
  # Opening Range Breakout (first 30 min)
  class OrbStrategy < StrategyBase
    def initialize(params = {})
      super(default_parameters.merge(params))
      @current_signal = :hold
      @range_high = nil
      @range_low = nil
      @candles_in_range = 0
      @max_candles = parameters[:range_minutes] / 5
    end

    def on_candle(candle, indicators: {})
      _ = indicators
      reset_daily_state(candle) if market_open_candle?(candle)

      if capturing_range?
        update_range(candle)
        return :hold
      end

      @current_signal = check_breakout(candle)
    end

    def signal
      @current_signal
    end

    private

    def market_open_candle?(candle)
      candle.timestamp.hour == 9 && candle.timestamp.min == 15
    end

    def reset_daily_state(candle)
      @range_high = candle.high
      @range_low = candle.low
      @candles_in_range = 1
      @current_signal = :hold
    end

    def capturing_range?
      @candles_in_range.positive? && @candles_in_range < @max_candles
    end

    def update_range(candle)
      @range_high = [@range_high, candle.high].max
      @range_low = [@range_low, candle.low].min
      @candles_in_range += 1
    end

    def check_breakout(candle)
      return :hold unless @candles_in_range >= @max_candles
      return :buy if candle.close > @range_high
      return :sell if candle.close < @range_low

      :hold
    end

    def default_parameters
      { range_minutes: 30 }
    end
  end
end
