'use strict';
/*
 * lib/bridge.js
 * Rôle : le lien avec le pont du serveur de jeu (ressource vava_chancellerie). Une clé aléatoire est tirée à chaque
 *        lancement de FXServer. Elle ne passe jamais sur sa ligne de commande (lisible par tout utilisateur de la
 *        machine) ni dans le server.cfg : seule l'adresse de la Chancellerie y est posée (+set). Le pont demande la clé
 *        en écrivant une marque dans la console de FXServer ; la Chancellerie, qui lit cette console, la lui donne par
 *        l'entrée de FXServer (commande de console, qui n'est pas recopiée dans la console du panneau et y serait
 *        masquée si FXServer la réaffichait). Les demandes partent vers l'adresse HTTP locale du serveur de jeu avec
 *        cette clé ; les évènements du pont ne sont acceptés que venus de la machine, avec cette même clé.
 */

const crypto = require('crypto');
const http = require('http');
const config = require('./config');

const TOKEN_BYTES = 32;
const HEADER = 'x-vava-token';
const CONVARS = { url: 'vava_chancellerie_url' };
// protocole partagé avec modules/vava_chancellerie/shared/constants.lua : ne changer l'un qu'avec l'autre
const KEY_COMMAND = 'vava_chancellerie_cle';
const KEY_ASK = 'vava_chancellerie:cle?';
// le pont répète sa demande tant que la clé n'arrive pas : une réponse au plus par intervalle
const KEY_RESEND_MS = 2000;
const PREFIX = '/vava_chancellerie';
const TIMEOUT_MS = 8000;
const RESPONSE_MAX = 4 * 1024 * 1024;
const LOOPBACK = new Set(['127.0.0.1', '::1', '::ffff:127.0.0.1']);

let token = null;
let keySentAt = 0;

/** Adresse locale du serveur de jeu : 0.0.0.0 s'interroge par 127.0.0.1. */
function localHost(bind) {
  return !bind || bind === '0.0.0.0' ? '127.0.0.1' : bind;
}

/** Nouvelle clé (gardée ici, donnée au pont quand il la demande) ; arguments de lancement : l'adresse seule. */
function launchArgs() {
  token = crypto.randomBytes(TOKEN_BYTES).toString('hex');
  keySentAt = 0;
  const { port } = config.get().http;
  return ['+set', CONVARS.url, `http://127.0.0.1:${port}`];
}

/**
 * Ligne de la console de FXServer : si le pont y demande sa clé, la commande à écrire sur l'entrée de FXServer ; sinon
 * null. Seules les lignes écrites par FXServer comptent (pas une commande tapée dans le panneau) ; une réponse au plus
 * par intervalle. Une marque écrite par une autre ressource ne fait que redonner la clé au pont, par l'entrée de
 * FXServer : elle ne sort jamais de la machine.
 * @param {{ stream: string, text: string }} line
 * @returns {string|null}
 */
function keyAnswer(line) {
  if (!token || !line || line.stream !== 'stdout' || !String(line.text).includes(KEY_ASK)) return null;
  const now = Date.now();
  if (now - keySentAt < KEY_RESEND_MS) return null;
  keySentAt = now;
  return `${KEY_COMMAND} ${token}`;
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

// au nom de qui la Chancellerie s'adresse aux joueurs (rang qui a le droit de proclamer)
const ANNOUNCER = { label: 'Chancellerie', rank: 'souverain' };

/** Proclamation à tous les joueurs, au nom de la Chancellerie (inscrite au journal du Conseil). */
function proclaim(endpoint, text) {
  return request(endpoint, 'POST', '/request', { actor: ANNOUNCER, name: 'announce', args: [text] });
}

/** Clé oubliée (FXServer arrêté) : plus aucun évènement accepté. */
function reset() {
  token = null;
  keySentAt = 0;
}

module.exports = { launchArgs, keyAnswer, secrets, verify, request, actorOf, proclaim, reset, HEADER, KEY_COMMAND, KEY_ASK };
