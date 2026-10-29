'use strict';
/*
 * lib/container.js
 * Rôle : le conteneur vu de l'intérieur (Linux). Chez un hébergeur (Pterodactyl, Docker…), le serveur n'a qu'une part
 *        de la machine, que Node ne voit pas : os.cpus() et os.totalmem() donnent la machine entière. Ses limites et
 *        sa consommation se lisent dans les cgroups (v2, ou v1 sur les machines anciennes) : processeur (quota, temps
 *        consommé, périodes bridées par le quota), mémoire (limite ; occupée sans le cache de fichiers inactif, comme
 *        Docker et Pterodactyl la comptent), cœurs réservés (cpuset) et leur charge (/proc/stat, tous processus
 *        confondus). Hors conteneur (machine dédiée, Windows) : rien, la machine est relevée comme avant.
 */

const fs = require('fs');

const ROOT = '/sys/fs/cgroup';
// présents dans un conteneur Docker (Pterodactyl), Podman, ou sous systemd dans LXC
const MARKERS = ['/.dockerenv', '/run/.containerenv', '/run/systemd/container'];
// v1 sans limite de mémoire : un nombre immense (2⁶³ arrondi à la page), jamais une vraie limite
const UNLIMITED_V1 = 2 ** 60;
const CPU_IDS_MAX = 4096;

// fichiers du conteneur, cherchés une fois : undefined (pas encore), null (hors conteneur)
let source;

function readText(file) {
  try {
    return fs.readFileSync(file, 'utf8');
  } catch (error) {
    return null;
  }
}

function readNumber(file) {
  const text = readText(file);
  const value = text === null ? NaN : Number(text.trim());
  return Number.isFinite(value) ? value : null;
}

/** Fichier « clé valeur » par ligne (cpu.stat, memory.stat) → { clé: nombre }, ou null. */
function readKeyed(file) {
  const text = readText(file);
  if (text === null) return null;
  const out = {};
  for (const line of text.split('\n')) {
    const [key, value] = line.trim().split(/\s+/);
    if (key && value !== undefined && Number.isFinite(Number(value))) out[key] = Number(value);
  }
  return out;
}

/** Liste de cœurs « 0-3,8,10-11 » → [0, 1, 2, 3, 8, 10, 11]. */
function cpuList(text) {
  const out = [];
  for (const part of String(text || '').trim().split(',')) {
    const [from, to] = part.split('-').map((value) => Number(value));
    if (!part || !Number.isInteger(from)) continue;
    const last = Number.isInteger(to) ? to : from;
    for (let id = from; id <= last && out.length < CPU_IDS_MAX; id += 1) out.push(id);
  }
  return out;
}

/** Appartenance du processus (/proc/self/cgroup) : { unified: chemin v2 ou null, controllers: { nom: chemin v1 } }. */
function membership() {
  const out = { unified: null, controllers: {} };
  for (const line of (readText('/proc/self/cgroup') || '').split('\n')) {
    const match = /^(\d+):([^:]*):(.*)$/.exec(line.trim());
    if (!match) continue;
    if (match[1] === '0' && match[2] === '') out.unified = match[3] || '/';
    else for (const name of match[2].split(',')) out.controllers[name] = match[3] || '/';
  }
  return out;
}

/**
 * Dossier d'un cgroup qui contient `probe` : celui du processus (chemin de /proc/self/cgroup) s'il est visible, sinon
 * la racine montée (conteneur dont le cgroup est monté à la racine), sinon null.
 */
function locate(bases, relative, probe) {
  for (const base of bases) {
    if (relative && relative !== '/' && fs.existsSync(`${base}${relative}/${probe}`)) return `${base}${relative}`;
    if (fs.existsSync(`${base}/${probe}`)) return base;
  }
  return null;
}

/** Mémoire occupée sans le cache de fichiers inactif (récupérable à tout moment). */
function withoutCache(usage, inactiveFile) {
  return Number.isFinite(inactiveFile) && inactiveFile < usage ? usage - inactiveFile : usage;
}

function cgroupV2(relative) {
  const dir = locate([ROOT], relative, 'cpu.stat');
  if (!dir) return null;
  return {
    // conteneur : son cgroup est la racine de ce qu'il voit, et porte des limites (memory.max n'existe pas à la vraie racine)
    rooted: dir === ROOT && (!relative || relative === '/') && fs.existsSync(`${ROOT}/memory.max`),
    cpu() {
      const stat = readKeyed(`${dir}/cpu.stat`);
      if (!stat || !Number.isFinite(stat.usage_usec)) return null;
      return { usageUs: stat.usage_usec, periods: Number.isFinite(stat.nr_periods) ? stat.nr_periods : null, throttled: Number.isFinite(stat.nr_throttled) ? stat.nr_throttled : null };
    },
    quota() {
      const [max, period] = (readText(`${dir}/cpu.max`) || '').trim().split(/\s+/);
      return max && max !== 'max' && Number(max) > 0 && Number(period) > 0 ? Number(max) / Number(period) : null;
    },
    memory() {
      const usage = readNumber(`${dir}/memory.current`);
      if (usage === null) return null;
      const stat = readKeyed(`${dir}/memory.stat`) || {};
      const max = (readText(`${dir}/memory.max`) || '').trim();
      return { used: withoutCache(usage, stat.inactive_file), limit: max && max !== 'max' && Number(max) > 0 ? Number(max) : null };
    },
    cpuset() {
      return cpuList(readText(`${dir}/cpuset.cpus.effective`));
    },
  };
}

function cgroupV1(controllers) {
  const cpuBases = [`${ROOT}/cpu,cpuacct`, `${ROOT}/cpuacct,cpu`, `${ROOT}/cpuacct`, `${ROOT}/cpu`];
  const acct = locate(cpuBases, controllers.cpuacct, 'cpuacct.usage');
  if (!acct) return null;
  const cpuDir = locate(cpuBases, controllers.cpu, 'cpu.cfs_quota_us');
  const memoryDir = locate([`${ROOT}/memory`], controllers.memory, 'memory.usage_in_bytes');
  const cpusetDir = locate([`${ROOT}/cpuset`], controllers.cpuset, 'cpuset.cpus');
  return {
    rooted: false,
    cpu() {
      const usage = readNumber(`${acct}/cpuacct.usage`);
      if (usage === null) return null;
      const stat = (cpuDir && readKeyed(`${cpuDir}/cpu.stat`)) || {};
      return { usageUs: usage / 1000, periods: Number.isFinite(stat.nr_periods) ? stat.nr_periods : null, throttled: Number.isFinite(stat.nr_throttled) ? stat.nr_throttled : null };
    },
    quota() {
      if (!cpuDir) return null;
      const quota = readNumber(`${cpuDir}/cpu.cfs_quota_us`);
      const period = readNumber(`${cpuDir}/cpu.cfs_period_us`);
      return quota > 0 && period > 0 ? quota / period : null;
    },
    memory() {
      if (!memoryDir) return null;
      const usage = readNumber(`${memoryDir}/memory.usage_in_bytes`);
      if (usage === null) return null;
      const stat = readKeyed(`${memoryDir}/memory.stat`) || {};
      const limit = readNumber(`${memoryDir}/memory.limit_in_bytes`);
      return { used: withoutCache(usage, stat.total_inactive_file), limit: limit > 0 && limit < UNLIMITED_V1 ? limit : null };
    },
    cpuset() {
      if (!cpusetDir) return [];
      return cpuList(readText(`${cpusetDir}/cpuset.effective_cpus`) || readText(`${cpusetDir}/cpuset.cpus`));
    },
  };
}

/** Les fichiers du conteneur, ou null hors conteneur (cherchés une fois). */
function find() {
  if (source !== undefined) return source;
  source = null;
  if (process.platform !== 'linux') return source;
  const member = membership();
  const group = fs.existsSync(`${ROOT}/cgroup.controllers`) ? cgroupV2(member.unified) : cgroupV1(member.controllers);
  if (group && (group.rooted || MARKERS.some((file) => fs.existsSync(file)))) source = group;
  return source;
}

/** Vrai si la Chancellerie tourne dans un conteneur dont les cgroups sont lisibles. */
function active() {
  return find() !== null;
}

/**
 * Limites du conteneur : { quota (cœurs, ex. 2.5, ou null sans quota), cpuset ([numéros des cœurs permis]),
 * memoryLimit (octets ou null) }, ou null hors conteneur.
 */
function limits() {
  const group = find();
  if (!group) return null;
  const memory = group.memory();
  return { quota: group.quota(), cpuset: group.cpuset(), memoryLimit: memory ? memory.limit : null };
}

/**
 * Compteurs cumulés du conteneur : { usageUs, periods, throttled, memory: { used, limit } | null }, ou null.
 */
function counters() {
  const group = find();
  if (!group) return null;
  const cpu = group.cpu();
  if (!cpu) return null;
  return { ...cpu, memory: group.memory() };
}

/** Temps cumulés de quelques cœurs de la machine (/proc/stat) : { numéro: { busy, total } } en tops d'horloge. */
function coreTimes(ids) {
  const wanted = new Set(ids);
  const out = {};
  for (const line of (readText('/proc/stat') || '').split('\n')) {
    const match = /^cpu(\d+)\s+(.*)$/.exec(line);
    if (!match || !wanted.has(Number(match[1]))) continue;
    const [user, nice, system, idle, iowait, irq, softirq, steal] = match[2].trim().split(/\s+/).map((v) => Number(v) || 0);
    const busy = user + nice + system + irq + softirq;
    out[match[1]] = { busy, total: busy + idle + iowait + steal };
  }
  return out;
}

module.exports = { active, limits, counters, coreTimes, cpuList };
