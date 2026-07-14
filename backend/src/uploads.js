'use strict';

/**
 * Sauvegarde des fichiers uploadés (avatars, covers, images d'abonnement…).
 * multer (app.js) place déjà les fichiers dans req.files. On les déplace dans
 * storage/<subfolder>/ et on renvoie l'URL publique complète servie par app.js.
 */

const fs = require('fs');
const path = require('path');
const firebase = require('./services/firebase');

const PUBLIC_BASE_URL = (process.env.PUBLIC_BASE_URL || 'https://api.vybzzz.online').replace(/\/+$/, '');

/**
 * @param {object} req        requête Express (req.files rempli par multer)
 * @param {string[]} fieldNames  noms de champ acceptés (photo, cover, image…)
 * @param {string} subfolder  dossier dans storage/ (profiles, covers, gifts, videos)
 * @param {string} urlPath    chemin public (profiles, events/covers, giftImages, events/videos)
 * @returns {string|null}     URL publique complète, ou null si aucun fichier
 */
function saveUpload(req, fieldNames, subfolder, urlPath) {
  const files = req.files || [];
  const file = files.find((f) => fieldNames.includes(f.fieldname));
  if (!file) return null;
  const destDir = path.join(__dirname, '..', 'storage', subfolder);
  fs.mkdirSync(destDir, { recursive: true });
  let ext = path.extname(file.originalname || '').toLowerCase();
  if (!ext || ext.length > 6) ext = '.jpg';
  const filename = `${Date.now()}_${Math.floor(Math.random() * 1e9)}${ext}`;
  // copyFile + unlink (pas renameSync) : uploads/ et storage/ peuvent être sur
  // des filesystems differents (volume Docker separe) -> rename echoue en EXDEV.
  fs.copyFileSync(file.path, path.join(destDir, filename));
  fs.unlinkSync(file.path);
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
  const files = req.files || [];
  const file = files.find((f) => fieldNames.includes(f.fieldname));
  if (!file) return null;

  if (firebase.isConfigured()) {
    let ext = path.extname(file.originalname || '').toLowerCase();
    if (!ext || ext.length > 6) ext = '.mp4';
    const destPath = `clips/${Date.now()}_${Math.floor(Math.random() * 1e9)}${ext}`;
    try {
      const url = await firebase.uploadLocalFile(file.path, destPath, file.mimetype || 'video/mp4');
      fs.unlinkSync(file.path);
      return { url, firebasePath: destPath };
    } catch (e) {
      console.error('[firebase upload] échec, repli sur le disque local :', e.message);
      // tombe dans le repli ci-dessous (le fichier temp existe encore)
    }
  }

  const url = saveUpload(req, fieldNames, 'videos', 'events/videos');
  return url ? { url, firebasePath: null } : null;
}

module.exports = { saveUpload, saveClipVideo, PUBLIC_BASE_URL };
