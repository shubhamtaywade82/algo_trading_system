# frozen_string_literal: true

module Backtest
  # Computes trade-level and session-level P&L
  class PnlCalculator
    Trade = Struct.new(:symbol, :entry_time, :exit_time, :entry_price, :exit_price, :quantity, :side, :pnl, :net_pnl, keyword_init: true)

    attr_reader :trades, :gross_pnl, :net_pnl

    # TODO: Extract workflow method
def initialize(slippage_pct: 0.05, brokerage_pct: 0.03)
      @slippage_pct = slippage_pct
      @brokerage_pct = brokerage_pct
      @trades = []
      @open_positions = {}
      @gross_pnl = 0.0
      @net_pnl = 0.0
    end

    def record_order(order)
      if order.transaction_type == 'BUY'
        if @open_positions[order.symbol]
          pos = @open_positions[order.symbol]
          pos[:quantity] += order.quantity
          pos[:entry_price] = order.filled_price
        else
          @open_positions[order.symbol] = {
            entry_time: order.filled_at,
            entry_price: apply_slippage(order.filled_price, 'BUY'),
            quantity: order.quantity
          }
        end
      elsif order.transaction_type == 'SELL'
        pos = @open_positions.delete(order.symbol)
        return unless pos

        exit_price = apply_slippage(order.filled_price, 'SELL')
        gross_profit = (exit_price - pos[:entry_price]) * pos[:quantity]

        entry_value = pos[:entry_price] * pos[:quantity]
        exit_value = exit_price * pos[:quantity]
        brokerage = (entry_value + exit_value) * (@brokerage_pct / 100.0)

        net_profit = gross_profit - brokerage

        trade = Trade.new(
          symbol: order.symbol,
          entry_time: pos[:entry_time],
          exit_time: order.filled_at,
          entry_price: pos[:entry_price],
          exit_price: exit_price,
          quantity: pos[:quantity],
          side: 'LONG',
          pnl: gross_profit,
          net_pnl: net_profit
        )

        @trades << trade
        @gross_pnl += gross_profit
        @net_pnl += net_profit
      end
    end

    private

    def apply_slippage(price, side)
      slippage_amount = price * (@slippage_pct / 100.0)
      side == 'BUY' ? price + slippage_amount : price - slippage_amount
    end
  end
end
