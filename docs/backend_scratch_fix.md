# Backend Team Instructions - Scratch Card Fix

## Problem
Sab scratch cards mein "Good Luck" (0 tokens) aa raha hai. User ko actual rewards nahi mil rahe.

## Required Fixes

### 1. Fix Reward Algorithm (URGENT)
**File:** `app/Http/Controllers/RewardController.php` ya reward service

**Current Issue:** Sab rewards 0 tokens return ho rahe hain

**Fix Required:**
```php
// In claimReward() method - ensure minimum token reward
public function claimReward($userId) {
    $settings = ScratchSettings::first();
    
    // Get reward config from admin panel
    $minTokens = $settings->min_token_reward ?? 10;  // Minimum 10 tokens
    $maxTokens = $settings->max_token_reward ?? 100;  // Maximum 100 tokens
    
    // Random token amount between min and max
    $tokenAmount = rand($minTokens, $maxTokens);
    
    // 20% chance for asset, 80% chance for tokens
    $isAsset = (rand(1, 100) <= 20);
    
    if ($isAsset) {
        // Return random asset from available assets
        $asset = Asset::inRandomOrder()->first();
        return [
            'reward_type' => 'asset',
            'asset_id' => $asset->id,
            'asset' => $asset
        ];
    } else {
        // Return tokens (NEVER 0)
        return [
            'reward_type' => 'token',
            'token_amount' => $tokenAmount
        ];
    }
}
```

### 2. Add API for Pending Scratch Cards
**New Endpoint:** `GET /api/v1/rewards/pending-cards`

**Purpose:** Frontend ko batana ki admin panel se kitne cards available hain

**Response:**
```json
{
  "success": true,
  "data": {
    "pending_cards": 3,
    "total_pending_rewards": 150,
    "cards": [
      {
        "id": 1,
        "reward_type": "token",
        "token_amount": 50,
        "added_by": "admin",
        "created_at": "2024-01-15T10:00:00Z"
      }
    ]
  }
}
```

### 3. Update Reward Config API
**Endpoint:** `GET /api/v1/rewards/config`

**Current Response:**
```json
{
  "min_reels_for_scratch": 5
}
```

**Add These Fields:**
```json
{
  "min_reels_for_scratch": 5,
  "min_token_reward": 10,
  "max_token_reward": 100,
  "asset_reward_chance": 20,
  "daily_card_limit": 5,
  "pending_admin_cards": 3
}
```

### 4. Admin Panel - Add Reward Settings Page

**Fields Required:**
- Minimum Token Reward (default: 10)
- Maximum Token Reward (default: 100)
- Asset Reward % Chance (default: 20)
- Min Reels For Scratch (default: 3)
- Daily Card Limit Per User (default: 5)

### 5. Database Migration (if needed)

```php
// Add to scratch_settings table
Schema::table('scratch_settings', function (Blueprint $table) {
    $table->integer('min_token_reward')->default(10);
    $table->integer('max_token_reward')->default(100);
    $table->integer('asset_reward_chance')->default(20);
});

// Create pending_scratch_cards table
Schema::create('pending_scratch_cards', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained();
    $table->string('reward_type'); // 'token' or 'asset'
    $table->decimal('token_amount', 10, 2)->nullable();
    $table->foreignId('asset_id')->nullable()->constrained();
    $table->string('added_by'); // 'admin' or 'algorithm'
    $table->boolean('is_claimed')->default(false);
    $table->timestamps();
});
```

## Testing Checklist

- [ ] Call `POST /api/v1/rewards/claim` - should return tokens > 0
- [ ] Check min 10 tokens, max 100 tokens
- [ ] 20% chance of getting asset reward
- [ ] API response mein `token_amount` kabhi null ya 0 nahi hona chahiye
- [ ] New endpoint `/api/v1/rewards/pending-cards` working

## Priority
1. **URGENT:** Fix 0 tokens issue (same day)
2. **HIGH:** Add pending cards API (next day)
3. **MEDIUM:** Admin panel settings (this week)

## Contact
Flutter team for any questions on integration.
