# Backend Tasks — Shortzz / Believoo App

> **Status: IMPLEMENTED by backend** — see `SCRATCH_VAULT_API.md` for the live
> API contract. App-side wiring is done (sell, history sync, redeem, FCM
> deep-link, read-only dummy lives).

Flutter app-side work is done. The items below need backend/admin-panel work.
API base used by app: `{apiURL}` (configured in `.env` via `flutter_dotenv`).
Existing scratch/collect endpoints live under `v1/`.

---

## 1. Sell Panda endpoint (HIGH PRIORITY)

The app shows a "SELL FOR X TOKENS" button when `asset.canSell == true`,
but there is no endpoint to call. Currently shows "Coming Soon".

**Needed:** `POST v1/assets/sell`

```
Request:  { "user_asset_id": <int> }   // or asset_id — decide one contract
Response: {
  "success": true,
  "message": "Panda sold!",
  "tokens_credited": 500,
  "new_token_balance": 1250,
  "remaining_quantity": 0
}
```

Rules backend should enforce:
- Only `legendary` (Panda) assets can be sold.
- Respect `sell_status` / `price` fields already returned in `v1/user/vault`.
- Credit the user's wallet/token balance atomically.
- Rate-limit: one sell request per asset instance.

## 2. Reward claim history endpoint (MEDIUM)

History is currently stored only on the device (SharedPreferences) — it is
lost on reinstall and not visible across devices.

**Needed:** `GET v1/rewards/history`

```
Response: { "data": [
  {
    "reward_type": "asset" | "token",
    "token_amount": 25,
    "asset_id": 5,
    "asset": { "id": 5, "name": "Panda", "rarity": "legendary", ... },
    "quantity": 1,
    "claimed_at": "2026-09-22T10:30:00Z"
  }, ...
] }
```

App already parses `claimed_at` / `created_at` on `ClaimedReward`.
Once this endpoint exists, local history can be replaced/synced.
Also consider logging fusion + sell events into the same history feed.

## 3. Token → Wallet redeem endpoint (MEDIUM)

`token_to_cash_rate` exists in settings (`v1/rewards/config`) but users have
no way to convert vault tokens to wallet balance/cash.

**Needed:** `POST v1/wallet/redeem-tokens`

```
Request:  { "tokens": 1000 }
Response: { "success": true, "cash_credited": 10.0, "wallet_balance": 45.0 }
```

Decide: minimum redeem amount, KYC requirement, and whether tokens go to
the existing wallet or a payout request flow.

## 4. Dummy livestreams — move off the client (HIGH — security/perf)

Every user's app currently **writes and deletes dummy livestream docs
directly in Firestore** (`addDummyUsers` / `removeDummyLive` in the app).
Problems:
- Any client can write to the shared `liveStreams` collection (rules must be
  permissive = abuse risk).
- N devices racing to create/delete the same dummy docs.

**Needed:** move dummy-live lifecycle to a Cloud Function / cron:
- Scheduled job reads admin-configured dummy lives and upserts docs.
- Clients become read-only for `liveStreams`.

## 5. Push notification when scratch card is earned (LOW)

Admin-added pending cards (`v1/rewards/pending-cards`) are only discovered
when the app polls. Send an FCM notification when admin grants cards so
users come back to claim them.

## 6. Daily scratch limit — server-side enforcement (MEDIUM)

The app now persists the daily counter locally, but a determined user can
clear app data. `v1/rewards/claim` should enforce `daily_card_limit` and
return `429`-style error: `{ "success": false, "message": "Daily limit reached" }`.

## 7. Daily streak rewards (OPTIONAL)

App now tracks a local scratch streak (consecutive days). To make it
meaningful, backend can award a bonus card at milestones (e.g. day 3/7/30)
via `pending-cards`.

## 8. Localization strings (LOW)

Vault UI now uses translation keys (`LKey.*` via `.tr`). English fallback is
built-in. If you want other languages, add translations for the new keys in
the dynamic-translations payload (keys = the English strings in
`lib/languages/languages_keys.dart`, section "iYol Vault").

---

## Ops tasks (not API work, but blocking release)

1. **Package name alignment** — currently 3 different IDs:
   - Android `applicationId`: `com.vidmite.app`
   - Android Firebase config: `com.believoo.app`
   - iOS bundle / Firebase: `com.retrytech.bubbly`
   Pick ONE canonical package; regenerate `google-services.json` /
   `GoogleService-Info.plist` from Firebase console for it.
2. **Rotate leaked secrets** — keystore passwords, Google Maps key, AdMob
   App ID, Firebase keys (they were in git history).
3. **APK size** — release build is ~190MB because it bundles 3 ABIs.
   App-side fix applied (release drops x86_64). For distribution prefer:
   - Play Store: `flutter build appbundle` (per-device ~60-70MB)
   - Direct APK: `flutter build apk --release --split-per-abi`

---

## Endpoint summary (for quick reference)

| Endpoint | Method | Status |
|---|---|---|
| `v1/rewards/config` | GET | exists |
| `v1/rewards/claim` | POST | exists |
| `v1/user/vault` | GET | exists |
| `v1/assets/fuse` | POST | exists |
| `v1/assets/fusion/rules` | GET | exists (was hardcoded URL, now uses apiURL) |
| `v1/rewards/pending-cards` | GET | exists |
| `v1/assets/sell` | POST | ✅ done — app wired |
| `v1/rewards/history` | GET | ✅ done — app wired |
| `v1/wallet/redeem-tokens` | POST | ✅ done — app wired |
| Firestore `dummy_live_streams` | — | ✅ done — app reads only |
