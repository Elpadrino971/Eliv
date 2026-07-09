'use strict';

/**
 * Sauvegarde des fichiers uploadés (avatars, covers, images d'abonnement…).
 * multer (app.js) place déjà les fichiers dans req.files. On les déplace dans
 * storage/<subfolder>/ et on renvoie l'URL publique complète servie par app.js.
 */

const fs = require('fs');
const path = require('path');

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

module.exports = { saveUpload, PUBLIC_BASE_URL };
