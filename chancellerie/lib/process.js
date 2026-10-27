'use strict';
/*
 * lib/process.js
 * Rôle : FXServer, lancé comme processus enfant de la Chancellerie. Démarrage, arrêt propre (sauvegarde des
 *        personnages, puis `quit`, puis arrêt forcé passé un délai), redémarrage, relance après un plantage (un
 *        nombre limité de fois dans une fenêtre de temps), console : chaque ligne écrite par FXServer est gardée
 *        dans un tampon tournant et diffusée ; les commandes partent sur son entrée standard.
 * Le processus a sa propre console (cachée) : un Ctrl+C dans la fenêtre de la Chancellerie ne le tue pas net,
 * il est arrêté proprement. Son numéro est écrit dans data/fxserver.pid : un FXServer resté orphelin après un
 * arrêt brutal de la Chancellerie est retrouvé et arrêté au lancement suivant.
 */

const EventEmitter = require('events');
const fs = require('fs');
const path = require('path');
const { spawn, execFile } = require('child_process');
const config = require('./config');
const journal = require('./journal');

const STATES = Object.freeze({ STOPPED: 'stopped', STARTING: 'starting', RUNNING: 'running', STOPPING: 'stopping', CRASHED: 'crashed' });
const PID_FILE = path.join(config.DATA, 'fxserver.pid');
// ligne qui prouve que le serveur est prêt à recevoir des joueurs
const READY_PATTERN = /Authenticated with cfx\.re Nucleus/;
const ANSI_PATTERN = /\x1b\[[0-9;]*[A-Za-z]/g;
const LINE_MAX = 4000;
const KILL_WAIT_MS = 5000;
const QUIT_REASON = 'Le serveur s\'arrête';
// une clé de licence ou un mot de passe affiché par une commande ne part jamais vers les navigateurs
const REDACTIONS = [
  [/cfxk_[A-Za-z0-9_]+/g, 'cfxk_••••'],
  [/(mysql:\/\/[^:/@\s"]*:)[^@\s"]*@/gi, '$1••••@'],
  [/((?:password|pwd|pass)=)[^;\s"]*/gi, '$1••••'],
];

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function redact(text) {
  return REDACTIONS.reduce((out, [pattern, replacement]) => out.replace(pattern, replacement), text);
}

function stripAnsi(text) {
  return text.replace(ANSI_PATTERN, '');
}

/** Arrête un processus et tous ceux qu'il a lancés (FXServer lance son gestionnaire de plantage). */
function killTree(pid) {
  return new Promise((resolve) => {
    if (process.platform === 'win32') {
      execFile('taskkill', ['/PID', String(pid), '/T', '/F'], { windowsHide: true }, () => resolve());
      return;
    }
    try {
      process.kill(-pid, 'SIGKILL');
    } catch (error) {
      // déjà arrêté
    }
    resolve();
  });
}

/** Nom de l'exécutable d'un processus vivant, ou null. */
function imageName(pid) {
  return new Promise((resolve) => {
    if (process.platform === 'win32') {
      execFile('tasklist', ['/FI', `PID eq ${pid}`, '/FO', 'CSV', '/NH'], { windowsHide: true }, (error, stdout) => {
        const match = !error && /^"([^"]+)","(\d+)"/m.exec(stdout || '');
        resolve(match && Number(match[2]) === pid ? match[1] : null);
      });
      return;
    }
    fs.readFile(`/proc/${pid}/cmdline`, 'utf8', (error, text) => resolve(error ? null : path.basename(text.split('\0')[0])));
  });
}

class ServerProcess extends EventEmitter {
  /**
   * @param {{ launchArgs?: () => string[], secrets?: () => string[] }} [options]  arguments ajoutés au lancement (clé du
   *        pont), secrets à masquer dans la console
   */
  constructor(options = {}) {
    super();
    this.launchArgs = options.launchArgs || (() => []);
    this.secrets = options.secrets || (() => []);
    this.state = STATES.STOPPED;
    this.since = Date.now();
    this.child = null;
    this.startedAt = null;
    this.crashes = [];
    this.relaunchTimer = null;
    this.relaunchAt = null;
    this.readyTimer = null;
    this.lastExit = null;
    this.lines = [];
    this.nextLineId = 1;
    this.partial = { stdout: '', stderr: '' };
  }

  setState(state) {
    if (this.state === state) return;
    this.state = state;
    this.since = Date.now();
    this.emit('state', this.status());
  }

  status() {
    const settings = config.get().process;
    const now = Date.now();
    return {
      state: this.state,
      // heure de la Chancellerie : l'interface corrige l'écart avec l'horloge du navigateur
      now,
      since: this.since,
      pid: this.child ? this.child.pid : null,
      startedAt: this.startedAt,
      uptimeMs: this.child && this.startedAt ? now - this.startedAt : 0,
      crashes: this.crashes.filter((at) => now - at <= settings.crashWindowMs).length,
      relaunchAt: this.relaunchAt,
      lastExit: this.lastExit,
    };
  }

  /** Une ligne de console : `stream` = stdout, stderr, input (commande saisie) ou system (message de la Chancellerie). */
  pushLine(stream, text) {
    let clean = redact(text.slice(0, LINE_MAX));
    for (const secret of this.secrets()) clean = clean.split(secret).join('••••');
    const line = { id: this.nextLineId, at: Date.now(), stream, text: clean };
    this.nextLineId += 1;
    this.lines.push(line);
    const max = config.get().process.consoleLines;
    if (this.lines.length > max) this.lines.splice(0, this.lines.length - max);
    this.emit('line', line);
    if (this.state === STATES.STARTING && stream === 'stdout' && READY_PATTERN.test(stripAnsi(line.text))) this.markRunning();
  }

  system(text) {
    this.pushLine('system', text);
  }

  /** Découpe un flux en lignes ; un retour chariot seul réécrit la ligne (barres de progression). */
  feed(stream, chunk) {
    const parts = (this.partial[stream] + chunk).split('\n');
    this.partial[stream] = parts.pop();
    if (this.partial[stream].length > LINE_MAX) {
      parts.push(this.partial[stream]);
      this.partial[stream] = '';
    }
    for (const part of parts) {
      const segments = part.replace(/\r$/, '').split('\r');
      this.pushLine(stream, segments[segments.length - 1]);
    }
  }

  flush() {
    for (const stream of Object.keys(this.partial)) {
      if (this.partial[stream]) this.pushLine(stream, this.partial[stream]);
      this.partial[stream] = '';
    }
  }

  history(count) {
    return this.lines.slice(-count);
  }

  markRunning() {
    clearTimeout(this.readyTimer);
    this.readyTimer = null;
    if (this.state === STATES.STARTING) this.setState(STATES.RUNNING);
  }

  cancelRelaunch() {
    clearTimeout(this.relaunchTimer);
    this.relaunchTimer = null;
    this.relaunchAt = null;
  }

  /** Raison d'un lancement impossible, ou null. */
  checkSetup() {
    const settings = config.get();
    if (!settings.setupDone) return 'not_configured';
    if (!settings.fxserverPath || !fs.existsSync(settings.fxserverPath)) return 'fxserver_missing';
    if (!settings.serverDataPath || !fs.existsSync(settings.serverDataPath)) return 'server_folder_missing';
    if (!fs.existsSync(config.cfgPath())) return 'cfg_missing';
    return null;
  }

  /**
   * Lance FXServer. Un lancement à la main remet à zéro le compte des plantages.
   * @param {string} actor
   * @returns {{ ok: boolean, error?: string }}
   */
  start(actor) {
    if (this.child || this.state === STATES.STOPPING) return { ok: false, error: 'already_running' };
    const problem = this.checkSetup();
    if (problem) return { ok: false, error: problem };
    this.cancelRelaunch();
    if (actor !== journal.SYSTEM) this.crashes = [];
    const settings = config.get();
    const executable = settings.fxserverPath;
    const args = [...this.launchArgs(), '+exec', settings.cfgFile];
    // un faux serveur écrit en JavaScript (tests) est lancé par Node lui-même
    const script = executable.toLowerCase().endsWith('.js');
    let child;
    try {
      child = spawn(script ? process.execPath : executable, script ? [executable, ...args] : args, {
        cwd: settings.serverDataPath, windowsHide: true, detached: true, stdio: ['pipe', 'pipe', 'pipe'],
      });
    } catch (error) {
      this.system(`Impossible de lancer FXServer : ${error.message}`);
      return { ok: false, error: 'spawn_failed' };
    }
    this.child = child;
    this.startedAt = Date.now();
    this.setState(STATES.STARTING);
    this.system(`Lancement de FXServer (par ${actor}).`);
    journal.record(actor, 'start');
    child.stdout.setEncoding('utf8');
    child.stderr.setEncoding('utf8');
    child.stdout.on('data', (chunk) => this.feed('stdout', chunk));
    child.stderr.on('data', (chunk) => this.feed('stderr', chunk));
    child.stdin.on('error', () => { /* entrée fermée par un arrêt : rien à faire */ });
    child.on('error', (error) => {
      this.system(`FXServer : ${error.message}`);
      // exécutable introuvable ou refusé : aucun processus n'existe, ce n'est pas un plantage à relancer
      if (this.child === child && child.pid === undefined) {
        this.child = null;
        this.startedAt = null;
        clearTimeout(this.readyTimer);
        this.readyTimer = null;
        journal.record(journal.SYSTEM, 'spawn_failed', { error: error.code || error.message });
        this.setState(STATES.STOPPED);
      }
    });
    child.on('exit', (code, signal) => this.onExit(child, code, signal));
    if (child.pid) this.writePid(child.pid, executable);
    this.readyTimer = setTimeout(() => this.markRunning(), settings.process.runningAfterMs);
    return { ok: true };
  }

  onExit(child, code, signal) {
    if (this.child !== child) return;
    this.flush();
    this.child = null;
    this.startedAt = null;
    clearTimeout(this.readyTimer);
    this.readyTimer = null;
    this.removePid();
    this.lastExit = { code, signal: signal || null, at: Date.now() };
    const wanted = this.state === STATES.STOPPING;
    this.system(wanted ? 'FXServer est arrêté.' : `FXServer s'est arrêté de lui-même (code ${code === null ? signal : code}).`);
    this.emit('exit', this.lastExit);
    if (wanted) {
      this.setState(STATES.STOPPED);
      return;
    }
    this.onCrash(code);
  }

  onCrash(code) {
    const settings = config.get().process;
    const now = Date.now();
    this.crashes = this.crashes.filter((at) => now - at <= settings.crashWindowMs);
    this.crashes.push(now);
    journal.record(journal.SYSTEM, 'crash', { code });
    if (this.crashes.length > settings.maxCrashes) {
      this.relaunchAt = null;
      this.system(`${this.crashes.length} arrêts en moins de ${Math.round(settings.crashWindowMs / 60000)} minutes : la relance automatique est suspendue. Consultez la console puis relancez à la main.`);
      journal.record(journal.SYSTEM, 'relaunch_abandoned', { crashes: this.crashes.length });
      this.setState(STATES.CRASHED);
      return;
    }
    // l'état reste « planté » jusqu'à la relance, avec sa date : l'interface l'affiche
    this.relaunchAt = now + settings.restartDelayMs;
    this.system(`Relance dans ${Math.round(settings.restartDelayMs / 1000)} secondes.`);
    this.setState(STATES.CRASHED);
    this.relaunchTimer = setTimeout(() => {
      this.relaunchTimer = null;
      this.relaunchAt = null;
      const result = this.start(journal.SYSTEM);
      if (!result.ok) {
        this.system(`Relance impossible : ${result.error}.`);
        this.emit('state', this.status());
      }
    }, settings.restartDelayMs);
  }

  /** Attend la fin du processus en cours ; vrai s'il s'est arrêté dans le délai. */
  waitExit(timeoutMs) {
    if (!this.child) return Promise.resolve(true);
    const child = this.child;
    return new Promise((resolve) => {
      const timer = setTimeout(() => {
        child.removeListener('exit', done);
        resolve(false);
      }, timeoutMs);
      function done() {
        clearTimeout(timer);
        resolve(true);
      }
      child.once('exit', done);
    });
  }

  /** Écrit une ligne sur l'entrée de FXServer ; faux si elle n'a pas pu partir. */
  write(text) {
    if (!this.child || !this.child.stdin.writable) return false;
    this.child.stdin.write(`${text}\n`);
    return true;
  }

  /**
   * Commande saisie dans la console : recopiée (masquée si elle contient un secret) avec son auteur.
   * @returns {{ ok: boolean, error?: string }}
   */
  command(text, actor) {
    if (!this.child) return { ok: false, error: 'not_running' };
    this.pushLine('input', `${actor} › ${text}`);
    return this.write(text) ? { ok: true } : { ok: false, error: 'not_running' };
  }

  /**
   * Arrêt propre : sauvegarde des personnages (si le serveur est en marche), `quit`, puis arrêt forcé passé le délai.
   * @param {string} actor
   * @param {{ quick?: boolean }} [options]  quick : délais raccourcis (fermeture de la fenêtre)
   */
  async stop(actor, { quick = false } = {}) {
    this.cancelRelaunch();
    if (!this.child) {
      this.setState(STATES.STOPPED);
      return { ok: true };
    }
    if (this.state === STATES.STOPPING) {
      await this.waitExit(config.get().process.stopTimeoutMs + KILL_WAIT_MS);
      return { ok: true };
    }
    const settings = config.get().process;
    const wasRunning = this.state === STATES.RUNNING;
    this.setState(STATES.STOPPING);
    this.system(`Arrêt demandé par ${actor}.`);
    journal.record(actor, 'stop');
    if (wasRunning && settings.saveCommand && this.write(settings.saveCommand)) {
      await Promise.race([delay(quick ? Math.min(settings.saveWaitMs, 1500) : settings.saveWaitMs), this.waitExit(settings.saveWaitMs)]);
    }
    this.write(`quit "${QUIT_REASON}"`);
    const exited = await this.waitExit(quick ? KILL_WAIT_MS : settings.stopTimeoutMs);
    if (!exited && this.child) {
      this.system('FXServer ne répond pas : arrêt forcé.');
      await killTree(this.child.pid);
      await this.waitExit(KILL_WAIT_MS);
    }
    return { ok: true };
  }

  async restart(actor) {
    journal.record(actor, 'restart');
    await this.stop(actor);
    return this.start(actor);
  }

  writePid(pid, executable) {
    try {
      config.ensureData();
      fs.writeFileSync(PID_FILE, JSON.stringify({ pid, image: path.basename(executable) }));
    } catch (error) {
      this.system(`Numéro de processus non écrit : ${error.message}`);
    }
  }

  removePid() {
    try {
      fs.unlinkSync(PID_FILE);
    } catch (error) {
      // déjà retiré
    }
  }

  /**
   * FXServer laissé en vie par un arrêt brutal de la Chancellerie : arrêté s'il s'agit bien de lui (le numéro a
   * pu être réattribué à un autre programme depuis). Renvoie vrai s'il a fallu l'arrêter.
   */
  async cleanupOrphan() {
    const saved = config.readJson(PID_FILE, null);
    if (!saved || !Number.isInteger(saved.pid)) return false;
    this.removePid();
    const image = await imageName(saved.pid);
    // un faux serveur des tests tourne sous Node : son nom enregistré est celui du script
    const expected = String(saved.image || '').toLowerCase().endsWith('.js') ? path.basename(process.execPath) : saved.image;
    if (!image || image.toLowerCase() !== String(expected).toLowerCase()) return false;
    await killTree(saved.pid);
    journal.record(journal.SYSTEM, 'orphan_stopped', { pid: saved.pid });
    return true;
  }
}

module.exports = { ServerProcess, STATES, redact, stripAnsi };
