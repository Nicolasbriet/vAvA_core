'use strict';
/*
 * lib/config.js
 * Rôle : emplacements de la Chancellerie et sa configuration (data/config.json). Les secrets du serveur (clé de
 *        licence, mot de passe de la base) n'y sont jamais copiés : ils ne vivent que dans le server.cfg, que
 *        FXServer doit lire.
 */

const fs = require('fs');
const path = require('path');

// dossier de la Chancellerie : celui du lanceur (même à travers un lien), sinon celui du programme
const HOME = path.resolve(process.env.CHANCELLERIE_HOME || path.join(__dirname, '..'));
const DATA = path.join(HOME, 'data');
const FILE = path.join(DATA, 'config.json');
const GUESS_LEVELS = 4;
const VERSION = '1.2.0';

const DEFAULTS = Object.freeze({
  http: { host: '127.0.0.1', port: 40120, secureCookies: false },
  serverDataPath: '',
  fxserverPath: '',
  cfgFile: 'server.cfg',
  setupDone: false,
  autoStart: true,
  process: {
    restartDelayMs: 5000,       // attente avant de relancer après un plantage
    maxCrashes: 3,              // plantages tolérés dans la fenêtre, avant d'abandonner la relance
    crashWindowMs: 120000,
    saveCommand: 'vava_saveall', // sauvegarde des personnages avant un arrêt
    saveWaitMs: 3000,
    stopTimeoutMs: 20000,       // au-delà, le processus est arrêté de force
    runningAfterMs: 30000,      // un serveur vivant depuis ce délai est considéré en marche
    consoleLines: 3000,
  },
  // Rangs du Conseil vus au dernier passage du pont (formulaire des comptes quand le serveur est arrêté).
  game: { ranks: [] },
  // Relevé des performances (processeur, mémoire, réseau, joueurs, ticks).
  metrics: { intervalMs: 5000 },
  // Heures « HH:MM » (heure de la machine) des redémarrages et des sauvegardes de la base ; avertissements des joueurs
  // (minutes avant) et leur message ({minutes} remplacé, vide : phrase par défaut) ; échéance sautée une fois.
  schedule: { restarts: [], warnings: [15, 5, 1], message: '', backups: [], skip: null },
  // Sauvegardes de la base : mysqldump (vide : cherché seul) et nombre de sauvegardes gardées.
  backups: { dumpPath: '', keep: 14 },
  // Installation et mises à jour de vAvA : dépôt GitHub, branche suivie (channel « commits ») ou dernière release
  // (« releases ») ; vérification à intervalle ; mise à jour appliquée au redémarrage planifié si demandé.
  updates: {
    repo: 'Nicolasbriet/vAvA_core', branch: 'main', channel: 'commits', autoCheck: true, checkEveryMin: 60, applyAtRestart: false,
    api: 'https://api.github.com', codeload: 'https://codeload.github.com',
  },
});

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

/** Fusion profonde : les valeurs de `extra` l'emportent. */
function merge(base, extra) {
  const out = { ...base };
  for (const [key, value] of Object.entries(extra || {})) {
    out[key] = isObject(value) && isObject(base[key]) ? merge(base[key], value) : value;
  }
  return out;
}

function ensureData() {
  fs.mkdirSync(DATA, { recursive: true });
}

/** Écriture atomique : un arrêt brutal ne laisse jamais un fichier à moitié écrit. */
function writeJson(file, value) {
  ensureData();
  const temporary = `${file}.tmp`;
  fs.writeFileSync(temporary, JSON.stringify(value, null, 2));
  fs.renameSync(temporary, file);
}

function readJson(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    return fallback;
  }
}

let current = merge(DEFAULTS, readJson(FILE, {}));

/**
 * Dossier du serveur proposé par défaut : le premier parent de la Chancellerie qui contient un dossier resources
 * (posée à côté de resources, ou rangée dedans, même dans une catégorie).
 */
function guessServerDataPath() {
  let dir = HOME;
  for (let level = 0; level < GUESS_LEVELS; level += 1) {
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
    if (fs.existsSync(path.join(dir, 'resources'))) return dir;
  }
  return '';
}

/** Emplacements usuels de FXServer.exe autour du dossier du serveur. */
function guessFxserverPath(serverDataPath) {
  if (!serverDataPath) return '';
  const executable = process.platform === 'win32' ? 'FXServer.exe' : 'run.sh';
  const candidates = [
    path.join(serverDataPath, executable),
    path.join(serverDataPath, 'server', executable),
    path.join(serverDataPath, 'artifacts', executable),
    path.join(path.dirname(serverDataPath), 'server', executable),
    path.join(path.dirname(serverDataPath), 'artifacts', executable),
  ];
  return candidates.find((candidate) => fs.existsSync(candidate)) || '';
}

module.exports = {
  VERSION,
  HOME,
  DATA,
  ensureData,
  writeJson,
  readJson,
  guessServerDataPath,
  guessFxserverPath,
  get: () => current,
  /** Applique un changement et l'écrit. */
  update(patch) {
    current = merge(current, patch);
    writeJson(FILE, current);
    return current;
  },
  /** Chemin du server.cfg géré. */
  cfgPath() {
    return current.serverDataPath ? path.join(current.serverDataPath, current.cfgFile) : '';
  },
};
