# 📊 NSE/BSE Options Production Backtesting System

A professional-grade framework for intraday options buying/selling on Indian markets using DhanHQ API.

## 🚀 Overview
This system provides high-fidelity simulation of intraday CE/PE trades with strict risk management, minute-level bars, and real-time Greek calculations.

### Key Features
- **Data Ingestion**: Automatic chunking and fetching of historical expired options data from DhanHQ.
- **Risk Engine**: Enforces 2.5% max risk per trade, 1.5% mandatory stop-loss, and auto-exit at 3:15 PM IST.
- **Deterministic Simulation**: A 7-state finite state machine (FSM) for reliable trade execution.
- **Greeks Support**: Real-time Black-Scholes calculation via Node.js bridge.
- **Multi-Strike Processing**: Simultaneous backtesting across ATM, ITM, and OTM strikes.

## 🛠 Tech Stack
- **Backend**: Ruby (simulation engine), Node.js (Greeks calculation)
- **Data**: DhanHQ Expired Options API
- **Reporting**: JSON, CSV, and interactive HTML dashboards

## 📖 Documentation
- [Quick Reference](QUICK_REFERENCE.md)
- [Implementation Guide](IMPLEMENTATION_GUIDE.md)
- [Architecture Details](ARCHITECTURE.md)

## ⚡ Quick Start
1. Setup environment:
   ```bash
   cp .env.example .env
   # Add your DHAN_ACCESS_TOKEN and AUTH_SERVER_BEARER_TOKEN
   ```
2. Run example backtest:
   ```bash
   ruby examples/backtest_example.rb
   ```

## 📊 Sample Output
```
Total Trades:      24
Win Rate:          66.7%
Total P&L:         ₹45,320
Max Drawdown:      -2.15%
Sharpe Ratio:      1.28
```
