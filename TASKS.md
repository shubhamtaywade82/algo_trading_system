# TASKS — Implementation Checklist (Production Options Backtesting)

## Phase 1 — Data Ingestion & API
- [x] **T01** — Implement `Api::DhanApiClient` with chunking logic.
- [x] **T02** — Implement `Api::TokenFetcher` for remote auth.
- [x] **T03** — Add data validation for timestamp continuity.

## Phase 2 — Simulation Engine
- [x] **T04** — Implement 7-state FSM in `Backtest::OptionsEngine`.
- [x] **T05** — Add STT (0.05%) and Margin (30%) calculation.
- [x] **T06** — Add Position Sizing (Max 2.5% risk) and SL (1.5%).
- [x] **T07** — Implement Time-based auto-exit at 15:15 IST.

## Phase 3 — Strategies & Greeks
- [x] **T08** — Implement `Strategies::TradingStrategies` collection.
- [x] **T09** — Create Node.js `greeks_calculator.js` bridge.
- [x] **T10** — Add IV spike and Volume momentum logic.

## Phase 4 — Orchestration & Reporting
- [x] **T11** — Implement `Backtest::Orchestrator` for multi-strike runs.
- [x] **T12** — Add JSON/CSV report generation.
- [x] **T13** — Create HTML dashboard template.

## Phase 7 — Final Production Release
- [x] **T23** — Implement `OptionsBacktestOrchestrator` for high-level backtest management.
- [x] **T24** — Consolidate strategies into `TradingStrategies` module with technical indicators (RSI, MACD, BB, ATR).
- [x] **T25** — Unified reporting (JSON, CSV, HTML) with metrics like Sharpe Ratio and Max Drawdown.
- [x] **T26** — Verified multi-strike simulation with synthetic volatile data.
- [x] **T27** — Cleaned up redundant legacy code from development phases.
