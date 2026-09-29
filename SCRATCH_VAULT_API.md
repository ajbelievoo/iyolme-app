# iYol Vault / Scratch & Collect — Backend API Contract

Base: `https://iyolme.com/api/` (same backend: `https://admin.iyolme.com/api/`)
Auth: header `authtoken: <user auth token>` on all endpoints below.

Envelope follows existing style — flat keys, `status: true/false` + `message`.

---

## POST `v1/assets/sell` — Sell collected asset for tokens

Request (JSON):
```json
{ "asset_id": 1, "quantity": 1 }
```
- `quantity` optional, default 1. (`user_asset_id` from the spec is not used — contract is `asset_id`.)
- Sell gate (must match vault `can_sell`): asset `rarity = legendary` (Panda) AND `is_sell_active = 1` AND (`sell_active_date` null OR already passed). Controlled from admin → Scratch & Collect → Character edit.
- Sell credits **tokens** (`coin_wallet`), amount = `asset.price × quantity`. Cash conversion happens via `redeem-tokens`.
- Atomic: transaction + row locks; a second call on the same units sees decremented quantity.

Success (both `status` and `success` keys are returned; spec aliases included):
```json
{
  "status": true,
  "success": true,
  "message": "Asset sold successfully",
  "asset_id": 1,
  "asset_name": "Panda",
  "quantity_sold": 1,
  "unit_price": 500,
  "tokens_earned": 500,
  "tokens_credited": 500,
  "remaining_quantity": 3,
  "new_token_balance": 1532
}
```
Errors: `This asset is not available for sale yet` | `Asset price is not set` | `Insufficient asset quantity` | `Unauthorized`.

---

## GET `v1/rewards/history` — Reward/claim history sync

Query params (all optional):
- `page` (default 1), `limit` (default 20, max 100)
- `type` — filter: `claim` | `sell` | `fusion` | `redeem`
- `after_id` — incremental sync: returns only rows with `id > after_id` (still ordered newest-first)

Response (`data` and `history` keys both contain the same array — use either):
```json
{
  "status": true,
  "success": true,
  "history": [
    {
      "id": 3,
      "type": "sell",
      "reward_type": "asset",
      "token_amount": 500,
      "cash_amount": null,
      "asset_id": 1,
      "asset_name": "Panda",
      "asset": { "id": 1, "name": "Panda", "rarity": "legendary", "..." : "..." },
      "quantity": 1,
      "description": "Sold 1 x Panda",
      "created_at": "2026-09-23T07:45:00.000000Z",
      "claimed_at": "2026-09-23T07:45:00.000000Z"
    }
  ],
  "data": [ "same array as history" ],
  "pagination": { "current_page": 1, "per_page": 20, "total": 42, "last_page": 3 }
}
```
History is logged for: scratch claims (`claim`), asset sells (`sell`), fusion wins (`fusion`), token redemptions (`redeem`).

---

## POST `v1/wallet/redeem-tokens` — Tokens → cash

Request:
```json
{ "tokens": 1000 }
```
- `cash_credited = tokens × token_to_cash_rate` (admin → Scratch & Collect settings; current `0.01` → 1000 tokens = $10).
- Deducts `coin_wallet`, credits `money_wallet`. Ledger rows written to `tbl_conversion_transactions` + `tbl_wallet_transactions`.

Success (`wallet_balance` alias of `new_wallet_balance` per spec):
```json
{
  "status": true,
  "success": true,
  "message": "Tokens redeemed successfully",
  "tokens_redeemed": 1000,
  "cash_credited": 10.0,
  "rate": 0.01,
  "new_token_balance": 82,
  "new_wallet_balance": 10.0,
  "wallet_balance": 10.0
}
```
Errors: `Insufficient token balance` (with `token_balance`) | `Redemption rate is not configured`.

---

## Daily claim limit (server-side)

`daily_card_limit` is now enforced by counting **every** claim in `tbl_reward_history` (`type=claim`) for the current server date — token wins AND asset wins both count (previously only new asset rows counted, so the limit was bypassable). Claims run inside a transaction with a user row lock — concurrent requests cannot exceed the limit.

Limit-hit response (unchanged message + extra fields):
```json
{ "status": false, "message": "Daily limit reached. Come back tomorrow!", "daily_card_limit": 5, "claims_today": 5 }
```

## Admin pending cards + FCM

Admin panel → Scratch & Collect → "Pending Scratch Cards": send a card to one user (User ID) or all users (empty = broadcast). On create, FCM push is sent automatically:
- single user → device token push
- all users → topic broadcast `iyolme_android` / `iyolme_ios`

Push `data` payload: `{ "type": "scratch_pending_card", "card_id": "<id>" }` — app can deep-link to the vault screen on tap.

## Dummy livestreams (Firestore)

Dummy lives are now written server-side only: cron `dummy-lives:sync` (every 5 min) pushes `status=1` rows from `dummy_live_videos` to Firestore collection **`dummy_live_streams`** (doc id = table id) and deletes stale docs. Doc fields: `title`, `link`, `status`, `user_id`, `username`, `fullname`, `profile_photo`, `is_verify`, `updated_at`.

**App change needed:** remove all client-side Firestore writes for dummy lives — read `dummy_live_streams` (or use `dummyLives` already returned in the app settings payload). Firestore rules should make this collection read-only for clients.

---

## Ops notes

- `tbl_billing_settings.google_package_name` → `com.iyolme.app` (confirm this matches the new applicationId; tell me if different).
- Secrets pending rotation: `googleCredentials.json` service account, DB passwords in `.env`, Cloudflare R2 keys — rotate in their consoles and update `.env` (values were exposed in earlier chats).
