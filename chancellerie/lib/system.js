'use strict';
/*
 * lib/system.js
 * Rôle : ce que consomment la machine et FXServer : processeur et mémoire de la machine (lus par Node), trafic de
 *        ses cartes réseau, processeur et mémoire du processus FXServer. Sous Linux, tout se lit dans /proc ; sous
 *        Windows, un seul PowerShell reste ouvert à côté de la Chancellerie et répond à chaque relevé (aucun
 *        compteur de performances localisé, aucune dépendance). Chaque relevé donne des compteurs cumulés : les
 *        débits et les pourcentages sont calculés par différence avec le relevé précédent.
 */

const fs = require('fs');
const os = require('os');
const { spawn } = require('child_process');

const WINDOWS = process.platform === 'win32';
const ANSWER_TIMEOUT_MS = 5000;
const RESPAWN_AFTER_MS = 60000;
// Linux : unités de /proc/<pid>/stat (tops d'horloge) ; 100 sur toutes les distributions courantes
const CLOCK_TICKS = 100;

// Relevé Windows : une ligne lue (numéro de processus, 0 pour aucun), une ligne JSON écrite. L'entrée fermée
// (Chancellerie arrêtée, même brutalement) termine la boucle : aucun PowerShell ne reste orphelin.
const WINDOWS_SAMPLER = `
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
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
  $id = 0
  if ([int]::TryParse($line.Trim(), [ref]$id) -and $id -gt 0) {
    try {
      $p = [System.Diagnostics.Process]::GetProcessById($id)
      $proc = @{ cpuMs = [int64]$p.TotalProcessorTime.TotalMilliseconds; memory = [int64]$p.WorkingSet64; threads = $p.Threads.Count; handles = $p.HandleCount }
    } catch { $proc = $null }
  }
  $out = @{ rx = $rx; tx = $tx; proc = $proc }
  [Console]::Out.WriteLine((ConvertTo-Json $out -Compress -Depth 3))
  [Console]::Out.Flush()
}
`;

let helper = null;
let helperFailedAt = 0;
let previous = null;
let lastCpu = null;

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

function linuxProcess(pid) {
  const stat = readText(`/proc/${pid}/stat`);
  const status = readText(`/proc/${pid}/status`);
  if (!stat || !status) return null;
  // le nom du programme, entre parenthèses, peut contenir des espaces : les champs se lisent après lui
  const fields = stat.slice(stat.lastIndexOf(')') + 2).split(' ');
  const rss = /VmRSS:\s+(\d+)\s+kB/.exec(status);
  const threads = /Threads:\s+(\d+)/.exec(status);
  return {
    cpuMs: ((Number(fields[11]) || 0) + (Number(fields[12]) || 0)) * (1000 / CLOCK_TICKS),
    memory: rss ? Number(rss[1]) * 1024 : 0,
    threads: threads ? Number(threads[1]) : 0,
    handles: null,
  };
}

// Relevé --------------------------------------------------------------------------------------------------------------

/** Compteurs cumulés bruts : { at, rx, tx, proc } (rx, tx, proc à null s'ils sont illisibles). */
async function counters(pid) {
  const at = Date.now();
  if (WINDOWS) {
    const answer = await askHelper(pid);
    if (!answer) return { at, rx: null, tx: null, proc: null };
    return { at, rx: Number(answer.rx), tx: Number(answer.tx), proc: answer.proc && pid ? { pid, ...answer.proc } : null };
  }
  const network = linuxNetwork();
  const proc = pid ? linuxProcess(pid) : null;
  return { at, rx: network ? network.rx : null, tx: network ? network.tx : null, proc: proc ? { pid, ...proc } : null };
}

const rate = (now, before, seconds) => (now === null || before === null || now < before ? null : (now - before) / seconds);

/**
 * Relevé : machine (processeur %, mémoire), réseau (octets par seconde reçus et envoyés) et FXServer (processeur %
 * de toute la machine, mémoire). Les débits et le processeur de FXServer sont null au premier relevé.
 * @param {number|null} pid  processus FXServer à suivre
 */
async function sample(pid) {
  const cores = os.cpus().length || 1;
  const now = await counters(pid);
  const before = previous;
  previous = now;
  const seconds = before ? (now.at - before.at) / 1000 : 0;
  const totalMem = os.totalmem();
  const out = {
    cpu: hostCpu(),
    memory: { used: totalMem - os.freemem(), total: totalMem },
    network: null,
    fxserver: null,
  };
  if (before && seconds > 0) {
    const rx = rate(now.rx, before.rx, seconds);
    const tx = rate(now.tx, before.tx, seconds);
    if (rx !== null && tx !== null) out.network = { rx, tx };
  }
  if (now.proc) {
    let cpu = null;
    if (before && before.proc && before.proc.pid === now.proc.pid && seconds > 0 && now.proc.cpuMs >= before.proc.cpuMs) {
      cpu = Math.min(100, ((now.proc.cpuMs - before.proc.cpuMs) / (seconds * 1000 * cores)) * 100);
    }
    out.fxserver = { cpu, memory: now.proc.memory, threads: now.proc.threads, handles: now.proc.handles };
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

module.exports = { sample, stop, cores: () => os.cpus().length || 1 };
