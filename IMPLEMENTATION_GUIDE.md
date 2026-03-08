# 🛠 Implementation Guide

This guide explains how to set up and customize the production backtesting system.

## 🔑 Authentication
The system uses a remote auth server to fetch DhanHQ tokens.
1. Add `AUTH_SERVER_BEARER_TOKEN` to your `.env`.
2. Run `bin/setup_auth` to populate `DHAN_ACCESS_TOKEN`.

## 📈 Data Ingestion
Use `Api::DhanApiClient` to fetch historical options data.
```ruby
api = Api::DhanApiClient.new(access_token: ENV['DHAN_ACCESS_TOKEN'])
data = api.fetch_expired_options(
  underlying: :nifty,
  from_date: Date.parse('2024-01-01'),
  to_date: Date.parse('2024-01-31')
)
```

## ⚙️ Simulation Engine
The `Backtest::OptionsEngine` handles the deterministic FSM:
- `IDLE`: Watching for signals.
- `SIGNAL_DETECTED`: Validating risk rules.
- `POSITION_OPEN`: Monitoring stop-loss/target.
- `POSITION_CLOSED`: Realizing P&L.

### STT & Charges
STT is calculated at 0.05% on **Contract Value** (Price × Lot Size), not just the margin.

## 🧪 Greeks Calculation
The Node.js bridge calculates Black-Scholes Greeks:
```javascript
// greeks_calculator.js
const greeks = calculateGreeks(spot, strike, t, r, iv, type);
```

## 📊 Reporting
Results are saved in `backtest_results/`:
- `summary.json`: High-level metrics.
- `trades.csv`: Detailed trade log for Excel.
- `dashboard.html`: Interactive visualization.
