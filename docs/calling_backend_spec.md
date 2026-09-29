# WhatsApp-like Calling — Backend Spec (Copy/Paste for Backend Team)

## 0) Goal
- 1-to-1 calling (later extend to group) with correct lifecycle:
  - Any side ends → both end
  - Accepted call never becomes missed
  - Busy/offline/declined/missed reasons
  - Call waiting/hold (phase 2)
  - Reliable lockscreen call notification via data push
- Current Flutter client already uses Firestore `calls/{callId}` + LiveKit token API.

---

## 1) Canonical Call Document (Firestore)
**Collection:** `calls/{callId}`

### Required fields
```json
{
  "callId": "call_12_98_1700000000000",
  "channelId": "call_12_98_1700000000000",
  "conversationId": "12_98",
  "callerId": 12,
  "receiverId": 98,
  "caller": { "user_id": 12, "username": "A", "fullname": "A", "profile": "..." },
  "receiver": { "user_id": 98, "username": "B", "fullname": "B", "profile": "..." },
  "isVideo": true,
  "status": "ringing",
  "createdAt": "<serverTimestamp>",
  "acceptedAt": null,
  "endedAt": null,
  "endedBy": null,
  "duration": 0,
  "declineReason": null,
  "endReason": null
}
```

### Allowed statuses (state machine)
- `ringing`
- `accepted`
- terminal:
  - `ended` (accepted call finished)
  - `declined` (receiver rejected)
  - `missed` (timeout/no answer)
  - `busy` (receiver already in a call)

### Terminal reason fields
- `endedBy`: `caller | receiver | system`
- `declineReason`: string (quick reply like "Call back later", optional)
- `endReason`: `network | app_killed | timeout | cancelled | unknown` (optional)

### Invariants
- If `acceptedAt != null` then **UI must never show "missed"** (treat as ended).
- Once `status` becomes terminal → it must never change again.

---

## 2) Indexes
For call history and incoming detection (no OR query needed):
- Index on `calls(callerId, createdAt desc)`
- Index on `calls(receiverId, createdAt desc)`
- Optional: `calls(receiverId, status, createdAt desc)` for “only ringing calls”

---

## 3) Security / Integrity (Must-have)
Firestore Rules (conceptual):
- Only `callerId`/`receiverId` can read the call doc.
- Only allowed transitions:
  - `ringing` → `accepted | declined | missed | busy`
  - `accepted` → `ended`
  - terminal → no further writes
- Only `receiverId` can write `accepted/declined/missed/busy` while ringing.
- Only `callerId` or `receiverId` can write `ended` after accepted.

Recommended enforcement:
- Use Cloud Functions / Backend API for transitions, and keep Firestore writes limited.
- Client should never be able to set terminal status for the other user arbitrarily.

---

## 4) Backend APIs (Minimal)
### 4.1 Create call (server-authoritative)
`POST /calls/create`
```json
{ "receiverId": 98, "isVideo": true, "conversationId": "12_98" }
```
Server does:
- Auth validate callerId from token/session.
- Check receiver “busy”:
  - Option A: Firestore `user_state/{receiverId}.activeCallId != null`
  - Option B: query `calls` where receiverId==X and status in (ringing,accepted) (needs index)
- If busy → create call doc with `status=busy` and return.
- Else create call doc with `status=ringing`, timestamps, store `caller/receiver` user snapshots.
- Send FCM data push to receiver:
  - `type=call`
  - `call_id=<callId>`
  - `caller_id`, `receiver_id`
  - `caller_name`, `caller_photo` (optional shortcut so UI doesn’t fetch)
  - `is_video`
  - **Android:** data-only + high priority
  - **iOS:** APNS alert required (or VoIP push for true CallKit)

Response:
```json
{ "callId": "...", "status": "ringing" }
```

### 4.2 Accept call
`POST /calls/{callId}/accept`
```json
{ "deviceInfo": { "platform": "android" } }
```
Server does:
- Validate receiver is the authenticated user.
- Ensure current status = `ringing`
- Update:
  - `status=accepted`
  - `acceptedAt=serverTimestamp`
  - set `user_state/{callerId}.activeCallId=callId`
  - set `user_state/{receiverId}.activeCallId=callId`
- Return LiveKit token (or a separate endpoint):
  - `POST /livekit/token` → `{roomName: channelId, userIdentity, userName}`

### 4.3 End call (any side)
`POST /calls/{callId}/end`
```json
{ "reason": "ended", "endedBy": "caller" }
```
Server does:
- Validate caller/receiver is ending.
- If current status = `accepted` → set `status=ended`, `endedAt`, `duration`, `endedBy`
- If current status = `ringing`:
  - if ended by caller → `status=missed` or `cancelled` (if you add it)
  - if ended by receiver → `status=declined`
- Clear `user_state/{callerId}.activeCallId` and `user_state/{receiverId}.activeCallId` if matches.
- Optional: send FCM “call ended” data push to the other side (extra reliability).

---

## 5) Presence / Busy / Call Waiting (Phase 2)
### 5.1 User state doc
`user_state/{userId}`
```json
{
  "online": true,
  "lastSeenAt": "<serverTimestamp>",
  "activeCallId": "call_...",
  "activeCallStatus": "ringing|accepted",
  "deviceTokens": ["..."]
}
```

### 5.2 Call waiting behavior (WhatsApp-like)
- If receiver has `activeCallId` and status=accepted:
  - New incoming call → receiver gets “call waiting” notification or “busy” response.
  - Backend choice:
    - Free tier: auto `busy`
    - Premium: allow “hold + switch”

### 5.3 Hold call
- Backend stores per-participant state (optional):
  - `calls/{callId}/participants/{userId} = { state: "active|hold" }`
- Client uses LiveKit track mute/unmute to simulate hold.

---

## 6) Reconnect + Network Quality
### Reconnect
- Client auto-reconnect to LiveKit room (client-side).
- Backend can allow rejoin window:
  - If status=accepted and endedAt==null, allow token refresh and rejoin for N seconds.

### Network Quality Indicator
- Best from LiveKit client stats (RTT, packet loss).
- Optional backend: store summarized quality when call ends:
  - `qualityScoreCaller`, `qualityScoreReceiver`

---

## 7) Call History / Logs
Option A (simple): use `calls` collection as history.
- Query by `callerId` / `receiverId` with limit + createdAt.

Option B (fast per-user): write fan-out logs (recommended at scale)
`call_logs/{userId}/items/{callId}`
```json
{
  "callId": "...",
  "peerId": 98,
  "direction": "incoming|outgoing",
  "status": "accepted|ended|missed|declined|busy",
  "isVideo": true,
  "createdAt": "<serverTimestamp>",
  "acceptedAt": null,
  "endedAt": null,
  "duration": 0,
  "endedBy": null,
  "declineReason": null
}
```
Write/update via Cloud Function on `calls/{callId}` changes.

---

## 8) Messaging: Quick Reply on Decline
When receiver declines with quick reply text:
- Store in call doc: `declineReason`
- Also write a chat text message into conversation:
  - `chats/{conversationId}/messages/{msgId}`
  - Update both `users/{uid}/users_list/{otherUid}` thread docs

Backend can do this via Cloud Function trigger on:
- `calls/{callId}` where `declineReason` changed and `status in (declined, missed)`

---

## 9) Premium / Pro Feature Flags (Backend-driven)
Create config endpoint:
`GET /app-config`
```json
{
  "calling": {
    "callWaiting": true,
    "recording": false,
    "paidCall": false,
    "scheduleCall": false
  },
  "ar": {
    "activeProvider": "banuba"  // or "deepar"
  }
}
```
Rules:
- If `activeProvider=banuba` then DeepAR disabled (mutual exclusion).

---

## 10) Future Features Notes (Group / Merge / Screen Share)
- Group call = LiveKit room with 3+ participants:
  - Replace `receiverId` with `participants[]` and `calls/{callId}/participants/*`.
- Merge calls = client joins another room; backend updates activeCallId mapping.
- Screen share = LiveKit supports screen track; backend only needs allow flag + auditing.

---

## 11) iOS True WhatsApp-like Call UI (Important)
For iOS “app killed/locked incoming call UI”:
- Need VoIP push + CallKit.
- Standard FCM/APNS notification won’t guarantee full-screen call UI.

