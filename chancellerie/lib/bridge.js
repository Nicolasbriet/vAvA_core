'use strict';
/*
 * lib/bridge.js
 * Rôle : le lien avec le pont du serveur de jeu (ressource vava_chancellerie). Une clé aléatoire est tirée à chaque
 *        lancement de FXServer et lui est passée sur la ligne de commande (+set, jamais dans le server.cfg), avec
 *        l'adresse de la Chancellerie. Les demandes partent vers l'adresse HTTP locale du serveur de jeu avec cette
 *        clé ; les évènements du pont ne sont acceptés que venus de la machine, avec cette même clé.
 */

const crypto = require('crypto');
const http = require('http');
const config = require('./config');

const TOKEN_BYTES = 32;
const HEADER = 'x-vava-token';
const CONVARS = { token: 'vava_chancellerie_token', url: 'vava_chancellerie_url' };
const PREFIX = '/vava_chancellerie';
const TIMEOUT_MS = 8000;
const RESPONSE_MAX = 4 * 1024 * 1024;
const LOOPBACK = new Set(['127.0.0.1', '::1', '::ffff:127.0.0.1']);

let token = null;

/** Adresse locale du serveur de jeu : 0.0.0.0 s'interroge par 127.0.0.1. */
function localHost(bind) {
  return !bind || bind === '0.0.0.0' ? '127.0.0.1' : bind;
}

/** Nouvelle clé et arguments de lancement de FXServer qui la portent. */
function launchArgs() {
  token = crypto.randomBytes(TOKEN_BYTES).toString('hex');
  const { port } = config.get().http;
  return ['+set', CONVARS.token, token, '+set', CONVARS.url, `http://127.0.0.1:${port}`];
}

/** Secrets à masquer dans la console (la clé, si FXServer la réaffichait). */
function secrets() {
  return token ? [token] : [];
}

/** Évènement du pont : venu de la machine, avec la clé du lancement en cours ? */
function verify(req) {
  if (!token || !LOOPBACK.has(req.socket.remoteAddress)) return false;
  const given = Buffer.from(String(req.headers[HEADER] || ''));
  const expected = Buffer.from(token);
  return given.length === expected.length && crypto.timingSafeEqual(given, expected);
}

/**
 * Demande au pont. Résultat toujours de la forme { ok, … } ; jamais d'exception.
 * @param {{ bind: string, port: number }} endpoint  adresse du serveur de jeu (server.cfg)
 * @param {string} method
 * @param {string} route  /request, /ranks, /camera/start…
 * @param {object} [body]
 */
function request(endpoint, method, route, body) {
  return new Promise((resolve) => {
    if (!token || !endpoint) {
      resolve({ ok: false, error: 'server_stopped' });
      return;
    }
    const payload = body === undefined ? null : JSON.stringify(body);
    const req = http.request({
      host: localHost(endpoint.bind), port: endpoint.port, method, path: PREFIX + route, timeout: TIMEOUT_MS,
      headers: { [HEADER]: token, ...(payload !== null ? { 'content-type': 'application/json', 'content-length': Buffer.byteLength(payload) } : {}) },
    }, (res) => {
      let size = 0;
      const chunks = [];
      res.on('data', (chunk) => {
        size += chunk.length;
        if (size > RESPONSE_MAX) req.destroy();
        else chunks.push(chunk);
      });
      res.on('end', () => {
        let parsed = null;
        try {
          parsed = JSON.parse(Buffer.concat(chunks).toString('utf8'));
        } catch (error) {
          parsed = null;
        }
        if (res.statusCode === 404 && !parsed) resolve({ ok: false, error: 'bridge_missing' });
        else if (!parsed || typeof parsed !== 'object') resolve({ ok: false, error: 'bridge_error' });
        else resolve(parsed);
      });
    });
    req.on('timeout', () => req.destroy());
    req.on('error', () => resolve({ ok: false, error: 'bridge_unreachable' }));
    if (payload !== null) req.write(payload);
    req.end();
  });
}

/** Acteur d'un compte du panneau pour le Registre : { label, rank }. */
function actorOf(account) {
  return { label: account.name, rank: account.rank };
}

/** Clé oubliée (FXServer arrêté) : plus aucun évènement accepté. */
function reset() {
  token = null;
}

module.exports = { launchArgs, secrets, verify, request, actorOf, reset, HEADER };
