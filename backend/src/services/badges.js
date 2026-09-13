'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Badges du mur de fans — logique validée :
//   👑 Top Supporter   : fidélité dans le temps pour CET artiste (cadeaux + billets
//                        cumulés sur tous ses concerts). Stable pendant le show.
//   💸 Meilleur Tippeur : plus gros donateur de CE live, temps réel, avec un seuil
//                        minimum et une marge anti-clignotement (+10 %).
//   ⭐ Invité VIP      : désigné à la main par la régie, jamais calculé.
// Règles : un badge par personne, une personne par badge (VIP > Top Supporter >
// Meilleur Tippeur), égalité = le premier arrivé, et un changement de Meilleur
// Tippeur devient un « Moment » sur le Stage (déclencheur de cadeaux).
// ─────────────────────────────────────────────────────────────────────────────

const { db } = require('../db');
const bus = require('./livebus');

const MIN_TIP_POINTS = Number(process.env.BADGE_MIN_TIP_POINTS) || 100;
const MARGIN = 0.10;
const BADGES = ['top_supporter', 'best_tipper', 'vip'];

function displayName(userId) {
  const u = db.prepare('SELECT full_name, artist_name FROM users WHERE id = ?').get(userId);
  return (u && (u.artist_name || u.full_name)) || 'Un fan';
}
function getState(eventId) {
  const out = {};
  for (const r of db.prepare('SELECT badge, user_id, name, score FROM live_badge_state WHERE event_id = ?').all(eventId)) {
    out[r.badge] = { user_id: r.user_id, name: r.name, score: r.score };
  }
  return out;
}
function save(eventId, badge, holder) {
  if (!holder) { db.prepare('DELETE FROM live_badge_state WHERE event_id = ? AND badge = ?').run(eventId, badge); return; }
  db.prepare(
    `INSERT INTO live_badge_state (event_id, badge, user_id, name, score, updated_at) VALUES (?, ?, ?, ?, ?, datetime('now'))
     ON CONFLICT(event_id, badge) DO UPDATE SET user_id = excluded.user_id, name = excluded.name, score = excluded.score, updated_at = excluded.updated_at`
  ).run(eventId, badge, holder.user_id, holder.name, holder.score || 0);
}
const pub = (h) => (h ? { user_id: h.user_id, name: h.name, score: h.score } : null);
const same = (a, b) => (a ? String(a.user_id) : null) === (b ? String(b.user_id) : null);

function compute(eventId) {
  const ev = db.prepare('SELECT artist_id FROM events WHERE id = ?').get(eventId);
  if (!ev) return null;
  const state = getState(eventId);
  const vip = state.vip || null;
  const taken = new Set(vip ? [String(vip.user_id)] : []);

  // 👑 Top Supporter : historique de l'artiste (cadeaux en points + billets en €×100)
  const sup = db.prepare(
    `SELECT user_id, SUM(score) s, MIN(first_id) first_id FROM (
       SELECT a.user_id, CAST(a.points AS REAL) score, a.id first_id
         FROM activities a JOIN events e ON e.id = a.event_id
        WHERE e.artist_id = ? AND a.type = 'gift' AND a.user_id IS NOT NULL
       UNION ALL
       SELECT t.user_id, CAST(t.price_paid AS REAL) * 100 score, t.id + 1000000000 first_id
         FROM tickets t JOIN events e ON e.id = t.event_id
        WHERE e.artist_id = ? AND t.user_id IS NOT NULL
     ) GROUP BY user_id ORDER BY s DESC, first_id ASC LIMIT 5`
  ).all(ev.artist_id, ev.artist_id);
  let top = sup.find((r) => !taken.has(String(r.user_id))) || null;
  if (top) { top = { user_id: top.user_id, name: displayName(top.user_id), score: Math.round(top.s) }; taken.add(String(top.user_id)); }

  // 💸 Meilleur Tippeur : ce live, seuil mini, marge anti-clignotement
  const tips = db.prepare(
    `SELECT user_id, SUM(CAST(points AS REAL)) s, MIN(id) first_id FROM activities
      WHERE event_id = ? AND type = 'gift' AND user_id IS NOT NULL GROUP BY user_id ORDER BY s DESC, first_id ASC`
  ).all(eventId);
  const cand = tips.find((r) => !taken.has(String(r.user_id)) && r.s >= MIN_TIP_POINTS) || null;
  let tipper = state.best_tipper && !taken.has(String(state.best_tipper.user_id)) ? state.best_tipper : null;
  const curRow = tipper ? tips.find((r) => String(r.user_id) === String(tipper.user_id)) : null;
  const curScore = curRow ? curRow.s : 0;
  if (cand && (!tipper || String(cand.user_id) === String(tipper.user_id) || cand.s >= curScore * (1 + MARGIN))) {
    tipper = { user_id: cand.user_id, name: displayName(cand.user_id), score: Math.round(cand.s) };
  } else if (tipper) {
    tipper = curScore >= MIN_TIP_POINTS ? { ...tipper, score: Math.round(curScore) } : null;
  }
  return { top_supporter: top, best_tipper: tipper, vip };
}

/** Recalcule, persiste, et pousse aux écrans si quelque chose a changé. */
function refresh(eventId, { announce = true } = {}) {
  const before = getState(eventId);
  const after = compute(eventId);
  if (!after) return null;
  BADGES.forEach((b) => save(eventId, b, after[b]));
  const payload = { type: 'badges', top_supporter: pub(after.top_supporter), best_tipper: pub(after.best_tipper), vip: pub(after.vip), min_tip_points: MIN_TIP_POINTS };
  const moved = BADGES.some((b) => !same(before[b], after[b]) || ((before[b] && after[b]) && before[b].score !== after[b].score));
  if (moved) {
    bus.emit(eventId, payload);
    if (announce && after.best_tipper && !same(before.best_tipper, after.best_tipper)) {
      bus.emit(eventId, { type: 'note', user: 'VybzzZ', text: '🏆 ' + after.best_tipper.name + ' devient Meilleur Tippeur' });
    }
  }
  return payload;
}
function setVip(eventId, userId, name) {
  save(eventId, 'vip', (userId || name) ? { user_id: userId || null, name: name || displayName(userId), score: 0 } : null);
  return refresh(eventId, { announce: false });
}
function current(eventId) { const s = getState(eventId); return { top_supporter: pub(s.top_supporter), best_tipper: pub(s.best_tipper), vip: pub(s.vip), min_tip_points: MIN_TIP_POINTS }; }

module.exports = { refresh, setVip, current, MIN_TIP_POINTS };
