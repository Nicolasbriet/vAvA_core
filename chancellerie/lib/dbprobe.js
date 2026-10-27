'use strict';
/*
 * lib/dbprobe.js
 * Rôle : « la base de données répond-elle ? » pour l'assistant. Ouvre une connexion TCP et lit le message
 *        d'accueil du serveur MySQL / MariaDB (sa version), puis referme aussitôt : aucun identifiant n'est
 *        envoyé. Les identifiants eux-mêmes sont vérifiés par oxmysql au démarrage du serveur.
 */

const net = require('net');

const TIMEOUT_MS = 3000;
const HEADER_BYTES = 4;
const PROTOCOL_10 = 10;
const ERROR_PACKET = 0xff;

/**
 * @param {string} host
 * @param {number} port
 * @returns {Promise<{ ok: true, version: string } | { ok: false, error: string }>}
 */
function probe(host, port) {
  return new Promise((resolve) => {
    let settled = false;
    let buffer = Buffer.alloc(0);
    const socket = net.connect({ host, port, timeout: TIMEOUT_MS });
    const finish = (result) => {
      if (settled) return;
      settled = true;
      socket.destroy();
      resolve(result);
    };
    socket.on('data', (chunk) => {
      buffer = Buffer.concat([buffer, chunk]);
      if (buffer.length < HEADER_BYTES) return;
      const length = buffer.readUIntLE(0, 3);
      if (buffer.length < HEADER_BYTES + length) return;
      const payload = buffer.subarray(HEADER_BYTES, HEADER_BYTES + length);
      if (payload[0] === ERROR_PACKET) {
        // le serveur refuse cette machine (hôte non autorisé, trop de connexions…)
        finish({ ok: false, error: 'db_refused' });
      } else if (payload[0] === PROTOCOL_10) {
        const end = payload.indexOf(0, 1);
        finish({ ok: true, version: payload.subarray(1, end === -1 ? payload.length : end).toString('latin1').slice(0, 80) });
      } else {
        finish({ ok: false, error: 'db_not_mysql' });
      }
    });
    socket.on('timeout', () => finish({ ok: false, error: 'db_timeout' }));
    socket.on('error', (error) => finish({ ok: false, error: error.code === 'ECONNREFUSED' ? 'db_unreachable' : 'db_error' }));
    socket.on('close', () => finish({ ok: false, error: 'db_not_mysql' }));
  });
}

module.exports = { probe };
