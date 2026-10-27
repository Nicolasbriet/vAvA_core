'use strict';
/*
 * lib/discord.js
 * Rôle : le client Discord du bot, sans dépendance : appels REST (avec la limite de débit de Discord respectée) et
 *        connexion Gateway par le WebSocket de Node (22 ou plus récent) : identification, battements, reprise de
 *        session après une coupure, reconnexion avec un délai croissant. Seules les interactions (commandes slash)
 *        sont écoutées : aucun droit privilégié n'est demandé à Discord. Le jeton n'apparaît dans aucun message.
 */

const EventEmitter = require('events');
const config = require('./config');

const INTENT_GUILDS = 1;
const OP = { DISPATCH: 0, HEARTBEAT: 1, IDENTIFY: 2, RESUME: 6, RECONNECT: 7, INVALID_SESSION: 9, HELLO: 10, ACK: 11 };
// fermetures définitives : jeton refusé, droits refusés… (les autres se reprennent)
const FATAL_CLOSES = { 4004: 'bad_token', 4010: 'bad_shard', 4011: 'bad_shard', 4012: 'bad_version', 4013: 'bad_intents', 4014: 'bad_intents' };
const RECONNECT_MIN_MS = 2000;
const RECONNECT_MAX_MS = 120000;
const REST_TIMEOUT_MS = 15000;
const RATE_RETRIES = 2;

function failure(code, detail) {
  const error = new Error(detail || code);
  error.code = code;
  return error;
}

class DiscordClient extends EventEmitter {
  /** @param {string} token */
  constructor(token) {
    super();
    this.token = token;
    this.state = 'stopped';
    this.error = null;
    this.user = null;
    this.applicationId = null;
    this.ws = null;
    this.seq = null;
    this.sessionId = null;
    this.resumeUrl = null;
    this.heartbeat = null;
    this.acked = true;
    this.retryMs = RECONNECT_MIN_MS;
    this.reconnectTimer = null;
    this.stopping = false;
  }

  settings() {
    return config.get().discord;
  }

  /** Appel REST : réponse JSON (ou null pour 204) ; lève `discord_<statut>` ou `network`. */
  async rest(method, route, body, attempt = 0) {
    let response;
    try {
      response = await fetch(`${this.settings().api}${route}`, {
        method,
        headers: {
          authorization: `Bot ${this.token}`,
          'user-agent': `DiscordBot (https://github.com/Nicolasbriet/vAvA_core, ${config.VERSION})`,
          ...(body !== undefined ? { 'content-type': 'application/json' } : {}),
        },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(REST_TIMEOUT_MS),
      });
    } catch (error) {
      throw failure('network', error.message);
    }
    if (response.status === 429 && attempt < RATE_RETRIES) {
      const info = await response.json().catch(() => ({}));
      await new Promise((resolve) => setTimeout(resolve, Math.min(10000, (Number(info.retry_after) || 1) * 1000)));
      return this.rest(method, route, body, attempt + 1);
    }
    if (response.status === 204) return null;
    const data = await response.json().catch(() => null);
    if (!response.ok) throw failure(`discord_${response.status}`, data && data.message ? String(data.message) : `HTTP ${response.status}`);
    return data;
  }

  setState(state, error = null) {
    this.state = state;
    this.error = error;
    this.emit('state', { state, error, user: this.user });
  }

  /** Connexion à la Gateway (ou reprise de la session en cours). */
  connect() {
    if (typeof WebSocket !== 'function') {
      this.setState('error', 'node_too_old');
      return;
    }
    this.stopping = false;
    clearTimeout(this.reconnectTimer);
    const resuming = Boolean(this.sessionId && this.resumeUrl);
    const base = resuming ? this.resumeUrl : this.settings().gateway;
    const url = `${String(base).replace(/\/+$/, '')}/?v=10&encoding=json`;
    this.setState('connecting');
    let ws;
    try {
      ws = new WebSocket(url);
    } catch (error) {
      this.scheduleReconnect('network');
      return;
    }
    this.ws = ws;
    ws.addEventListener('message', (event) => this.onMessage(ws, event.data, resuming));
    ws.addEventListener('close', (event) => this.onClose(ws, event.code));
    ws.addEventListener('error', () => { /* la fermeture suit */ });
  }

  send(ws, payload) {
    if (ws && ws.readyState === 1) ws.send(JSON.stringify(payload));
  }

  onMessage(ws, raw, resuming) {
    if (ws !== this.ws) return;
    let packet;
    try {
      packet = JSON.parse(typeof raw === 'string' ? raw : Buffer.from(raw).toString('utf8'));
    } catch (error) {
      return;
    }
    if (packet.s !== null && packet.s !== undefined) this.seq = packet.s;
    switch (packet.op) {
      case OP.HELLO:
        this.startHeartbeat(ws, packet.d.heartbeat_interval);
        if (resuming) this.send(ws, { op: OP.RESUME, d: { token: this.token, session_id: this.sessionId, seq: this.seq } });
        else {
          this.send(ws, {
            op: OP.IDENTIFY,
            d: { token: this.token, intents: INTENT_GUILDS, properties: { os: process.platform, browser: 'vava-chancellerie', device: 'vava-chancellerie' } },
          });
        }
        break;
      case OP.ACK:
        this.acked = true;
        break;
      case OP.HEARTBEAT:
        this.send(ws, { op: OP.HEARTBEAT, d: this.seq });
        break;
      case OP.RECONNECT:
        ws.close(4900, 'reconnexion demandée');
        break;
      case OP.INVALID_SESSION:
        // session perdue : une nouvelle identification, après un court délai imposé par Discord
        if (!packet.d) {
          this.sessionId = null;
          this.resumeUrl = null;
        }
        ws.close(4900, 'session invalide');
        break;
      case OP.DISPATCH:
        this.onDispatch(packet.t, packet.d);
        break;
      default:
    }
  }

  onDispatch(type, data) {
    if (type === 'READY') {
      this.sessionId = data.session_id;
      this.resumeUrl = data.resume_gateway_url || null;
      this.user = { id: data.user.id, username: data.user.username };
      this.applicationId = data.application ? data.application.id : data.user.id;
      this.retryMs = RECONNECT_MIN_MS;
      this.setState('ready');
      this.emit('ready', { user: this.user, applicationId: this.applicationId });
    } else if (type === 'RESUMED') {
      this.retryMs = RECONNECT_MIN_MS;
      this.setState('ready');
    } else if (type === 'INTERACTION_CREATE') {
      this.emit('interaction', data);
    }
  }

  startHeartbeat(ws, interval) {
    clearInterval(this.heartbeat);
    this.acked = true;
    const beat = () => {
      if (ws !== this.ws) return;
      // battement sans réponse : connexion morte, on la reprend
      if (!this.acked) {
        ws.close(4901, 'battement sans réponse');
        return;
      }
      this.acked = false;
      this.send(ws, { op: OP.HEARTBEAT, d: this.seq });
    };
    // premier battement décalé au hasard, comme le demande Discord
    setTimeout(beat, Math.floor(interval * Math.random()));
    this.heartbeat = setInterval(beat, interval);
  }

  onClose(ws, code) {
    if (ws !== this.ws) return;
    clearInterval(this.heartbeat);
    this.ws = null;
    if (this.stopping) {
      this.setState('stopped');
      return;
    }
    if (FATAL_CLOSES[code]) {
      this.sessionId = null;
      this.setState('error', FATAL_CLOSES[code]);
      return;
    }
    this.scheduleReconnect('disconnected');
  }

  scheduleReconnect(reason) {
    this.setState('connecting', reason);
    clearTimeout(this.reconnectTimer);
    this.reconnectTimer = setTimeout(() => this.connect(), this.retryMs);
    this.retryMs = Math.min(RECONNECT_MAX_MS, this.retryMs * 2);
  }

  stop() {
    this.stopping = true;
    clearTimeout(this.reconnectTimer);
    clearInterval(this.heartbeat);
    const ws = this.ws;
    this.ws = null;
    if (ws) ws.close(1000, 'arrêt');
    this.setState('stopped');
  }
}

module.exports = { DiscordClient, failure };
