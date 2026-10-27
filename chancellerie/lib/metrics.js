'use strict';
/*
 * lib/metrics.js
 * Rôle : les performances du serveur, relevées à intervalle fixe : processeur et mémoire de la machine et de
 *        FXServer, débit réseau (reçu, envoyé), joueurs connectés, durée moyenne des ticks des fils de FXServer
 *        (principal, réseau, synchronisation). Deux historiques : la dernière heure à chaque relevé (en mémoire), les
 *        dernières 24 heures en moyennes par minute (écrites dans data/metrics.json, reprises au lancement). Chaque
 *        relevé est diffusé aux navigateurs ouverts.
 */

const EventEmitter = require('events');
const path = require('path');
const config = require('./config');
const servercfg = require('./servercfg');
const status = require('./status');
const system = require('./system');
const { STATES } = require('./process');

const FILE = path.join(config.DATA, 'metrics.json');
const HOUR_MS = 3600 * 1000;
const DAY_MINUTES = 24 * 60;
const MINUTE_MS = 60000;
const SAVE_EVERY_MS = 10 * MINUTE_MS;
// relevés plus lents que l'intervalle : le suivant attend, jamais deux à la fois
const INTERVAL_MIN_MS = 2000;

const round = (value, digits = 1) => (value === null || value === undefined ? null : Math.round(value * 10 ** digits) / 10 ** digits);

/** Moyenne des valeurs non nulles d'un champ, ou null. */
function mean(samples, read) {
  let sum = 0;
  let count = 0;
  for (const sample of samples) {
    const value = read(sample);
    if (value === null || value === undefined) continue;
    sum += value;
    count += 1;
  }
  return count ? sum / count : null;
}

/** Relevés d'une minute résumés en un seul (moyennes ; joueurs : le plus haut de la minute). */
function summarize(minute, samples) {
  const players = samples.map((s) => s.players).filter((v) => v !== null);
  return {
    at: minute,
    cpu: round(mean(samples, (s) => s.cpu)),
    memUsed: round(mean(samples, (s) => s.memUsed), 0),
    memTotal: samples[samples.length - 1].memTotal,
    rx: round(mean(samples, (s) => s.rx), 0),
    tx: round(mean(samples, (s) => s.tx), 0),
    fxCpu: round(mean(samples, (s) => s.fxCpu)),
    fxMem: round(mean(samples, (s) => s.fxMem), 0),
    players: players.length ? Math.max(...players) : null,
    tickMain: round(mean(samples, (s) => s.tickMain), 2),
    tickNetwork: round(mean(samples, (s) => s.tickNetwork), 2),
    tickSync: round(mean(samples, (s) => s.tickSync), 2),
  };
}

class Metrics extends EventEmitter {
  /** @param {import('./process').ServerProcess} server */
  constructor(server) {
    super();
    this.server = server;
    this.recent = [];
    this.minutes = [];
    this.pending = [];
    this.pendingMinute = null;
    this.lastPerf = null;
    this.timer = null;
    this.saveTimer = null;
    this.busy = false;
    const saved = config.readJson(FILE, null);
    if (saved && Array.isArray(saved.minutes)) {
      const oldest = Date.now() - DAY_MINUTES * MINUTE_MS;
      this.minutes = saved.minutes.filter((m) => m && Number.isFinite(m.at) && m.at >= oldest).slice(-DAY_MINUTES);
    }
  }

  intervalMs() {
    return Math.max(INTERVAL_MIN_MS, Number(config.get().metrics.intervalMs) || 5000);
  }

  start() {
    if (this.timer) return;
    this.timer = setInterval(() => this.tick(), this.intervalMs());
    this.saveTimer = setInterval(() => this.save(), SAVE_EVERY_MS);
    this.tick();
  }

  stop() {
    clearInterval(this.timer);
    clearInterval(this.saveTimer);
    this.timer = null;
    this.saveTimer = null;
    this.flushMinute();
    this.save();
    system.stop();
  }

  save() {
    try {
      config.writeJson(FILE, { minutes: this.minutes });
    } catch (error) {
      console.error(`[Chancellerie] performances non écrites : ${error.message}`);
    }
  }

  /** Durée moyenne d'un tick (ms) par fil depuis le relevé précédent ; null si inconnue ou serveur relancé. */
  ticks(perf) {
    const before = this.lastPerf;
    this.lastPerf = perf;
    if (!perf || !before) return null;
    const out = {};
    for (const thread of ['main', 'network', 'sync']) {
      const now = perf[thread];
      const then = before[thread];
      if (!now || !then || now.count <= then.count || now.sum < then.sum) {
        out[thread] = null;
        continue;
      }
      out[thread] = ((now.sum - then.sum) / (now.count - then.count)) * 1000;
    }
    return out;
  }

  async tick() {
    if (this.busy) return;
    this.busy = true;
    try {
      const server = this.server;
      const running = server.state === STATES.RUNNING;
      const endpoint = running ? servercfg.endpoint() : null;
      const [machine, players, perf] = await Promise.all([
        system.sample(server.child ? server.child.pid : null),
        endpoint ? status.players(endpoint) : null,
        endpoint ? status.perf(endpoint) : null,
      ]);
      const ticks = this.ticks(perf);
      const sample = {
        at: Date.now(),
        cpu: round(machine.cpu),
        memUsed: machine.memory.used,
        memTotal: machine.memory.total,
        rx: machine.network ? Math.round(machine.network.rx) : null,
        tx: machine.network ? Math.round(machine.network.tx) : null,
        fxCpu: machine.fxserver ? round(machine.fxserver.cpu) : null,
        fxMem: machine.fxserver ? machine.fxserver.memory : null,
        fxThreads: machine.fxserver ? machine.fxserver.threads : null,
        players: Array.isArray(players) ? players.length : null,
        tickMain: ticks ? round(ticks.main, 2) : null,
        tickNetwork: ticks ? round(ticks.network, 2) : null,
        tickSync: ticks ? round(ticks.sync, 2) : null,
        state: server.state,
      };
      this.push(sample);
      this.emit('sample', sample);
    } catch (error) {
      console.error(`[Chancellerie] relevé des performances en erreur : ${error.stack || error.message}`);
    } finally {
      this.busy = false;
    }
  }

  push(sample) {
    this.recent.push(sample);
    const oldest = sample.at - HOUR_MS;
    while (this.recent.length && this.recent[0].at < oldest) this.recent.shift();
    const minute = Math.floor(sample.at / MINUTE_MS) * MINUTE_MS;
    if (this.pendingMinute !== null && minute !== this.pendingMinute) this.flushMinute();
    this.pendingMinute = minute;
    this.pending.push(sample);
  }

  flushMinute() {
    if (!this.pending.length) return;
    this.minutes.push(summarize(this.pendingMinute, this.pending));
    if (this.minutes.length > DAY_MINUTES) this.minutes.splice(0, this.minutes.length - DAY_MINUTES);
    this.pending = [];
  }

  /** Historique : 'hour' (chaque relevé de la dernière heure) ou 'day' (moyennes par minute sur 24 h). */
  history(range) {
    if (range === 'day') {
      const pending = this.pending.length ? [summarize(this.pendingMinute, this.pending)] : [];
      return { range, stepMs: MINUTE_MS, samples: [...this.minutes, ...pending] };
    }
    return { range: 'hour', stepMs: this.intervalMs(), samples: [...this.recent] };
  }

  latest() {
    return this.recent.length ? this.recent[this.recent.length - 1] : null;
  }
}

module.exports = { Metrics, cores: system.cores };
