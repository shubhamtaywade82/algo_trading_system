# TASKS — Implementation Checklist

Complete tasks sequentially. Mark each task `[x]` when done.
After completing each task, update README.md with usage examples.

---

## Phase 1 — Core Infrastructure

- [ ] **T01** — Create `Gemfile` with all required dependencies
- [ ] **T02** — Create `src/utils/event_bus.rb` — pub/sub event bus
- [ ] **T03** — Create `src/utils/logger.rb` — structured JSON logger
- [ ] **T04** — Create `src/utils/config.rb` — YAML config loader
- [ ] **T05** — Create `src/utils/time_helpers.rb` — IST time utilities, market hours
- [ ] **T06** — Create `config/settings.yml` — default runtime config
- [ ] **T07** — Create `config/strategies.yml` — default strategy parameters

---

## Phase 2 — DhanHQ API Client

- [ ] **T08** — Create `src/api/dhan_client.rb` — REST client (all endpoints in DHAN_API_MAPPING.md)
- [ ] **T09** — Create `src/api/websocket_feed.rb` — WebSocket subscription and tick dispatch
- [ ] **T10** — Add rate limiting and retry logic to `dhan_client.rb`
- [ ] **T11** — Write RSpec tests for `dhan_client.rb` using VCR cassettes

---

## Phase 3 — Market Data

- [ ] **T12** — Create `src/market_data/candle_loader.rb` — loads historical + intraday candles
- [ ] **T13** — Create `src/market_data/tick_normalizer.rb` — normalizes raw WebSocket ticks
- [ ] **T14** — Write RSpec tests for candle loader using fixture data

---

## Phase 4 — Indicators

- [ ] **T15** — Create `src/indicators/indicator_base.rb` — abstract base class
- [ ] **T16** — Create `src/indicators/ema.rb` — EMA with configurable period
- [ ] **T17** — Create `src/indicators/rsi.rb` — RSI with configurable period (default 14)
- [ ] **T18** — Create `src/indicators/atr.rb` — ATR with configurable period (default 14)
- [ ] **T19** — Create `src/indicators/vix_reader.rb` — reads India VIX from market feed
- [ ] **T20** — Write RSpec tests for all indicators using known-output fixture data

---

## Phase 5 — Strategies

- [ ] **T21** — Create `src/strategies/strategy_base.rb` — abstract strategy base
- [ ] **T22** — Create `src/strategies/ema_crossover.rb` — EMA 9/21 crossover strategy
- [ ] **T23** — Create `src/strategies/orb_strategy.rb` — Opening Range Breakout (first 30 min)
- [ ] **T24** — Create `src/strategies/vix_spike_strategy.rb` — VIX spike reversal strategy
- [ ] **T25** — Write RSpec tests for each strategy using replayed candle sequences

---

## Phase 6 — Execution Engine

- [ ] **T26** — Create `src/execution/risk_engine.rb` — enforces all risk rules
- [ ] **T27** — Create `src/execution/order_manager.rb` — order creation, modification, cancellation
- [ ] **T28** — Create `src/execution/position_tracker.rb` — tracks open positions and P&L
- [ ] **T29** — Wire execution engine to EventBus (subscribe to strategy signals)
- [ ] **T30** — Write RSpec tests for risk engine (all edge cases)

---

## Phase 7 — Backtest Engine

- [ ] **T31** — Create `src/backtest/engine.rb` — candle replay loop
- [ ] **T32** — Create `src/backtest/pnl_calculator.rb` — trade-level P&L with slippage + brokerage
- [ ] **T33** — Create `src/backtest/report_generator.rb` — CSV and JSON report output
- [ ] **T34** — Create `examples/backtest_example.rb` — runnable backtest example
- [ ] **T35** — Write RSpec tests for backtest engine (no look-ahead assertion)

---

## Phase 8 — Integration & Live Runner

- [ ] **T36** — Create `src/live_runner.rb` — wires all modules for live trading session
- [ ] **T37** — Create `bin/trade` — CLI entry point for live session
- [ ] **T38** — Create `bin/backtest` — CLI entry point for running backtests
- [ ] **T39** — End-to-end integration test with paper trading mode

---

## Phase 9 — Polish

- [ ] **T40** — Add Rake tasks (`rake backtest`, `rake trade`, `rake spec`)
- [ ] **T41** — Update README.md with full usage instructions and examples
- [ ] **T42** — Add `.env.example` with required environment variable keys
- [ ] **T43** — Final code review: ensure no hardcoded secrets, all risk rules enforced
