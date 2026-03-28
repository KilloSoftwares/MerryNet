# Maranet Zero — API Documentation

## Base URL
```
Production: https://api.maranet.app/api/v1
Bootstrap:  https://free.facebook.com.maranet.app
```

## Authentication

All authenticated endpoints require a Bearer token:
```
Authorization: Bearer <access_token>
```

### POST `/auth/login`
Request OTP code via SMS.

**Request:**
```json
{
  "phone": "254712345678"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "OTP sent successfully",
    "otpId": "uuid"
  }
}
```

### POST `/auth/verify`
Verify OTP and receive tokens.

**Request:**
```json
{
  "phone": "254712345678",
  "code": "123456"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJ...",
    "refreshToken": "eyJ...",
    "user": {
      "id": "uuid",
      "phone": "254712345678",
      "isNewUser": true
    }
  }
}
```

### POST `/auth/refresh`
Refresh access token.

**Request:**
```json
{
  "refreshToken": "eyJ..."
}
```

### GET `/auth/profile` 🔒
Get authenticated user profile.

---

## Plans

### GET `/subscriptions/plans`
Get available subscription plans (public).

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "hourly",
      "name": "Hourly Bundle",
      "description": "Unlimited internet for 1 hour",
      "price": 10,
      "currency": "KES",
      "durationHours": 1
    },
    {
      "id": "daily",
      "name": "Daily Bundle",
      "price": 30,
      "durationHours": 24
    },
    {
      "id": "weekly",
      "name": "Weekly Bundle",
      "price": 150,
      "durationHours": 168
    },
    {
      "id": "monthly",
      "name": "Monthly Bundle",
      "price": 500,
      "durationHours": 720
    }
  ]
}
```

---

## Payments

### POST `/payments/initiate` 🔒
Initiate M-Pesa STK Push payment.

**Request:**
```json
{
  "planId": "daily",
  "phone": "254712345678",
  "autoRenew": false
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "Payment initiated. Check your phone for the M-Pesa prompt.",
    "checkoutRequestId": "ws_CO_...",
    "merchantRequestId": "...",
    "planId": "daily",
    "amount": 30,
    "currency": "KES"
  }
}
```

### POST `/payments/mpesa/callback`
M-Pesa callback endpoint (called by Safaricom, no auth).

### GET `/payments/status/:checkoutRequestId` 🔒
Check payment status.

### GET `/payments/transactions` 🔒
Get transaction history (paginated).

---

## Subscriptions

### GET `/subscriptions/active` 🔒
Get user's current active subscription.

### GET `/subscriptions` 🔒
Get subscription history (paginated).

---

## Resellers

### POST `/resellers/register` 🔒
Register as a reseller.

**Request:**
```json
{
  "deviceId": "rpi-001-abc",
  "location": "Nairobi, Kenya",
  "capacity": 100,
  "compensationType": "COMMISSION",
  "platform": "rpi"
}
```

### GET `/resellers/dashboard` 🔒 (Reseller only)
Get reseller dashboard: node info + earnings.

### GET `/resellers/earnings` 🔒 (Reseller only)
Get detailed earnings breakdown.

### GET `/resellers/nodes` 🔒
Get list of online reseller nodes.

---

## Health

### GET `/health`
Service health check.

```json
{
  "success": true,
  "data": {
    "status": "healthy",
    "service": "maranet-api",
    "version": "1.0.0",
    "uptime": 86400
  }
}
```

---

## Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `BAD_REQUEST` | 400 | Invalid request body |
| `UNAUTHORIZED` | 401 | Missing or invalid token |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `CONFLICT` | 409 | Resource already exists |
| `TOO_MANY_REQUESTS` | 429 | Rate limit exceeded |
| `PAYMENT_REQUIRED` | 402 | Payment needed |
| `SERVICE_UNAVAILABLE` | 503 | External service down |
| `INTERNAL_ERROR` | 500 | Server error |

## Rate Limits

| Endpoint | Limit |
|----------|-------|
| `/auth/login` | 10/min |
| `/auth/verify` | 10/min |
| `/payments/initiate` | 5/5min |
| All other endpoints | 100/15min |
