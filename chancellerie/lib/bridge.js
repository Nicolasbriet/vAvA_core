'use strict';
/*
 * lib/bridge.js
 * Rôle : le lien avec le pont du serveur de jeu (ressource vava_chancellerie). Une clé aléatoire est tirée à chaque
 *        lancement de FXServer. Elle ne passe jamais sur sa ligne de commande (lisible par tout utilisateur de la
 *        machine) ni dans le server.cfg : seule l'adresse de la Chancellerie y est posée (+set). Le pont demande la clé
 *        en écrivant une marque dans la console de FXServer ; la Chancellerie, qui lit cette console, la lui donne par
 *        l'entrée de FXServer (commande de console, qui n'est pas recopiée dans la console du panneau et y serait
 *        masquée si FXServer la réaffichait), une fois par démarrage du pont. Les demandes partent vers l'adresse HTTP
 *        locale du serveur de jeu avec cette clé ; les évènements du pont ne sont acceptés que venus de la machine, avec
 *        cette même clé. Si le pont ne prend pas la clé (une autre l'a devancée, pas de confirmation), une alerte est
 *        levée (`alerts`).
 */

const crypto = require('crypto');
const EventEmitter = require('events');
const http = require('http');
const config = require('./config');

const TOKEN_BYTES = 32;
const HEADER = 'x-vava-token';
const CONVARS = { url: 'vava_chancellerie_url' };
// protocole partagé avec modules/vava_chancellerie/shared/constants.lua (relu par tests/spec/chancellerie_rules_spec.lua) :
// ne changer l'un qu'avec l'autre
const KEY_COMMAND = 'vava_chancellerie_cle';
const KEY_ASK = 'vava_chancellerie:cle?';
const KEY_ASK_LINE = 'en attente de la clé de la Chancellerie (vava_chancellerie:cle?)';
const KEY_CONFLICT_LINE = 'une autre clé du pont a été refusée : la première reçue est gardée';
// ligne écrite par print() dans le pont : « [script:vava_chancellerie] texte » (nom parfois complété d'espaces ou abrégé)
const escape = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const bridgeLine = (text) => new RegExp(`^\\[\\s*script:vava_chan[a-z_]*\\] ${escape(text)}$`);
const ASK_PATTERN = bridgeLine(KEY_ASK_LINE);
const CONFLICT_PATTERN = bridgeLine(KEY_CONFLICT_LINE);
// la ressource du pont démarre ou s'arrête (restart vava_chancellerie) : elle redemandera sa clé
const BRIDGE_RESTART_PATTERN = /(?:^|\] )(?:Started|Stopping) resource vava_chancellerie$/;
const ANSI_PATTERN = /\x1b\[[0-9;]*[A-Za-z]/g;
// le pont répète sa demande tant que la clé n'arrive pas : une réponse au plus par intervalle
const KEY_RESEND_MS = 2000;
// clé donnée : le pont doit prévenir (évènement `ready` vérifié) dans ce délai, sinon alerte
const READY_WAIT_MS = 15000;
const PREFIX = '/vava_chancellerie';
const TIMEOUT_MS = 8000;
const RESPONSE_MAX = 4 * 1024 * 1024;
const LOOPBACK = new Set(['127.0.0.1', '::1', '::ffff:127.0.0.1']);

// Alertes pour le panneau (index.js les montre dans la console, au journal et aux navigateurs) : la clé de la
// Chancellerie n'a pas été prise par le pont. Une ressource serveur hostile peut l'avoir devancée : ceci ne fait que le
// signaler, rien ici ne protège d'une ressource serveur, qui a déjà tous les pouvoirs sur le serveur.
const ALERTS = Object.freeze({
  conflict: 'Le pont a refusé la clé de la Chancellerie : une autre lui avait été donnée avant. Une ressource du serveur l\'a peut-être prise : vérifiez les ressources lancées, puis redémarrez le serveur.',
  noReady: 'Le pont n\'a pas confirmé la clé de la Chancellerie : les pages du royaume ne répondront pas. Redémarrez le serveur ; si cela se répète, vérifiez les ressources lancées.',
  foreign: 'Un évènement du pont est arrivé avec une autre clé que celle de la Chancellerie : une ressource du serveur l\'a peut-être prise. Vérifiez les ressources lancées, puis redémarrez le serveur.',
  unexpectedAsk: 'Le pont redemande sa clé sans redémarrage repéré : elle ne lui est pas redonnée. S\'il ne répond plus, redémarrez le serveur depuis la Chancellerie.',
});
const alerts = new EventEmitter();

let token = null;
let keySentAt = 0;
// vrai tant que le pont n'a pas confirmé la clé (évènement `ready` vérifié) depuis le lancement ou son redémarrage
let armed = false;
let readyTimer = null;
const raised = new Set();

/** Adresse locale du serveur de jeu : 0.0.0.0 s'interroge par 127.0.0.1. */
function localHost(bind) {
  return !bind || bind === '0.0.0.0' ? '127.0.0.1' : bind;
}

/** Alerte, une fois par sorte jusqu'au prochain lancement ou redémarrage du pont. */
function alert(kind) {
  if (raised.has(kind)) return;
  raised.add(kind);
  alerts.emit('alert', { kind, text: ALERTS[kind] });
}

function clearReadyTimer() {
  clearTimeout(readyTimer);
  readyTimer = null;
}

/** Le pont (re)démarre : il demandera sa clé, qui lui sera donnée une fois. */
function arm() {
  armed = true;
  keySentAt = 0;
  raised.clear();
  clearReadyTimer();
}

/** Nouvelle clé (gardée ici, donnée au pont quand il la demande) ; arguments de lancement : l'adresse seule. */
function launchArgs() {
  token = crypto.randomBytes(TOKEN_BYTES).toString('hex');
  arm();
  const { port } = config.get().http;
  return ['+set', CONVARS.url, `http://127.0.0.1:${port}`];
}

/**
 * Ligne de la console de FXServer : si le pont y demande sa clé, la commande à écrire sur l'entrée de FXServer ; sinon
 * null. Seules les lignes écrites par FXServer comptent (pas une commande tapée dans le panneau), et seulement la ligne
 * exacte du pont ; une réponse au plus par intervalle, aucune une fois la clé confirmée (`ready` vérifié) jusqu'au
 * prochain lancement ou redémarrage du pont. Une marque écrite par une autre ressource ne fait que redonner la clé au
 * pont, par l'entrée de FXServer : elle ne sort jamais de la machine. Lève aussi les alertes (refus de la clé).
 * @param {{ stream: string, text: string }} line
 * @returns {string|null}
 */
function keyAnswer(line) {
  if (!token || !line || line.stream !== 'stdout') return null;
  const text = String(line.text).replace(ANSI_PATTERN, '').trim();
  if (BRIDGE_RESTART_PATTERN.test(text)) {
    arm();
    return null;
  }
  if (CONFLICT_PATTERN.test(text)) {
    alert('conflict');
    return null;
  }
  if (!ASK_PATTERN.test(text)) return null;
  if (!armed) {
    alert('unexpectedAsk');
    return null;
  }
  const now = Date.now();
  if (now - keySentAt < KEY_RESEND_MS) return null;
  keySentAt = now;
  if (!readyTimer) {
    readyTimer = setTimeout(() => {
      readyTimer = null;
      if (armed && token) alert('noReady');
    }, READY_WAIT_MS);
    readyTimer.unref();
  }
  return `${KEY_COMMAND} ${token}`;
}

/** Évènement `ready` vérifié (avec la clé) : le pont a sa clé ; plus de réponse à sa marque jusqu'à son redémarrage. */
function confirmed() {
  armed = false;
  clearReadyTimer();
}

/** Secrets à masquer dans la console (la clé, si FXServer la réaffichait). */
function secrets() {
  return token ? [token] : [];
}

/**
 * Évènement du pont : venu de la machine, avec la clé du lancement en cours ? Venu de la machine avec une autre clé :
 * alerte (le pont a peut-être reçu une clé qui n'est pas la nôtre).
 */
function verify(req) {
  if (!token || !LOOPBACK.has(req.socket.remoteAddress)) return false;
  const given = Buffer.from(String(req.headers[HEADER] || ''));
  const expected = Buffer.from(token);
  const ok = given.length === expected.length && crypto.timingSafeEqual(given, expected);
  if (!ok && given.length > 0) alert('foreign');
  return ok;
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
  armed = false;
  clearReadyTimer();
}

module.exports = {
  launchArgs, keyAnswer, confirmed, secrets, verify, request, actorOf, proclaim, reset, alerts,
  HEADER, KEY_COMMAND, KEY_ASK, KEY_ASK_LINE, KEY_CONFLICT_LINE,
};
