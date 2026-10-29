'use strict';
/*
 * lib/camera.js
 * Rôle : caméras sur l'écran des joueurs, côté Chancellerie. Chaque caméra appartient à la session de navigateur qui
 *        l'a ouverte : elle seule reçoit l'offre du joueur filmé et peut répondre ou l'arrêter. Une session regarde
 *        au plus un mur complet (seize cases) et une vue en grand. La Chancellerie ne relaie que la négociation
 *        WebRTC ; l'image va directement du jeu du joueur au navigateur. Les caméras d'une session s'éteignent quand
 *        son dernier flux d'évènements se ferme (onglet fermé, déconnexion) ; celles d'un compte qui perd le droit de
 *        regarder s'éteignent quand un rang du Conseil change (le pont le signale ; chaque compte qui regarde est
 *        revérifié avec son rang actuel, comme en jeu).
 */

const accounts = require('./accounts');
const bridge = require('./bridge');
const events = require('./events');
const servercfg = require('./servercfg');

// un mur 4 × 4 et une vue en grand
const MAX_PER_SESSION = 17;
const SDP_MAX = 20000;
const QUALITIES = new Set(['tile', 'full']);

/** @type {Map<string, { token: string, account: string, target: number, quality: string, label: string, startedAt: number }>} */
const cameras = new Map();

const ownedBy = (token) => [...cameras.entries()].filter(([, camera]) => camera.token === token);

/** Joueurs à regarder ; `opening` : ouverture du mur (inscrite au journal du Registre). */
async function players(endpoint, account, opening) {
  const result = await bridge.request(endpoint, 'POST', opening ? '/cameras/wall' : '/cameras/players', { actor: bridge.actorOf(account) });
  if (!result.ok) return result;
  const list = Array.isArray(result.players) ? result.players : [];
  return {
    ok: true,
    players: list.map((p) => ({ source: Number(p.source) || 0, label: String(p.label || '').slice(0, 64), active: p.active === true }))
      .filter((p) => p.source > 0),
  };
}

/**
 * Ouvre la caméra d'un joueur.
 * @param {object} endpoint  adresse du serveur de jeu
 * @param {object} account   compte du panneau (son rang est vérifié par le Registre)
 * @param {string} token     session de navigateur
 * @param {number} target    numéro du joueur
 * @param {string} quality   tile (case d'un mur) ou full (vue en grand)
 */
async function start(endpoint, account, token, target, quality) {
  if (!QUALITIES.has(quality)) return { ok: false, error: 'invalid' };
  if (ownedBy(token).length >= MAX_PER_SESSION) return { ok: false, error: 'too_many_cameras' };
  const result = await bridge.request(endpoint, 'POST', '/camera/start', { actor: bridge.actorOf(account), target, quality });
  if (!result.ok) return result;
  const iceServers = (Array.isArray(result.iceServers) ? result.iceServers : []).filter((url) => typeof url === 'string');
  cameras.set(result.session, { token, account: account.name, target, quality, label: result.label, startedAt: Date.now() });
  return { ok: true, session: result.session, label: result.label, iceServers };
}

/** Réponse du navigateur propriétaire. */
async function answer(endpoint, token, session, sdp) {
  const camera = cameras.get(session);
  if (!camera || camera.token !== token) return { ok: false, error: 'unknown_session' };
  if (typeof sdp !== 'string' || !sdp || sdp.length > SDP_MAX) return { ok: false, error: 'invalid' };
  return bridge.request(endpoint, 'POST', '/camera/answer', { session, sdp });
}

/** Arrêt demandé par le navigateur propriétaire. */
async function stop(endpoint, token, session) {
  const camera = cameras.get(session);
  if (!camera || camera.token !== token) return { ok: false, error: 'unknown_session' };
  cameras.delete(session);
  return bridge.request(endpoint, 'POST', '/camera/stop', { session });
}

/** FXServer ou module des caméras arrêté : toutes les caméras sont mortes avec lui. */
function clear(reason = 'server_stopped') {
  for (const [session, camera] of cameras) events.sendTo(camera.token, 'camera', { session, ended: reason });
  cameras.clear();
}

/** Le compte n'a plus le droit de regarder : ses caméras s'éteignent, navigateur et jeu prévenus. */
function revoke(endpoint, name) {
  for (const [session, camera] of cameras) {
    if (camera.account !== name) continue;
    cameras.delete(session);
    events.sendTo(camera.token, 'camera', { session, ended: 'forbidden' });
    bridge.request(endpoint, 'POST', '/camera/stop', { session });
  }
}

/**
 * Un rang du Conseil a changé (en jeu, ou dans le panneau) : chaque compte qui regarde est revérifié avec son rang
 * actuel. Compte supprimé ou sans rang : ses caméras s'éteignent ; sinon le Registre dit s'il garde le droit (liste des
 * joueurs, sans journal). Pont injoignable : rien ne change (l'arrêt du serveur éteint tout de lui-même). Ne lève
 * jamais : appelée sans attendre son résultat.
 */
async function recheck() {
  try {
    const endpoint = servercfg.endpoint();
    const names = new Set([...cameras.values()].map((camera) => camera.account));
    for (const name of names) {
      const account = accounts.get(name);
      if (account && account.rank) {
        const result = await bridge.request(endpoint, 'POST', '/cameras/players', { actor: bridge.actorOf(account) });
        if (result.ok || result.error !== 'forbidden') continue;
      }
      revoke(endpoint, name);
    }
  } catch (error) {
    console.error(`[Chancellerie] revérification des caméras en erreur : ${error.stack || error.message}`);
  }
}

/** Évènement du pont : offre à transmettre, fin d'une caméra, module des caméras arrêté, ou droits à revérifier. */
function incoming(event) {
  if (event.reset === true) {
    clear('stopped');
    return;
  }
  if (event.recheck === true) {
    recheck();
    return;
  }
  const camera = typeof event.session === 'string' && cameras.get(event.session);
  if (!camera) return;
  if (event.ended) {
    cameras.delete(event.session);
    events.sendTo(camera.token, 'camera', { session: event.session, ended: String(event.ended) });
    return;
  }
  if (event.signal && event.signal.type === 'offer' && typeof event.signal.sdp === 'string') {
    events.sendTo(camera.token, 'camera', { session: event.session, offer: event.signal.sdp });
  }
}

/** Plus aucun flux pour cette session : ses caméras s'éteignent. */
function closeSession(endpoint, token) {
  for (const [session] of ownedBy(token)) stop(endpoint, token, session);
}

module.exports = { players, start, answer, stop, incoming, closeSession, clear, recheck, count: () => cameras.size };
