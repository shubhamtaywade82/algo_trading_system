# frozen_string_literal: true

module Strategies
  # Abstract base class for all strategies
  class StrategyBase
    def initialize(params = {})
      @params = params
    end

    def on_candle(_candle, indicators:)
      raise NotImplementedError, "#{self.class} must implement #on_candle"
    end

    def on_tick(_tick); end

    def signal
      raise NotImplementedError, "#{self.class} must implement #signal"
    end

    def parameters
      @params || {}
    end
  end
end
