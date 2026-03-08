# NSE Options Algorithmic Trading System

A modular, event-driven algorithmic trading system for buying NSE options
intraday, integrated with the DhanHQ brokerage API. Built for both live
trading and historical backtesting with full live/backtest parity.

---

## Architecture Overview

```
EventBus (pub/sub)
    │
    ├── MarketData  ←→  DhanHQ API (REST + WebSocket)
    ├── Indicators  ←   EMA, RSI, ATR, VIX
    ├── Strategies  ←   EMA Crossover, ORB, VIX Spike Reversal
    ├── Execution   →   RiskEngine → OrderManager → DhanHQ
    └── Backtest    →   CandleReplay → PnlCalculator → Reports
```

Full architecture: [`ARCHITECTURE.md`](ARCHITECTURE.md)

---

## Quick Start

### Prerequisites

- Ruby 3.2+
- DhanHQ account with API access enabled

### Setup

```bash
git clone <repo-url> algo_trading_system
cd algo_trading_system

# Install dependencies
bundle install

# Configure credentials
cp .env.example .env
# Edit .env with your DHAN_CLIENT_ID and DHAN_ACCESS_TOKEN
```

### Run a Backtest

```bash
bundle exec ruby examples/backtest_example.rb
```

Or with CLI (after Phase 8 is implemented):

```bash
bundle exec ruby bin/backtest --strategy ema_crossover \
  --symbol NIFTY --from 2024-01-01 --to 2024-03-31
```

### Live Paper Trading

```bash
TRADING_ENV=paper bundle exec ruby bin/trade --strategy ema_crossover
```

### Run Tests

```bash
bundle exec rspec
```

### Code Quality (ruby_mastery)

```bash
# Analyze src/ for violations
bundle exec ruby_mastery analyze src/

# Apply safe automatic refactors
bundle exec ruby_mastery refactor src/

# Architecture health score (target > 80)
bundle exec ruby_mastery architecture score src/

# Visualize module dependency graph
bundle exec ruby_mastery architecture graph src/

# Generate AI agent context summary
bundle exec ruby_mastery architect src/
```

---

## Repo Structure

```
algo_trading_system/
│
├── AGENT.md                  ← AI agent instructions (read first)
├── AI_CONTEXT.md             ← Quick reference for agents
├── SYSTEM_PROMPT.md          ← Trading system identity and mandate
├── ARCHITECTURE.md           ← System design and component diagram
├── IMPLEMENTATION_GUIDE.md   ← Coding standards and data structures
├── DHAN_API_MAPPING.md       ← Exact DhanHQ API payloads
├── DOMAIN_KNOWLEDGE.md       ← NSE market ground truth
├── STRATEGY_RULES.md         ← Entry/exit rules for all strategies
├── TASKS.md                  ← Ordered implementation checklist
├── bootstrap_prompt.txt      ← Single prompt to start an AI agent
│
├── config/
│   ├── settings.yml          ← Runtime config (capital, risk, symbols)
│   └── strategies.yml        ← Per-strategy parameter overrides
│
├── specs/
│   ├── api_contract.md       ← Inter-module interface contracts
│   └── strategy_rules.md     ← Formal strategy state machine specs
│
├── examples/
│   └── backtest_example.rb   ← Runnable backtest example
│
├── research/
│   └── options_strategy_notes.md  ← Strategy development notes
│
├── src/                      ← All generated code lives here
│   ├── api/                  ← DhanHQ API client
│   ├── market_data/          ← Candle loading, tick normalization
│   ├── indicators/           ← EMA, RSI, ATR, VIX
│   ├── strategies/           ← Pluggable strategy modules
│   ├── execution/            ← Order manager, risk engine
│   ├── backtest/             ← Backtest engine and reports
│   └── utils/                ← EventBus, logger, config, time helpers
│
├── spec/                     ← RSpec tests
│   └── fixtures/candles/     ← Candle fixture data for tests
│
├── bin/
│   ├── trade                 ← Live trading entry point
│   └── backtest              ← Backtest entry point
│
├── backtest_results/         ← Generated backtest CSV/JSON reports
├── Gemfile
├── .env.example
└── .gitignore
```

---

## Implemented Strategies

| Strategy           | Description                          | Timeframe | Status  |
|--------------------|--------------------------------------|-----------|---------|
| `ema_crossover`    | EMA 9/21 crossover with RSI filter   | 5m        | Planned |
| `orb_strategy`     | Opening Range Breakout (first 30min) | 5m        | Planned |
| `vix_spike_strategy`| VIX spike fear/reversal play        | 15m       | Planned |

---

## Risk Management

- **Per-trade risk**: 1% of capital (configurable)
- **Daily loss limit**: 3% — trading halts automatically
- **Max open positions**: 3 simultaneously
- **Stop-loss**: mandatory on every trade, enforced by `RiskEngine`
- **Exit-only window**: 15:20–15:30 IST — all positions auto-closed

---

## Using This Repo with AI Agents

This is a spec-driven repository designed for AI-assisted code generation.

**With Claude Code:**
```
Analyze this repository. Follow AGENT.md. Implement the project in src/.
```

**With Cursor:**
```
Read the entire repository. Follow AGENT.md instructions.
Then implement the trading system architecture starting with src/market_data and src/indicators.
```

**Bootstrap prompt** (paste `bootstrap_prompt.txt` to start any agent):
```bash
cat bootstrap_prompt.txt | pbcopy  # then paste into your AI tool
```

---

## Configuration

Edit `config/settings.yml` for runtime parameters:

```yaml
capital: 500000          # Total capital in INR
risk_per_trade_pct: 1.0  # Risk 1% per trade
max_daily_loss_pct: 3.0  # Halt at 3% daily loss
```

Edit `config/strategies.yml` for strategy-specific parameters.

---

## Environment Variables

| Variable            | Required | Description                    |
|---------------------|----------|--------------------------------|
| `DHAN_CLIENT_ID`    | Yes      | Your DhanHQ client ID          |
| `DHAN_ACCESS_TOKEN` | Yes      | Your DhanHQ API access token   |
| `TRADING_ENV`       | No       | `paper` (default) or `live`    |
| `LOG_LEVEL`         | No       | `debug`, `info`, `warn`, `error` |

---

## License

MIT
