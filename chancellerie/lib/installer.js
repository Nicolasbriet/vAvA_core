'use strict';
/*
 * lib/installer.js
 * Rôle : poser vAvA sur le disque et l'y tenir à jour sans rien casser.
 *        - Disposition du dépôt : la racine est la ressource vAvA_core (sans modules/, examples/, chancellerie/,
 *          docs/), chaque dossier de modules/ une ressource ([vava]), chaque dossier d'examples/ une ressource
 *          d'outils de développement ([vava-dev], posée mais jamais lancée d'office), chancellerie/ la Chancellerie.
 *        - Fusion à trois voies, fichier par fichier : la version installée (empreintes gardées dans
 *          data/install.json), celle du disque, la nouvelle. Un fichier que personne n'a touché est remplacé ; un
 *          fichier modifié sur place et inchangé en amont est gardé ; modifié des deux côtés, un fichier de réglages
 *          (config.lua, config_client.lua, config/…) est gardé et la nouvelle version posée à côté (« .nouveau »),
 *          un autre fichier est remplacé et l'ancien gardé à côté (« .local »). Sans version installée connue (vAvA
 *          posé à la main), les fichiers de réglages qui diffèrent sont gardés, les autres remplacés.
 *        - Sauvegarde des ressources touchées avant d'écrire, et restauration à l'identique (retour en arrière).
 *        - Première installation : FXServer (build recommandée par Cfx.re), oxmysql (dernière version).
 *        - La Chancellerie elle-même : nouvelle version vérifiée (elle doit se charger) avant de remplacer les
 *          fichiers ; l'ancienne est gardée, et demarrer.bat la remet si la nouvelle ne démarre pas.
 */

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const config = require('./config');
const dl = require('./download');
const resources = require('./resources');

const STATE_FILE = path.join(config.DATA, 'install.json');
const UPDATES = path.join(config.DATA, 'updates');
const STAGING = path.join(UPDATES, 'staging');
const BACKUPS = path.join(UPDATES, 'backups');
const PANEL_PREVIOUS = path.join(UPDATES, 'chancellerie-precedente');
// tant que ce fichier existe, la nouvelle Chancellerie n'a pas encore prouvé qu'elle démarre (lu par demarrer.bat)
const PANEL_FLAG = path.join(UPDATES, 'chancellerie-a-verifier');
// laissé par demarrer.bat quand il a remis l'ancienne version
const PANEL_REVERTED = path.join(UPDATES, 'chancellerie-annulee');
const BACKUPS_KEPT = 3;
const CORE = 'vAvA_core';
const CATEGORY = '[vava]';
// exemples et outils de développement du dépôt : posés dans leur propre catégorie, à activer à la main
const DEV_CATEGORY = '[vava-dev]';
const RESOURCE_FOLDERS = [{ dir: 'modules', category: CATEGORY }, { dir: 'examples', category: DEV_CATEGORY }];
const ROOT_EXCLUDED = new Set(['modules', 'examples', 'chancellerie', 'docs', '.github', '.git', '.gitignore', '.gitattributes']);
// dans le dossier de la Chancellerie : jamais touchés par une mise à jour
const PANEL_KEPT = new Set(['data', 'node', 'node.exe']);
// le lanceur en cours d'exécution ne se réécrit pas (cmd comme bash le lisent au fil de l'eau) : sa nouvelle version
// est posée à côté
const PANEL_LAUNCHERS = [process.platform === 'win32' ? 'demarrer.bat' : 'demarrer.sh'];
const VERIFY_TIMEOUT_MS = 30000;
const FIVEM_VERSIONS = (platform) => `https://changelogs-live.fivem.net/api/changelog/versions/${platform}/server`;
const OXMYSQL_RELEASE = 'https://api.github.com/repos/overextended/oxmysql/releases/latest';

// État ----------------------------------------------------------------------------------------------------------------

/** Ce qui est installé : source (commit), ressources (dossier et empreintes), Chancellerie, oxmysql, FXServer. */
function state() {
  return config.readJson(STATE_FILE, { source: null, resources: {}, chancellerie: null, oxmysql: null, fxserver: null, pending: null });
}

function saveState(value) {
  config.writeJson(STATE_FILE, value);
}

const resourcesRoot = (serverDataPath) => path.join(serverDataPath, 'resources');

/** Fichier de réglages, que son propriétaire a pu adapter ? */
function userOwned(relative) {
  return ['config.lua', 'config_client.lua'].includes(path.posix.basename(relative)) || relative.startsWith('config/');
}

// Dépôt ---------------------------------------------------------------------------------------------------------------

/**
 * Ressources d'un dépôt extrait : [{ name, dir, skip }] ; et le dossier de la Chancellerie (ou null).
 * @param {string} root
 */
function layout(root) {
  if (!fs.existsSync(path.join(root, 'fxmanifest.lua'))) throw dl.failure('bad_archive', 'fxmanifest.lua absent à la racine du dépôt');
  const list = [{ name: CORE, dir: root, category: CATEGORY, skip: (relative) => ROOT_EXCLUDED.has(relative.split('/')[0]) }];
  for (const folder of RESOURCE_FOLDERS) {
    const base = path.join(root, folder.dir);
    let names = [];
    try {
      names = fs.readdirSync(base, { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name).sort();
    } catch (error) {
      names = [];
    }
    for (const name of names) {
      if (fs.existsSync(path.join(base, name, 'fxmanifest.lua'))) {
        list.push({ name, dir: path.join(base, name), category: folder.category, skip: (r) => r.split('/')[0] === '.git' });
      }
    }
  }
  const panel = path.join(root, 'chancellerie');
  return { resources: list, panel: fs.existsSync(path.join(panel, 'index.js')) ? panel : null };
}

/** Dossier d'une ressource sur le disque : celui de l'installation, sinon celui trouvé, sinon <catégorie>/nom. */
function targetOf(name, serverDataPath, installed, found, category = CATEGORY) {
  const root = resourcesRoot(serverDataPath);
  const known = installed.resources[name] && installed.resources[name].folder;
  if (known && fs.existsSync(path.join(root, known))) return path.join(root, known);
  const scanned = found.find((r) => r.name === name);
  if (scanned) return path.join(root, scanned.folder);
  return path.join(root, category, name);
}

/** `.git` dans ce dossier ou l'un de ses deux parents ? */
function gitAbove(start) {
  let current = start;
  for (let level = 0; level < 3; level += 1) {
    if (fs.existsSync(path.join(current, '.git'))) return true;
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
  return false;
}

/**
 * Un dossier suivi par git (copie de développement) : on ne l'écrase pas, on le signale. Un lien ou une jonction
 * (ressource posée par `mklink /J` vers un dépôt) est suivi jusqu'au vrai dossier : c'est lui que git suit.
 */
function inGitCheckout(dir) {
  const logical = path.resolve(dir);
  if (gitAbove(logical)) return true;
  let real;
  try {
    real = fs.realpathSync.native(logical);
  } catch (error) {
    return false;
  }
  return real !== logical && gitAbove(real);
}

// Fusion --------------------------------------------------------------------------------------------------------------

/**
 * Ce qu'il faut faire pour amener `target` à la version de `source`, en gardant les modifications locales.
 * @param {Record<string, string>} incoming  empreintes de la nouvelle version
 * @param {Record<string, string>|null} baseline  empreintes de la version installée (null : inconnue)
 * @returns {{ copy: string[], keepLocal: string[], sideNew: string[], sideLocal: string[], remove: string[] }}
 */
function plan(target, incoming, baseline) {
  const out = { copy: [], keepLocal: [], sideNew: [], sideLocal: [], remove: [] };
  for (const [relative, fresh] of Object.entries(incoming)) {
    const file = path.join(target, relative);
    const local = fs.existsSync(file) ? dl.hashFile(file) : null;
    const base = baseline ? baseline[relative] : undefined;
    if (local === fresh) continue;
    if (local === null || (base !== undefined && local === base)) out.copy.push(relative);
    else if (base !== undefined && fresh === base) out.keepLocal.push(relative);
    else if (userOwned(relative)) out.sideNew.push(relative);
    else if (base === undefined) out.copy.push(relative);
    else out.sideLocal.push(relative);
  }
  for (const [relative, base] of Object.entries(baseline || {})) {
    if (incoming[relative] !== undefined) continue;
    const file = path.join(target, relative);
    if (fs.existsSync(file) && dl.hashFile(file) === base) out.remove.push(relative);
  }
  return out;
}

const changes = (p) => p.copy.length + p.sideNew.length + p.sideLocal.length + p.remove.length;

/** Applique un plan (les fichiers « .nouveau » et « .local » sont posés à côté de l'original). */
function applyPlan(source, target, p) {
  for (const relative of p.copy) dl.copyFile(path.join(source, relative), path.join(target, relative));
  for (const relative of p.sideNew) dl.copyFile(path.join(source, relative), path.join(target, `${relative}.nouveau`));
  for (const relative of p.sideLocal) {
    dl.copyFile(path.join(target, relative), path.join(target, `${relative}.local`));
    dl.copyFile(path.join(source, relative), path.join(target, relative));
  }
  for (const relative of p.remove) fs.rmSync(path.join(target, relative), { force: true });
}

/**
 * Plans de toutes les ressources d'un dépôt extrait contre le serveur.
 * @returns {{ name, source, target, incoming, plan, isNew }[]}
 */
function planResources(root, serverDataPath) {
  const installed = state();
  const found = resources.scan(serverDataPath, { details: true });
  return layout(root).resources.map((resource) => {
    const target = targetOf(resource.name, serverDataPath, installed, found, resource.category);
    const incoming = dl.hashTree(resource.dir, resource.skip);
    const baseline = installed.resources[resource.name] ? installed.resources[resource.name].files : null;
    return { name: resource.name, source: resource.dir, target, incoming, plan: plan(target, incoming, baseline), isNew: !fs.existsSync(target) };
  });
}

// Sauvegarde des ressources --------------------------------------------------------------------------------------------

/** Copie des dossiers qui vont changer, et de l'état ; renvoie l'identifiant de la sauvegarde. */
function backupResources(plans) {
  const id = new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-');
  const dir = path.join(BACKUPS, id);
  const meta = { at: Date.now(), resources: {}, created: [] };
  for (const item of plans) {
    if (!changes(item.plan)) continue;
    if (item.isNew) {
      meta.created.push(item.target);
      continue;
    }
    dl.copyDir(item.target, path.join(dir, 'resources', item.name));
    meta.resources[item.name] = item.target;
  }
  fs.mkdirSync(dir, { recursive: true });
  config.writeJson(path.join(dir, 'meta.json'), meta);
  config.writeJson(path.join(dir, 'install.json'), state());
  // les plus anciennes sauvegardes s'en vont
  const all = fs.readdirSync(BACKUPS).sort();
  for (const old of all.slice(0, Math.max(0, all.length - BACKUPS_KEPT))) fs.rmSync(path.join(BACKUPS, old), { recursive: true, force: true });
  return id;
}

/** Remet les ressources (et l'état) telles qu'avant la mise à jour. */
function restoreResources(id) {
  const dir = path.join(BACKUPS, id);
  const meta = config.readJson(path.join(dir, 'meta.json'), null);
  if (!meta) throw dl.failure('backup_missing', `sauvegarde ${id} introuvable`);
  for (const [name, target] of Object.entries(meta.resources)) dl.copyDir(path.join(dir, 'resources', name), target);
  for (const target of meta.created) fs.rmSync(target, { recursive: true, force: true });
  const previous = config.readJson(path.join(dir, 'install.json'), null);
  if (previous) saveState({ ...previous, pending: null });
}

/**
 * Applique les plans des ressources et retient la nouvelle version installée.
 * @returns {{ changed: string[], added: string[], kept: string[], sideNew: string[], sideLocal: string[] }}
 */
function applyResources(plans, serverDataPath, source) {
  const root = resourcesRoot(serverDataPath);
  const report = { changed: [], added: [], kept: [], sideNew: [], sideLocal: [] };
  const installed = state();
  for (const item of plans) {
    if (changes(item.plan)) {
      applyPlan(item.source, item.target, item.plan);
      (item.isNew ? report.added : report.changed).push(item.name);
    }
    report.kept.push(...item.plan.keepLocal.map((f) => `${item.name}/${f}`));
    report.sideNew.push(...item.plan.sideNew.map((f) => `${item.name}/${f}`));
    report.sideLocal.push(...item.plan.sideLocal.map((f) => `${item.name}/${f}`));
    installed.resources[item.name] = { folder: path.relative(root, item.target).split(path.sep).join('/'), files: item.incoming };
  }
  installed.source = source;
  saveState(installed);
  return report;
}

// Téléchargements -----------------------------------------------------------------------------------------------------

/** Dépôt téléchargé et extrait à une version ; renvoie son dossier racine. */
async function fetchSource(updates, ref, job) {
  const archive = path.join(STAGING, `source-${ref.replace(/[^\w.-]/g, '_')}.tar.gz`);
  const dir = path.join(STAGING, `source-${ref.replace(/[^\w.-]/g, '_')}`);
  fs.rmSync(dir, { recursive: true, force: true });
  await dl.downloadTo(`${updates.codeload}/${updates.repo}/tar.gz/${encodeURIComponent(ref)}`, archive, job ? job.track : undefined);
  await dl.extract(archive, dir);
  fs.rmSync(archive, { force: true });
  return dl.unwrap(dir);
}

/** Build recommandée de FXServer pour cette machine : { build, url }. */
async function recommendedFxserver() {
  const info = await dl.getJson(FIVEM_VERSIONS(process.platform === 'win32' ? 'win32' : 'linux'));
  if (!info.recommended || !info.recommended_download) throw dl.failure('artifacts_unavailable', 'réponse inattendue de Cfx.re');
  return { build: String(info.recommended), url: String(info.recommended_download) };
}

/** Pose FXServer dans `dir` (s'il n'y est pas déjà) ; renvoie le chemin de son exécutable. */
async function installFxserver(dir, job) {
  const executable = path.join(dir, process.platform === 'win32' ? 'FXServer.exe' : 'run.sh');
  if (fs.existsSync(executable)) {
    job.say(`FXServer est déjà présent : ${executable}`);
    return executable;
  }
  const { build, url } = await recommendedFxserver();
  job.say(`Téléchargement de FXServer (build recommandée ${build})…`);
  const archive = path.join(STAGING, `fxserver-${build}${url.endsWith('.zip') ? '.zip' : '.tar.xz'}`);
  await dl.downloadTo(url, archive, job.track);
  job.say('Extraction de FXServer…');
  await dl.extract(archive, dir);
  fs.rmSync(archive, { force: true });
  if (!fs.existsSync(executable)) throw dl.failure('fxserver_invalid', `${path.basename(executable)} absent de l'archive`);
  const installed = state();
  installed.fxserver = { build, at: Date.now() };
  saveState(installed);
  return executable;
}

/** Pose oxmysql (dernière version) dans resources/[standalone] s'il manque. */
async function installOxmysql(serverDataPath, job) {
  if (resources.scan(serverDataPath).some((r) => r.name === 'oxmysql')) {
    job.say('oxmysql est déjà présent.');
    return null;
  }
  const release = await dl.getJson(OXMYSQL_RELEASE);
  const asset = (release.assets || []).find((a) => a.name === 'oxmysql.zip');
  if (!asset) throw dl.failure('oxmysql_unavailable', 'oxmysql.zip absent de la dernière version');
  job.say(`Téléchargement d'oxmysql ${release.tag_name}…`);
  const archive = path.join(STAGING, 'oxmysql.zip');
  const dir = path.join(STAGING, 'oxmysql');
  fs.rmSync(dir, { recursive: true, force: true });
  await dl.downloadTo(asset.browser_download_url, archive, job.track);
  await dl.extract(archive, dir);
  const source = fs.existsSync(path.join(dir, 'fxmanifest.lua')) ? dir : path.join(dir, 'oxmysql');
  if (!fs.existsSync(path.join(source, 'fxmanifest.lua'))) throw dl.failure('oxmysql_unavailable', 'archive d\'oxmysql inattendue');
  dl.copyDir(source, path.join(resourcesRoot(serverDataPath), '[standalone]', 'oxmysql'));
  fs.rmSync(archive, { force: true });
  fs.rmSync(dir, { recursive: true, force: true });
  const installed = state();
  installed.oxmysql = { version: release.tag_name, at: Date.now() };
  saveState(installed);
  return release.tag_name;
}

// La Chancellerie elle-même ---------------------------------------------------------------------------------------------

const panelSkip = (relative) => PANEL_KEPT.has(relative.split('/')[0]);

/** Plan de mise à jour de la Chancellerie (dossier de la nouvelle version) ; null si rien ne change. */
function planPanel(source) {
  if (!source) return null;
  const incoming = dl.hashTree(source, panelSkip);
  const installed = state();
  const baseline = installed.chancellerie ? installed.chancellerie.files : null;
  const p = plan(config.HOME, incoming, baseline);
  // aucun fichier de la Chancellerie n'est un réglage : une modification locale cède à la nouvelle version
  p.copy.push(...p.sideNew, ...p.sideLocal);
  p.sideNew = [];
  p.sideLocal = [];
  const launchers = p.copy.filter((f) => PANEL_LAUNCHERS.includes(f) && fs.existsSync(path.join(config.HOME, f)));
  p.copy = p.copy.filter((f) => !launchers.includes(f));
  return { incoming, plan: p, launchers, empty: !changes(p) && !launchers.length };
}

/** La nouvelle Chancellerie se charge-t-elle (tous ses modules, et le JavaScript de son interface) ? */
function verifyPanel(source) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [path.join(source, 'index.js'), '--verifier'], {
      env: { ...process.env, CHANCELLERIE_HOME: config.HOME }, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
    });
    let output = '';
    child.stdout.on('data', (chunk) => { output += chunk; });
    child.stderr.on('data', (chunk) => { output += chunk; });
    const timer = setTimeout(() => child.kill(), VERIFY_TIMEOUT_MS);
    child.on('close', (code) => {
      clearTimeout(timer);
      if (code === 0) resolve();
      else reject(dl.failure('panel_invalid', output.trim().split('\n').slice(-3).join(' ').slice(0, 400) || `code ${code}`));
    });
  });
}

/**
 * Remplace les fichiers de la Chancellerie : l'ancienne version est gardée (data/updates/chancellerie-precedente) et
 * marquée à vérifier ; demarrer.bat la remet si la nouvelle ne démarre pas.
 */
function applyPanel(source, panelPlan, ref) {
  fs.rmSync(PANEL_PREVIOUS, { recursive: true, force: true });
  // entrée par entrée : la copie se range dans data/, qui est dans le dossier copié
  for (const entry of fs.readdirSync(config.HOME)) {
    if (!PANEL_KEPT.has(entry)) fs.cpSync(path.join(config.HOME, entry), path.join(PANEL_PREVIOUS, entry), { recursive: true });
  }
  fs.writeFileSync(PANEL_FLAG, String(Date.now()));
  applyPlan(source, config.HOME, panelPlan.plan);
  for (const launcher of panelPlan.launchers) dl.copyFile(path.join(source, launcher), path.join(config.HOME, `${launcher}.nouveau`));
  const installed = state();
  installed.chancellerie = { ref, files: panelPlan.incoming };
  saveState(installed);
}

/** La Chancellerie a démarré : sa mise à jour est confirmée. */
function confirmPanel() {
  if (!fs.existsSync(PANEL_FLAG)) return false;
  fs.rmSync(PANEL_FLAG, { force: true });
  return true;
}

/**
 * demarrer.bat a-t-il remis l'ancienne Chancellerie (la nouvelle s'arrêtait au démarrage) ? La version installée de
 * la Chancellerie redevient inconnue : la suivante sera comparée fichier par fichier.
 */
function panelReverted() {
  if (!fs.existsSync(PANEL_REVERTED)) return false;
  fs.rmSync(PANEL_REVERTED, { force: true });
  const installed = state();
  installed.chancellerie = null;
  saveState(installed);
  return true;
}

/** Retient la version de la Chancellerie sans rien écrire (installation : celle du dépôt est la référence). */
function recordPanel(source, ref) {
  if (!source) return;
  const installed = state();
  installed.chancellerie = { ref, files: dl.hashTree(source, panelSkip) };
  saveState(installed);
}

function cleanStaging() {
  fs.rmSync(STAGING, { recursive: true, force: true });
}

module.exports = {
  CORE, state, saveState, layout, plan, planResources, applyResources, backupResources, restoreResources, changes,
  fetchSource, recommendedFxserver, installFxserver, installOxmysql, planPanel, verifyPanel, applyPanel, confirmPanel,
  panelReverted, recordPanel, cleanStaging, inGitCheckout, userOwned,
};
