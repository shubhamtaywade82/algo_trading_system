# DHAN API MAPPING (Production Backtesting)

This document maps the DhanHQ "Expired Options Data" API specification to the backtesting system.

## Endpoint: Rolling Option Chart Data
`POST https://api.dhan.co/v2/charts/rollingoption`

### Request Payload Specification
| Field | Type | Description | Values |
|-------|------|-------------|--------|
| `exchangeSegment` | String | Trading segment | `NSE_FNO`, `BSE_FNO` |
| `interval` | String | Candle interval in minutes | `1`, `5`, `15`, `25`, `60` |
| `securityId` | Number | Underlying Index ID | `13` (Nifty), `12` (BankNifty), `1` (Sensex) |
| `instrument` | String | Instrument type | `OPTIDX` |
| `expiryFlag` | String | Expiry type | `WEEK`, `MONTH` |
| `expiryCode` | Number | Rolling expiry index | `0` (Current), `1` (Next) |
| `strike` | String | Strike price relative to ATM | `ATM`, `ATM+100`, `ATM-100` |
| `drvOptionType` | String | Option type | `CALL`, `PUT` |
| `requiredData` | Array | Fields to return | `["open", "high", "low", "close", "iv", "oi", "volume", "spot"]` |
| `fromDate` | String | Start date (YYYY-MM-DD) | Max 30 days range per request |
| `toDate` | String | End date (YYYY-MM-DD) | |

### Response Schema
```json
{
  "status": "success",
  "data": {
    "ce": {
      "timestamp": [1704080700, ...],
      "open": [350.5, ...],
      "high": [365.0, ...],
      "low": [348.0, ...],
      "close": [362.2, ...],
      "iv": [15.2, ...],
      "oi": [120500, ...],
      "volume": [5000, ...],
      "spot": [21550.5, ...]
    }
  }
}
```

### Critical Implementation Rules
1. **Chunking**: Requests exceeding 30 days must be split into multiple calls.
2. **Rate Limiting**: Limit to 10 requests per second.
3. **STT**: Apply 0.05% on `Close * LotSize` for every sell transaction.
4. **Data Validation**: Verify `timestamp` array is strictly monotonic.
