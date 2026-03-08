# frozen_string_literal: true

require_relative 'strategy_base'

module Strategies
  # EMA 9/21 crossover with RSI filter
  class EmaCrossover < StrategyBase
    def initialize(params = {})
      super(default_parameters.merge(params))
      @current_signal = :hold
    end

    def on_candle(_candle, indicators:)
      ema_fast = indicators[:ema_fast]
      ema_slow = indicators[:ema_slow]
      rsi = indicators[:rsi]

      return :hold unless indicators_ready?(ema_fast, ema_slow, rsi)

      @current_signal = generate_signal(ema_fast, ema_slow, rsi)
    end

    def signal
      @current_signal
    end

    private

    def indicators_ready?(fast, slow, rsi)
      fast&.ready? && slow&.ready? && rsi&.ready?
    end

    def generate_signal(fast, slow, rsi)
      return :buy if crossover_buy?(fast, slow, rsi)
      return :sell if crossover_sell?(fast, slow)

      :hold
    end

    def crossover_buy?(fast, slow, rsi)
      fast.value > slow.value && rsi.value > parameters[:rsi_threshold]
    end

    def crossover_sell?(fast, slow)
      fast.value < slow.value
    end

    def default_parameters
      {
        fast_period: 9,
        slow_period: 21,
        rsi_period: 14,
        rsi_threshold: 60
      }
    end
  end
end
