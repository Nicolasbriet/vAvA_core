'use strict';
/*
 * lib/events.js
 * Rôle : flux d'évènements vers les navigateurs connectés : état du serveur pour tous, lignes de la console pour
 *        les comptes qui ont le droit de la lire, nouvelles du royaume (signalements, joueurs) pour les comptes qui
 *        ont un rang du Conseil, caméras pour la seule session qui les a ouvertes. Un flux se ferme quand sa session
 *        expire ou se déconnecte ; leur nombre est borné (par session et au total).
 */

const accounts = require('./accounts');
const sessions = require('./sessions');
const { openStream } = require('./http');

const HEARTBEAT_MS = 25000;
const MAX_PER_SESSION = 4;
const MAX_TOTAL = 40;
const HISTORY_LINES = 600;

/** @type {Set<{ token: string, name: string, send: Function, res: import('http').ServerResponse, console: boolean }>} */
const clients = new Set();
let heartbeat = null;
let onEmpty = () => {};

function close(client) {
  if (!clients.has(client)) return;
  clients.delete(client);
  client.res.end();
  if (![...clients].some((other) => other.token === client.token)) onEmpty(client.token);
  if (!clients.size) {
    clearInterval(heartbeat);
    heartbeat = null;
  }
}

/** Battement : garde la connexion ouverte et ferme celles dont la session n'est plus valide. */
function beat() {
  for (const client of [...clients]) {
    if (!sessions.peek(client.token)) close(client);
    else client.res.write(': veille\n\n');
  }
}

module.exports = {
  /**
   * Ouvre un flux pour une session.
   * @param {import('./process').ServerProcess} server
   * @returns {boolean} faux si la limite est atteinte
   */
  open(req, res, token, name, canReadConsole, server) {
    const mine = [...clients].filter((client) => client.token === token).length;
    if (mine >= MAX_PER_SESSION || clients.size >= MAX_TOTAL) return false;
    const client = { token, name, res, console: canReadConsole, send: openStream(res) };
    clients.add(client);
    req.on('close', () => close(client));
    client.send('state', server.status());
    if (canReadConsole) client.send('history', { lines: server.history(HISTORY_LINES) });
    if (!heartbeat) heartbeat = setInterval(beat, HEARTBEAT_MS);
    return true;
  },

  /** Branche le flux sur le processus FXServer. */
  attach(server) {
    server.on('state', (status) => {
      for (const client of clients) client.send('state', status);
    });
    server.on('line', (line) => {
      for (const client of clients) if (client.console) client.send('line', line);
    });
  },

  /** Évènement pour une seule session (caméra). */
  sendTo(token, event, data) {
    for (const client of clients) if (client.token === token) client.send(event, data);
  },

  /** Nouvelle du royaume, pour les comptes qui ont un rang du Conseil (relu à chaque envoi). */
  broadcastRanked(event, data) {
    for (const client of clients) {
      const account = accounts.get(client.name);
      if (account && account.rank) client.send(event, data);
    }
  },

  /** Appelé quand une session n'a plus aucun flux ouvert. */
  onSessionEmpty(callback) {
    onEmpty = callback;
  },

  /** Ferme les flux d'une session (déconnexion). */
  closeSession(token) {
    for (const client of [...clients]) if (client.token === token) close(client);
  },

  count: () => clients.size,
};
