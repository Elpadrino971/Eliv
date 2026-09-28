'use strict';

/**
 * Sauvegarde des fichiers uploadés (avatars, covers, images d'abonnement…).
 * multer (app.js) place déjà les fichiers dans req.files. On les déplace dans
 * storage/<subfolder>/ et on renvoie l'URL publique complète servie par app.js.
 *
 * SÉCURITÉ : l'extension du fichier stocké ne vient JAMAIS du nom envoyé par
 * le client. Elle est dérivée du type RÉEL du contenu (octets de signature),
 * restreint à une liste blanche de médias. Avant, `evil.html` / `evil.svg`
 * étaient enregistrés tels quels puis servis en text/html depuis l'origine de
 * l'admin (XSS stocké -> vol du token admin en localStorage).
 */

const fs = require('fs');
const path = require('path');
const firebase = require('./services/firebase');

const PUBLIC_BASE_URL = (process.env.PUBLIC_BASE_URL || 'https://api.vybzzz.online').replace(/\/+$/, '');

// Liste blanche : type MIME réel -> extension stockée. Tout le reste est
// refusé (svg, html, js, pdf, exécutables…).
const ALLOWED_TYPES = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
  'video/mp4': '.mp4',
  'video/quicktime': '.mov',
  'video/x-m4v': '.m4v',
  'video/webm': '.webm',
  'audio/mpeg': '.mp3',
  'audio/mp4': '.m4a',
  'audio/x-m4a': '.m4a',
  'audio/aac': '.aac',
};
// Extensions acceptées côté client (filtre multer) : Flutter n'envoie pas de
// Content-Type (application/octet-stream), on se rabat donc sur l'extension
// AVANT réception ; le contenu est ensuite vérifié par sa signature.
const ALLOWED_EXT = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.mp4', '.mov', '.m4v', '.webm', '.mp3', '.m4a', '.aac']);
// Extensions servies « inline » par les dossiers statiques ; tout autre
// fichier (ancien upload .html/.svg…) part en pièce jointe.
const INLINE_MEDIA_EXT = new Set([...ALLOWED_EXT, '.heic', '.heif', '.bmp']);

function extOf(name) {
  return path.extname(String(name || '')).toLowerCase();
}

/** Filtre multer : MIME déclaré OU extension dans la liste blanche. */
function clientTypeAllowed(file) {
  const mime = String(file.mimetype || '').toLowerCase();
  if (ALLOWED_TYPES[mime]) return true;
  return ALLOWED_EXT.has(extOf(file.originalname));
}

/**
 * Type réel d'un fichier d'après ses premiers octets. null si inconnu.
 * Couvre les images/vidéos de la liste blanche + les formats audio courants.
 */
function sniffMime(filePath) {
  let fd = null;
  try {
    fd = fs.openSync(filePath, 'r');
    const buf = Buffer.alloc(16);
    const n = fs.readSync(fd, buf, 0, 16, 0);
    if (n < 4) return null;
    const hex = buf.toString('hex', 0, Math.min(n, 12));
    const ascii = buf.toString('latin1', 0, n);
    if (hex.startsWith('ffd8ff')) return 'image/jpeg';
    if (hex.startsWith('89504e470d0a1a0a')) return 'image/png';
    if (ascii.startsWith('GIF87a') || ascii.startsWith('GIF89a')) return 'image/gif';
    if (ascii.startsWith('RIFF') && ascii.slice(8, 12) === 'WEBP') return 'image/webp';
    if (hex.startsWith('1a45dfa3')) return 'video/webm'; // Matroska/WebM
    if (n >= 12 && ascii.slice(4, 8) === 'ftyp') {
      const brand = ascii.slice(8, 12);
      if (brand === 'qt  ') return 'video/quicktime';
      if (brand.startsWith('M4A')) return 'audio/mp4';
      if (brand.startsWith('M4V')) return 'video/x-m4v';
      if (/^(heic|heix|hevc|mif1|msf1|heim|heis)$/.test(brand)) return 'image/heic'; // refusé (hors liste)
      return 'video/mp4'; // isom, mp41, mp42, avc1, iso2…
    }
    if (ascii.startsWith('ID3')) return 'audio/mpeg';
    if (hex.startsWith('fffb') || hex.startsWith('fff3') || hex.startsWith('fff2')) return 'audio/mpeg';
    if (hex.startsWith('fff1') || hex.startsWith('fff9')) return 'audio/aac';
    return null;
  } catch (_) {
    return null;
  } finally {
    if (fd !== null) { try { fs.closeSync(fd); } catch (_) { /* ignore */ } }
  }
}

/**
 * Détermine le type retenu pour un upload : signature du contenu d'abord ;
 * pour l'audio seulement (signatures moins fiables), repli sur MIME déclaré +
 * extension. Renvoie { mime, ext } ou null si refusé.
 */
function resolveType(file) {
  const detected = sniffMime(file.path);
  if (detected) {
    return ALLOWED_TYPES[detected] ? { mime: detected, ext: ALLOWED_TYPES[detected] } : null;
  }
  const claimed = String(file.mimetype || '').toLowerCase();
  const ext = extOf(file.originalname);
  if (claimed.startsWith('audio/') && ALLOWED_TYPES[claimed] && ALLOWED_EXT.has(ext)) {
    return { mime: claimed, ext: ALLOWED_TYPES[claimed] };
  }
  if (claimed === 'application/octet-stream' && ['.mp3', '.m4a', '.aac'].includes(ext)) {
    const mime = ext === '.mp3' ? 'audio/mpeg' : ext === '.aac' ? 'audio/aac' : 'audio/mp4';
    return { mime, ext };
  }
  return null;
}

function discard(file) {
  try { fs.unlinkSync(file.path); } catch (_) { /* déjà supprimé */ }
}

function pickFile(req, fieldNames) {
  const files = req.files || [];
  return files.find((f) => fieldNames.includes(f.fieldname)) || null;
}

/**
 * @param {object} req        requête Express (req.files rempli par multer)
 * @param {string[]} fieldNames  noms de champ acceptés (photo, cover, image…)
 * @param {string} subfolder  dossier dans storage/ (profiles, covers, gifts, videos)
 * @param {string} urlPath    chemin public (profiles, events/covers, giftImages, events/videos)
 * @returns {string|null}     URL publique complète, ou null si aucun fichier (ou type refusé)
 */
function saveUpload(req, fieldNames, subfolder, urlPath) {
  const file = pickFile(req, fieldNames);
  if (!file) return null;
  const type = resolveType(file);
  if (!type) {
    console.warn(`[uploads] fichier refusé (type non reconnu) champ=${file.fieldname} mime=${file.mimetype || '?'} ext=${extOf(file.originalname) || '?'}`);
    discard(file);
    return null;
  }
  const destDir = path.join(__dirname, '..', 'storage', subfolder);
  fs.mkdirSync(destDir, { recursive: true });
  const filename = `${Date.now()}_${Math.floor(Math.random() * 1e9)}${type.ext}`;
  // copyFile + unlink (pas renameSync) : uploads/ et storage/ peuvent être sur
  // des filesystems differents (volume Docker separe) -> rename echoue en EXDEV.
  fs.copyFileSync(file.path, path.join(destDir, filename));
  discard(file);
  return `${PUBLIC_BASE_URL}/${urlPath}/${filename}`;
}

/**
 * Vidéo de clip (feed "Pour toi" / "Clips") : upload vers Firebase Storage
 * si configuré (léger, pas de transcodage — adapté aux clips courts), sinon
 * repli sur le disque local (comportement historique, aucune régression si
 * Firebase n'est pas encore branché).
 * @returns {Promise<{url: string, firebasePath: string|null}|null>}
 */
async function saveClipVideo(req, fieldNames) {
  const file = pickFile(req, fieldNames);
  if (!file) return null;
  const type = resolveType(file);
  if (!type || !type.mime.startsWith('video/')) {
    console.warn(`[uploads] clip refusé (pas une vidéo reconnue) mime=${file.mimetype || '?'} ext=${extOf(file.originalname) || '?'}`);
    discard(file);
    return null;
  }

  if (firebase.isConfigured()) {
    const destPath = `clips/${Date.now()}_${Math.floor(Math.random() * 1e9)}${type.ext}`;
    try {
      const url = await firebase.uploadLocalFile(file.path, destPath, type.mime);
      discard(file);
      return { url, firebasePath: destPath };
    } catch (e) {
      console.error('[firebase upload] échec, repli sur le disque local :', e.message);
      // tombe dans le repli ci-dessous (le fichier temp existe encore)
    }
  }

  const url = saveUpload(req, fieldNames, 'videos', 'events/videos');
  return url ? { url, firebasePath: null } : null;
}

// Options des dossiers statiques : tout ce qui n'est pas un média connu est
// servi en pièce jointe (jamais rendu dans le navigateur), et le type déclaré
// ne doit pas être « deviné » par le navigateur.
function staticOptions() {
  return {
    index: false,
    dotfiles: 'ignore',
    setHeaders(res, filePath) {
      res.setHeader('X-Content-Type-Options', 'nosniff');
      if (!INLINE_MEDIA_EXT.has(extOf(filePath))) {
        res.setHeader('Content-Disposition', 'attachment');
        res.setHeader('Content-Type', 'application/octet-stream');
      }
    },
  };
}

// Middleware de fin de requête : supprime les fichiers temporaires que la
// route n'a pas consommés (mauvais champ, erreur, réponse anticipée…).
function cleanupUnconsumed(req, res, next) {
  const done = () => {
    for (const f of req.files || []) {
      if (f && f.path) { try { if (fs.existsSync(f.path)) fs.unlinkSync(f.path); } catch (_) { /* ignore */ } }
    }
  };
  res.once('finish', done);
  res.once('close', done);
  next();
}

// Dossier temporaire de multer. Un fichier reçu par une route qui ne le
// consomme pas (ou une requête interrompue) y restait pour toujours ->
// remplissage du disque. Purge au démarrage de tout ce qui a plus de 24 h.
const UPLOADS_TMP_DIR = path.join(__dirname, '..', 'uploads');
function purgeOrphanUploads(maxAgeMs = 24 * 60 * 60 * 1000) {
  let removed = 0;
  try {
    if (!fs.existsSync(UPLOADS_TMP_DIR)) return 0;
    const cutoff = Date.now() - maxAgeMs;
    for (const name of fs.readdirSync(UPLOADS_TMP_DIR)) {
      const p = path.join(UPLOADS_TMP_DIR, name);
      try {
        const st = fs.statSync(p);
        if (st.isFile() && st.mtimeMs < cutoff) { fs.unlinkSync(p); removed += 1; }
      } catch (_) { /* fichier disparu entre-temps */ }
    }
    if (removed) console.log(`[uploads] ${removed} fichier(s) temporaire(s) orphelin(s) purgé(s).`);
  } catch (e) {
    console.warn('[uploads] purge des orphelins impossible :', e.message);
  }
  return removed;
}

module.exports = {
  saveUpload,
  saveClipVideo,
  purgeOrphanUploads,
  clientTypeAllowed,
  sniffMime,
  resolveType,
  staticOptions,
  cleanupUnconsumed,
  PUBLIC_BASE_URL,
  UPLOADS_TMP_DIR,
};
