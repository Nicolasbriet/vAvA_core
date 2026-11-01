#!/usr/bin/env node
'use strict';
/*
 * scripts/livraison.js
 * Rôle : le Lua (T-154) et les pages (T-160) livrés sans commentaires, hors de la Chancellerie : même implémentation
 *        qu'elle (chancellerie/lib/delivery.js, lib/luastrip.js, lib/webstrip.js ; disposition des ressources par
 *        lib/installer.js layout).
 *        Usage (node ≥ 18, sans dépendance ; lancé de n'importe où, racine = dossier parent de scripts/) :
 *          --liste            Lua servi par chaque ressource du dépôt : « ressource<TAB>chemin<TAB>état » (allégé, gardé
 *                             (réglage), gardé (files)) ; paquet du Conseil : « ressource@conseil<TAB>chemin<TAB>état » ;
 *                             manifeste illisible : « ressource<TAB>-<TAB>illisible : raison » (code 1)
 *          --essai <dossier>  chaque fichier Lua suivi par git allégé dans <dossier>/<chemin du dépôt> : « livre<TAB>chemin »
 *                             (allégé à la livraison), « depot<TAB>chemin » (essayé seulement), « refuse<TAB>chemin<TAB>
 *                             ligne<TAB>raison » ; lu par scripts/lib/meme-code.lua (preuve par le compilateur) ;
 *                             suivi de chemins (`--essai <dossier> a.lua b.lua`) : ces seuls fichiers (verifier.sh)
 *          --liste-pages      pages servies (JS, CSS, HTML) par chaque ressource : « ressource<TAB>chemin<TAB>état »
 *                             (allégé, gardé (réglage), gardé (déjà minifié), gardé (script)) ; paquet du Conseil :
 *                             « ressource@conseil<TAB>chemin<TAB>état » ; manifeste illisible : comme --liste (code 1)
 *          --essai-pages <dossier>  chaque page suivie par git (.js, .css, .html, .htm) allégée dans <dossier>/<chemin du
 *                             dépôt) : « livre<TAB>chemin » (allégée à la livraison), « depot<TAB>chemin » (essayée
 *                             seulement), « refuse<TAB>chemin<TAB>ligne<TAB>raison<TAB>livre|depot » ; lu par scripts/lib/meme-page.js
 *                             (second lecteur et V8) ; suivi de chemins : ces seuls fichiers ; code 1 si une page
 *                             livrée est refusée
 *          --sortie <dossier> copie de livraison disposée comme par l'installeur ([vava]/vAvA_core, [vava]/<module>,
 *                             [vava-dev]/<exemple>), fichiers suivis par git seulement, puis allégée (Lua et pages :
 *                             une ligne de bilan chacun ; code 1 au moindre refus)
 *        <dossier> : absent ou vide, ni dans le dépôt ni le contenant, ni dans une autre copie git (chemin réel : une
 *        jonction vers la copie git est suivie), jamais un lien ; le dépôt lui-même n'est jamais écrit. Codes : 0 succès, 1 écart ou refus, 2 usage.
 * Dépendances : node, git (--essai, --essai-pages, --sortie), chancellerie/lib/delivery.js, chancellerie/lib/installer.js.
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const delivery = require('../chancellerie/lib/delivery');
const { layout } = require('../chancellerie/lib/installer');

const ROOT = path.resolve(__dirname, '..');
const STATES = { lean: 'allégé', 'kept-config': 'gardé (réglage)', 'kept-files': 'gardé (files)' };
const PAGE_STATES = { lean: 'allégé', 'kept-config': 'gardé (réglage)', 'kept-min': 'gardé (déjà minifié)', 'kept-script': 'gardé (script)' };
const USAGE = 'usage : node scripts/livraison.js --liste | --liste-pages | --essai <dossier> [chemin.lua…] '
  + '| --essai-pages <dossier> [chemin…] | --sortie <dossier>';

const say = (line) => process.stdout.write(`${line}\n`);
const warn = (line) => process.stderr.write(`${line}\n`);
const slash = (p) => p.split(path.sep).join('/');

/** `inner` est-il `base` ou dedans ? (comparaison de Windows sans casse, par path.relative) */
function within(base, inner) {
  const relative = path.relative(base, inner);
  return relative === '' || (relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative));
}

/** Chemin réel d'un dossier peut-être absent : celui du plus proche parent existant, puis le reste. */
function realTarget(target) {
  let current = path.resolve(target);
  const rest = [];
  while (!fs.existsSync(current)) {
    const parent = path.dirname(current);
    if (parent === current) break;
    rest.unshift(path.basename(current));
    current = parent;
  }
  return path.join(fs.realpathSync.native(current), ...rest);
}

/** Racine de la copie git (dossier qui porte un `.git`, dossier ou fichier de worktree) qui contient `real`, ou null. */
function gitCheckoutOf(real) {
  let current = real;
  for (;;) {
    if (fs.existsSync(path.join(current, '.git'))) return current;
    const parent = path.dirname(current);
    if (parent === current) return null;
    current = parent;
  }
}

/**
 * Raison de refuser un dossier de sortie, ou null.
 * @param {string} target
 * @param {string} [repo]  racine du dépôt (essais)
 */
function refusal(target, repo = ROOT) {
  const real = realTarget(target);
  const repoReal = fs.realpathSync.native(repo);
  if (within(repoReal, real)) return `dossier dans le dépôt (${real}) : le dépôt n'est jamais écrit`;
  if (within(real, repoReal)) return `dossier qui contient le dépôt (${real})`;
  // toute copie git (autre worktree, autre clone), comme installer.inGitCheckout (relecture sécurité S-6)
  const checkout = gitCheckoutOf(real);
  if (checkout) return `dossier dans une copie git (${checkout}) : choisir un dossier hors de toute copie git`;
  let stat = null;
  try {
    stat = fs.lstatSync(target);
  } catch (error) {
    stat = null;
  }
  if (!stat) return null;
  if (stat.isSymbolicLink()) return `lien ou jonction (${target}) : donner un dossier ordinaire`;
  if (!stat.isDirectory()) return `ce n'est pas un dossier (${target})`;
  if (fs.readdirSync(target).length) return `dossier non vide (${target})`;
  return null;
}

/** Ressources du dépôt et leur Lua servi : [{ resource, served }]. */
function servedResources() {
  return layout(ROOT).resources.map((resource) => ({ resource, served: delivery.servedLua(resource.dir) }));
}

/** Fichiers suivis par git sous `root` (chemins relatifs, `/`). */
function trackedIn(root, ...pathspec) {
  const out = execFileSync('git', ['ls-files', '-z', '--', ...pathspec], { cwd: root, maxBuffer: 64 * 1024 * 1024 });
  return out.toString('utf8').split('\0').filter(Boolean);
}

const gitFiles = (...pathspec) => trackedIn(ROOT, ...pathspec);

function liste() {
  let code = 0;
  for (const { resource, served } of servedResources()) {
    if (!served.ok) {
      say(`${resource.name}\t-\tillisible : ${served.reason}`);
      code = 1;
      continue;
    }
    for (const file of served.files) say(`${resource.name}${file.council ? '@conseil' : ''}\t${file.path}\t${STATES[file.state]}`);
  }
  return code;
}

function listePages(root = ROOT) {
  let code = 0;
  for (const resource of layout(root).resources) {
    const served = delivery.servedPages(resource.dir);
    if (!served.ok) {
      say(`${resource.name}\t-\tillisible : ${served.reason}`);
      code = 1;
      continue;
    }
    for (const file of served.files) say(`${resource.name}${file.council ? '@conseil' : ''}\t${file.path}\t${PAGE_STATES[file.state]}`);
  }
  return code;
}

/**
 * Chaque page suivie par git allégée dans `target` (rien n'est écrit dans le dépôt). `root` : racine du dépôt (essais,
 * sur un dépôt factice).
 */
function essaiPages(target, only = [], root = ROOT) {
  let code = 0;
  const delivered = new Set();
  for (const resource of layout(root).resources) {
    const served = delivery.servedPages(resource.dir);
    if (!served.ok) {
      warn(`ressource ${resource.name} illisible : ${served.reason}`);
      code = 1;
      continue;
    }
    for (const file of served.files) {
      if (file.state === 'lean') delivered.add(slash(path.relative(root, path.join(resource.dir, file.path))).toLowerCase());
    }
  }
  let counted = 0;
  let refused = 0;
  const wanted = only.length ? new Set(only.map((p) => slash(p))) : null;
  for (const relative of trackedIn(root)) {
    const kind = delivery.pageKind(relative);
    if (!kind || (wanted && !wanted.has(relative))) continue;
    const source = path.join(root, relative);
    if (!fs.existsSync(source)) continue;
    const status = delivered.has(relative.toLowerCase()) ? 'livre' : 'depot';
    const result = delivery.leanPageText(fs.readFileSync(source), kind, relative);
    counted += 1;
    if (!result.ok) {
      refused += 1;
      say(`refuse\t${relative}\t${result.line}\t${result.reason}\t${status}`);
      if (status === 'livre') code = 1;
      continue;
    }
    const out = path.join(target, relative);
    fs.mkdirSync(path.dirname(out), { recursive: true });
    fs.writeFileSync(out, result.buffer);
    say(`${status}\t${relative}`);
  }
  warn(`ESSAI DES PAGES : ${counted} fichiers lus, ${refused} refusés.`);
  return code;
}

function essai(target, only = []) {
  let code = 0;
  const delivered = new Set();
  for (const { resource, served } of servedResources()) {
    if (!served.ok) {
      warn(`ressource ${resource.name} illisible : ${served.reason}`);
      code = 1;
      continue;
    }
    for (const file of served.files) {
      if (file.state === 'lean') delivered.add(slash(path.relative(ROOT, path.join(resource.dir, file.path))).toLowerCase());
    }
  }
  let counted = 0;
  let refused = 0;
  // chemins donnés (fichiers modifiés, scripts/verifier.sh hors --tout) : les seuls essayés parmi le Lua suivi
  const wanted = only.length ? new Set(only.map((p) => slash(p))) : null;
  for (const relative of gitFiles('*.lua')) {
    if (wanted && !wanted.has(relative)) continue;
    const source = path.join(ROOT, relative);
    if (!fs.existsSync(source)) continue;
    const kind = delivered.has(relative.toLowerCase()) ? 'livre' : 'depot';
    const result = delivery.leanText(fs.readFileSync(source));
    counted += 1;
    if (!result.ok) {
      refused += 1;
      say(`refuse\t${relative}\t${result.line}\t${result.reason}`);
      if (kind === 'livre') code = 1;
      continue;
    }
    const out = path.join(target, relative);
    fs.mkdirSync(path.dirname(out), { recursive: true });
    fs.writeFileSync(out, result.buffer);
    say(`${kind}\t${relative}`);
  }
  warn(`ESSAI : ${counted} fichiers Lua suivis lus, ${refused} refusés par le lexeur.`);
  return code;
}

/** Copie de livraison allégée dans `target`. `root` : racine du dépôt (essais, sur un dépôt factice). */
function sortie(target, root = ROOT) {
  const tracked = trackedIn(root);
  const copied = [];
  for (const resource of layout(root).resources) {
    const prefix = resource.dir === root ? '' : `${slash(path.relative(root, resource.dir))}/`;
    const dest = path.join(target, resource.category, resource.name);
    for (const file of tracked) {
      if (!file.startsWith(prefix)) continue;
      const relative = file.slice(prefix.length);
      const source = path.join(resource.dir, relative);
      if (resource.skip(relative) || !fs.existsSync(source)) continue;
      fs.mkdirSync(path.dirname(path.join(dest, relative)), { recursive: true });
      fs.copyFileSync(source, path.join(dest, relative));
    }
    copied.push({ name: resource.name, dir: dest });
  }
  const summary = delivery.leanResources(copied, { lua: true, web: true });
  const { pages } = summary;
  for (const item of [...summary.refused, ...pages.refused]) say(`refusé : ${item.file} (ligne ${item.line} : ${item.reason})`);
  for (const item of summary.skipped) say(`ressource laissée telle quelle : ${item.resource} (${item.reason})`);
  say(`Livraison dans ${target} : ${summary.resources} ressources, ${summary.files} fichiers allégés, `
    + `${summary.before} → ${summary.after} octets (− ${summary.before - summary.after}), ${summary.refused.length} refusé(s).`);
  say(`Pages : ${pages.files} fichiers allégés, ${pages.before} → ${pages.after} octets (− ${pages.before - pages.after}), `
    + `${pages.refused.length} refusée(s).`);
  return summary.refused.length || pages.refused.length || summary.skipped.length ? 1 : 0;
}

function main(argv) {
  const [mode, target, ...rest] = argv;
  if (mode === '--liste' && target === undefined) return liste();
  if (mode === '--liste-pages' && target === undefined) return listePages();
  if (!['--essai', '--essai-pages', '--sortie'].includes(mode) || !target || target.startsWith('--') || (mode === '--sortie' && rest.length)) {
    warn(USAGE);
    return 2;
  }
  const reason = refusal(target);
  if (reason) {
    warn(`refusé : ${reason}`);
    return 1;
  }
  fs.mkdirSync(target, { recursive: true });
  if (mode === '--essai') return essai(target, rest);
  if (mode === '--essai-pages') return essaiPages(target, rest);
  return sortie(target);
}

if (require.main === module) process.exitCode = main(process.argv.slice(2));

module.exports = { refusal, within, realTarget, gitCheckoutOf, listePages, essaiPages, sortie };
