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
  Ideally, Zego access should use a **server-issued token**.

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
- (Optional anti-abuse) limit the number of teasers per user/live.

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

## 6. 🟢 LOCALIZATION / I18N (future)

**Current state**: the app is **single-language (English, hard-coded)**. There is
NO i18n system in place (no `flutter_localizations`, no `.arb`, no GetX
translations). The in-app "Language" screen is **cosmetic only** — selecting a
language does nothing yet. `intl` is used solely for date formatting.

**Planned**: introduce real i18n in the app (likely GetX Translations) and wire
the Language screen to actually switch locale.

### Backend impact (when we get there)
- **Dynamic content** (event names, descriptions, API error messages) is sent by
  the backend and won't be translated client-side. If multilingual content is
  desired, the backend must support it:
  - Either accept an `Accept-Language` header / `?lang=` param and return
    localized strings, or
  - Return translatable fields as keyed/multilingual objects.
- Keep returning **machine-readable error codes** (not just human text) so the
  app can map them to localized messages.

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
| App UI localization | ✅ (i18n system) | 🟢 only for dynamic content |

---

## 8. MISC (already done in the app)

- Full design redesign to **midnight blue + gold** (single locked theme, fonts
  Cinzel/Playfair/Montserrat/Inter).
- Improved error handling: the app now shows **detailed validation errors**
  returned by the API (`errors` per field) instead of a generic message.
  → keep this response format on the backend.
- The app forces **dark mode** (single visual identity).

---

## 9. TEST DATA QUALITY (cleanup)

- The `link` / `stream_url` field on some test events points to a third-party
  store (`ordaraat.com`) — visible in the demo live.
  → Clean up test data so it points to real VYBZZZ streams.
- Several test artists have **no profile picture** (gray avatar).
  → Add realistic `profile_image` values on demo accounts.

---

## 10. 🟠 EVENT POSTERS (template-based, NOT AI face generation)

**Goal**: turn an artist's **official photo** into a premium VYBZZZ poster for an
upcoming concert. The app composes the artist's real photo with a branded
template — it does **NOT** generate or alter faces with AI (avoids
celebrity-detection blocks, deepfake issues, and image-rights problems).

### Flow (artist studio → "Create Event Poster")
1. Artist uploads their **own official photo**.
2. Picks event type (Concert / Live / Showcase / Festival…).
3. Picks a style (Gold Premium / Red Urban / Blue Midnight / Festival Energy).
4. App generates 2–3 poster variants (overlay + artist name + date + venue +
   badge "This week / Live soon / Exclusive" + CTA).
5. Selected poster becomes the event cover on Home, and can be exported to
   social formats (story, square, FB/YT cover).

### Backend impact
- Store multiple cover formats per event (e.g. `cover_image`, `cover_story`,
  `cover_square`) OR a single source + format metadata.
- Optional: `poster_style` / `poster_template` field on the event for re-render.
- Legal: artist must accept a clause guaranteeing they hold the rights to the
  images/logos/names provided (add to artist terms).
- The app does the composition client-side; no backend image generation required
  for v1 (backend only stores the result).

---

## 11. 🟠 EVENT PULSE — aggregated, anonymized insights (NO data selling)

**Goal**: help artists understand interest around their events to sell better.
**Strictly aggregated & anonymized.** VYBZZZ does **NOT** sell personal data and
does **NOT** expose individual users to artists. Purpose: propel VYBZZZ + help
artists promote, never monetize personal data.

### What artists see (example)
> "Your event was viewed 3,240 times this week. 18% showed strong interest.
> Most active areas: Cayenne, Kourou, Paris, Pointe-à-Pitre. Best engagement
> window: Friday evening."

### Metrics to track (per event, aggregated only)
- views, likes, favorites/saves, shares
- clicks on "Book" / "Notify me"
- conversion rate to ticket page
- **approximate** area/region (NOT precise address)
- best day/time of engagement
- return rate to the event page
- (optional) poster variant performance (A/B)

### Backend impact
| Method | Endpoint | Purpose |
|---|---|---|
| `POST` | `/event/{id}/signal` | Record an interaction (view/like/save/notify/book-intent) |
| `GET` | `/event/{id}/pulse` | Aggregated insights for the artist dashboard |

### HARD RULES (privacy / legal)
- 🔴 **Never** return to artists: user lists, emails, phones, individual profiles,
  precise location, or per-user behavior.
- Only **aggregated** numbers + **approximate** regions.
- Region must be coarse (city/region level), with a **minimum cohort size**
  (e.g. hide a region if < N users) to prevent re-identification.
- Profiling for marketing requires clear, prior **user consent** (RGPD):
  transparency, purpose limitation, data minimization, retention limits, and
  user rights (access/erasure).
- Present this as **"aggregated analytics / event insights"**, never "data sale".

### Artist dashboard UI ("Event Pulse")
- Interest Score (0–100)
- Audience Signals (views/likes/saves/book clicks)
- Top Areas (coarse regions)
- Best Time to Push
- Poster Performance (if A/B)
- Recommendation (e.g. "Gaining traction — push a 48h early-access offer")

---

## 12. Pricing tiers (Standard / Premium / VIP) — DEFERRED TO V2

**Decision:** v1 ships with the **single fixed price** (`ticket_price`) already
in production. The 3-tier model (Standard / Premium / VIP) is **postponed to
v2** — the Event Detail UI currently shows one price and one "Continue to
Checkout" CTA. The premium layout (large hero, gradient, compact info chips,
sticky CTA) is kept; only the multi-tier pricing was removed.

**For v2 — to make tiers real (no fake prices / perks):**
1. **DB / Event:** add real per-tier pricing. Either three columns
   (`standard_price`, `premium_price`, `vip_price`) or a `pricing_tiers` JSON
   array `[{name, price, perks[]}]`.
2. **Event model (Flutter):** parse those fields into the `Event` class
   (replace the client-side x2/x5 multipliers).
3. **Artist event creation:** add Premium & VIP price inputs (the unused
   `vipController` in `artist_create_event.dart` is a leftover to reuse), plus
   recommended price presets per artist level (small / confirmed / major).
4. **Buy API:** `buyTicket` must accept the chosen tier
   (`tier_name`/`tier_id` + `amount`) so the backend charges and records the
   correct price. Today it only sends `event_id` + `user_id`.
5. **Ticket model:** store the purchased `tier` so the app can unlock the right
   perks (replay length, VIP chat, digital merch, etc.).
6. **Perks gating:** back the tier perks server-side (what each tier actually
   unlocks) — do not gate only on the client.

Until 1–5 land, VIP/Premium are **display-only**: the backend still records the
base `ticket_price` for every purchase.

_To be completed once backend access is obtained._
