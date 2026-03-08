# IMPLEMENTATION GUIDE

This document defines coding standards, patterns, and module-level
specifications for the algo trading system. Follow these rules exactly.

---

## Ruby Version & Style

- Ruby 3.2+
- Follow standard Ruby style (2-space indent, snake_case methods, PascalCase classes)
- Use `frozen_string_literal: true` at the top of every file
- Use keyword arguments for methods with 3+ parameters
- Prefer `Struct` over plain hashes for typed data objects

---

## Project Layout

```
algo_trading_system/
├── config/
│   ├── settings.yml        ← runtime config (capital, symbols, timeframe)
│   └── strategies.yml      ← per-strategy parameter overrides
├── src/
│   ├── api/
│   ├── market_data/
│   ├── indicators/
│   ├── strategies/
│   ├── execution/
│   ├── backtest/
│   └── utils/
├── spec/                   ← RSpec tests
├── examples/               ← runnable example scripts
└── Gemfile
```

---

## Gemfile (required gems)

```ruby
source "https://rubygems.org"

gem "faraday"          # HTTP client for REST API
gem "faraday-retry"    # automatic retry middleware
gem "websocket-client-simple"  # WebSocket feed
gem "dotenv"           # .env loading
gem "dry-configurable" # config objects
gem "dry-events"       # event bus
gem "zeitwerk"         # autoloading
gem "rspec"            # testing
gem "vcr"              # HTTP cassette recording for tests
gem "timecop"          # time manipulation in tests
gem "csv"              # backtest report export
```

---

## EventBus Pattern

All inter-module communication goes through `Utils::EventBus`.

```ruby
# Publishing an event
EventBus.publish("market_data.candle_closed", candle: candle_obj)

# Subscribing to an event
EventBus.subscribe("market_data.candle_closed") do |payload|
  process_candle(payload[:candle])
end
```

Event names use dot-namespaced strings. Never use symbols for event names.

---

## Candle Data Structure

All candle data must conform to this Struct:

```ruby
Candle = Struct.new(
  :symbol,      # String  — "NIFTY"
  :timestamp,   # Time    — candle open time in IST
  :open,        # Float
  :high,        # Float
  :low,         # Float
  :close,       # Float
  :volume,      # Integer
  :timeframe,   # String  — "1m", "5m", "15m", "1h", "1d"
  keyword_init: true
)
```

---

## Order Data Structure

```ruby
Order = Struct.new(
  :order_id,        # String — broker-assigned ID
  :symbol,          # String
  :exchange,        # String — "NSE"
  :segment,         # String — "FO" (Futures & Options)
  :transaction_type,# String — "BUY" or "SELL"
  :order_type,      # String — "MARKET", "LIMIT", "SL", "SL-M"
  :product_type,    # String — "INTRADAY"
  :quantity,        # Integer — number of lots × lot size
  :price,           # Float  — 0 for MARKET orders
  :trigger_price,   # Float  — for SL/SL-M orders
  :status,          # String — "PENDING", "OPEN", "FILLED", "CANCELLED"
  :filled_price,    # Float  — actual fill price
  :filled_at,       # Time
  keyword_init: true
)
```

---

## Strategy Base Contract

Every strategy MUST inherit from `Strategies::StrategyBase` and implement:

```ruby
module Strategies
  class StrategyBase
    # Called when a new candle closes. Return :buy, :sell, or :hold.
    def on_candle(candle, indicators:)
      raise NotImplementedError
    end

    # Called on every tick. Optional — default is no-op.
    def on_tick(tick); end

    # Returns the current signal without advancing state.
    # Must be idempotent.
    def signal
      raise NotImplementedError
    end

    # Returns a hash of strategy parameters with defaults.
    def parameters
      {}
    end
  end
end
```

---

## Indicator Base Contract

Every indicator MUST inherit from `Indicators::IndicatorBase`:

```ruby
module Indicators
  class IndicatorBase
    def update(candle)   # feed a new candle, update internal state
      raise NotImplementedError
    end

    def value            # return current computed value (Float or nil)
      raise NotImplementedError
    end

    def ready?           # true when enough data has been seen
      raise NotImplementedError
    end
  end
end
```

---

## Risk Engine Rules (non-negotiable)

The `Execution::RiskEngine` must enforce these checks before every order:

1. **Stop-loss present**: reject any order without a stop-loss price
2. **Position size**: `risk_amount = capital × risk_pct / 100`; derive lot count from this
3. **Max positions**: reject if open positions >= `config.max_positions`
4. **Daily loss limit**: reject all new orders if daily_loss >= `config.max_daily_loss_pct`
5. **Time check**: reject orders outside 09:20–15:20 IST window

---

## Backtest Constraints

- No look-ahead: indicators receive candles one at a time, in chronological order
- Slippage: add 0.05% to every fill price by default (configurable)
- Brokerage: 0.03% per trade for options (flat, configurable)
- Mark-to-market at every candle close for open positions

---

## Logging

Use `Utils::Logger` for all log output:

```ruby
Logger.info("order.placed", order_id: "123", symbol: "NIFTY", price: 150.0)
Logger.warn("risk.daily_limit_near", used_pct: 2.8)
Logger.error("api.request_failed", endpoint: "/orders", status: 500)
```

Output format: structured JSON, one object per line.

---

## Code Quality Gate — ruby_mastery

All code in `src/` must pass `ruby_mastery` analysis before a module is considered complete.

```bash
# Analyze the full src/ directory
bundle exec ruby_mastery analyze src/

# Apply automatic refactors (guard clauses, enumerable replacements, etc.)
bundle exec ruby_mastery refactor src/

# Generate a structured report
bundle exec ruby_mastery report src/ --format json

# Visualize inter-module architecture
bundle exec ruby_mastery architecture graph src/

# Get architecture health score (target: > 80)
bundle exec ruby_mastery architecture score src/

# Generate AI agent context summary
bundle exec ruby_mastery architect src/
```

Thresholds (configured in `ruby_mastery.yml`):
- Method length: ≤ 15 lines
- Class length: ≤ 250 lines
- Nesting depth: ≤ 2 levels
- Architecture: no cross-layer dependencies that bypass the EventBus

After completing each phase in `TASKS.md`, run `ruby_mastery analyze src/` and resolve
all violations before advancing to the next phase.

---

## Testing Standards

- Every public method must have an RSpec example
- Use `VCR` cassettes for all HTTP interactions
- Use `Timecop.freeze` for time-sensitive tests
- Backtest engine tests must use the fixture candles in `spec/fixtures/candles/`
