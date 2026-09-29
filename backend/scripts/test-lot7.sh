#!/usr/bin/env bash
# Tests dynamiques du lot 7 (estimation de revenus + artistes invités avec
# partage de la part artiste) sur une base JETABLE. Ne touche jamais
# backend/vybzzz.sqlite.
#
#   bash scripts/test-lot7.sh            # base + serveur temporaires (port 8094)
#   L7_DB=/tmp/x.sqlite L7_PORT=8095 bash scripts/test-lot7.sh
#
# Prérequis : node, curl, jq. Sort en erreur (exit 1) au premier test raté.
set -u
cd "$(dirname "$0")/.."

L7_DB="${L7_DB:-${VYBZZZ_DB:-/tmp/vybzzz-lot7-test.sqlite}}"
L7_PORT="${L7_PORT:-8094}"
API="http://127.0.0.1:${L7_PORT}/api"
JWT="${JWT_SECRET:-$(openssl rand -hex 32)}"
rm -f "$L7_DB" "$L7_DB-wal" "$L7_DB-shm"

VYBZZZ_DB="$L7_DB" JWT_SECRET="$JWT" MUX_WEBHOOK_SECRET=x STRIPE_WEBHOOK_SECRET=x REVENUECAT_WEBHOOK_AUTH=x \
  NODE_ENV=development PORT="$L7_PORT" node src/server.js > "${L7_DB}.log" 2>&1 &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null' EXIT
for i in $(seq 1 60); do curl -sf "http://127.0.0.1:${L7_PORT}/" >/dev/null && break; sleep 0.5; done
curl -sf "http://127.0.0.1:${L7_PORT}/" >/dev/null || { echo "serveur injoignable"; cat "${L7_DB}.log"; exit 1; }

# Comptes de test (insérés directement : pas d'OTP à jouer) + jetons signés
# avec le même JWT_SECRET que le serveur.
SEED=$(VYBZZZ_DB="$L7_DB" JWT_SECRET="$JWT" node -e '
const Database = require("better-sqlite3"); const jwt = require("jsonwebtoken");
const db = new Database(process.env.VYBZZZ_DB);
const mk = (email, extra) => {
  const cols = Object.assign({ email, password: "x", full_name: email.split("@")[0], role: "user", is_artist: 0, is_verified: 1, status: "active", wallet: "0" }, extra);
  const keys = Object.keys(cols);
  const id = db.prepare(`INSERT INTO users (${keys.join(",")}) VALUES (${keys.map(() => "?").join(",")})`).run(...keys.map((k) => cols[k])).lastInsertRowid;
  return { id, token: jwt.sign({ id, email }, process.env.JWT_SECRET, { expiresIn: "1d" }) };
};
const out = {
  main: mk("l7.main@test.local", { artist_name: "Lot7 Main", role: "artist", is_artist: 1 }),
  guest: mk("l7.guest@test.local", { artist_name: "Lot7 Guest", role: "artist", is_artist: 1 }),
  other: mk("l7.other@test.local", { artist_name: "Lot7 Other", full_name: "Zed Autre", role: "artist", is_artist: 1 }),
  promo: mk("l7.promo@test.local", { artist_name: "Lot7 Promo", role: "artist", is_artist: 1, sub_free_until: "2999-01-01 00:00:00" }),
  fan: mk("l7.fan@test.local", { full_name: "Fan Lot7" }),
  admin: mk("l7.admin@test.local", { role: "admin" }),
};
console.log(JSON.stringify(out));
')
tok() { echo "$SEED" | jq -r ".$1.token"; }
uid() { echo "$SEED" | jq -r ".$1.id"; }
MAIN=$(tok main); GUEST=$(tok guest); PROMO=$(tok promo); FAN=$(tok fan); ADMIN=$(tok admin)
MAIN_ID=$(uid main); GUEST_ID=$(uid guest); OTHER_ID=$(uid other)

PASS=0; FAILS=0
check() { # check <label> <condition-exit-code>
  if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); echo "  ok   $1"; else FAILS=$((FAILS+1)); echo "  FAIL $1"; fi
}
wallet() { VYBZZZ_DB="$L7_DB" node -e 'const db=require("better-sqlite3")(process.env.VYBZZZ_DB);console.log(db.prepare("SELECT wallet FROM users WHERE id=?").get(process.argv[1]).wallet)' "$1"; }
sql() { VYBZZZ_DB="$L7_DB" node -e 'const db=require("better-sqlite3")(process.env.VYBZZZ_DB);console.log(JSON.stringify(db.prepare(process.argv[1]).all()))' "$1"; }

echo "## A. GET /pricing/estimate"
R=$(curl -s "$API/pricing/estimate?price=4.99" -H "Authorization: Bearer $MAIN"); echo "$R"
check "4.99 artiste normal : net 4.24, part artiste 2.49, plateforme 1.75, promo=false" \
  "$(echo "$R" | jq -e '.data.net==4.24 and .data.artist_share==2.49 and .data.platform_share==1.75 and .data.promo==false and .data.artist_rate==0.588 and (.data.grid|length)==13' >/dev/null; echo $?)"
R=$(curl -s "$API/pricing/estimate?price=4.99" -H "Authorization: Bearer $PROMO"); echo "$R"
check "4.99 artiste en promo : 50 % du net (2.12), promo=true" \
  "$(echo "$R" | jq -e '.data.artist_share==2.12 and .data.platform_share==2.12 and .data.promo==true and .data.artist_rate==0.5' >/dev/null; echo $?)"
R=$(curl -s "$API/pricing/estimate?price=0" -H "Authorization: Bearer $MAIN"); echo "$R"
check "0 : tout à 0" "$(echo "$R" | jq -e '.data.price==0 and .data.net==0 and .data.artist_share==0 and .data.platform_share==0' >/dev/null; echo $?)"
C=$(curl -s -o /dev/null -w '%{http_code}' "$API/pricing/estimate?price=5" -H "Authorization: Bearer $MAIN")
R=$(curl -s "$API/pricing/estimate?price=5" -H "Authorization: Bearer $MAIN"); echo "$R"
check "5 : 422 avec la grille dans errors.price" "$([ "$C" = 422 ] && echo "$R" | jq -e '(.errors.price|length)==13' >/dev/null; echo $?)"
C=$(curl -s -o /dev/null -w '%{http_code}' "$API/pricing/estimate?price=4.99"); check "sans jeton : 401" "$([ "$C" = 401 ]; echo $?)"

echo "## B. GET /artists/search"
R=$(curl -s "$API/artists/search?q=lot7" -H "Authorization: Bearer $MAIN"); echo "$R"
check "search lot7 : 3 artistes (appelant exclu), sans e-mail" \
  "$(echo "$R" | jq -e '(.data|length)==3 and ([.data[].id]|index('"$MAIN_ID"'))==null and ([.data[]|has("email")]|any|not)' >/dev/null; echo $?)"
R=$(curl -s "$API/artists/search?q=l7.guest%40test" -H "Authorization: Bearer $MAIN")
check "search par e-mail : trouve l'invité, e-mail non renvoyé" "$(echo "$R" | jq -e '(.data|length)==1 and .data[0].id=='"$GUEST_ID"' and (.data[0]|has("email")|not)' >/dev/null; echo $?)"
R=$(curl -s "$API/artists/search?q=ZED%20AUTRE" -H "Authorization: Bearer $MAIN")
check "search insensible à la casse sur full_name" "$(echo "$R" | jq -e '(.data|length)==1 and .data[0].id=='"$OTHER_ID"'' >/dev/null; echo $?)"
R=$(curl -s "$API/artists/search?q=fan" -H "Authorization: Bearer $MAIN")
check "search : un fan (non artiste) n'apparaît pas" "$(echo "$R" | jq -e '(.data|length)==0' >/dev/null; echo $?)"

echo "## C. POST /events avec invités"
N_BEFORE=$(sql "SELECT COUNT(*) c FROM events" | jq '.[0].c')
R=$(curl -s -X POST "$API/events" -H "Authorization: Bearer $MAIN" -F name="Lot7 invalide" -F ticket_price=4.99 -F start_date_time=2030-01-01T20:00:00Z \
  -F guests='[{"user_id":'"$GUEST_ID"',"share_pct":60},{"user_id":'"$OTHER_ID"',"share_pct":50}]'); echo "$R"
N_AFTER=$(sql "SELECT COUNT(*) c FROM events" | jq '.[0].c')
check "guests Σ 110 : 422 et aucun event créé" "$(echo "$R" | jq -e '.status=="error" and (.errors.guests|length)==1' >/dev/null && [ "$N_BEFORE" = "$N_AFTER" ]; echo $?)"
R=$(curl -s -X POST "$API/events" -H "Authorization: Bearer $MAIN" -F name="Lot7 fan" -F ticket_price=4.99 -F start_date_time=2030-01-01T20:00:00Z -F guests='[{"user_id":'"$(uid fan)"',"share_pct":10}]')
check "guests avec un non-artiste : 422" "$(echo "$R" | jq -e '.status=="error"' >/dev/null; echo $?)"
R=$(curl -s -X POST "$API/events" -H "Authorization: Bearer $MAIN" -F name="Lot7 self" -F ticket_price=4.99 -F start_date_time=2030-01-01T20:00:00Z -F guests='[{"user_id":'"$MAIN_ID"',"share_pct":10}]')
check "guests = propriétaire lui-même : 422" "$(echo "$R" | jq -e '.status=="error"' >/dev/null; echo $?)"
R=$(curl -s -X POST "$API/events" -H "Authorization: Bearer $MAIN" -F name="Lot7 duo" -F ticket_price=4.99 -F start_date_time=2030-01-01T20:00:00Z \
  -F guests='[{"user_id":'"$GUEST_ID"',"share_pct":30}]'); echo "$R" | jq -c '{id:.data.id, ticket_price:.data.ticket_price, guests:.data.guests}'
EVENT_ID=$(echo "$R" | jq -r '.data.id')
check "création avec invité 30 % : guests dans serializeEvent (sans share_pct)" \
  "$(echo "$R" | jq -e '.status=="success" and (.data.guests|length)==1 and .data.guests[0].user_id=='"$GUEST_ID"' and (.data.guests[0]|has("share_pct")|not) and (.data.guests[0]|has("artist_name"))' >/dev/null; echo $?)"
R=$(curl -s "$API/event/$EVENT_ID"); check "GET /event/:id public : guests présents" "$(echo "$R" | jq -e '(.data.guests|length)==1' >/dev/null; echo $?)"

echo "## D. GET/PUT /events/:id/guests"
R=$(curl -s "$API/events/$EVENT_ID/guests" -H "Authorization: Bearer $MAIN"); echo "$R"
check "GET propriétaire : 1 invité, remaining 70" "$(echo "$R" | jq -e '.data.remaining_pct==70 and .data.guests[0].share_pct==30 and (.data.guests[0]|has("email")|not)' >/dev/null; echo $?)"
C=$(curl -s -o /dev/null -w '%{http_code}' "$API/events/$EVENT_ID/guests" -H "Authorization: Bearer $GUEST"); check "GET par un autre artiste : 403" "$([ "$C" = 403 ]; echo $?)"
C=$(curl -s -o /dev/null -w '%{http_code}' "$API/events/$EVENT_ID/guests" -H "Authorization: Bearer $ADMIN"); check "GET admin : 200" "$([ "$C" = 200 ]; echo $?)"
R=$(curl -s -X PUT "$API/events/$EVENT_ID/guests" -H "Authorization: Bearer $MAIN" -H 'Content-Type: application/json' \
  -d '{"guests":[{"user_id":'"$GUEST_ID"',"share_pct":60},{"user_id":'"$OTHER_ID"',"share_pct":50}]}'); echo "$R"
check "PUT Σ 110 : 422" "$(echo "$R" | jq -e '.status=="error" and (.message|test("dépasse"))' >/dev/null; echo $?)"
R=$(curl -s -X PUT "$API/events/$EVENT_ID/guests" -H "Authorization: Bearer $MAIN" -H 'Content-Type: application/json' \
  -d '{"guests":[{"user_id":'"$GUEST_ID"',"share_pct":50},{"user_id":'"$OTHER_ID"',"share_pct":50}]}'); echo "$R"
check "PUT Σ 100 : ok, remaining 0" "$(echo "$R" | jq -e '.status=="success" and .data.remaining_pct==0 and (.data.guests|length)==2' >/dev/null; echo $?)"
R=$(curl -s -X PUT "$API/events/$EVENT_ID/guests" -H "Authorization: Bearer $MAIN" -F guests='[{"user_id":'"$GUEST_ID"',"share_pct":30}]'); echo "$R"
check "PUT en multipart (guests = JSON string) : retour à 30 %" "$(echo "$R" | jq -e '.status=="success" and .data.remaining_pct==70' >/dev/null; echo $?)"
C=$(curl -s -o /dev/null -w '%{http_code}' -X PUT "$API/events/$EVENT_ID/guests" -H "Authorization: Bearer $GUEST" -H 'Content-Type: application/json' -d '{"guests":[]}')
check "PUT par un autre artiste : 403" "$([ "$C" = 403 ]; echo $?)"

echo "## E. Achat billet 4,99 € avec invité 30 %"
W_MAIN0=$(wallet "$MAIN_ID"); W_GUEST0=$(wallet "$GUEST_ID")
R=$(curl -s -X POST "$API/buy-ticket" -H "Authorization: Bearer $FAN" -H 'Content-Type: application/json' -d '{"event_id":'"$EVENT_ID"'}')
check "achat : 200, has_ticket" "$(echo "$R" | jq -e '.status=="success" and .data.has_ticket==true' >/dev/null; echo $?)"
TICKET_ID=$(sql "SELECT id FROM tickets WHERE event_id=$EVENT_ID" | jq '.[0].id')
W_MAIN1=$(wallet "$MAIN_ID"); W_GUEST1=$(wallet "$GUEST_ID")
echo "  wallets : principal $W_MAIN0 -> $W_MAIN1 ; invité $W_GUEST0 -> $W_GUEST1 (part artiste 2.49 : 70 % = 1.74, 30 % = 0.75)"
check "wallet principal +1.74 (70 % de 2.49 + reste d'arrondi)" "$([ "$W_MAIN1" = "1.74" ]; echo $?)"
check "wallet invité +0.75 (30 % de 2.49)" "$([ "$W_GUEST1" = "0.75" ]; echo $?)"
TX=$(sql "SELECT user_id, direction, type, amount, description, source, source_id FROM wallet_transactions WHERE type='ticket_share' AND source_id='$TICKET_ID' ORDER BY id"); echo "  $TX"
check "2 lignes wallet_transactions type=ticket_share (credit)" "$(echo "$TX" | jq -e 'length==2 and all(.direction=="credit") and (map(.amount|tonumber)|add)==2.49 and (.[1].description|test("30 %"))' >/dev/null; echo $?)"
PE=$(sql "SELECT artist_id, artist_share, platform_share FROM platform_earnings WHERE source='ticket' AND source_id=$TICKET_ID")
check "platform_earnings inchangé (part artiste totale 2.49 sur l'artiste principal)" "$(echo "$PE" | jq -e 'length==1 and .[0].artist_id=='"$MAIN_ID"' and (.[0].artist_share|tonumber)==2.49' >/dev/null; echo $?)"

echo "## F. PUT après vente"
R=$(curl -s -X PUT "$API/events/$EVENT_ID/guests" -H "Authorization: Bearer $MAIN" -H 'Content-Type: application/json' -d '{"guests":[{"user_id":'"$GUEST_ID"',"share_pct":40}]}'); echo "$R"
check "changement de répartition après vente : 409" "$(echo "$R" | jq -e '.status=="error"' >/dev/null && [ "$(curl -s -o /dev/null -w '%{http_code}' -X PUT "$API/events/$EVENT_ID/guests" -H "Authorization: Bearer $MAIN" -H 'Content-Type: application/json' -d '{"guests":[{"user_id":'"$GUEST_ID"',"share_pct":40}]}')" = 409 ]; echo $?)"
R=$(curl -s -X PUT "$API/events/$EVENT_ID/guests" -H "Authorization: Bearer $MAIN" -H 'Content-Type: application/json' -d '{"guests":[{"user_id":'"$GUEST_ID"',"share_pct":30}]}')
check "même répartition après vente : 200 (idempotent)" "$(echo "$R" | jq -e '.status=="success"' >/dev/null; echo $?)"

echo "## G. Remboursement"
VYBZZZ_DB="$L7_DB" JWT_SECRET="$JWT" node -e '
const access = require("./src/services/event_access");
console.log(JSON.stringify(access.refundTicket(Number(process.argv[1]), { reason: "test lot7" })));' "$TICKET_ID"
W_MAIN2=$(wallet "$MAIN_ID"); W_GUEST2=$(wallet "$GUEST_ID")
echo "  wallets après remboursement : principal $W_MAIN2 ; invité $W_GUEST2"
check "débits inverses : principal 0.00, invité 0.00" "$([ "$W_MAIN2" = "0.00" ] && [ "$W_GUEST2" = "0.00" ]; echo $?)"
TX=$(sql "SELECT user_id, direction, amount FROM wallet_transactions WHERE type='ticket_share' AND source_id='$TICKET_ID' AND direction='debit'"); echo "  $TX"
check "2 lignes ticket_share debit (1.74 + 0.75)" "$(echo "$TX" | jq -e 'length==2 and (map(.amount|tonumber)|add)==2.49' >/dev/null; echo $?)"
R=$(curl -s -X PUT "$API/events/$EVENT_ID/guests" -H "Authorization: Bearer $MAIN" -H 'Content-Type: application/json' -d '{"guests":[{"user_id":'"$GUEST_ID"',"share_pct":40}]}')
check "après remboursement (plus de vente active) : la répartition redevient modifiable" "$(echo "$R" | jq -e '.status=="success" and .data.guests[0].share_pct==40' >/dev/null; echo $?)"

echo "## H. Billet gratuit (prix 0) : rien à créditer"
R=$(curl -s -X POST "$API/events" -H "Authorization: Bearer $MAIN" -F name="Lot7 gratuit" -F ticket_price=0 -F start_date_time=2030-01-02T20:00:00Z -F guests='[{"user_id":'"$GUEST_ID"',"share_pct":50}]')
FREE_ID=$(echo "$R" | jq -r '.data.id')
curl -s -X POST "$API/buy-ticket" -H "Authorization: Bearer $FAN" -H 'Content-Type: application/json' -d '{"event_id":'"$FREE_ID"'}' >/dev/null
TX=$(sql "SELECT COUNT(*) c FROM wallet_transactions WHERE type='ticket_share' AND source_id IN (SELECT CAST(id AS TEXT) FROM tickets WHERE event_id=$FREE_ID)")
check "prix 0 : aucune ligne ticket_share, wallets inchangés" "$(echo "$TX" | jq -e '.[0].c==0' >/dev/null && [ "$(wallet "$MAIN_ID")" = "0.00" ]; echo $?)"

echo "## I. Billet web (insertTicket) : même partage"
VYBZZZ_DB="$L7_DB" JWT_SECRET="$JWT" node -e '
const access = require("./src/services/event_access");
const r = access.grantByEmail({ email: "l7.web@test.local", eventId: Number(process.argv[1]), pricePaid: "4.99", storeFeeRate: 0, source: "stripe", ref: "cs_test_lot7" });
console.log(JSON.stringify(r));' "$EVENT_ID" >/dev/null
# compte vérifié créé après coup -> rattachement de la place en attente
VYBZZZ_DB="$L7_DB" JWT_SECRET="$JWT" node -e '
const Database = require("better-sqlite3"); const db = new Database(process.env.VYBZZZ_DB);
const id = db.prepare("INSERT INTO users (email, password, full_name, is_verified, status) VALUES (?, ?, ?, 1, ?)").run("l7.web@test.local", "x", "Web Buyer", "active").lastInsertRowid;
const access = require("./src/services/event_access");
console.log("rattachées:", access.attachPendingForUser(db.prepare("SELECT * FROM users WHERE id = ?").get(id)));'
W_MAIN3=$(wallet "$MAIN_ID"); W_GUEST3=$(wallet "$GUEST_ID")
echo "  wallets après billet web 4,99 (Stripe, frais 0 ici, invité 40 %) : principal $W_MAIN3 ; invité $W_GUEST3"
# part artiste = 4.99 × 58,8 % = 2.93 ; invité 40 % = 1.17 ; principal = 1.76
check "billet web : principal 1.76, invité 1.17" "$([ "$W_MAIN3" = "1.76" ] && [ "$W_GUEST3" = "1.17" ]; echo $?)"

echo "## J. Admin"
R=$(curl -s "$API/admin/events/$EVENT_ID/guests" -H "Authorization: Bearer $ADMIN"); echo "$R" | jq -c '{guests:.data.guests, remaining:.data.remaining_pct, has_paid_sales:.data.has_paid_sales, estimate:.data.estimate}'
check "GET admin guests : estimation présente (parts principal + invité)" "$(echo "$R" | jq -e '.data.estimate.artist_share==2.49 and (.data.estimate.parts|length)==2 and .data.has_paid_sales==true' >/dev/null; echo $?)"
C=$(curl -s -o /dev/null -w '%{http_code}' -X PUT "$API/admin/events/$EVENT_ID/guests" -H "Authorization: Bearer $ADMIN" -H 'Content-Type: application/json' -d '{"guests":[]}')
check "PUT admin après vente (changement) : 409" "$([ "$C" = 409 ]; echo $?)"

echo
echo "Résultat : $PASS ok, $FAILS échec(s)"
[ "$FAILS" -eq 0 ]
