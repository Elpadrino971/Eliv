'use strict';

/**
 * Génération de Kit Token ZegoCloud côté serveur (algorithme "Token04"
 * officiel Zego : en-tête binaire + AES-256-CBC, base64 préfixé "04").
 * Le ServerSecret ne quitte JAMAIS le backend — l'app ne reçoit qu'un token
 * à durée de vie courte. Remplace l'usage de `appSign` en clair dans l'app
 * (un appSign extrait par décompilation permet de générer des tokens
 * illimités sur le compte Zego -> risque de facturation frauduleuse).
 *
 * ATTENTION : ServerSecret != AppSign. Dans la Console Zego, c'est un champ
 * distinct (32 caractères), dédié à la génération de token côté serveur.
 */

const crypto = require('crypto');

const ZEGO_APP_ID = Number(process.env.ZEGO_APP_ID) || 0;
const ZEGO_SERVER_SECRET = process.env.ZEGO_SERVER_SECRET;

function isConfigured() {
  return Boolean(ZEGO_APP_ID && ZEGO_SERVER_SECRET && ZEGO_SERVER_SECRET.length === 32);
}

function generateToken04(userId, effectiveSeconds = 4 * 3600, payload = '') {
  if (!isConfigured()) {
    const err = new Error('ZegoCloud non configuré (ZEGO_APP_ID/ZEGO_SERVER_SECRET manquant ou ServerSecret invalide, doit faire exactement 32 caractères).');
    err.code = 'ZEGO_NOT_CONFIGURED';
    throw err;
  }
  const createTime = Math.floor(Date.now() / 1000);
  const expireTime = createTime + effectiveSeconds;

  const tokenInfo = {
    app_id: ZEGO_APP_ID,
    user_id: String(userId),
    nonce: crypto.randomInt(0, 2147483647),
    ctime: createTime,
    expire: expireTime,
    payload,
  };

  const plaintext = Buffer.from(JSON.stringify(tokenInfo), 'utf8');
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-cbc', Buffer.from(ZEGO_SERVER_SECRET, 'utf8'), iv);
  const encrypted = Buffer.concat([cipher.update(plaintext), cipher.final()]);

  // Le buffer binaire NE CONTIENT PAS le numéro de version : "04" n'est
  // qu'un préfixe texte ajouté après le base64 (cf. implémentation Node.js
  // officielle ZEGOCLOUD/zego_server_assistant, token/nodejs/server/
  // zegoServerAssistant.js). Un ancien writeUInt16BE(4, ...) ici décalait
  // tous les champs suivants de 2 octets -> le serveur Zego rejette le
  // token (errorCode != 0) même si notre propre décodage restait cohérent.
  const buf = Buffer.alloc(8 + 2 + iv.length + 2 + encrypted.length);
  let offset = 0;
  buf.writeBigInt64BE(BigInt(expireTime), offset); offset += 8;
  buf.writeUInt16BE(iv.length, offset); offset += 2;
  iv.copy(buf, offset); offset += iv.length;
  buf.writeUInt16BE(encrypted.length, offset); offset += 2;
  encrypted.copy(buf, offset); offset += encrypted.length;

  return { token: `04${buf.toString('base64')}`, appId: ZEGO_APP_ID, expiresAt: expireTime };
}

module.exports = { isConfigured, generateToken04 };
