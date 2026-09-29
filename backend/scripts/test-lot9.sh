#!/usr/bin/env bash
# Tests dynamiques du lot 9 (tarification dynamique par paliers + replay MP4)
# sur une base JETABLE. Ne touche jamais backend/vybzzz.sqlite.
#
#   bash scripts/test-lot9.sh                     # base + serveur temporaires (port 8095)
#   L9_DB=/tmp/x.sqlite L9_PORT=8096 bash scripts/test-lot9.sh
#   L9_SKIP_SITE=1 …                              # sans le rendu Playwright du site
#
# Prérequis : node, curl, jq ; Playwright global (npm root -g) + chromium dans
# /opt/pw-browsers pour la partie site. Sort en erreur (exit 1) au premier lot raté.
set -u
cd "$(dirname "$0")/.."

L9_DB="${L9_DB:-${VYBZZZ_DB:-/tmp/vybzzz-lot9-test.sqlite}}"
L9_PORT="${L9_PORT:-8095}"
API="http://127.0.0.1:${L9_PORT}/api"
JWT="${JWT_SECRET:-$(openssl rand -hex 32)}"
RC_PORT=$((L9_PORT + 1))
rm -f "$L9_DB" "$L9_DB-wal" "$L9_DB-shm"

PASS=0; FAILS=0
check() { if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); echo "  ok   $1"; else FAILS=$((FAILS+1)); echo "  FAIL $1"; fi; }

# ─── Faux RevenueCat : renvoie, pour l'app_user_id demandé, les achats
# consommables déclarés via POST /__set (par product_id). ───
RC_LOG="${L9_DB}.rc.log"
node -e '
const http = require("http"); let purchases = {};
http.createServer((req, res) => {
  let body = ""; req.on("data", (c) => body += c);
  req.on("end", () => {
    if (req.method === "POST" && req.url === "/__set") { purchases = JSON.parse(body || "{}"); res.end("ok"); return; }
    const m = req.url.match(/^\/subscribers\/(\d+)/);
    console.log("RC GET", req.url);
    res.setHeader("Content-Type", "application/json");
    res.end(JSON.stringify({ subscriber: { non_subscriptions: purchases[m ? m[1] : ""] || {} } }));
  });
}).listen(process.argv[1], "127.0.0.1");' "$RC_PORT" > "$RC_LOG" 2>&1 &
RC_PID=$!

# Sans identifiants Mux (env -u) : aucun appel réel vers api.mux.com pendant
# les tests, et la route replay-mp4 doit répondre 503 « non configuré ».
env -u MUX_TOKEN_ID -u MUX_TOKEN_SECRET \
  VYBZZZ_DB="$L9_DB" JWT_SECRET="$JWT" MUX_WEBHOOK_SECRET=x STRIPE_WEBHOOK_SECRET=x REVENUECAT_WEBHOOK_AUTH=x \
  REVENUECAT_API_KEY=test REVENUECAT_API_BASE="http://127.0.0.1:${RC_PORT}" RC_RETRY_DELAY_MS=50 \
  NODE_ENV=development PORT="$L9_PORT" node src/server.js > "${L9_DB}.log" 2>&1 &
SERVER_PID=$!
trap 'kill $SERVER_PID $RC_PID 2>/dev/null' EXIT
for i in $(seq 1 60); do curl -sf "http://127.0.0.1:${L9_PORT}/" >/dev/null && break; sleep 0.5; done
curl -sf "http://127.0.0.1:${L9_PORT}/" >/dev/null || { echo "serveur injoignable"; cat "${L9_DB}.log"; exit 1; }

SEED=$(VYBZZZ_DB="$L9_DB" JWT_SECRET="$JWT" node -e '
const Database = require("better-sqlite3"); const jwt = require("jsonwebtoken");
const db = new Database(process.env.VYBZZZ_DB);
const mk = (email, extra) => {
  const cols = Object.assign({ email, password: "x", full_name: email.split("@")[0], role: "user", is_artist: 0, is_verified: 1, status: "active", wallet: "0" }, extra);
  const keys = Object.keys(cols);
  const id = db.prepare(`INSERT INTO users (${keys.join(",")}) VALUES (${keys.map(() => "?").join(",")})`).run(...keys.map((k) => cols[k])).lastInsertRowid;
  return { id, token: jwt.sign({ id, email }, process.env.JWT_SECRET, { expiresIn: "1d" }) };
};
console.log(JSON.stringify({
  artist: mk("l9.artist@test.local", { artist_name: "Lot9 Artist", role: "artist", is_artist: 1 }),
  fan1: mk("l9.fan1@test.local", {}), fan2: mk("l9.fan2@test.local", {}), fan3: mk("l9.fan3@test.local", {}), fan4: mk("l9.fan4@test.local", {}),
  admin: mk("l9.admin@test.local", { role: "admin" }),
}));')
tok() { echo "$SEED" | jq -r ".$1.token"; }
uid() { echo "$SEED" | jq -r ".$1.id"; }
ARTIST=$(tok artist); ADMIN=$(tok admin)
FAN1=$(tok fan1); FAN2=$(tok fan2); FAN3=$(tok fan3); FAN4=$(tok fan4)
FAN1_ID=$(uid fan1); FAN2_ID=$(uid fan2); FAN3_ID=$(uid fan3); FAN4_ID=$(uid fan4)
sql() { VYBZZZ_DB="$L9_DB" node -e 'const db=require("better-sqlite3")(process.env.VYBZZZ_DB);console.log(JSON.stringify(db.prepare(process.argv[1]).all()))' "$1"; }
iso_in() { node -e 'console.log(new Date(Date.now()+Number(process.argv[1])*60000).toISOString())' "$1"; } # minutes
SCHED='[{"hours_before":72,"price":"4.99"},{"hours_before":48,"price":"6.99"},{"hours_before":0,"price":"9.99"}]'

echo "## A. effectivePrice (unitaire) — grille 72→4,99 / 48→6,99 / 0→9,99, début 2026-10-04T03:50:00Z"
R=$(VYBZZZ_DB="$L9_DB" node -e '
const p = require("./src/services/pricing");
const ev = { ticket_price: "4.99", start_date_time: "2026-10-04T03:50:00Z", price_schedule: process.argv[1] };
const H = 3600e3, start = Date.parse(ev.start_date_time);
const at = (h) => p.effectivePrice(ev, start - h * H);
const out = { t100: at(100), t60: at(60), t10: at(10), after: at(-2), noStart: p.effectivePrice({ ticket_price: "4.99", price_schedule: process.argv[1] }), noSched: p.effectivePrice({ ticket_price: "4.99", start_date_time: ev.start_date_time }) };
out.accepted_t60 = p.acceptedPrices(ev, start - 60 * H).map((a) => a.product_id);
out.accepted_10min_after_switch = p.acceptedPrices(ev, start - 72 * H + 10 * 60e3).map((a) => a.product_id);
out.accepted_40min_after_switch = p.acceptedPrices(ev, start - 72 * H + 40 * 60e3).map((a) => a.product_id);
console.log(JSON.stringify(out));' "$SCHED")
echo "$R" | jq -c '{t100:.t100.price, t60:.t60.price, t10:.t10.price, after:.after.price, next_at_t60:.t60.next_price_at, next_t60:.t60.next_price, noStart:.noStart.price, noSched:.noSched.price, acc60:.accepted_t60, acc10:.accepted_10min_after_switch, acc40:.accepted_40min_after_switch}'
check "T-100 h → 4,99 ; prochain 6,99 à T-72 h" "$(echo "$R" | jq -e '.t100.price=="4.99" and .t100.next_price=="6.99" and .t100.next_price_at=="2026-10-01T03:50:00.000Z"' >/dev/null; echo $?)"
check "T-60 h → 6,99 ; prochain 9,99 à T-48 h" "$(echo "$R" | jq -e '.t60.price=="6.99" and .t60.next_price=="9.99" and .t60.next_price_at=="2026-10-02T03:50:00.000Z"' >/dev/null; echo $?)"
check "T-10 h → 9,99 ; pas de prochain" "$(echo "$R" | jq -e '.t10.price=="9.99" and .t10.next_price==null and .t10.next_price_at==null' >/dev/null; echo $?)"
check "après le début → 9,99 (dernier palier persiste), base 4,99, schedule 3 paliers" "$(echo "$R" | jq -e '.after.price=="9.99" and .after.base=="4.99" and (.after.schedule|length)==3' >/dev/null; echo $?)"
check "sans start_date_time / sans grille → prix de base" "$(echo "$R" | jq -e '.noStart.price=="4.99" and .noSched.price=="4.99" and .noSched.schedule==[]' >/dev/null; echo $?)"
check "acceptedPrices : T-60 h → [ticket_6] ; 10 min après bascule → [ticket_6, ticket_4] ; 40 min → [ticket_6]" "$(echo "$R" | jq -e '.accepted_t60==["ticket_6"] and .accepted_10min_after_switch==["ticket_6","ticket_4"] and .accepted_40min_after_switch==["ticket_6"]' >/dev/null; echo $?)"

echo "## B. POST /events (artiste) : grilles invalides → 422, grille valide → 200"
post_event() { curl -s -o /dev/null -w '%{http_code}' -X POST "$API/events" -H "Authorization: Bearer $ARTIST" -H 'Content-Type: application/json' -d "$1"; }
START60=$(iso_in $((60*60)))
N_BEFORE=$(sql "SELECT COUNT(*) c FROM events" | jq -r '.[0].c')  # la base neuve contient les concerts de démo du seed
C=$(post_event '{"name":"Bad grid","ticket_price":"4.99","start_date_time":"'"$START60"'","price_schedule":"[{\"hours_before\":72,\"price\":\"5.49\"}]"}')
check "prix hors grille (5,49) → 422" "$([ "$C" = 422 ]; echo $?)"
R=$(curl -s -X POST "$API/events" -H "Authorization: Bearer $ARTIST" -H 'Content-Type: application/json' -d '{"name":"Bad order","ticket_price":"4.99","start_date_time":"'"$START60"'","price_schedule":"[{\"hours_before\":48,\"price\":\"4.99\"},{\"hours_before\":72,\"price\":\"6.99\"}]"}')
echo "  $(echo "$R" | jq -c '{status, message}')"
check "ordre non décroissant → 422 (message explicite)" "$(echo "$R" | jq -e '.status=="error" and (.message|test("décroissantes"))' >/dev/null; echo $?)"
C=$(post_event '{"name":"Too many","ticket_price":"4.99","start_date_time":"'"$START60"'","price_schedule":"[{\"hours_before\":100,\"price\":\"2.99\"},{\"hours_before\":80,\"price\":\"4.99\"},{\"hours_before\":60,\"price\":\"6.99\"},{\"hours_before\":40,\"price\":\"9.99\"},{\"hours_before\":20,\"price\":\"14.99\"},{\"hours_before\":0,\"price\":\"19.99\"}]"}')
check "6 paliers → 422" "$([ "$C" = 422 ]; echo $?)"
C=$(post_event '{"name":"Free tier","ticket_price":"4.99","start_date_time":"'"$START60"'","price_schedule":"[{\"hours_before\":72,\"price\":\"0\"}]"}')
check "palier gratuit → 422" "$([ "$C" = 422 ]; echo $?)"
C=$(post_event '{"name":"Bad json","ticket_price":"4.99","start_date_time":"'"$START60"'","price_schedule":"{oops"}')
check "JSON illisible → 422" "$([ "$C" = 422 ]; echo $?)"
check "aucun event créé par les essais invalides" "$(sql "SELECT COUNT(*) c FROM events" | jq -e --argjson n "$N_BEFORE" '.[0].c==$n' >/dev/null; echo $?)"
R=$(curl -s -X POST "$API/events" -H "Authorization: Bearer $ARTIST" -H 'Content-Type: application/json' -d '{"name":"Lot9 T-60h","ticket_price":"4.99","start_date_time":"'"$START60"'","price_schedule":"'"$(echo "$SCHED" | sed 's/"/\\"/g')"'"}')
EVENT_ID=$(echo "$R" | jq -r '.data.id')
echo "  $(echo "$R" | jq -c '.data | {id, ticket_price, base_price, next_price, next_price_at, price_schedule}')"
check "création OK ; serializeEvent à T-60 h : ticket_price 6.99 (chaîne), base 4.99, next 9.99, grille 3 paliers" "$(echo "$R" | jq -e '.data.ticket_price=="6.99" and .data.base_price=="4.99" and .data.next_price=="9.99" and (.data.next_price_at|type)=="string" and (.data.price_schedule|length)==3' >/dev/null; echo $?)"
R=$(curl -s "$API/event/$EVENT_ID")
check "GET /event/:id (public) : même contrat, stocké en base = 4.99" "$(echo "$R" | jq -e '.data.ticket_price=="6.99"' >/dev/null && sql "SELECT ticket_price FROM events WHERE id=$EVENT_ID" | jq -e '.[0].ticket_price=="4.99"' >/dev/null; echo $?)"

echo "## C. /buy-ticket à T-60 h (RevenueCat mocké)"
rc_set() { curl -s -X POST "http://127.0.0.1:${RC_PORT}/__set" -d "$1" >/dev/null; }
# fan1 n'a acheté que ticket_4 (ancien palier, bascule il y a 12 h) -> refusé (402)
rc_set '{"'"$FAN1_ID"'":{"ticket_4":[{"id":"tx-f1-4","store_transaction_id":"st-f1-4","purchase_date":"2026-01-01T00:00:00Z"}]}}'
R=$(curl -s -w '\n%{http_code}' -X POST "$API/buy-ticket" -H "Authorization: Bearer $FAN1" -H 'Content-Type: application/json' -d '{"event_id":'"$EVENT_ID"'}')
C=$(echo "$R" | tail -1)
check "ticket_4 seul à T-60 h → 402 (palier 4,99 terminé depuis 12 h)" "$([ "$C" = 402 ]; echo $?)"
# fan2 a acheté ticket_6 -> billet à 6.99
rc_set '{"'"$FAN2_ID"'":{"ticket_6":[{"id":"tx-f2-6","store_transaction_id":"st-f2-6","purchase_date":"2026-01-01T00:00:00Z"}]}}'
R=$(curl -s -X POST "$API/buy-ticket" -H "Authorization: Bearer $FAN2" -H 'Content-Type: application/json' -d '{"event_id":'"$EVENT_ID"'}')
check "ticket_6 à T-60 h → billet, price_paid 6.99, reçu st-f2-6" "$(echo "$R" | jq -e '.status=="success" and .data.has_ticket==true' >/dev/null && sql "SELECT price_paid, rc_transaction_id FROM tickets WHERE user_id=$FAN2_ID" | jq -e '.[0].price_paid=="6.99" and .[0].rc_transaction_id=="st-f2-6"' >/dev/null; echo $?)"
echo "  $(sql "SELECT gross, artist_share, platform_share FROM platform_earnings WHERE source='ticket' ORDER BY id DESC LIMIT 1")"
check "platform_earnings : gross 6.99 (prix effectif, pas la base)" "$(sql "SELECT gross FROM platform_earnings WHERE source='ticket' ORDER BY id DESC LIMIT 1" | jq -e '.[0].gross=="6.99"' >/dev/null; echo $?)"

echo "## D. Tolérance de bascule : 10 min après le passage 4,99 → 6,99"
START10=$(iso_in $((72*60 - 10)))
VYBZZZ_DB="$L9_DB" node -e 'require("better-sqlite3")(process.env.VYBZZZ_DB).prepare("UPDATE events SET start_date_time=? WHERE id=?").run(process.argv[1], process.argv[2])' "$START10" "$EVENT_ID"
R=$(curl -s "$API/event/$EVENT_ID"); echo "  $(echo "$R" | jq -c '.data | {ticket_price, next_price}')"
check "prix effectif 6,99 (bascule il y a 10 min)" "$(echo "$R" | jq -e '.data.ticket_price=="6.99"' >/dev/null; echo $?)"
rc_set '{"'"$FAN3_ID"'":{"ticket_4":[{"id":"tx-f3-4","store_transaction_id":"st-f3-4","purchase_date":"2026-01-01T00:00:00Z"}]}}'
R=$(curl -s -X POST "$API/buy-ticket" -H "Authorization: Bearer $FAN3" -H 'Content-Type: application/json' -d '{"event_id":'"$EVENT_ID"'}')
check "ticket_4 accepté dans les 30 min → billet enregistré au prix payé 4.99" "$(echo "$R" | jq -e '.status=="success" and .data.has_ticket==true' >/dev/null && sql "SELECT price_paid FROM tickets WHERE user_id=$FAN3_ID" | jq -e '.[0].price_paid=="4.99"' >/dev/null; echo $?)"
check "platform_earnings du billet toléré : gross 4.99" "$(sql "SELECT gross FROM platform_earnings WHERE source='ticket' ORDER BY id DESC LIMIT 1" | jq -e '.[0].gross=="4.99"' >/dev/null; echo $?)"
grep -c "RC GET" "$RC_LOG" >/dev/null && echo "  (faux RevenueCat interrogé : $(grep -c 'RC GET' "$RC_LOG") fois)"
# 40 min après la bascule : ticket_4 refusé
START40=$(iso_in $((72*60 - 40)))
VYBZZZ_DB="$L9_DB" node -e 'require("better-sqlite3")(process.env.VYBZZZ_DB).prepare("UPDATE events SET start_date_time=? WHERE id=?").run(process.argv[1], process.argv[2])' "$START40" "$EVENT_ID"
rc_set '{"'"$FAN4_ID"'":{"ticket_4":[{"id":"tx-f4-4","store_transaction_id":"st-f4-4","purchase_date":"2026-01-01T00:00:00Z"}]}}'
C=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/buy-ticket" -H "Authorization: Bearer $FAN4" -H 'Content-Type: application/json' -d '{"event_id":'"$EVENT_ID"'}')
check "ticket_4 40 min après la bascule → 402" "$([ "$C" = 402 ]; echo $?)"

echo "## E. Roue / site : publicStatus.price, next_price, next_price_at ; web checkout au prix effectif"
VYBZZZ_DB="$L9_DB" node -e 'require("./src/services/wheel").linkEvent("dj-wilson", Number(process.argv[1]))' "$EVENT_ID"
R=$(curl -s "$API/campaign/dj-wilson"); echo "  $(echo "$R" | jq -c '.data | {price, next_price, next_price_at, event_id}')"
check "publicStatus : price 6.99, next_price 9.99, next_price_at = début − 48 h" "$(echo "$R" | jq -e --arg exp "$(node -e 'console.log(new Date(Date.parse(process.argv[1])-48*3600e3).toISOString())' "$START40")" '.data.price=="6.99" and .data.next_price=="9.99" and .data.next_price_at==$exp' >/dev/null; echo $?)"
R=$(VYBZZZ_DB="$L9_DB" node -e '
const stripe = require("./src/services/stripe");
stripe.isConfigured = () => true;
stripe.createTicketCheckout = async (args) => { console.log(JSON.stringify({ amountCents: args.amountCents })); return { id: "cs_test_l9", url: "https://stripe.test/x" }; };
require("./src/services/web_tickets").createCheckout({ eventId: Number(process.argv[1]), rawEmail: "l9.web@test.local", campaign: "dj-wilson" }).then((r) => console.log(JSON.stringify(r)));' "$EVENT_ID")
echo "  $(echo "$R" | tr '\n' ' ')"
check "createCheckout facture 699 centimes (prix effectif) et enregistre 6.99" "$(echo "$R" | head -1 | jq -e '.amountCents==699' >/dev/null && sql "SELECT amount FROM web_ticket_orders WHERE stripe_session_id='cs_test_l9'" | jq -e '.[0].amount=="6.99"' >/dev/null; echo $?)"

echo "## F. Admin : POST/PUT /admin/events avec grille, liste enrichie, replay-mp4"
C=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/admin/events" -H "Authorization: Bearer $ADMIN" -H 'Content-Type: application/json' -d '{"name":"Admin bad","ticket_price":"4.99","start_date_time":"2026-12-01 20:00:00","tz_offset_minutes":"0","price_schedule":"[{\"hours_before\":24,\"price\":\"3.50\"}]"}')
check "admin : prix hors grille → 422" "$([ "$C" = 422 ]; echo $?)"
R=$(curl -s -X POST "$API/admin/events" -H "Authorization: Bearer $ADMIN" -H 'Content-Type: application/json' -d '{"name":"Admin ok","ticket_price":"4.99","start_date_time":"2026-12-01 20:00:00","tz_offset_minutes":"0","mux_playback_id":"PLAYBACKID123","price_schedule":"'"$(echo "$SCHED" | sed 's/"/\\"/g')"'"}')
check "admin : création avec grille" "$(echo "$R" | jq -e '.status=="success"' >/dev/null; echo $?)"
ADMIN_EV=$(sql "SELECT id FROM events WHERE name='Admin ok'" | jq -r '.[0].id')
R=$(curl -s "$API/admin/events" -H "Authorization: Bearer $ADMIN" | jq -c --argjson id "$ADMIN_EV" '.data[] | select(.id==$id) | {ticket_price, effective_price, next_price, next_price_at, price_schedule, replay_mp4_url}')
echo "  $R"
check "liste admin : ticket_price = base 4.99, effective_price 4.99 (T > 72 h), next 6.99, grille liste, URL MP4 highest.mp4?download=Admin-ok" "$(echo "$R" | jq -e '.ticket_price=="4.99" and .effective_price=="4.99" and .next_price=="6.99" and (.price_schedule|length)==3 and .replay_mp4_url=="https://stream.mux.com/PLAYBACKID123/highest.mp4?download=Admin-ok"' >/dev/null; echo $?)"
C=$(curl -s -o /dev/null -w '%{http_code}' -X PUT "$API/admin/events/$ADMIN_EV" -H "Authorization: Bearer $ADMIN" -H 'Content-Type: application/json' -d '{"name":"Admin ok","ticket_price":"4.99","start_date_time":"2026-12-01 20:00:00","tz_offset_minutes":"0","price_schedule":"[]"}')
check "PUT admin : grille vidée ([]) → price_schedule NULL" "$([ "$C" = 200 ] && sql "SELECT price_schedule FROM events WHERE id=$ADMIN_EV" | jq -e '.[0].price_schedule==null' >/dev/null; echo $?)"
C=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/admin/events/$ADMIN_EV/replay-mp4" -H "Authorization: Bearer $ADMIN")
check "replay-mp4 sans mux_asset_id → 409" "$([ "$C" = 409 ]; echo $?)"
VYBZZZ_DB="$L9_DB" node -e 'require("better-sqlite3")(process.env.VYBZZZ_DB).prepare("UPDATE events SET mux_asset_id=? WHERE id=?").run("asset123", process.argv[1])' "$ADMIN_EV"
C=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/admin/events/$ADMIN_EV/replay-mp4" -H "Authorization: Bearer $ADMIN")
check "replay-mp4 avec asset mais Mux non configuré → 503" "$([ "$C" = 503 ]; echo $?)"

echo "## G. Mux : corps envoyés (fetch mocké, log du body)"
R=$(MUX_TOKEN_ID=id MUX_TOKEN_SECRET=secret node -e '
const calls = [];
global.fetch = async (url, opt) => { calls.push({ url, method: opt.method, body: JSON.parse(opt.body || "null") }); return { ok: true, text: async () => JSON.stringify({ data: { id: "ls1", stream_key: "sk", playback_ids: [{ id: "pb" }], url: "https://up", status: "preparing", name: "highest.mp4", resolution: "highest" } }) }; };
const mux = require("./src/services/mux");
(async () => {
  await mux.createLiveStream({ passthrough: { kind: "event", id: 7 } });
  await mux.createDirectUpload({ passthrough: { kind: "event", id: 7 } });
  await mux.createAssetFromUrl("https://x/y.mp4", { passthrough: { kind: "clip", id: 1 } });
  await mux.createStaticRendition("asset123");
  calls.forEach((c) => console.error("  " + c.method + " " + c.url + " " + JSON.stringify(c.body)));
  console.log(JSON.stringify({ calls, url: mux.staticRenditionUrl("pb", "DJ Wilson — Anniversaire") }));
})();' 2>&1)
echo "$R" | grep '^  POST'
J=$(echo "$R" | grep -v '^  POST')
check "createLiveStream : new_asset_settings.static_renditions = [{resolution:'highest'}] (pas de mp4_support)" "$(echo "$J" | jq -e '.calls[0].url=="https://api.mux.com/video/v1/live-streams" and .calls[0].body.new_asset_settings.static_renditions==[{"resolution":"highest"}] and (.calls[0].body.new_asset_settings|has("mp4_support")|not) and .calls[0].body.passthrough=="{\"kind\":\"event\",\"id\":7}"' >/dev/null; echo $?)"
check "createDirectUpload : idem" "$(echo "$J" | jq -e '.calls[1].body.new_asset_settings.static_renditions==[{"resolution":"highest"}]' >/dev/null; echo $?)"
check "createAssetFromUrl (clips) : ni mp4_support ni static_renditions" "$(echo "$J" | jq -e '(.calls[2].body|has("mp4_support")|not) and (.calls[2].body|has("static_renditions")|not)' >/dev/null; echo $?)"
check "createStaticRendition : POST /video/v1/assets/asset123/static-renditions {resolution:'highest'}" "$(echo "$J" | jq -e '.calls[3].url=="https://api.mux.com/video/v1/assets/asset123/static-renditions" and .calls[3].body=={"resolution":"highest"}' >/dev/null; echo $?)"
check "staticRenditionUrl : nom de fichier nettoyé" "$(echo "$J" | jq -e '.url=="https://stream.mux.com/pb/highest.mp4?download=DJ-Wilson-Anniversaire"' >/dev/null; echo $?)"

if [ "${L9_SKIP_SITE:-0}" != "1" ]; then
  echo "## H. Site (Playwright) : ligne d'urgence « Passe à 9,99 € dans 5 h 12 »"
  if NODE_PATH="${NODE_PATH:-$(npm root -g)}" PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}" node scripts/test-lot9-site.js; then PASS=$((PASS+1)); else FAILS=$((FAILS+1)); fi
fi

echo
echo "Résultat : $PASS ok, $FAILS échec(s)"
[ "$FAILS" -eq 0 ]
