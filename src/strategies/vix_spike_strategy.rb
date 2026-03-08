# frozen_string_literal: true

require_relative 'strategy_base'

module Strategies
  # VIX spike reversal strategy
  class VixSpikeStrategy < StrategyBase
    def initialize(params = {})
      super(default_parameters.merge(params))
      @current_signal = :hold
    end

    def on_candle(_candle, indicators:)
      vix = indicators[:vix]

      return :hold unless vix&.ready?

      @current_signal = generate_signal(vix)
    end

    def signal
      @current_signal
    end

    private

    def generate_signal(vix)
      return :buy if vix.value > parameters[:vix_threshold]

      :hold
    end

    def default_parameters
      { vix_threshold: 15 }
    end
  end
end
