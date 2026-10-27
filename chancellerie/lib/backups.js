'use strict';
/*
 * lib/backups.js
 * Rôle : les sauvegardes. Celles du server.cfg (faites à chaque écriture, dans data/backups) se relisent sans leurs
 *        secrets et se restaurent (le fichier en place est sauvegardé d'abord). Celles de la base de données sont
 *        faites par mysqldump (ou mariadb-dump), trouvé seul autour de MySQL, MariaDB, XAMPP, Laragon ou WampServer,
 *        ou désigné à la main ; le dump est compressé (gzip) dans data/backups/db, les plus anciens au-delà du nombre
 *        gardé sont effacés. Les identifiants de la base sont lus dans le server.cfg et passent à mysqldump par un
 *        fichier d'options éphémère : jamais sur la ligne de commande, jamais vers le navigateur. Le client mysql voisin
 *        crée la base à l'installation, si elle n'existe pas.
 */

const crypto = require('crypto');
const EventEmitter = require('events');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const { spawn } = require('child_process');
const config = require('./config');
const journal = require('./journal');
const servercfg = require('./servercfg');

const DB_DIR = path.join(servercfg.BACKUPS, 'db');
const NAME_PATTERN = /^[A-Za-z0-9._-]{1,120}$/;
const DUMP_TIMEOUT_MS = 30 * 60 * 1000;
const STDERR_KEPT = 2000;
const KEEP_MIN = 1;
const KEEP_MAX = 200;
const TOOLS = process.platform === 'win32' ? ['mariadb-dump.exe', 'mysqldump.exe'] : ['mariadb-dump', 'mysqldump'];
const CLIENTS = process.platform === 'win32' ? ['mariadb.exe', 'mysql.exe'] : ['mariadb', 'mysql'];
// dossiers d'installation usuels, sous Windows : on cherche le dossier bin de chaque version
const WINDOWS_ROOTS = [
  ['C:\\Program Files', /^MariaDB/i], ['C:\\Program Files\\MySQL', /^MySQL Server/i], ['C:\\Program Files (x86)\\MySQL', /^MySQL Server/i],
  ['C:\\xampp', /^mysql$/i], ['C:\\laragon\\bin\\mysql', /./], ['C:\\wamp64\\bin\\mysql', /./], ['C:\\wamp64\\bin\\mariadb', /./],
];

const events = new EventEmitter();
let dump = null;
let last = null;

function list(dir, filter) {
  let names;
  try {
    names = fs.readdirSync(dir);
  } catch (error) {
    return [];
  }
  const out = [];
  for (const name of names) {
    if (!filter(name)) continue;
    try {
      const stat = fs.statSync(path.join(dir, name));
      if (stat.isFile()) out.push({ name, size: stat.size, at: stat.mtimeMs });
    } catch (error) {
      // effacé entre-temps
    }
  }
  return out.sort((a, b) => b.at - a.at);
}

/** Fichier d'une liste par son nom (aucun chemin : seulement un nom présent dans le dossier). */
function find(dir, filter, name) {
  if (typeof name !== 'string' || !NAME_PATTERN.test(name) || !filter(name)) return null;
  return list(dir, filter).some((entry) => entry.name === name) ? path.join(dir, name) : null;
}

// server.cfg ------------------------------------------------------------------------------------------------------------

const isCfgBackup = (name) => name.startsWith('server.cfg.') && name.endsWith('.bak');

const cfg = {
  list: () => list(servercfg.BACKUPS, isCfgBackup),

  /** Texte d'une sauvegarde, sans ses secrets ; null si elle n'existe pas. */
  view(name) {
    const file = find(servercfg.BACKUPS, isCfgBackup, name);
    if (!file) return null;
    return servercfg.mask(fs.readFileSync(file, 'utf8')).text;
  },

  /** Remet une sauvegarde en place ; renvoie { ok, backup } (sauvegarde du fichier remplacé). */
  restore(name) {
    const file = find(servercfg.BACKUPS, isCfgBackup, name);
    const target = config.cfgPath();
    if (!file) return { ok: false, error: 'unknown_backup' };
    if (!target) return { ok: false, error: 'paths_missing' };
    const text = fs.readFileSync(file, 'utf8');
    return { ok: true, backup: servercfg.write(target, text) };
  },
};

// Base de données -------------------------------------------------------------------------------------------------------

const isDbBackup = (name) => name.endsWith('.sql.gz');

function isFile(file) {
  try {
    return fs.statSync(file).isFile();
  } catch (error) {
    return false;
  }
}

function subdirs(dir) {
  try {
    return fs.readdirSync(dir, { withFileTypes: true }).filter((entry) => entry.isDirectory()).map((entry) => entry.name);
  } catch (error) {
    return [];
  }
}

/** Outil de dump accepté : mysqldump ou mariadb-dump, rien d'autre. */
function acceptedTool(file) {
  return typeof file === 'string' && path.isAbsolute(file) && TOOLS.includes(path.basename(file).toLowerCase()) && isFile(file);
}

/** Chemin de mysqldump : celui réglé, sinon trouvé dans le PATH ou les dossiers d'installation usuels ; '' sinon. */
function findTool() {
  const configured = config.get().backups.dumpPath;
  if (configured) return acceptedTool(configured) ? configured : '';
  return search(TOOLS);
}

/** Client mysql (ou mariadb) : à côté de mysqldump d'abord, sinon cherché comme lui ; '' sinon. */
function findClient() {
  const dump = findTool();
  if (dump) {
    const near = CLIENTS.map((name) => path.join(path.dirname(dump), name)).find(isFile);
    if (near) return near;
  }
  return search(CLIENTS);
}

/** Premier de ces programmes trouvé dans le PATH ou les dossiers d'installation usuels ; '' sinon. */
function search(names) {
  const dirs = String(process.env.PATH || '').split(path.delimiter).filter(Boolean);
  if (process.platform === 'win32') {
    for (const [root, pattern] of WINDOWS_ROOTS) {
      for (const name of subdirs(root).filter((n) => pattern.test(n)).sort().reverse()) dirs.push(path.join(root, name, 'bin'));
      if (pattern.test(path.basename(root))) dirs.push(path.join(root, 'bin'));
    }
  }
  for (const dir of dirs) {
    for (const tool of names) {
      const candidate = path.join(dir, tool);
      if (isFile(candidate)) return candidate;
    }
  }
  return '';
}

/** Fichier d'options éphémère (identifiants), lisible du seul propriétaire ; renvoie son chemin. */
function optionsFile(user, password) {
  const file = path.join(config.DATA, `.dump-${crypto.randomBytes(8).toString('hex')}.cnf`);
  config.ensureData();
  fs.writeFileSync(file, `[client]\nuser=${optionValue(user)}\npassword=${optionValue(password)}\n`, { mode: 0o600 });
  return file;
}

/**
 * Crée la base si elle n'existe pas (utf8mb4), avec le client mysql de la machine.
 * @param {{ host: string, port: number, user: string, password: string, database: string }} target  nom de base déjà validé
 * @returns {Promise<{ ok: boolean, error?: string, detail?: string }>}
 */
function createDatabase(target) {
  const client = findClient();
  if (!client) return Promise.resolve({ ok: false, error: 'db_client_missing' });
  const options = optionsFile(target.user, target.password);
  const sql = `CREATE DATABASE IF NOT EXISTS \`${target.database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`;
  return new Promise((resolve) => {
    const child = spawn(client, [`--defaults-extra-file=${options}`, `--host=${target.host}`, `--port=${target.port}`, '-e', sql], {
      windowsHide: true, stdio: ['ignore', 'ignore', 'pipe'], timeout: 20000,
    });
    let stderr = '';
    child.stderr.setEncoding('utf8');
    child.stderr.on('data', (chunk) => { stderr = (stderr + chunk).slice(-STDERR_KEPT); });
    const done = (code, spawnError) => {
      fs.rmSync(options, { force: true });
      let detail = stderr.split('\n').map((l) => l.trim()).filter(Boolean).pop() || spawnError || '';
      if (target.password) detail = detail.split(target.password).join('••••');
      resolve(code === 0 ? { ok: true } : { ok: false, error: 'db_create_failed', detail: detail.slice(0, 300) });
    };
    child.on('error', (error) => done(-1, error.message));
    child.on('close', (code) => done(code));
  });
}

/** Valeur d'un fichier d'options MySQL, entre guillemets. */
function optionValue(value) {
  return `"${String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

/** Les plus anciennes sauvegardes au-delà du nombre gardé sont effacées. */
function prune() {
  const keep = config.get().backups.keep;
  for (const old of list(DB_DIR, isDbBackup).slice(keep)) {
    try {
      fs.unlinkSync(path.join(DB_DIR, old.name));
    } catch (error) {
      // déjà effacée
    }
  }
}

function finish(result) {
  last = { ...result, at: Date.now() };
  dump = null;
  events.emit('change', db.status());
}

const db = {
  NAME_PATTERN,
  KEEP_MIN,
  KEEP_MAX,
  events,
  acceptedTool,
  list: () => list(DB_DIR, isDbBackup),
  file: (name) => find(DB_DIR, isDbBackup, name),

  status() {
    const tool = findTool();
    return {
      running: dump !== null,
      startedAt: dump ? dump.startedAt : null,
      last,
      tool,
      toolConfigured: Boolean(config.get().backups.dumpPath),
      keep: config.get().backups.keep,
      database: (servercfg.current() || { values: servercfg.DEFAULTS }).values.db.database,
    };
  },

  remove(name) {
    const file = find(DB_DIR, isDbBackup, name);
    if (!file) return { ok: false, error: 'unknown_backup' };
    fs.unlinkSync(file);
    return { ok: true };
  },

  /**
   * Lance un dump (un seul à la fois) ; la fin est annoncée par l'évènement « change ».
   * @param {string} actor
   * @returns {{ ok: boolean, error?: string }}
   */
  create(actor) {
    if (dump) return { ok: false, error: 'backup_running' };
    const tool = findTool();
    if (!tool) return { ok: false, error: 'dump_tool_missing' };
    const current = servercfg.current();
    if (!current || !current.values.db.database) return { ok: false, error: 'cfg_missing' };
    const { host, port, user, database } = current.values.db;
    fs.mkdirSync(DB_DIR, { recursive: true });
    const stamp = new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-');
    // deux sauvegardes dans la même seconde ne s'écrasent pas
    let name = `${database}_${stamp}.sql.gz`;
    for (let n = 2; fs.existsSync(path.join(DB_DIR, name)); n += 1) name = `${database}_${stamp}-${n}.sql.gz`;
    const target = path.join(DB_DIR, name);
    const partial = `${target}.partial`;
    // fichier d'options lisible du seul propriétaire, effacé dès la fin
    const options = optionsFile(user, current.secrets.dbPassword);
    const args = [`--defaults-extra-file=${options}`, `--host=${host}`, `--port=${port}`, '--single-transaction', '--quick',
      '--no-tablespaces', '--triggers', '--default-character-set=utf8mb4', database];
    const startedAt = Date.now();
    let child;
    try {
      child = spawn(tool, args, { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
    } catch (error) {
      fs.rmSync(options, { force: true });
      return { ok: false, error: 'dump_failed' };
    }
    dump = { startedAt, child };
    journal.record(actor, 'backup_started', { base: database });
    events.emit('change', db.status());
    let stderr = '';
    let writeError = null;
    let settled = false;
    const output = fs.createWriteStream(partial);
    output.on('error', (error) => { writeError = error.message; });
    // le fichier n'est complet qu'une fois l'écriture compressée terminée et fermée
    const written = new Promise((resolve) => output.on('close', resolve));
    child.stdout.pipe(zlib.createGzip()).pipe(output);
    child.stderr.setEncoding('utf8');
    child.stderr.on('data', (chunk) => { stderr = (stderr + chunk).slice(-STDERR_KEPT); });
    const timer = setTimeout(() => child.kill(), DUMP_TIMEOUT_MS);
    const done = async (code, spawnError) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      fs.rmSync(options, { force: true });
      if (code !== 0) output.destroy();
      await written;
      if (code !== 0 || writeError) {
        fs.rmSync(partial, { force: true });
        // dernière ligne de mysqldump (« Access denied… »), sans jamais le mot de passe
        let detail = stderr.split('\n').map((l) => l.trim()).filter(Boolean).pop() || writeError || spawnError || `code ${code}`;
        if (current.secrets.dbPassword) detail = detail.split(current.secrets.dbPassword).join('••••');
        journal.record(actor, 'backup_failed', { base: database, erreur: detail.slice(0, 200) });
        finish({ ok: false, error: 'dump_failed', detail: detail.slice(0, 300) });
        return;
      }
      fs.renameSync(partial, target);
      journal.record(actor, 'backup_done', { fichier: name });
      prune();
      finish({ ok: true, name, size: fs.statSync(target).size, durationMs: Date.now() - startedAt });
    };
    child.on('error', (error) => done(-1, error.message));
    child.on('close', (code) => done(code));
    return { ok: true };
  },
};

module.exports = { cfg, db, createDatabase };
