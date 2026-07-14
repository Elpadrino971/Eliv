'use strict';

/**
 * Firebase Storage (Admin SDK) — stockage des clips utilisateur/admin du
 * feed ("Pour toi" / "Clips"), plus léger et moins cher que Mux pour de
 * courtes vidéos brutes (pas d'encodage adaptatif nécessaire). Les concerts
 * / replays restent sur Mux (voir services/mux.js).
 *
 * Le fichier de clé de compte de service (JSON) ne doit jamais être commité
 * ni monté en volume : on le passe en base64 dans une seule variable d'env
 * (FIREBASE_SERVICE_ACCOUNT_BASE64), plus simple à gérer que Mux/Stripe qui
 * n'ont qu'un secret texte.
 */

const admin = require('firebase-admin');

const STORAGE_BUCKET = process.env.FIREBASE_STORAGE_BUCKET;
const SERVICE_ACCOUNT_B64 = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;

let bucket = null;

function isConfigured() {
  return Boolean(STORAGE_BUCKET && SERVICE_ACCOUNT_B64);
}

function getBucket() {
  if (!isConfigured()) {
    const err = new Error('Firebase non configuré (FIREBASE_STORAGE_BUCKET / FIREBASE_SERVICE_ACCOUNT_BASE64 manquant).');
    err.code = 'FIREBASE_NOT_CONFIGURED';
    throw err;
  }
  if (!bucket) {
    const serviceAccount = JSON.parse(Buffer.from(SERVICE_ACCOUNT_B64, 'base64').toString('utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      storageBucket: STORAGE_BUCKET,
    });
    bucket = admin.storage().bucket();
  }
  return bucket;
}

/**
 * Upload un fichier local (chemin disque, ex. venant de multer) vers
 * Firebase Storage, le rend public, renvoie l'URL publique directe.
 */
async function uploadLocalFile(localPath, destPath, contentType) {
  const b = getBucket();
  await b.upload(localPath, { destination: destPath, metadata: { contentType } });
  const file = b.file(destPath);
  await file.makePublic();
  return `https://storage.googleapis.com/${b.name}/${destPath}`;
}

async function deleteFile(destPath) {
  const b = getBucket();
  await b.file(destPath).delete({ ignoreNotFound: true });
}

module.exports = { isConfigured, uploadLocalFile, deleteFile };
