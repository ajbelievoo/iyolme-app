# Ads & Boost System + RBAC Documentation

## 1. Ads vs Boost Separation (Crucial)

**Strict Separation of Concerns:**
- **Ads (Campaigns/Platform Ads):** Strictly **MONEY** based ($).
  - Managed via `UserAdController` and `AdMonetizationController`.
  - Uses Wallet Balance (Real Money).
- **Boosts (Post Promotion):** Strictly **COIN** based (Virtual Currency).
  - Managed via `PostsController` (e.g., `createPostBoost`).
  - Uses Coin Wallet.

---

## 2. Role-Based Access Control (RBAC)

### Roles
1. **user**: Standard app user.
2. **moderator**: Has limited admin capabilities based on assigned permissions.
3. **admin**: Superuser, has access to ALL features (bypasses permission checks).

### Policy Update (Campaigns/Wallet/Analytics)
- Campaigns, Wallet, and Analytics user endpoints no longer require feature gates.
- All user-facing Ads/Campaigns operations are accessible to normal users with `authorizeUser` only.
- Admin module remains separate; admin-only endpoints still use feature gates.

### User Profile Response Contract (`/api/user/fetchUserDetails`)
When fetching a user's profile (especially "me"), the response now includes:
```json
{
  "status": true,
  "message": "user details fetched successfully",
  "data": {
    "id": 123,
    "role": "moderator", // or "admin", "user"
    "permissions": [
      "campaigns_view",
      "user_freeze",
      "analytics_access",
      "user_edit",             // New: Edit user details (password etc)
      "wallet_manage_balance"  // New: Add Coins/USD
    ],
    // ... other fields
  }
}
```
**Note:**
- `permissions` is always an array of strings.
- If `role` is `admin`, `permissions` will contain ALL available feature keys.
- **Permissions are merged:** Result is `Role Permissions` + `User Specific Custom Permissions`.
- Flutter App should use these to gate UI features.

### Middleware
- **`checkFeature:feature_key`**: Applied to sensitive routes.
  - Returns `403 Forbidden` if user lacks the feature.
  - Admins bypass this check automatically.

---

## 3. Admin Permission APIs (RBAC Management)

Base URL: `/api/admin/permissions`
Middleware: `authorizeUser`, `checkFeature:admin_dashboard_access`

### 3.1 Get All System Features
- **Endpoint:** `GET /features`
- **Response:** List of all available feature keys and descriptions.

### 3.2 Get Role Permissions
- **Endpoint:** `POST /role/permissions`
- **Body:** `{ "role": "moderator" }`
- **Response:** List of feature keys assigned to the role.

### 3.3 Update Role Permissions
- **Endpoint:** `POST /role/update-permissions`
- **Body:**
  ```json
  {
    "role": "moderator",
    "features": ["campaigns_view", "user_freeze", "wallet_manage"]
  }
  ```

### 3.4 Assign Role to User
- **Endpoint:** `POST /user/assign-role`
- **Body:** `{ "userId": 123, "role": "moderator" }`
- **Note:** Also syncs `is_moderator` flag for backward compatibility.

### 3.5 User-Specific Custom Permissions
**Custom Moderator Support:** Assign extra permissions to specific users (overrides role defaults).

- **Get User Permissions:** `POST /user/permissions`
  - Body: `{ "userId": 123 }`
  - Response: `{ "permissions": ["..."], "role": "moderator" }`

- **Update User Permissions:** `POST /user/update-permissions`
  - Body:
    ```json
    {
      "userId": 123,
      "features": ["wallet_manage_balance", "user_edit"] // List of custom enabled features
    }
    ```

---

## 4. User Management Updates (Admin Panel)

### 4.1 User Editing
- **Password Management:** Admins can now set a new password for any user directly from the User Details > Edit page.
- **Verification Status:** Admins can toggle the "Verified" badge for ANY user (removed previous dummy-user restriction).

### 4.2 Wallet Management
- **Add Money (USD):** New modal in User Details > Wallet to add funds to user's Money Wallet.
- **Add Tokens (Coins):** Existing functionality to add Iyol Tokens (Coins).
- **Transaction History:** A new "Transactions" tab in the User Details page shows a unified history of both Coin and USD transactions performed by admins or system events.
- **Permissions:** These actions are gated by the `wallet_manage_balance` permission.

### 4.3 New Feature Keys
Ensure these keys are handled in the Flutter app if you are building custom admin interfaces there:
- `user_edit`: Ability to edit user profile details.
- `wallet_manage_balance`: Ability to add coins/money to users.

---

## 5. Flutter In-App Purchase (IAP) & Refund Abuse Prevention

This section details the Product IDs and the **mandatory** integration flow to prevent refund abuse for both Ads Wallet and Coin Purchases.

### 5.1 Product IDs

#### Ads Wallet Packages (Add Money to Ads Wallet)
These are the new packages created for adding funds to the Advertiser Wallet.

| Package Name | Price (USD) | Play Store Product ID | App Store Product ID |
| :--- | :--- | :--- | :--- |
| Starter Pack | $1.00 | `ad_wallet_1` | `ad_wallet_1` |
| Basic Pack | $10.00 | `ad_wallet_10` | `ad_wallet_10` |
| Standard Pack | $25.00 | `ad_wallet_25` | `ad_wallet_25` |
| Pro Pack | $50.00 | `ad_wallet_50` | `ad_wallet_50` |
| Elite Pack | $100.00 | `ad_wallet_100` | `ad_wallet_100` |

#### Coin / Iyol Token Packages (Buy Coins)
These are the existing packages for buying coins.

| Package Name | Price | Play Store Product ID | App Store Product ID |
| :--- | :--- | :--- | :--- |
| Coin Plan 1 | 1 | `android.hito1purchased` | `android.hito1purchased` |
| Coin Plan 2 | 1 | `android.hito2purchased` | `android.hito2purchased` |

### 5.2 Secure Purchase Flow (MANDATORY)

To prevent refund abuse and fraud, you **MUST** follow this exact flow. The backend will **NOT** credit the wallet if this flow is not followed.

#### Step 1: Initiate Purchase in App
- User clicks "Buy".
- App initiates purchase via Google Play / App Store.
- **Wait for success callback** from the store.

#### Step 2: Send Purchase Data to Backend
Once the purchase is successful on the device, **DO NOT** acknowledge it immediately in the app. Instead, send the receipt data to the backend for verification.

**Required Payload for Backend Verification:**
```json
{
  "purchase_token": "token_string_from_google_response",
  "order_id": "GPA.1234-5678-9012-34567",
  "product_id": "ad_wallet_10",
  "amount": "10.00",
  "currency": "USD",
  "gateway": "google_play", 
  "package_id": "2" // ID from our database (tbl_ad_wallet_packages / tbl_coin_plan)
}
```

#### Step 3: Backend Verification & Credit
1. The Backend receives the request.
2. It calls Google/Apple API to **verify** the `purchase_token` and `order_id`.
3. If valid, the Backend **ACKNOWLEDGES** (or Consumes) the purchase via the Google Play API.
  - *Note: If the backend fails to acknowledge, Google will auto-refund the user after 3 days.*
4. **Only after successful acknowledgment**, the Backend adds money/coins to the user's wallet.
5. The Backend marks the transaction as `completed` and returns a success response to the app.

#### Step 4: Handle Response in App
- If Backend returns **Success**: The purchase is complete. You can update the UI.
- If Backend returns **Error**: Display the error. Do not grant coins/credits locally.

### 5.3 API Endpoints

#### A. Ads Wallet Top-up
**Endpoint:** `POST /api/topUpAdsWallet`
**Body:**
```json
{
  "user_id": 123,
  "amount": "10.00",
  "transaction_id": "GPA.1234...", // Send Order ID here
  "purchase_token": "token_string...", // MANDATORY
  "status": "completed", // Initial status
  "payment_gateway": "google_play", // or "app_store"
  "package_id": 2 // Optional but recommended
}
```

#### B. Buy Coins
**Endpoint:** `POST /api/buyCoins`
**Body:**
```json
{
  "user_id": 123,
  "coin_plan_id": 8, // ID from tbl_coin_plan
  "transaction_id": "GPA.1234...",
  "purchase_token": "token_string...", // MANDATORY
  "gateway": "google_play"
}
```

### 5.4 Refund Abuse Rules
- **No Refund After Credit**: Once the wallet is credited, the system marks the purchase as "consumed".
- **Refund Webhooks**: If a user forces a refund via Google, the backend will receive a webhook and automatically:
  - Deduct the balance from the wallet.
  - Or freeze the account if balance is insufficient.

---

## 6. Ads Fetch & Tracking (Client Integration)

### 6.1 Fetch Ads
- **Endpoint:** `POST /api/ads/fetch`
- **Headers:** `authtoken: <user_token>`
- **Body:**
  ```json
  {
    "placement": "feed", // feed | story | reel | reels
    "country_code": "IN" // optional, ISO code
  }
  ```
- **Notes:**
  - `reels` is accepted and internally normalized to `reel`.
  - Returns both Platform Ads and approved User Ads when available.
  - If `test_mode` is enabled in Ad Settings and no ads match, backend returns recent active platform ads as fallback.
- **Response:**
  ```json
  {
    "status": true,
    "data": [
      {
        "id": 12,
        "source": "platform", // or "user"
        "type": "image",      // image | video | reel
        "url": "https://.../uploads/ads/xyz.jpg",
        "title": "Sponsored",
        "description": "Ad description",
        "cta_text": "Learn More",
        "cta_url": "https://destination.example",
        "click_url": "https://destination.example"
      }
    ]
  }
  ```

### 6.2 Track Ad Events
- **Endpoint:** `POST /api/ads/trackAdEvent`
- **Headers:** `authtoken: <user_token>`
- **Body:**
  ```json
  {
    "ad_id": 12,
    "placement": "feed",     // optional
    "event": "impression",   // impression | click
    "action": "cta_click",   // optional context
    "metadata_json": "{}"    // optional JSON string
  }
  ```
- **Response:**
  ```json
  { "status": true }
  ```
- Legacy alternative exists: `POST /api/ads/track` (maps to user earnings). Prefer `trackAdEvent` for platform ads analytics.

---

## 7. Intelligent Boost System (Instagram-style)

The Boost system now uses a dynamic scoring engine instead of simple interval injection.

### 7.1 Boost Logic
- **Score Formula:** `(Remaining Budget * 0.5) + (Engagement Rate * 0.3) + (Recency * 0.2)`
- **Scaling:** High CTR (>5%) boosts score by 20%.
- **Budget Pacing:** Distributes impressions evenly over the duration.
- **Organic Blend:** Boosted posts are mixed into the feed naturally based on score, not fixed intervals.
- **Targeting:** Supports Country, Age, and Gender filtering.

### 7.2 Create Boost Request
**Endpoint:** `POST /api/boost/createBoostRequest`
**Body:**
```json
{
  "post_id": 123, // OR use "postId": 123 (both accepted)
  "budget_coins": 1000,
  "duration_hours": 24,
  "placement": "feed", // feed | reel | reels | story | profile | explore
  "status": "draft",   // Optional: on 'draft' no deduction/activation
  "target_country": "US,IN,UK", // Optional: Comma separated ISO codes
  "target_age_min": 18,         // Optional: Min 13
  "target_age_max": 35,         // Optional
  "target_gender": 0            // Optional: 0=Male, 1=Female, 2=Other
}
```
**Response:**
```json
{ "status": true, "message": "ok", "data": { "id": 456 } }
```
**Notes:**
- `post_id/postId` must exist and belong to the requesting user, else: `400 { "status": false, "message": "invalid post_id" }`
- `placement`: `reels` normalized to `reel`; `profile` and `explore` stored with feed fallback for estimates.
- `status='draft'`: skips coin deduction and activation.

### 7.3 Fetch Boosted Posts
**Endpoint:** `POST /api/boost/fetchBoostedPosts`
- Returns boosts sorted by dynamic score.
- Applies targeting filters automatically based on user profile.

### 7.4 Fetch My Boost Requests
**Endpoints (aliases):**
- `GET /api/boost/fetchMyBoostRequests`
- `GET /api/boost/myRequests`
- `GET /api/boost/fetchMyRequests`
- `GET /api/user/boost/myRequests`
  **Response List Item:**
```json
{
  "id": 456,
  "post_id": 123,
  "status": "Pending",   // or Active, Completed, Draft, etc.
  "budget": 1000,
  "spend": 120,
  "created_at": "2025-01-01 10:00:00",
  "metadata": {
    "placement": "feed",
    "target_country": "US",
    "target_age_min": 18,
    "target_age_max": 35,
    "target_gender": 0
  }
}
```

### 7.5 Boost Estimate
**Endpoint:** `GET /api/boost/estimate`
**Query:**
```json
{
  "budget_coins": 100,
  "duration_hours": 24,
  "placement": "profile"
}
```
**Response:**
```json
{
  "status": true,
  "data": {
    "estimatedReachMin": 120,
    "estimatedReachMax": 300,
    "estimatedImpressionsMin": 200,
    "estimatedImpressionsMax": 600
  }
}
```
**Notes:**
- Non-zero estimates are guaranteed; `profile` and `explore` use server-side feed fallback if needed.

---

## 8. Advanced Auction & Intelligence System

The backend now runs a unified auction engine for Feed Ads (Boosts + Platform Ads + User Ads) with advanced targeting and pacing.

### 8.1 Unified Auction Engine
- **Logic:** `AdRank = Bid × CTR × QualityScore × Relevance × PacingMultiplier`
- **Bid:** Boosts = 1 Coin (High Priority); Ads = CPM based (e.g. $5 CPM = 0.5 Coins).
- **CTR:** Historical Click-Through Rate.
- **Quality:** High CTR (>5%) gets 1.2x boost; New ads (<100 imps) get 1.2x learning boost.
- **Relevance (Personalization):**
  - Matches User's recent interest tags (from Liked posts) with Ad tags/category.
  - 1 Match = 1.2x, 2 Matches = 1.4x, 3+ Matches = 1.5x.
- **Smart Pacing (AI-Lite):**
  - High Traffic Hours (18:00 - 22:00): Budget Pushed (1.2x multiplier).
  - Low Traffic Hours (02:00 - 06:00): Budget Throttled (0.8x multiplier).

### 8.2 Dashboard Intelligence API
**Endpoint:** `POST /api/admin/monetization/dashboard-intelligence`
**Headers:** `authtoken: <admin_token>`
**Body:** `{ "country": "US" }` (Optional)
**Response:**
```json
{
  "status": true,
  "data": {
    "suggested_bid": 6.50, // Recommended CPM based on competition
    "currency": "USD",
    "competition_level": "high",
    "warnings": [
      {
        "type": "low_ctr",
        "ad_id": 101,
        "message": "Ad 'Summer Sale' has low CTR (0.8%). Consider updating creative."
      }
    ]
  }
}
```

### 8.3 Fraud & Quality Controls
- **Frequency Cap:** Boosts (3/day), Ads (5/day) per user.
- **Ad Fatigue:** Auto-skip if Impressions > 500 AND CTR < 1.5%.
- **Deduplication:** 60s Impression window, 30m Click window.
- **Fraud Rate Limit:** >20 impressions in 5 mins from single IP blocked.

---

## 9. Ads Monetization System (Backend)

### 9.1 Overview
- Ads System creators ko direct Money ($) earn karwata hai (views/clicks/actions ke basis par).
- Boost System coins-based distribution hai; ads ke earnings se alag.
- Hybrid earning model: View (CPM), Click (CPC), Action (CPA).

### 9.1.a Campaigns (User Ads) API Summary
- **Create:** `POST /api/campaign/create`
  - Body includes: `title`, `placement`, `audienceCountry`, `dailyBudget`, `totalBudget`, optional `postId` or `mediaUrl`, optional `status='draft'`
  - Validation: if `postId` provided, it must belong to the requester (else `400 invalid post_id`)
  - Response: `{ "status": true, "message": "ok", "data": { "campaignId": <id> } }`
- **List:** `GET /api/campaign/list`
  - Items include: `id`, `title`, `mediaUrl`, `status`, `statusCode`, `placement`, `budget`, `dailyBudget`, `spend`, `impressions`, `clicks`, `createdAt`
- **Analytics Overall:** `GET /api/campaign/analytics/overall?range=7d|30d`
- **Campaign Analytics:** `GET /api/campaign/analytics/{campaignId}`
- **Wallet Summary:** `GET /api/wallet`
- **Wallet Top-up:** `POST /api/wallet/top-up` (alias `POST /api/topUpAdsWallet`)
- All above user endpoints require `authorizeUser` only; no feature gates.

### 9.2 Log Ad Event (Creator Earnings)
- **Endpoint:** `POST /api/user/logAdEvent`
- **Headers:** `authtoken: <user_token>`
- **Params:**
  - `ad_id` (int, required)
  - `event_type` (string, required: `view` | `click` | `action`)
  - `content_user_id` (int, required; jis creator ki content par ad dikhaya)
  - `viewer_id` (int, optional)
  - `placement` (string, optional: `feed` | `story` | `reel` ...)
  - `country` (string, optional; auto-detect agar missing)
- **Response (Success):**
```json
{ "status": true, "message": "ad event logged successfully" }
```

### 9.3 User Earnings Dashboard
- **Endpoint:** `GET /api/user/getEarningsDashboard?user_id=<id>`
- **Headers:** `authtoken: <user_token>`
- **Response (Success):** Returns Money Wallet balance, today stats, totals, recent transactions.

### 9.4 Admin Monetization APIs
- Get Rates: `GET /api/admin/monetization/rates`
- Update Rate: `POST /api/admin/monetization/rates`
```json
{ "country_code":"US","cpm":5.00,"cpc":0.50,"cpa":2.00,"creator_share_percent":70,"platform_share_percent":30 }
```
- Update Settings (Fraud/Limits): `POST /api/admin/monetization/settings`
```json
{ "daily_earning_limit":100.00,"fraud_click_limit":5,"fraud_impression_limit":20,"fraud_action_limit":1,"fraud_window_minutes":10 }
```
- Update User Multiplier: `POST /api/admin/monetization/user-multiplier`
```json
{ "user_id":123, "multiplier":1.5 }
```
- Admin Overview: `GET /api/admin/monetization/overview`

### 9.5 Advertiser Budget Flow
- Creation: Budget amount ($) advertiser wallet se upfront deduct hota; status `pending` (0).
- Approval: Active (1) hone par ad run hota.
- Consumption: Event cost (CPM/CPC/CPA) `spent_amount` me add hota; creator ko share milta.
- Auto-Pause: `spent_amount >= budget_amount` hone par status `completed/paused` (3).
- Rejection: Remaining budget refund to advertiser wallet.

---

## 10. Earnings & History API (Withdrawal Section)

### 10.1 Earnings Summary
- **Endpoint:** `GET /api/wallet/earnings/summary`
- **Headers:** `authtoken: <USER_TOKEN>`
- **Query:** `from`, `to` (optional, YYYY-MM-DD)
- Returns totals per source (Paid Calls, Gifts, Ads, Tasks...), current balances, rates.

### 10.2 Earnings Ledger (History)
- **Endpoint:** `GET /api/wallet/earnings/ledger`
- **Headers:** `authtoken: <USER_TOKEN>`
- **Query:** `limit`, `from`, `to`, `type` (optional)
- Returns unified transaction history sorted by newest first.

### 10.3 Billing & Display Rules
- Rounding: Duration billing rounded UP to full minute (`ceil(seconds/60)`).
- Display: APIs return Net Earnings (receiver share). `amount_tokens` reflects receiver’s net.
