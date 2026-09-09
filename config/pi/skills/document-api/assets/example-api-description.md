# Local Transaction Details (v2)

## Get local transaction details.

**Path:** `POST /api/v2/user/transactions/local/details`

**Purpose:** Retrieve details for a local transaction (P2P or social insurance) by its id.

One endpoint serves multiple transaction kinds: the `data.type` discriminator selects which
`data.details` payload shape is returned.

Repeating a request with the same `requestId` and body returns the original response instead of
being processed again, so the call is safe to retry.

All monetary amounts are in UZS.

### Headers

| Header                   | Required | Description                           |
|--------------------------|----------|---------------------------------------|
| `x-api-key`              | yes      | Service API key.                      |
| `x-impersonated-user-id` | yes      | Keycloak user id the request acts as. |

### Request body

**Type:** `application/json`

| Parameter            | Type                               | Required | Validation | Description                                                    |
|----------------------|------------------------------------|----------|------------|----------------------------------------------------------------|
| `requestId`          | string                             | yes      | non-blank  | Client request id; echoed back in the response.                |
| `timestamp`          | long (epoch ms)                    | yes      | positive   | Request time in epoch milliseconds.                            |
| `data`               | object                             | yes      |            | Request payload.                                               |
| `data.transactionId` | uuid                               | yes      |            | Transaction id. For `SOCIAL_INSURANCE` this is the payment id. |
| `data.type`          | enum [ "P2P", "SOCIAL_INSURANCE" ] | yes      |            | Transaction type.                                              |

#### Request example

##### P2P

```json
{
  "requestId": "c843e704-6393-491d-bddf-71f49d81b8b9",
  "timestamp": 1767225600000,
  "data": {
    "transactionId": "32575138-85f8-489c-8389-29e5aa9fe4d3",
    "type": "P2P"
  }
}
```

##### Social insurance

```json
{
  "requestId": "c843e704-6393-491d-bddf-71f49d81b8b9",
  "timestamp": 1767225600000,
  "data": {
    "transactionId": "32575138-85f8-489c-8389-29e5aa9fe4d3",
    "type": "SOCIAL_INSURANCE"
  }
}
```

### Response body

**Type:** `application/json`

| Parameter      | Type                               | Optional | Description                                 |
|----------------|------------------------------------|----------|---------------------------------------------|
| `requestId`    | string                             | no       | Echoed from the request.                    |
| `success`      | boolean                            | no       | `true` on success.                          |
| `timestamp`    | long (epoch ms)                    | no       | Response time in epoch milliseconds.        |
| `data`         | object                             | no       | Result payload.                             |
| `data.type`    | enum [ "P2P", "SOCIAL_INSURANCE" ] | no       | Transaction kind, mirrors the request.      |
| `data.details` | object                             | no       | Type-specific payload (see variants below). |

Optional fields are `null` when absent.

#### type = P2P

| Parameter           | Type                                           | Optional | Description                                          |
|---------------------|------------------------------------------------|----------|-----------------------------------------------------|
| `transactionStatus` | enum [ "COMPLETED", "REVERSED" ]               | no       | Final transaction status.                           |
| `transactionType`   | enum [ "DEBIT", "CREDIT", "BETWEEN_MY_CARDS" ] | no       | Direction of the transfer.                          |
| `transactionId`     | uuid                                           | no       | Transaction id.                                     |
| `receiverName`      | string                                         | no       | Recipient name.                                     |
| `receiverMaskedPan` | string                                         | no       | Recipient masked PAN, e.g. `860000***1111`.         |
| `receiverBankName`  | string                                         | yes      | Recipient bank name; absent when it can't be resolved. |
| `receiverCardBrand` | string                                         | no       | Recipient card brand.                               |
| `senderName`        | string                                         | no       | Sender name.                                        |
| `senderMaskedPan`   | string                                         | no       | Sender masked PAN.                                  |
| `senderBankName`    | string                                         | yes      | Sender bank name; absent when it can't be resolved. |
| `senderCardBrand`   | string                                         | no       | Sender card brand.                                  |
| `time`              | datetime                                       | no       | Transaction time (ISO-8601, offset).                |
| `amount`            | decimal                                        | no       | Transfer amount.                                    |
| `commission`        | decimal                                        | yes      | Commission rate, percent; absent for `CREDIT` (incoming) transactions. |
| `commissionAmount`  | decimal                                        | yes      | Charged commission; absent for `CREDIT` (incoming) transactions. |
| `fiscalDocument`    | string                                         | yes      | OFD/fiscal receipt link; absent for `CREDIT` transactions and until the operation is fiscalized. |

#### type = SOCIAL_INSURANCE

| Parameter          | Type                             | Optional | Description                              |
|--------------------|----------------------------------|----------|------------------------------------------|
| `status`           | enum [ "COMPLETED", "REVERSED" ] | no       | Final payment status.                    |
| `paymentId`        | uuid                             | no       | Insurance payment id.                    |
| `payerMaskedPan`   | string                           | no       | Payer masked PAN, e.g. `123456***7890`.  |
| `pinfl`            | string                           | no       | PINFL the payment is made for.           |
| `month`            | integer                          | no       | Coverage month (1–12).                   |
| `year`             | integer                          | no       | Coverage year.                           |
| `amount`           | decimal                          | no       | Principal amount, commission excluded.   |
| `commission`       | decimal                          | yes      | Commission rate.                         |
| `commissionAmount` | decimal                          | no       | Charged commission.                      |
| `terminalId`       | string                           | yes      | Originating terminal id.                 |
| `time`             | datetime                         | yes      | Payment time (ISO-8601, UTC).            |
| `fiscalDocument`   | string                           | yes      | OFD/fiscal receipt link; absent until the payment is fiscalized. |

#### Response example

##### P2P

```json
{
  "requestId": "c843e704-6393-491d-bddf-71f49d81b8b9",
  "success": true,
  "timestamp": 1767225600000,
  "data": {
    "type": "P2P",
    "details": {
      "transactionStatus": "COMPLETED",
      "transactionType": "DEBIT",
      "transactionId": "32575138-85f8-489c-8389-29e5aa9fe4d3",
      "receiverName": "Recipient",
      "receiverMaskedPan": "860011***2222",
      "receiverBankName": "External Bank",
      "receiverCardBrand": "HUMO",
      "senderName": "Sender",
      "senderMaskedPan": "860000***1111",
      "senderBankName": "Baraka Bank",
      "senderCardBrand": "UZCARD",
      "time": "2026-01-01T00:00:00Z",
      "amount": 100000.00,
      "commission": 1.0,
      "commissionAmount": 1000.00,
      "fiscalDocument": null
    }
  }
}
```

##### Social insurance

```json
{
  "requestId": "c843e704-6393-491d-bddf-71f49d81b8b9",
  "success": true,
  "timestamp": 1767225600000,
  "data": {
    "type": "SOCIAL_INSURANCE",
    "details": {
      "status": "COMPLETED",
      "paymentId": "32575138-85f8-489c-8389-29e5aa9fe4d3",
      "payerMaskedPan": "123456***7890",
      "pinfl": "22222222222222",
      "month": 3,
      "year": 2025,
      "amount": 1450.00,
      "commission": 1.5,
      "commissionAmount": 50.00,
      "terminalId": "TERM-001",
      "time": "2026-01-01T00:00:00Z",
      "fiscalDocument": "https://ofd.soliq.uz/?t=SI01"
    }
  }
}
```

### Errors

On failure the response carries `success: false` and a numeric `errorCode`. The HTTP status reflects
the error class. Lookups are scoped to the impersonated user, so another user's transaction id
resolves as not found.

#### Error body

| Parameter   | Type            | Description                                                          |
|-------------|-----------------|---------------------------------------------------------------------|
| `success`   | boolean         | Always `false` for errors.                                          |
| `errorCode` | integer         | Stable application error code (see table below).                    |
| `message`   | string          | Human-readable, localized message.                                  |
| `error`     | object \| null  | Extra detail; for validation errors, a map of field name → message. |
| `requestId` | string          | Echoed from the request.                                            |
| `traceId`   | string          | Correlation id for log lookup.                                      |
| `timestamp` | long (epoch ms) | Response time in epoch milliseconds.                                |
| `path`      | string          | Request path.                                                       |
| `method`    | string          | Request method.                                                     |

| HTTP | errorCode | When                                                                                                   |
|------|-----------|--------------------------------------------------------------------------------------------------------|
| 400  | 1002      | Request body fails validation (blank `requestId`, non-positive `timestamp`, missing `data.transactionId`/`data.type`). `error` carries per-field messages. |
| 401  | 1006      | `x-api-key` header missing.                                                                             |
| 403  | 1007      | `x-api-key` header invalid.                                                                             |
| 406  | 1010      | `x-impersonated-user-id` header missing.                                                                |
| 404  | 11003     | P2P transaction not found for the user.                                                                 |
| 404  | 14004     | Social insurance payment not found for the user.                                                        |

#### Error example

```json
{
  "success": false,
  "errorCode": 14004,
  "message": "Social insurance payment not found",
  "error": null,
  "requestId": "c843e704-6393-491d-bddf-71f49d81b8b9",
  "traceId": "b1c2d3e4f5a6",
  "timestamp": 1767225600000,
  "path": "/api/v2/user/transactions/local/details",
  "method": "POST"
}
```
