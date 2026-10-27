'use strict';
/*
 * lib/status.js
 * Rôle : ce que dit le serveur de jeu lui-même, par ses adresses publiques (players.json) : joueurs connectés,
 *        réduits au numéro, au nom et à la latence (aucun identifiant ni adresse). Réponse gardée quelques
 *        secondes : plusieurs navigateurs ouverts n'interrogent pas le serveur plus souvent.
 */

const http = require('http');

const CACHE_MS = 5000;
const TIMEOUT_MS = 2500;
const BODY_MAX = 2 * 1024 * 1024;

let cache = { key: '', at: 0, value: null };

/** Adresse locale du serveur de jeu : 0.0.0.0 s'interroge par 127.0.0.1. */
function localHost(bind) {
  return !bind || bind === '0.0.0.0' ? '127.0.0.1' : bind;
}

function getJson(host, port, route) {
  return new Promise((resolve) => {
    const request = http.get({ host, port, path: route, timeout: TIMEOUT_MS }, (response) => {
      if (response.statusCode !== 200) {
        response.resume();
        resolve(null);
        return;
      }
      let size = 0;
      const chunks = [];
      response.on('data', (chunk) => {
        size += chunk.length;
        if (size > BODY_MAX) request.destroy();
        else chunks.push(chunk);
      });
      response.on('end', () => {
        try {
          resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
        } catch (error) {
          resolve(null);
        }
      });
    });
    request.on('timeout', () => request.destroy());
    request.on('error', () => resolve(null));
  });
}

/**
 * Joueurs connectés : [{ id, name, ping }], ou null si le serveur ne répond pas.
 * @param {{ bind: string, port: number }} endpoint
 */
async function players(endpoint) {
  const key = `${endpoint.bind}:${endpoint.port}`;
  if (cache.key === key && Date.now() - cache.at < CACHE_MS) return cache.value;
  const list = await getJson(localHost(endpoint.bind), endpoint.port, '/players.json');
  const value = Array.isArray(list)
    ? list.map((p) => ({ id: Number(p.id) || 0, name: String(p.name || '').slice(0, 64), ping: Number(p.ping) || 0 })).sort((a, b) => a.id - b.id)
    : null;
  cache = { key, at: Date.now(), value };
  return value;
}

/** Oublie la dernière réponse (serveur arrêté ou relancé). */
function reset() {
  cache = { key: '', at: 0, value: null };
}

module.exports = { players, reset };
