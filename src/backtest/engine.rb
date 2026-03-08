# frozen_string_literal: true

require_relative '../utils/event_bus'
require_relative '../utils/logger'
require_relative 'pnl_calculator'

module Backtest
  # Replays historical candles through strategy identically to live mode
  class Engine
    attr_reader :pnl_calculator, :trades

    # TODO: Extract workflow method
def initialize(strategy, indicators, execution_engine)
      @strategy = strategy
      @indicators = indicators
      @execution_engine = execution_engine
      @pnl_calculator = PnlCalculator.new
      @event_bus = Utils::EventBus.instance

      subscribe_events
    end

    def replay(candles)
      candles.each do |candle|
        @event_bus.publish('market_data.candle_closed', candle: candle)

        @indicators.each { |_, ind| ind.update(candle) }

        signal = @strategy.on_candle(candle, indicators: @indicators)

        process_signal(signal, candle)

        simulate_fills(candle)
      end
    end

    private

    def subscribe_events
      @event_bus.subscribe('order.placed') do |payload|
        @pending_orders ||= []
        @pending_orders << payload[:order]
      end

      @event_bus.subscribe('order.filled') do |payload|
        @pnl_calculator.record_order(payload[:order])
      end
    end

    def process_signal(signal, candle)
      pos_tracker = @execution_engine.position_tracker
      has_position = pos_tracker.open_positions.key?(candle.symbol)

      if signal == :buy && !has_position
        order_params = {
          symbol: candle.symbol,
          transaction_type: 'BUY',
          order_type: 'MARKET',
          quantity: 50,
          price: candle.close,
          trigger_price: candle.close * 0.99
        }
        @execution_engine.order_manager.place_order(order_params, current_time: candle.timestamp)
      elsif signal == :sell && has_position
        order_params = {
          symbol: candle.symbol,
          transaction_type: 'SELL',
          order_type: 'MARKET',
          quantity: pos_tracker.open_positions[candle.symbol].quantity,
          price: candle.close,
          trigger_price: candle.close * 1.01
        }
        @execution_engine.order_manager.place_order(order_params, current_time: candle.timestamp)
      end
    end

    def simulate_fills(candle)
      @pending_orders ||= []
      @pending_orders.each do |order|
        @execution_engine.order_manager.simulate_fill(order.order_id, candle.close, candle.timestamp)
      end
      @pending_orders.clear
    end
  end
end
