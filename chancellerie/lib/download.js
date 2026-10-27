'use strict';
/*
 * lib/download.js
 * Rôle : ce qu'il faut pour installer et mettre à jour depuis Internet, sans dépendance : lecture d'une API JSON
 *        (GitHub, artefacts de FiveM), téléchargement d'un fichier avec sa progression (taille bornée, délai), extraction
 *        d'une archive (zip lu ici même ; tar.gz et tar.xz par le tar de la machine, livré avec Linux comme avec
 *        Windows 10 et 11, qui refuse les chemins absolus et les « .. »), empreintes SHA-256 et copie de dossiers.
 */

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { Readable, Transform } = require('stream');
const { pipeline } = require('stream/promises');
const zlib = require('zlib');
const { promisify } = require('util');
const { execFile } = require('child_process');
const config = require('./config');

const USER_AGENT = `vAvA-Chancellerie/${config.VERSION}`;
const JSON_TIMEOUT_MS = 15000;
const DOWNLOAD_TIMEOUT_MS = 15 * 60 * 1000;
const DOWNLOAD_MAX = 1024 * 1024 * 1024;
const EXTRACT_TIMEOUT_MS = 10 * 60 * 1000;
const TAR = process.platform === 'win32' ? path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'tar.exe') : 'tar';

/** Erreur au code lisible par l'interface. */
function failure(code, detail) {
  const error = new Error(detail || code);
  error.code = code;
  return error;
}

/** JSON d'une adresse ; lève `network` ou `http_<statut>`. */
async function getJson(url, headers = {}) {
  let response;
  try {
    response = await fetch(url, { headers: { 'user-agent': USER_AGENT, accept: 'application/json', ...headers }, signal: AbortSignal.timeout(JSON_TIMEOUT_MS) });
  } catch (error) {
    throw failure('network', `${url} : ${error.message}`);
  }
  if (!response.ok) throw failure(response.status === 403 || response.status === 429 ? 'rate_limited_remote' : `http_${response.status}`, url);
  return response.json();
}

/**
 * Télécharge une adresse dans un fichier (écrit à côté puis renommé : jamais de fichier à moitié là).
 * @param {(received: number, total: number|null) => void} [onProgress]
 */
async function downloadTo(url, file, onProgress) {
  let response;
  try {
    response = await fetch(url, { headers: { 'user-agent': USER_AGENT }, signal: AbortSignal.timeout(DOWNLOAD_TIMEOUT_MS) });
  } catch (error) {
    throw failure('network', `${url} : ${error.message}`);
  }
  if (!response.ok || !response.body) throw failure(`http_${response.status}`, url);
  const total = Number(response.headers.get('content-length')) || null;
  if (total && total > DOWNLOAD_MAX) throw failure('too_large', url);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const partial = `${file}.partial`;
  let received = 0;
  let last = 0;
  const counter = new Transform({
    transform(chunk, encoding, callback) {
      received += chunk.length;
      if (received > DOWNLOAD_MAX) {
        callback(failure('too_large', url));
        return;
      }
      if (onProgress && Date.now() - last > 250) {
        last = Date.now();
        onProgress(received, total);
      }
      callback(null, chunk);
    },
  });
  try {
    await pipeline(Readable.fromWeb(response.body), counter, fs.createWriteStream(partial));
  } catch (error) {
    fs.rmSync(partial, { force: true });
    throw error.code ? error : failure('network', `${url} : ${error.message}`);
  }
  fs.renameSync(partial, file);
  if (onProgress) onProgress(received, total);
  return received;
}

const inflateRaw = promisify(zlib.inflateRaw);
const ZIP_END = 0x06054b50;
const ZIP_ENTRY = 0x02014b50;
const ZIP_LOCAL = 0x04034b50;
const ZIP_END_SEARCH = 65557;
const ZIP_STORED = 0;
const ZIP_DEFLATED = 8;

/**
 * Extrait un zip (oxmysql, FXServer pour Windows) sans programme extérieur : le tar de Linux ne lit pas ce format.
 * Les droits Unix rangés dans l'archive sont remis ; un chemin qui sortirait du dossier est refusé.
 */
async function extractZip(archive, dir) {
  const data = await fs.promises.readFile(archive);
  const root = path.resolve(dir);
  let end = -1;
  for (let i = data.length - 22; i >= Math.max(0, data.length - ZIP_END_SEARCH); i -= 1) {
    if (data.readUInt32LE(i) === ZIP_END) {
      end = i;
      break;
    }
  }
  if (end === -1) throw failure('extract_failed', 'zip illisible');
  const count = data.readUInt16LE(end + 10);
  let offset = data.readUInt32LE(end + 16);
  if (count === 0xffff || offset === 0xffffffff) throw failure('extract_failed', 'zip64 non pris en charge');
  for (let n = 0; n < count; n += 1) {
    if (data.readUInt32LE(offset) !== ZIP_ENTRY) throw failure('extract_failed', 'zip abîmé');
    const method = data.readUInt16LE(offset + 10);
    const size = data.readUInt32LE(offset + 20);
    const nameLength = data.readUInt16LE(offset + 28);
    const extraLength = data.readUInt16LE(offset + 30);
    const commentLength = data.readUInt16LE(offset + 32);
    const madeBy = data.readUInt16LE(offset + 4) >> 8;
    const attributes = data.readUInt32LE(offset + 38);
    const local = data.readUInt32LE(offset + 42);
    const name = data.toString('utf8', offset + 46, offset + 46 + nameLength).replace(/\\/g, '/');
    offset += 46 + nameLength + extraLength + commentLength;
    const target = path.resolve(root, name);
    if (target !== root && !target.startsWith(root + path.sep)) throw failure('extract_failed', `chemin refusé : ${name}`);
    if (name.endsWith('/')) {
      fs.mkdirSync(target, { recursive: true });
      continue;
    }
    if (data.readUInt32LE(local) !== ZIP_LOCAL) throw failure('extract_failed', 'zip abîmé');
    const start = local + 30 + data.readUInt16LE(local + 26) + data.readUInt16LE(local + 28);
    const raw = data.subarray(start, start + size);
    let content;
    if (method === ZIP_STORED) content = raw;
    else if (method === ZIP_DEFLATED) content = await inflateRaw(raw);
    else throw failure('extract_failed', `compression ${method} non prise en charge`);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    await fs.promises.writeFile(target, content);
    // archive faite sous Unix : droits d'exécution gardés (scripts)
    const mode = (attributes >>> 16) & 0o777;
    if (madeBy === 3 && mode && process.platform !== 'win32') fs.chmodSync(target, mode);
  }
}

/** Extrait une archive dans un dossier (créé) : zip par la Chancellerie, tar.gz et tar.xz par le tar de la machine. */
function extract(archive, dir) {
  fs.mkdirSync(dir, { recursive: true });
  if (archive.toLowerCase().endsWith('.zip')) return extractZip(archive, dir);
  return new Promise((resolve, reject) => {
    execFile(TAR, ['-xf', archive, '-C', dir], { windowsHide: true, timeout: EXTRACT_TIMEOUT_MS, maxBuffer: 4 * 1024 * 1024 }, (error, stdout, stderr) => {
      if (error) reject(failure('extract_failed', String(stderr || error.message).trim().split('\n').pop()));
      else resolve();
    });
  });
}

function hashFile(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

/**
 * Fichiers d'un dossier, chemins relatifs à barres obliques : { 'client/main.lua': empreinte }. `skip(relatif)` écarte
 * un fichier ou un dossier entier.
 */
function hashTree(dir, skip = () => false) {
  const out = {};
  function walk(current, prefix) {
    let entries;
    try {
      entries = fs.readdirSync(current, { withFileTypes: true });
    } catch (error) {
      return;
    }
    for (const entry of entries) {
      const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
      if (skip(relative)) continue;
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) walk(full, relative);
      else if (entry.isFile()) out[relative] = hashFile(full);
    }
  }
  walk(dir, '');
  return out;
}

/** Copie un fichier (dossiers créés). */
function copyFile(from, to) {
  fs.mkdirSync(path.dirname(to), { recursive: true });
  fs.copyFileSync(from, to);
}

/** Copie un dossier entier (remplace la cible). */
function copyDir(from, to) {
  fs.rmSync(to, { recursive: true, force: true });
  fs.cpSync(from, to, { recursive: true });
}

/** Le seul sous-dossier d'une archive extraite (GitHub range tout dans « auteur-dépôt-commit/ »), sinon le dossier. */
function unwrap(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true }).filter((e) => !e.name.startsWith('pax_global_header'));
  return entries.length === 1 && entries[0].isDirectory() ? path.join(dir, entries[0].name) : dir;
}

module.exports = { getJson, downloadTo, extract, hashFile, hashTree, copyFile, copyDir, unwrap, failure, USER_AGENT };
