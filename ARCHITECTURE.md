# ARCHITECTURE — NSE Options Algorithmic Trading System

## Overview

The system is a modular, event-driven algorithmic trading platform built in Ruby.
It supports both live trading via DhanHQ API and historical backtesting using the
same strategy code, ensuring full live/backtest parity.

---

## High-Level Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Event Bus                               │
│           (internal pub/sub, zero external dependencies)        │
└──────────┬──────────────┬──────────────┬────────────────────────┘
           │              │              │
    ┌──────▼──────┐ ┌─────▼──────┐ ┌────▼────────────┐
    │ Market Data │ │ Indicators │ │   Strategies    │
    │  Module     │ │  Engine    │ │   Runner        │
    └──────┬──────┘ └─────┬──────┘ └────┬────────────┘
           │              │              │
           └──────────────┼──────────────┘
                          │
                   ┌──────▼──────┐
                   │  Execution  │
                   │  Engine     │
                   └──────┬──────┘
                          │
              ┌───────────┴───────────┐
              │                       │
       ┌──────▼──────┐        ┌───────▼──────┐
       │  DhanHQ API │        │   Backtest   │
       │  Client     │        │   Engine     │
       └─────────────┘        └──────────────┘
```

---

## Module Specifications

### 1. `src/api/` — DhanHQ API Client

**Responsibility**: Thin wrapper around the DhanHQ REST and WebSocket APIs.

Files:
- `dhan_client.rb` — REST API calls (orders, positions, market data)
- `websocket_feed.rb` — live market data subscription

Contracts:
- Must never expose raw HTTP; callers use typed methods only
- Must handle rate limiting with exponential backoff
- Must emit events on the EventBus when data arrives (live mode)

---

### 2. `src/market_data/` — Market Data Module

**Responsibility**: Candle loading, tick normalization, data caching.

Files:
- `candle_loader.rb` — loads OHLCV candles (historical + live)
- `tick_normalizer.rb` — normalizes raw tick data to standard format

Events emitted:
- `market_data.candle_closed` — when a new candle completes
- `market_data.tick` — on every price tick (live mode only)

---

### 3. `src/indicators/` — Indicator Engine

**Responsibility**: Stateful technical indicator computation.

Files:
- `indicator_base.rb` — abstract base class
- `ema.rb` — Exponential Moving Average
- `rsi.rb` — Relative Strength Index (14-period default)
- `atr.rb` — Average True Range
- `vix_reader.rb` — reads India VIX from market data feed

Design:
- Indicators are stateful objects updated incrementally (not batch-computed)
- Each indicator subscribes to `market_data.candle_closed` events
- Emits `indicator.updated` after each computation

---

### 4. `src/strategies/` — Strategy Runner

**Responsibility**: Pluggable strategy modules that read indicator state and produce signals.

Files:
- `strategy_base.rb` — abstract base with lifecycle hooks
- `ema_crossover.rb` — EMA 9/21 crossover strategy
- `orb_strategy.rb` — Opening Range Breakout strategy
- `vix_spike_strategy.rb` — VIX spike reversal strategy

Strategy Interface (every strategy MUST implement):

```ruby
class MyStrategy < StrategyBase
  def on_candle(candle, indicators)   # called on each new candle
  def on_tick(tick)                   # called on each tick (optional)
  def signal                          # returns :buy, :sell, or :hold
  def parameters                      # returns hash of config params
end
```

---

### 5. `src/execution/` — Execution Engine

**Responsibility**: Order lifecycle management, position tracking, risk enforcement.

Files:
- `order_manager.rb` — creates, tracks, and cancels orders
- `position_tracker.rb` — tracks open positions and P&L
- `risk_engine.rb` — enforces per-trade and daily risk limits

Rules enforced by risk engine:
- Max 1% capital at risk per trade
- Max 3% daily drawdown → halts trading
- Max 3 concurrent open positions
- Mandatory stop-loss on every order

---

### 6. `src/backtest/` — Backtest Engine

**Responsibility**: Replay historical candles through the strategy stack identically to live mode.

Files:
- `engine.rb` — main backtest loop (replays candles, fires events)
- `pnl_calculator.rb` — computes trade-level and session-level P&L
- `report_generator.rb` — generates CSV/JSON backtest reports

Design constraint:
- The backtest engine must produce the same strategy signals as live mode
  given the same data. No look-ahead bias allowed.

---

### 7. `src/utils/` — Shared Utilities

Files:
- `event_bus.rb` — lightweight pub/sub (subscribe, publish, unsubscribe)
- `logger.rb` — structured JSON logger
- `config.rb` — loads config from `config/settings.yml`
- `time_helpers.rb` — IST-aware time utilities, market hours checks

---

## Data Flow — Live Trading

```
DhanHQ WebSocket
    → TickNormalizer
    → EventBus: market_data.tick
    → IndicatorEngine.on_tick
    → StrategyRunner.on_tick
    → Signal: :buy
    → RiskEngine.validate
    → OrderManager.place_order
    → DhanHQ REST API
    → EventBus: order.filled
    → PositionTracker.update
```

## Data Flow — Backtest

```
CandleLoader.load_history(symbol, from, to)
    → BacktestEngine.replay(candles)
        → EventBus: market_data.candle_closed   (for each candle)
        → IndicatorEngine.on_candle
        → StrategyRunner.on_candle
        → Signal: :buy
        → RiskEngine.validate (paper mode)
        → PnlCalculator.record_trade
    → ReportGenerator.generate
```

---

## Configuration

All configuration lives in `config/settings.yml`:

```yaml
capital: 500000          # total capital in INR
risk_per_trade_pct: 1.0  # % of capital risked per trade
max_daily_loss_pct: 3.0  # % daily loss limit
max_positions: 3
broker: dhan
symbols:
  - NIFTY
  - BANKNIFTY
  - FINNIFTY
timeframe: "5m"          # candle timeframe
```

Secrets (API keys) go in `.env` — never committed to git.
