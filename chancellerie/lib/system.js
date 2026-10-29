'use strict';
/*
 * lib/system.js
 * Rôle : ce que consomment la machine (ou le conteneur) et FXServer : processeur et mémoire de la machine (lus par
 *        Node) ou, chez un hébergeur, du conteneur rapportés à son allocation (lib/container.js) avec le temps bridé
 *        par son quota et la charge de ses cœurs réservés ; trafic des cartes réseau ; processeur et mémoire du
 *        processus FXServer, et ses fils les plus chargés (en % d'un cœur : un fil à 100 % sature son cœur). Sous
 *        Linux, tout se lit dans /proc et les cgroups ; sous Windows, un seul PowerShell reste ouvert à côté de la
 *        Chancellerie et répond à chaque relevé (aucun compteur de performances localisé, aucune dépendance). Chaque
 *        relevé donne des compteurs cumulés : les débits et les pourcentages sont calculés par différence avec le
 *        relevé précédent.
 */

const fs = require('fs');
const os = require('os');
const { spawn } = require('child_process');
const container = require('./container');

const WINDOWS = process.platform === 'win32';
const ANSWER_TIMEOUT_MS = 5000;
const RESPAWN_AFTER_MS = 60000;
// Linux : unités de /proc/<pid>/stat (tops d'horloge) ; 100 sur toutes les distributions courantes
const CLOCK_TICKS = 100;
// fils de FXServer gardés dans un relevé : les plus chargés
const BUSIEST_MAX = 8;

// Relevé Windows : une ligne lue (numéro de processus, 0 pour aucun), une ligne JSON écrite. L'entrée fermée
// (Chancellerie arrêtée, même brutalement) termine la boucle : aucun PowerShell ne reste orphelin. Les noms des fils
// (posés par FXServer) se lisent par GetThreadDescription (Windows 10 1607 et plus) ; sans elle, les fils restent
// sans nom.
const WINDOWS_SAMPLER = `
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$named = $false
try {
  Add-Type -Namespace Vava -Name Threads -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr OpenThread(int access, bool inherit, int id);
[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
[DllImport("kernel32.dll")] public static extern int GetThreadDescription(IntPtr thread, out IntPtr text);
[DllImport("kernel32.dll")] public static extern IntPtr LocalFree(IntPtr memory);
public static string Name(int id) {
  IntPtr handle = OpenThread(0x0800, false, id);
  if (handle == IntPtr.Zero) return null;
  try {
    IntPtr text;
    if (GetThreadDescription(handle, out text) < 0 || text == IntPtr.Zero) return null;
    try { return System.Runtime.InteropServices.Marshal.PtrToStringUni(text); } finally { LocalFree(text); }
  } finally { CloseHandle(handle); }
}
'@
  $named = $true
} catch { }
while ($true) {
  $line = [Console]::In.ReadLine()
  if ($line -eq $null) { break }
  $rx = [int64]0; $tx = [int64]0
  foreach ($nic in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
    try {
      if ($nic.NetworkInterfaceType -eq 'Loopback' -or $nic.OperationalStatus -ne 'Up') { continue }
      $stats = $nic.GetIPStatistics()
      $rx += $stats.BytesReceived; $tx += $stats.BytesSent
    } catch { }
  }
  $proc = $null
  $threads = $null
  $id = 0
  if ([int]::TryParse($line.Trim(), [ref]$id) -and $id -gt 0) {
    try {
      $p = [System.Diagnostics.Process]::GetProcessById($id)
      $proc = @{ cpuMs = [int64]$p.TotalProcessorTime.TotalMilliseconds; memory = [int64]$p.WorkingSet64; threads = $p.Threads.Count; handles = $p.HandleCount }
      $threads = @(foreach ($t in $p.Threads) {
        try {
          $name = $null
          if ($named) { try { $name = [Vava.Threads]::Name($t.Id) } catch { $named = $false } }
          @{ id = $t.Id; ms = [int64]$t.TotalProcessorTime.TotalMilliseconds; name = $name }
        } catch { }
      })
    } catch { $proc = $null; $threads = $null }
  }
  $out = @{ rx = $rx; tx = $tx; proc = $proc; threads = $threads }
  [Console]::Out.WriteLine((ConvertTo-Json $out -Compress -Depth 4))
  [Console]::Out.Flush()
}
`;

let helper = null;
let helperFailedAt = 0;
let previous = null;
let lastCpu = null;
// temps cumulés des fils de FXServer au relevé précédent : { pid, times: numéro du fil → ms }
let lastThreads = { pid: null, times: new Map() };

/** Temps cumulés des cœurs : { busy, total } en millisecondes. */
function cpuTimes() {
  let busy = 0;
  let total = 0;
  for (const core of os.cpus()) {
    const { user, nice, sys, irq, idle } = core.times;
    busy += user + nice + sys + irq;
    total += user + nice + sys + irq + idle;
  }
  return { busy, total };
}

/** Processeur de la machine depuis l'appel précédent, en % (null au premier). */
function hostCpu() {
  const now = cpuTimes();
  const before = lastCpu;
  lastCpu = now;
  if (!before || now.total <= before.total) return null;
  return Math.min(100, Math.max(0, ((now.busy - before.busy) / (now.total - before.total)) * 100));
}

const hostCores = () => os.cpus().length || 1;

/** Cœurs dont dispose le serveur : l'allocation du conteneur (quota, cœurs permis) ou ceux de la machine. */
function capacity(limit) {
  let cores = hostCores();
  if (limit && limit.quota) cores = Math.min(cores, limit.quota);
  if (limit && limit.cpuset.length) cores = Math.min(cores, limit.cpuset.length);
  return cores;
}

/** Cœurs réservés au conteneur (épinglés par l'hébergeur), ou null s'il tourne sur tous ceux de la machine. */
function reservedCores(limit) {
  return limit && limit.cpuset.length && limit.cpuset.length < hostCores() ? limit.cpuset : null;
}

// Windows -------------------------------------------------------------------------------------------------------------

function startHelper() {
  const encoded = Buffer.from(WINDOWS_SAMPLER, 'utf16le').toString('base64');
  let child;
  try {
    child = spawn('powershell.exe', ['-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', encoded], {
      windowsHide: true, stdio: ['pipe', 'pipe', 'ignore'],
    });
  } catch (error) {
    helperFailedAt = Date.now();
    return null;
  }
  const state = { child, buffer: '', waiting: [] };
  child.stdout.setEncoding('utf8');
  child.stdout.on('data', (chunk) => {
    state.buffer += chunk;
    let index = state.buffer.indexOf('\n');
    while (index !== -1) {
      const line = state.buffer.slice(0, index).trim();
      state.buffer = state.buffer.slice(index + 1);
      const resolve = state.waiting.shift();
      if (resolve) {
        try {
          resolve(JSON.parse(line));
        } catch (error) {
          resolve(null);
        }
      }
      index = state.buffer.indexOf('\n');
    }
  });
  const fail = () => {
    if (helper === state) helper = null;
    helperFailedAt = Date.now();
    for (const resolve of state.waiting.splice(0)) resolve(null);
  };
  child.on('error', fail);
  child.on('exit', fail);
  child.stdin.on('error', fail);
  return state;
}

/** Une réponse du PowerShell, ou null (absent, en panne, trop lent). */
function askHelper(pid) {
  if (!helper) {
    if (Date.now() - helperFailedAt < RESPAWN_AFTER_MS) return Promise.resolve(null);
    helper = startHelper();
    if (!helper) return Promise.resolve(null);
  }
  const state = helper;
  return new Promise((resolve) => {
    let done = false;
    const finish = (value) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      resolve(value);
    };
    const timer = setTimeout(() => {
      // réponse en retard : sa place reste dans la file, pour qu'elle soit jetée et ne réponde pas à la suivante
      const index = state.waiting.indexOf(finish);
      if (index !== -1) state.waiting.splice(index, 1, () => {});
      finish(null);
    }, ANSWER_TIMEOUT_MS);
    state.waiting.push(finish);
    state.child.stdin.write(`${pid || 0}\n`);
  });
}

// Linux ---------------------------------------------------------------------------------------------------------------

function readText(file) {
  try {
    return fs.readFileSync(file, 'utf8');
  } catch (error) {
    return null;
  }
}

// interfaces virtuelles (bouclage, Docker, ponts, VPN de conteneurs) : leur trafic est déjà compté par la carte réelle
const VIRTUAL_INTERFACE = /^(lo|docker\d*|veth|br-|virbr|cni|flannel|tun|tap|wg)/;

function linuxNetwork() {
  const text = readText('/proc/net/dev');
  if (!text) return null;
  let rx = 0;
  let tx = 0;
  for (const line of text.split('\n').slice(2)) {
    const [name, rest] = line.split(':');
    if (!rest || VIRTUAL_INTERFACE.test(name.trim())) continue;
    const fields = rest.trim().split(/\s+/).map(Number);
    rx += fields[0] || 0;
    tx += fields[8] || 0;
  }
  return { rx, tx };
}

/** Nom et temps processeur (ms) d'une ligne /proc/…/stat. */
function statTimes(stat) {
  // le nom, entre parenthèses, peut contenir des espaces : les champs se lisent après lui
  const close = stat.lastIndexOf(')');
  const fields = stat.slice(close + 2).split(' ');
  return {
    name: stat.slice(stat.indexOf('(') + 1, close),
    ms: ((Number(fields[11]) || 0) + (Number(fields[12]) || 0)) * (1000 / CLOCK_TICKS),
  };
}

function linuxProcess(pid) {
  const stat = readText(`/proc/${pid}/stat`);
  const status = readText(`/proc/${pid}/status`);
  if (!stat || !status) return null;
  const rss = /VmRSS:\s+(\d+)\s+kB/.exec(status);
  const threads = /Threads:\s+(\d+)/.exec(status);
  return {
    cpuMs: statTimes(stat).ms,
    memory: rss ? Number(rss[1]) * 1024 : 0,
    threads: threads ? Number(threads[1]) : 0,
    handles: null,
  };
}

/** Fils d'un processus : [{ id, name, ms, main }] ; un fil sans nom à lui (celui du processus) a name à null. */
function linuxThreads(pid) {
  let ids;
  try {
    ids = fs.readdirSync(`/proc/${pid}/task`);
  } catch (error) {
    return null;
  }
  const out = [];
  let leader = null;
  for (const id of ids) {
    const stat = readText(`/proc/${pid}/task/${id}/stat`);
    if (!stat) continue; // fil terminé entre-temps
    const thread = { id: Number(id), ...statTimes(stat), main: Number(id) === pid };
    if (thread.main) leader = thread.name;
    out.push(thread);
  }
  // le nom du processus (FXServer, ou le chargeur musl lancé par run.sh) n'est pas celui d'un fil
  for (const thread of out) if (thread.main || thread.name === leader) thread.name = null;
  return out;
}

// Relevé --------------------------------------------------------------------------------------------------------------

/** Fils lus par le PowerShell : [{ id, name, ms, main }] (une liste d'un seul élément peut arriver sans crochets). */
function windowsThreads(list) {
  const threads = Array.isArray(list) ? list : list ? [list] : [];
  return threads.map((t) => ({ id: Number(t.id) || 0, name: typeof t.name === 'string' && t.name ? t.name : null, ms: Number(t.ms) || 0, main: false }));
}

/**
 * Compteurs cumulés bruts : { at, rx, tx, proc, threads, limit, box, cores } (à null s'ils sont illisibles ; limit,
 * box et cores seulement dans un conteneur : limites, compteurs du cgroup, temps des cœurs réservés).
 */
async function counters(pid) {
  const at = Date.now();
  if (WINDOWS) {
    const answer = await askHelper(pid);
    if (!answer) return { at, rx: null, tx: null, proc: null, threads: null, limit: null, box: null, cores: null };
    return {
      at, rx: Number(answer.rx), tx: Number(answer.tx),
      proc: answer.proc && pid ? { pid, ...answer.proc } : null,
      threads: answer.proc && pid ? windowsThreads(answer.threads) : null,
      limit: null, box: null, cores: null,
    };
  }
  const network = linuxNetwork();
  const proc = pid ? linuxProcess(pid) : null;
  const limit = container.limits();
  const box = limit ? container.counters() : null;
  const reserved = box ? reservedCores(limit) : null;
  return {
    at, rx: network ? network.rx : null, tx: network ? network.tx : null,
    proc: proc ? { pid, ...proc } : null,
    threads: proc ? linuxThreads(pid) : null,
    limit: box ? limit : null, box, cores: reserved ? container.coreTimes(reserved) : null,
  };
}

const rate = (now, before, seconds) => (now === null || before === null || now < before ? null : (now - before) / seconds);
const percent = (value) => Math.min(100, Math.max(0, value));

/** Fils de FXServer les plus chargés depuis le relevé précédent : [{ id, name, main, cpu (% d'un cœur) }]. */
function busiest(pid, threads, seconds) {
  const known = lastThreads.pid === pid ? lastThreads.times : new Map();
  const times = new Map();
  const out = [];
  for (const thread of threads) {
    times.set(thread.id, thread.ms);
    const before = known.get(thread.id);
    if (before === undefined || seconds <= 0 || thread.ms < before) continue;
    out.push({ id: thread.id, name: thread.name, main: thread.main, cpu: percent(((thread.ms - before) / (seconds * 1000)) * 100) });
  }
  lastThreads = { pid, times };
  return out.sort((a, b) => b.cpu - a.cpu).slice(0, BUSIEST_MAX);
}

/** Charge des cœurs réservés depuis le relevé précédent : [{ id, cpu }] (cpu null au premier relevé). */
function coreLoads(now, before) {
  return Object.keys(now).map(Number).sort((a, b) => a - b).map((id) => {
    const a = now[id];
    const b = before && before[id];
    return { id, cpu: b && a.total > b.total ? percent(((a.busy - b.busy) / (a.total - b.total)) * 100) : null };
  });
}

/**
 * Relevé : portée ('container' chez un hébergeur, sinon 'machine') et cœurs dont dispose le serveur (capacity) ;
 * processeur % de cette capacité, mémoire, temps bridé % (conteneur avec quota) et charge des cœurs réservés ; réseau
 * (octets par seconde reçus et envoyés) ; FXServer (processeur % de la capacité, mémoire, fils les plus chargés). Les
 * débits et les pourcentages sont null (ou absents) au premier relevé.
 * @param {number|null} pid  processus FXServer à suivre
 */
async function sample(pid) {
  const now = await counters(pid);
  const before = previous;
  previous = now;
  const seconds = before ? (now.at - before.at) / 1000 : 0;
  const cores = capacity(now.limit);
  const out = {
    scope: now.box ? 'container' : 'machine',
    capacity: cores,
    cpu: null,
    memory: null,
    throttled: null,
    cores: now.cores ? coreLoads(now.cores, before && before.cores) : null,
    network: null,
    fxserver: null,
  };
  if (now.box) {
    const was = before && before.box;
    if (was && seconds > 0 && now.box.usageUs >= was.usageUs) out.cpu = percent(((now.box.usageUs - was.usageUs) / (seconds * 1e6 * cores)) * 100);
    // bridé : part des périodes du quota où le conteneur a buté sur sa limite (aucune période : rien à brider)
    const counted = (box) => box.periods !== null && box.throttled !== null;
    if (was && now.limit.quota && counted(now.box) && counted(was) && now.box.periods >= was.periods) {
      const periods = now.box.periods - was.periods;
      out.throttled = periods > 0 ? percent(((now.box.throttled - was.throttled) / periods) * 100) : 0;
    }
    out.memory = now.box.memory ? { used: now.box.memory.used, total: now.box.memory.limit || os.totalmem() } : null;
  } else {
    out.cpu = hostCpu();
  }
  if (!out.memory) {
    const totalMem = os.totalmem();
    out.memory = { used: totalMem - os.freemem(), total: totalMem };
  }
  if (before && seconds > 0) {
    const rx = rate(now.rx, before.rx, seconds);
    const tx = rate(now.tx, before.tx, seconds);
    if (rx !== null && tx !== null) out.network = { rx, tx };
  }
  if (now.proc) {
    let cpu = null;
    if (before && before.proc && before.proc.pid === now.proc.pid && seconds > 0 && now.proc.cpuMs >= before.proc.cpuMs) {
      cpu = percent(((now.proc.cpuMs - before.proc.cpuMs) / (seconds * 1000 * cores)) * 100);
    }
    out.fxserver = {
      cpu, memory: now.proc.memory, threads: now.proc.threads, handles: now.proc.handles,
      busiest: now.threads ? busiest(now.proc.pid, now.threads, seconds) : null,
    };
  }
  return out;
}

/** Ferme le PowerShell de relevé (arrêt de la Chancellerie). */
function stop() {
  if (helper) {
    helper.child.stdin.end();
    helper = null;
  }
}

/** Cœurs dont dispose le serveur (allocation du conteneur, ou machine). */
function cores() {
  return capacity(WINDOWS ? null : container.limits());
}

/** 'container' chez un hébergeur (cgroups lisibles), sinon 'machine'. */
function scope() {
  return !WINDOWS && container.active() ? 'container' : 'machine';
}

module.exports = { sample, stop, cores, scope };
