'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Bus temps réel minimal (en mémoire, aucune dépendance).
//
// Le backend PUBLIE des événements "live" par concert (cadeau envoyé, billet
// acheté, …) au moment où ils sont CONFIRMÉS et inscrits en base ; les écrans
// Stage / Régie s'y ABONNENT en SSE (Server-Sent Events) via routes/live.routes.
// Un seul process Node -> suffisant pour le VPS. Si un jour on passe en
// multi-instances, remplacer la Map par Redis pub/sub sans toucher aux appelants.
// ─────────────────────────────────────────────────────────────────────────────

const clients = new Map(); // channel (event_id ou '*') -> Set<res>

function channel(id) {
  const key = String(id);
  if (!clients.has(key)) clients.set(key, new Set());
  return clients.get(key);
}

/** Abonne une réponse HTTP (déjà en mode SSE) aux événements d'un concert. */
function subscribe(eventId, res) {
  const set = channel(eventId);
  set.add(res);
  res.on('close', () => { set.delete(res); });
}

/** Publie un événement à tous les abonnés du concert (+ au canal global '*'). */
function emit(eventId, payload) {
  const type = (payload && payload.type) || 'message';
  const data = JSON.stringify({ ...payload, event_id: String(eventId), at: new Date().toISOString() });
  const frame = `event: ${type}\ndata: ${data}\n\n`;
  const targets = new Set([...channel(eventId), ...channel('*')]);
  for (const res of targets) {
    try { res.write(frame); } catch (_) { targets.delete(res); }
  }
  return targets.size;
}

/** Nombre d'écrans abonnés à un concert (utile pour un compteur / debug). */
function count(eventId) { return channel(eventId).size; }

module.exports = { subscribe, emit, count };
