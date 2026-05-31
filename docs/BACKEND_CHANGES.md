# VYBZZZ — Backend Changes (Annex)

> Document for the backend developer (`vybzzz.fryandeatfood.com`).
> Lists the endpoints / fields / business rules required by the app's new
> features, so nothing comes as a surprise. To be refined once backend access
> is available.
>
> Priority legend: 🔴 critical (security) · 🟠 required for a feature · 🟢 nice-to-have
> Effort legend: S (small) · M (medium) · L (large)

---

## 0. 🔴 SECURITY — TOP PRIORITY

### 0.1 Revoke the exposed Firebase Admin key
- The **Firebase Admin SDK** service account (`firebase-adminsdk-fbsvc@vybzzz`,
  key `bf1200fc5027…`) was **bundled in clear text inside the mobile app**
  (`lib/services/vybzzz_bf1200fc5027.dart`, now removed from the app).
- **Action**: revoke/regenerate this key in Google Cloud Console
  (IAM → Service Accounts → Keys). **Treat it as compromised.**
- The new key must stay **server-side only** (environment variable), never
  returned to the app.

### 0.2 Send push notifications from the server
- The app no longer generates an admin FCM token (removed). Push notifications
  must be sent **exclusively from the backend** (server endpoint).
- Verify/expose a mechanism: "send notification to user X / topic Y".

### 0.3 Rotate other secrets if exposed
- ZegoCloud `appSign` and RevenueCat key: rotate if present in any public repo.
  Ideally, Zego access should use a **server-issued token** (see §4).

---

## 1. 🟠 LIVE TEASER (free preview of the ongoing live)

**UX goal**: the user swipes (right → left) toward the ongoing live and can watch
it **for free for 30s or 60s**. An overlay gradually darkens until fully opaque,
then a CTA offers to buy access / see other lives / watch shorts.

### Fields to add to the `event` object
| Field | Type | Purpose |
|---|---|---|
| `teaser_enabled` | bool | Enable/disable the free preview for this live |
| `teaser_duration` | int (seconds) | Preview length (e.g. 30 or 60) |
| `teaser_stream_url` | string (optional) | Dedicated teaser stream/segment if different from full live |

> If we don't want per-event durations, the app can use a fixed value (60s).
> A backend-controlled value per live is preferred (artist/admin flexibility).

### Business rule
- Watching the teaser **does not consume** a ticket and **must not count** as a
  paid entry (exclude from sales stats / artist revenue).
- (Optional anti-abuse) limit the number of teasers per user/live → see §5.

---

## 2. 🟠 LIVE ACCESS CHECK (ticket)

**Goal**: when entering the live, the app automatically checks whether the user
is allowed in.

### Existing
- The `event` model already exposes `ticket_buyer_ids` (list of buyers). The app
  can compare it against the current user ID. ✅

### To confirm / expose
- A reliable endpoint such as **`GET /event/{id}/access`** returning the current
  user's access state:
  ```json
  {
    "has_access": true,
    "access_type": "ticket | ghost_pass | referral | none",
    "expires_at": "2026-06-15T20:30:00Z"  // for time-limited access
  }
  ```
- Why a dedicated endpoint rather than `ticket_buyer_ids`: needed to handle
  **temporary** access (ghost pass, referral) that aren't simple purchases.

---

## 3. 🟠 REFERRAL — artist AND user

**Goal**: an artist or a user can refer someone.
- **Artist → user**: grant **full free tickets**.
- **User → user**: rewards (e.g. ghost pass, points…).

### Endpoints to create
| Method | Endpoint | Purpose |
|---|---|---|
| `POST` | `/referral/generate` | Generate a referral code/link for the current user |
| `GET` | `/referral/me` | List of referrals sent + status (pending / validated) |
| `POST` | `/referral/redeem` | Redeem a received code (body: `{ "code": "..." }`) |

### Business rules to define
- Who can refer what (artist = full tickets; user = lesser reward).
- Limits (max referrals, anti-fraud: no self-referral, one redeem per user, etc.).
- Reward granted to the referrer AND/OR the referee.

### Useful user fields
- `referral_code` (string, unique) on the user object.
- `referred_by` (id, optional) to track the source.

---

## 4. 🟠 GHOST PASS 👻 (gamified, free, time-limited VIP access)

**Goal**: give **temporary** VIP access (e.g. 10 min) to a live, which is **NOT
counted as a paying customer** but as a **gamification reward** (engagement,
login streaks, referral…).

### Key point
- Must be a **distinct access type** from a paid ticket, so the backend can
  **exclude it from sales stats and artist revenue**.

### Endpoints / fields
| Method | Endpoint | Purpose |
|---|---|---|
| `POST` | `/ghost-pass/grant` | Grant a ghost pass to a user for an event (duration in min) |
| `GET` | `/ghost-pass/me` | User's active ghost passes (with `expires_at`) |

- Access type returned by `/event/{id}/access`: `"access_type": "ghost_pass"`.
- `duration_minutes` + `expires_at` for the in-app countdown.
- Rule: an **expired** ghost pass grants no access (the app forces exit or
  prompts purchase at expiry).

---

## 5. 🟢 DISCOVERY & ANTI-ABUSE (nice-to-have)

### Broader discovery feed
- Endpoint to fetch lives/shorts **outside the user's interests** (broad
  discovery), e.g. `GET /discover/live?scope=all`.
- Powers the end-of-teaser CTA "discover more concerts".

### "Hook" shorts
- Flag some shorts as **hook/teaser** (`is_hook: true`) to surface them at the
  end of a live teaser.

### Teaser anti-abuse (optional)
- Track teaser views per user/live (`teaser_views`) if we want to limit free
  re-watching.

---

## 6. 🟢 TEST DATA QUALITY (cleanup)

- The `link` / `stream_url` field on some test events points to a third-party
  store (`ordaraat.com`) — visible in the demo live.
  → Clean up test data so it points to real VYBZZZ streams.
- Several test artists have **no profile picture** (gray avatar).
  → Add realistic `profile_image` values on demo accounts.

---

## 7. SUMMARY — App-only vs Backend-blocked

| Feature | App alone | Backend required |
|---|---|---|
| Darkening teaser overlay + countdown | ✅ | — |
| End-of-teaser CTA (UI) | ✅ | — |
| Fixed teaser duration (60s) | ✅ | — (but §1 preferred) |
| Per-live teaser duration | — | 🟠 `teaser_duration` |
| Live access check | partial (`ticket_buyer_ids`) | 🟠 `/event/{id}/access` for temporary access |
| Real referral | UI only | 🟠 `/referral/*` endpoints |
| Real ghost pass | UI + timer | 🟠 `ghost_pass` + stats exclusion |
| Broader discovery | — | 🟢 `/discover/*` |

---

## 8. MISC (already done in the app)

- Full design redesign to **midnight blue + gold** (single locked theme, fonts
  Cinzel/Playfair/Montserrat/Inter).
- Improved error handling: the app now shows **detailed validation errors**
  returned by the API (`errors` per field) instead of a generic message.
  → keep this response format on the backend.
- The app forces **dark mode** (single visual identity).

---

_To be completed once backend access is obtained._
