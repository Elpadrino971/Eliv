# Founder Plan — Backend Spec (PHP Laravel)

Limited launch offer: **200 Founder seats**, progressive price, then it converts
to the permanent **Growth** plan. The Flutter app is already wired to display
this (seat counter, price anchor, badge) the moment the API returns the fields
below — until then it degrades gracefully.

Host: `https://vybzzz.fryandeatfood.com` · API base: `/api`
Auth: `Authorization: Bearer <token>` (same as the rest of the API).

---

## 1. The model (decided)

| Tier | Seats | Price/mo | Commission |
|------|-------|----------|------------|
| Founder #1 | 24  | **79 €**  | 60% |
| Founder #2 | 76  | **99 €**  | 60% |
| Founder #3 | 100 | **149 €** | 60% |
| **Total Founder** | **200** | — | 60% |
| → then **Growth** (permanent) | ∞ | **199 €** | 60% |

Permanent ladder (after launch): Starter 99 €/50% · Growth 199 €/60% · Elite 299 €/70%.

Rules:
- Seats are consumed **in order**: the first 24 paid subs are at 79 €, the next
  76 at 99 €, the next 100 at 149 €.
- Once **200** are sold → **hide Founder, show Growth** (199 €/60%).
- **Grandfather**: a Founder keeps their **price + 60%** for life *while the
  subscription stays active*. If they **upgrade to Elite**, they move to
  **299 €/70%** (they lose the Founder price by choice).
- **Commission is enforced server-side** on every payout. Never trust the client.

---

## 2. Database (suggested migrations)

```php
// founder_config (single row, or just constants)
Schema::create('founder_config', function (Blueprint $t) {
    $t->id();
    $t->unsignedInteger('seats_total')->default(200);
    // tiers as JSON: [{"price":79,"qty":24,"iap":"founder_79"}, ...]
    $t->json('tiers');
    $t->unsignedInteger('public_price')->default(199); // Growth anchor
    $t->unsignedTinyInteger('commission')->default(60);
});

// founder_seats : one row per sold Founder seat (source of truth for the count)
Schema::create('founder_seats', function (Blueprint $t) {
    $t->id();                          // 1..200 → also the seat number
    $t->foreignId('user_id')->constrained();
    $t->unsignedInteger('price');      // locked price (79/99/149)
    $t->unsignedTinyInteger('commission')->default(60);
    $t->string('iap_product_id');      // founder_79 / 99 / 149
    $t->timestamps();
});
```

`seats_sold = founder_seats()->count()`. Keep it **transactional** (see §6) so
two buyers can't grab the same seat / cross a tier boundary twice.

User subscription record should store the **locked** values so grandfathering
survives price changes: `plan`, `locked_price`, `locked_commission`, `is_founder`.

---

## 3. Change the existing `GET /api/subscription/get`

The app already renders the plan list from this endpoint. Make it
**seat-aware**: while seats remain, return the **Founder** entry with the
current tier; once full, return **Growth** instead. Add these fields to the
Founder entry (the app reads them):

```jsonc
{
  "count": 3,
  "list": [
    {
      "id": 10,
      "title": "Founder",
      "price": "149",                 // current active tier price
      "price_type": "monthly",
      "commission": "60",
      "commission_type": "percentage",

      // ── new Founder fields (only on the Founder entry) ──
      "is_founder": true,
      "seats_total": 200,
      "seats_remaining": 63,          // = 200 - seats_sold
      "next_price": null,             // price after current tier fills (null if last tier)
      "next_price_in_seats": null,    // seats left before price rises (null if last tier)
      "public_price": "199",          // struck-through anchor (Growth price)
      "badge": "BEST VALUE",
      "iap_product_id": "founder_149" // which IAP product to purchase right now
    },
    { "id": 1, "title": "Starter", "price": "99",  "commission": "50", ... },
    { "id": 3, "title": "Elite",   "price": "299", "commission": "70", ... }
  ]
}
```

Computing the Founder entry server-side:
```php
$sold = FounderSeat::count();
if ($sold >= 200) {
    // return Growth (199/60) instead of Founder, omit founder fields
} else {
    // find current tier from cumulative quantities (24, then 100, then 200)
    [$price, $iap, $cumEnd] = current_tier($sold);     // e.g. 149, 'founder_149', 200
    $seatsRemaining = 200 - $sold;
    $nextPriceInSeats = $cumEnd - $sold === ... ;       // seats until THIS tier ends
    // next_price = price of the next tier (or null if last)
}
```
> The app falls back to its normal card if these fields are absent — so you can
> ship the fields incrementally.

---

## 4. Purchase flow (seat assignment + grandfather)

On a **verified** purchase (Apple receipt validation or Stripe webhook):

```php
DB::transaction(function () use ($user) {
    $sold = FounderSeat::lockForUpdate()->count();   // lock to avoid oversell
    abort_if($sold >= 200, 409, 'Founder sold out'); // tell app to refresh → Growth
    [$price, $iap] = current_tier($sold);

    FounderSeat::create([
        'user_id' => $user->id,
        'price' => $price,
        'commission' => 60,
        'iap_product_id' => $iap,
    ]);

    $user->subscription()->update([
        'plan' => 'founder',
        'locked_price' => $price,
        'locked_commission' => 60,
        'is_founder' => true,
    ]);
});
```

- **Grandfather**: always read `locked_price` / `locked_commission` from the
  user's subscription for billing + payouts — never recompute from the current
  tier.
- **Upgrade to Elite**: set `plan=elite, locked_price=299, locked_commission=70,
  is_founder=false`. (Optional: free their Founder seat or keep it counted —
  recommend **keep counted** so the 200 scarcity stays real.)

---

## 5. Commission enforcement (critical)

On every transaction payout, the artist's share = `locked_commission` from their
subscription, computed **server-side**. The `%` shown in the app is display
only; the real split must come from the DB, so a tampered client can't change
its cut.

---

## 6. Concurrency / edge cases

- Use `lockForUpdate()` (or an atomic `INSERT ... SELECT` with a unique seat
  index) so two simultaneous buyers can't take seat #200 twice or skip a tier.
- At exactly 200 sold: next `subscription/get` returns Growth; in-flight
  purchases that lose the race get `409` → app shows "sold out, here is Growth".
- Refund / churn: decide whether a cancelled Founder frees a seat. Recommended:
  **no** (keeps scarcity honest); the seat stays consumed.

---

## 7. App Store / Play IAP products to create (your side)

Apple can't change a product's price dynamically, so each price = its own
auto-renewable product (same subscription group):

- `founder_79`, `founder_99`, `founder_149`
- `starter_99`, `growth_199`, `elite_299`

The API tells the app which Founder product is active via `iap_product_id`.

---

## TL;DR for the dev
1. Add `founder_seats` (source of truth) + lock the user's price/commission.
2. Make `subscription/get` seat-aware: Founder (current tier + the new fields)
   until 200, then Growth.
3. Enforce commission from `locked_commission` on payouts.
4. Create the 6 IAP products above.
