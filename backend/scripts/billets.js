const Database = require('better-sqlite3');
const db = new Database(process.env.VYBZZZ_DB || '/data/vybzzz.sqlite', { readonly: true });
const ev = Number(process.env.EV || 12);
const e = db.prepare('SELECT id, name FROM events WHERE id = ?').get(ev);
console.log('\n=== ' + (e ? e.name : 'concert #' + ev) + ' (#' + ev + ') ===\n');
const t = db.prepare(`SELECT u.email, COALESCE(u.full_name,'') AS nom, t.price_paid, t.created_at
  FROM tickets t JOIN users u ON u.id = t.user_id WHERE t.event_id = ? AND t.status = 'active' ORDER BY t.created_at`).all(ev);
console.log('BILLETS (compte VybzzZ, place active) : ' + t.length);
t.forEach((r, i) => console.log(String(i + 1).padStart(3) + '. ' + r.email + '  ' + r.nom + '  ' + (r.price_paid || '0') + ' €  ' + r.created_at));
const p = db.prepare(`SELECT email, source, price_paid, created_at FROM pending_tickets
  WHERE event_id = ? AND granted_at IS NULL ORDER BY created_at`).all(ev);
console.log('\nEN ATTENTE (place réservée, pas encore de compte avec cet e-mail) : ' + p.length);
p.forEach((r, i) => console.log(String(i + 1).padStart(3) + '. ' + r.email + '  ' + r.source + '  ' + (r.price_paid || '0') + ' €  ' + r.created_at));
const paid = t.filter(r => parseFloat(r.price_paid) > 0).length;
console.log('\nTotal places : ' + (t.length + p.length) + '  (payées : ' + paid + ', offertes/gagnées : ' + (t.length - paid) + ', en attente : ' + p.length + ')\n');
