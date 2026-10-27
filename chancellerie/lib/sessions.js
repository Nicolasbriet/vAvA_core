'use strict';
/*
 * lib/sessions.js
 * Rôle : sessions de connexion, gardées en mémoire seulement (un redémarrage de la Chancellerie demande de se
 *        reconnecter). Jeton aléatoire de 32 octets, expiration après inactivité et durée maximale.
 */

const crypto = require('crypto');

const IDLE_MS = 12 * 60 * 60 * 1000;
const MAX_MS = 7 * 24 * 60 * 60 * 1000;
const TOKEN_BYTES = 32;

/** @type {Map<string, { name: string, createdAt: number, seenAt: number }>} */
const sessions = new Map();

/** Session valide pour ce jeton, sans la prolonger (un flux ouvert ne compte pas comme une activité). */
function peek(token) {
  if (typeof token !== 'string') return null;
  const session = sessions.get(token);
  if (!session) return null;
  const now = Date.now();
  if (now - session.seenAt > IDLE_MS || now - session.createdAt > MAX_MS) {
    sessions.delete(token);
    return null;
  }
  return session;
}

module.exports = {
  COOKIE: 'chancellerie',
  MAX_AGE_S: Math.floor(MAX_MS / 1000),
  peek,

  create(name) {
    const token = crypto.randomBytes(TOKEN_BYTES).toString('hex');
    const now = Date.now();
    sessions.set(token, { name, createdAt: now, seenAt: now });
    return token;
  },

  /** Session valide pour ce jeton (et prolongée), ou null. */
  get(token) {
    const session = peek(token);
    if (session) session.seenAt = Date.now();
    return session;
  },

  destroy(token) {
    sessions.delete(token);
  },

  /** Ferme les sessions d'un compte (mot de passe changé, compte supprimé), sauf celle-ci ; renvoie leurs jetons. */
  destroyFor(name, exceptToken) {
    const closed = [];
    for (const [token, session] of sessions) {
      if (token !== exceptToken && session.name.toLowerCase() === String(name).toLowerCase()) {
        sessions.delete(token);
        closed.push(token);
      }
    }
    return closed;
  },
};
