# DHAN API MAPPING

Complete mapping of DhanHQ API endpoints used by this system.
Do NOT invent fields or endpoints not listed here.

API Base URL: `https://api.dhan.co`
WebSocket URL: `wss://api-feed.dhan.co`

Authentication: `access-token` header on every request.

---

## 1. Place Order

**Endpoint**: `POST /orders`

**Request Body**:
```json
{
  "dhanClientId": "string",
  "correlationId": "string",         // optional — our internal order ref
  "transactionType": "BUY | SELL",
  "exchangeSegment": "NSE_FNO",
  "productType": "INTRADAY",
  "orderType": "MARKET | LIMIT | STOP_LOSS | STOP_LOSS_MARKET",
  "validity": "DAY",
  "tradingSymbol": "string",         // e.g. "NIFTY25JAN25C24000"
  "securityId": "string",            // DhanHQ security ID (required)
  "quantity": 50,                    // in units (lots × lot_size)
  "disclosedQuantity": 0,
  "price": 0.0,                      // 0 for MARKET orders
  "triggerPrice": 0.0,               // required for SL/SL-M orders
  "afterMarketOrder": false
}
```

**Response**:
```json
{
  "orderId": "string",
  "orderStatus": "TRANSIT"
}
```

---

## 2. Modify Order

**Endpoint**: `PUT /orders/{order-id}`

**Request Body**:
```json
{
  "dhanClientId": "string",
  "orderId": "string",
  "orderType": "LIMIT",
  "legName": "ENTRY_LEG",
  "quantity": 50,
  "price": 145.0,
  "disclosedQuantity": 0,
  "triggerPrice": 0.0,
  "validity": "DAY"
}
```

---

## 3. Cancel Order

**Endpoint**: `DELETE /orders/{order-id}`

**Response**:
```json
{
  "orderId": "string",
  "orderStatus": "CANCELLED"
}
```

---

## 4. Get Order List

**Endpoint**: `GET /orders`

**Response** (array of orders):
```json
[
  {
    "dhanClientId": "string",
    "orderId": "string",
    "correlationId": "string",
    "orderStatus": "TRADED | PENDING | CANCELLED | REJECTED | TRANSIT",
    "transactionType": "BUY | SELL",
    "exchangeSegment": "NSE_FNO",
    "productType": "INTRADAY",
    "orderType": "MARKET",
    "tradingSymbol": "string",
    "securityId": "string",
    "quantity": 50,
    "price": 0.0,
    "triggerPrice": 0.0,
    "filledQty": 50,
    "avgTradedPrice": 148.75,
    "createTime": "2024-01-15 09:32:00",
    "updateTime": "2024-01-15 09:32:05",
    "exchangeTime": "2024-01-15 09:32:04",
    "drvExpiryDate": "2024-01-25",
    "drvOptionType": "CALL | PUT",
    "drvStrikePrice": 24000.0
  }
]
```

---

## 5. Get Positions

**Endpoint**: `GET /positions`

**Response** (array):
```json
[
  {
    "dhanClientId": "string",
    "tradingSymbol": "string",
    "securityId": "string",
    "positionType": "LONG | SHORT",
    "exchangeSegment": "NSE_FNO",
    "productType": "INTRADAY",
    "buyAvg": 148.75,
    "buyQty": 50,
    "sellAvg": 0.0,
    "sellQty": 0,
    "netQty": 50,
    "realizedProfit": 0.0,
    "unrealizedProfit": 375.0,
    "rbiReferenceRate": 0.0,
    "multiplier": 1,
    "carryForwardBuyQty": 0,
    "carryForwardSellQty": 0,
    "carryForwardBuyValue": 0.0,
    "carryForwardSellValue": 0.0,
    "dayBuyQty": 50,
    "daySellQty": 0,
    "dayBuyValue": 7437.5,
    "daySellValue": 0.0
  }
]
```

---

## 6. Get Holdings

**Endpoint**: `GET /holdings`

---

## 7. Get Fund Limits (Capital Available)

**Endpoint**: `GET /fundlimit`

**Response**:
```json
{
  "dhanClientId": "string",
  "availabelBalance": 485000.0,
  "sodLimit": 500000.0,
  "collateralAmount": 0.0,
  "receiveableAmount": 0.0,
  "utilizedAmount": 15000.0,
  "blockedPayoutAmount": 0.0,
  "withdrawableBalance": 485000.0
}
```

---

## 8. Historical Candle Data

**Endpoint**: `POST /charts/historical`

**Request Body**:
```json
{
  "securityId": "string",
  "exchangeSegment": "NSE_EQ | NSE_FNO | IDX_I",
  "instrument": "INDEX | EQUITY | FUTIDX | OPTIDX",
  "expiryCode": 0,
  "fromDate": "2024-01-01",
  "toDate": "2024-01-31"
}
```

**Response**:
```json
{
  "open":   [21500.0, 21550.0],
  "high":   [21600.0, 21620.0],
  "low":    [21480.0, 21510.0],
  "close":  [21580.0, 21600.0],
  "volume": [1200000, 980000],
  "timestamp": [1704172200, 1704258600]
}
```

---

## 9. Intraday Candle Data

**Endpoint**: `POST /charts/intraday`

**Request Body**:
```json
{
  "securityId": "string",
  "exchangeSegment": "NSE_EQ",
  "instrument": "INDEX",
  "interval": "1 | 5 | 15 | 25 | 60",
  "fromDate": "2024-01-15",
  "toDate": "2024-01-15"
}
```

---

## 10. Market Quote (LTP)

**Endpoint**: `POST /marketfeed/ltp`

**Request Body**:
```json
{
  "NSE_FNO": ["securityId1", "securityId2"]
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "NSE_FNO": {
      "securityId1": { "last_price": 148.75 }
    }
  }
}
```

---

## 11. Option Chain

**Endpoint**: `GET /optionchain`

**Query Params**: `UnderlyingScrip`, `UnderlyingSeg`, `Expiry`

**Response**: Full option chain with bid/ask, OI, IV for each strike.

---

## 12. WebSocket Feed (Live Data)

**Connection**: `wss://api-feed.dhan.co`

**Subscription Message**:
```json
{
  "RequestCode": 15,
  "InstrumentCount": 1,
  "InstrumentList": [
    {
      "ExchangeSegment": "NSE_FNO",
      "SecurityId": "string"
    }
  ]
}
```

**Tick Message Received**:
```json
{
  "type": "ticker",
  "exchangeSegment": "NSE_FNO",
  "securityId": "string",
  "LTP": 148.75,
  "LTQ": 50,
  "ATP": 147.20,
  "volume": 125000,
  "OI": 980000,
  "timestamp": 1704172245
}
```

---

## Security ID Mapping (Key Symbols)

| Symbol      | Segment | Security ID |
|-------------|---------|-------------|
| NIFTY 50    | IDX_I   | 13          |
| BANKNIFTY   | IDX_I   | 25          |
| FINNIFTY    | IDX_I   | 27          |

Option security IDs must be looked up dynamically from the option chain API.

---

## Rate Limits

- REST API: 10 requests/second per client ID
- WebSocket: 1 connection per client ID; max 100 instrument subscriptions
- Historical data: 20 requests/minute

Implement exponential backoff on HTTP 429 responses.
