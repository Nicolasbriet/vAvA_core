'use strict';
/*
 * lib/delivery.js
 * Rôle : ce qui est livré aux joueurs et allégé de ses commentaires. D'après le manifeste de chaque ressource :
 *        - Lua (T-154) : celui des `shared_script(s)` et `client_script(s)`, celui du paquet du Conseil
 *          (`vava_conseil_lua`, T-157) et le `fxmanifest.lua` lui-même. Jamais : les réglages de l'exploitant
 *          (`config.lua`, `config_client.lua`, `config_conseil.lua`, `config/…`), le Lua du seul serveur, les `files`.
 *        - Pages (T-160) : JavaScript, CSS et HTML des `files`, `file`, `ui_page`, `loadscreen` et du paquet du Conseil
 *          (`vava_conseil_web`). Jamais : le réglage de page `config.js`, les `*.min.js` et `*.min.css`, le JavaScript
 *          exécuté par FiveM (`client_script`), les SVG, JSON, polices et images, `web/dev/` (jamais au manifeste).
 *        Le manifeste est lu comme par scripts/lib/manifeste.awk (recoupé à chaque vérification) ; une forme illisible
 *        laisse toute la ressource telle quelle. Chaque fichier n'est réécrit qu'après son propre contrôle
 *        (lib/luastrip.js, lib/webstrip.js ; pour le JavaScript, aussi la compilation par V8, jamais exécutée).
 *        Utilisé par l'installeur (copie téléchargée, avant les empreintes) et par scripts/livraison.js.
 * Dépendances : fs, path, vm (node), ./luastrip, ./webstrip.
 */

const fs = require('fs');
const path = require('path');
const vm = require('vm');
const luastrip = require('./luastrip');
const webstrip = require('./webstrip');

// directives lues dans un manifeste (celles de scripts/lib/manifeste.awk)
const TRACKED_DIRECTIVES = ['files', 'file', 'ui_page', 'loadscreen', 'shared_script', 'shared_scripts', 'client_script',
  'client_scripts', 'server_script', 'server_scripts', 'vava_conseil_lua', 'vava_conseil_web'];
// Lua servi à la connexion (réglages exclus)
const LEAN_DIRECTIVES = ['shared_script', 'shared_scripts', 'client_script', 'client_scripts'];
// Lua du paquet du Conseil (T-157), réglages exclus de même
const COUNCIL_DIRECTIVES = ['vava_conseil_lua'];
// données servies telles quelles (même en .lua)
const DATA_DIRECTIVES = ['files', 'file', 'ui_page', 'loadscreen'];
const COUNCIL_SIDE = ['vava_conseil_lua', 'vava_conseil_web'];
// borne d'un fichier lu ou allégé (relecture sécurité S-3 : mémoire du lexeur bornée ; le plus gros fichier livré fait
// 86 Ko)
const MAX_BYTES = 1024 * 1024;
const MANIFEST = 'fxmanifest.lua';

// pages (T-160) : directives qui les servent telles quelles aux joueurs (ou au Conseil), sortes par extension (sans la
// casse), réglages de page jamais allégés (nom de base, sans la casse), fichiers déjà minifiés gardés
const PAGE_DIRECTIVES = ['files', 'file', 'ui_page', 'loadscreen', 'vava_conseil_web'];
const PAGE_KINDS = Object.freeze({ '.js': 'js', '.css': 'css', '.html': 'html', '.htm': 'html' });
const PAGE_SETTINGS = ['config.js'];
const PAGE_MINIFIED = ['.min.js', '.min.css'];
// JavaScript exécuté par FiveM : listé (recoupement), jamais allégé
const SCRIPT_DIRECTIVES = ['shared_script', 'shared_scripts', 'client_script', 'client_scripts'];

// réglages de l'exploitant : gardés à la mise à jour (« .nouveau » à côté), jamais allégés ; config_conseil.lua
// (réglages du paquet du Conseil, T-157) en est un (relecture réseau R-5 de T-157)
const USER_FILES = ['config.lua', 'config_client.lua', 'config_conseil.lua'];

/** Fichier de réglages, que son propriétaire a pu adapter ? (sans la casse : NTFS ne la distingue pas, S-5) */
function userOwned(relative) {
  const lower = relative.toLowerCase();
  return USER_FILES.includes(path.posix.basename(lower)) || lower.startsWith('config/');
}

// Lecture du manifeste ------------------------------------------------------------------------------------------------

/** Chaîne normalisée comme norm() de manifeste.awk ; null si elle sort de la ressource ou désigne une autre ressource. */
function normalize(raw) {
  let m = raw.replace(/\\/g, '/').replace(/\/\/+/g, '/');
  while (m.includes('/./')) m = m.replace(/\/\.\//g, '/');
  while (m.startsWith('./')) m = m.slice(2);
  m = m.replace(/^\/+/, '');
  if (m.startsWith('@')) return null;
  const out = [];
  for (const part of m.split('/')) {
    if (part === '..') {
      if (!out.length) return null;
      out.pop();
    } else if (part !== '.' && part !== '') out.push(part);
  }
  return out.length ? out.join('/') : null;
}

/** Contenu d'une chaîne lue par le lexeur, tel qu'écrit (échappements non interprétés, comme l'awk). */
function stringValue(text, e) {
  if (e.kind === 'string') return text.slice(e.start + 1, e.end - 1);
  const open = text.indexOf('[', e.start + 1) + 1;
  const level = open - e.start - 2;
  return text.slice(open, e.end - level - 2).replace(/[\r\n]/g, '');
}

// évènements du lexeur sans effet sur la lecture d'un manifeste
const SKIPPED = new Set(['ws', 'eol', 'comment', 'bom']);

/**
 * Chaînes des directives suivies : [{ directive, value }] dans l'ordre ; ou { reason } si une directive est suivie
 * d'autre chose qu'une chaîne ou une table de chaînes.
 */
function manifestStrings(text) {
  const events = luastrip.scan(text);
  const last = events[events.length - 1];
  if (last && last.kind === 'error') return { reason: `manifeste illisible (ligne ${last.line} : ${last.reason})` };
  const tokens = events.filter((e) => !SKIPPED.has(e.kind));
  const out = [];
  let pending = '';   // directive suivie qui attend sa valeur (hors table)
  let inside = '';    // directive de la table ouverte
  let depth = 0;
  let after = false;  // juste après la chaîne d'une directive en forme simple
  const unreadable = (e) => ({ reason: `forme illisible (ligne ${e.line})` });
  for (let k = 0; k < tokens.length; k += 1) {
    const e = tokens[k];
    const word = text.slice(e.start, e.end);
    if (after) {
      after = false;
      const next = tokens[k + 1];
      if (word === '.' && next && next.start === e.end && text[next.start] === '.') return unreadable(e);
    }
    if (e.kind === 'string' || e.kind === 'long') {
      const directive = depth > 0 ? inside : pending;
      if (depth === 0) {
        pending = '';
        if (directive) after = true;
      }
      if (directive) out.push({ directive, value: stringValue(text, e) });
    } else if (e.kind === 'name') {
      if (depth > 0) {
        if (inside) return unreadable(e);
        continue;
      }
      if (pending) return unreadable(e);
      pending = TRACKED_DIRECTIVES.includes(word) ? word : '';
    } else if (word === '{') {
      if (depth > 0) depth += 1;
      else if (pending) {
        depth = 1;
        inside = pending;
        pending = '';
      }
    } else if (word === '}') {
      if (depth > 0) {
        depth -= 1;
        if (depth === 0) inside = '';
      }
    } else if (depth > 0) {
      if (inside && word !== ',' && word !== ';') return unreadable(e);
    } else if (pending && word !== '(') {
      return unreadable(e);
    } else if (!'(),;'.includes(word)) pending = '';
  }
  return { strings: out };
}

// Jokers (sémantique de bash avec globstar et sans dotglob) -----------------------------------------------------------

const hasGlob = (part) => /[*?[]/.test(part);

/**
 * Une partie de chemin à jokers en éléments : '*', '?', { set, negate } pour `[…]` / `[!…]`, ou un caractère. Un `[`
 * sans `]` est un caractère ; un intervalle à l'envers (`[z-a]`) ne prend rien, comme bash.
 */
function compilePart(part) {
  const out = [];
  for (let i = 0; i < part.length; i += 1) {
    const c = part[i];
    if (c === '*') {
      if (out[out.length - 1] !== '*') out.push('*');
      continue;
    }
    if (c === '?') {
      out.push('?');
      continue;
    }
    let j = i + 1;
    const negate = c === '[' && (part[j] === '!' || part[j] === '^');
    if (negate) j += 1;
    const close = c === '[' ? part.indexOf(']', j + 1) : -1;
    if (close < 0) {
      out.push(c);
      continue;
    }
    const ranges = [];
    for (let k = j; k < close; k += 1) {
      if (part[k + 1] === '-' && k + 2 < close) {
        ranges.push([part[k], part[k + 2]]);
        k += 2;
      } else ranges.push([part[k], part[k]]);
    }
    out.push({ ranges, negate });
    i = close;
  }
  return out;
}

function matchOne(item, ch) {
  if (item === '?') return true;
  if (typeof item === 'string') return item === ch;
  const inside = item.ranges.some(([lo, hi]) => ch >= lo && ch <= hi);
  return inside !== item.negate;
}

/**
 * Le nom correspond-il aux éléments ? Parcours sans retour arrière exponentiel (une seule étoile retenue à la fois :
 * au plus nom × motif comparaisons, relecture sécurité S-2), aucune expression régulière.
 */
function matchPart(items, name) {
  let p = 0;
  let s = 0;
  let star = -1;
  let mark = 0;
  while (s < name.length) {
    if (p < items.length && items[p] !== '*' && matchOne(items[p], name[s])) {
      p += 1;
      s += 1;
    } else if (p < items.length && items[p] === '*') {
      star = p;
      mark = s;
      p += 1;
    } else if (star >= 0) {
      p = star + 1;
      mark += 1;
      s = mark;
    } else return false;
  }
  while (p < items.length && items[p] === '*') p += 1;
  return p === items.length;
}

function entriesOf(dir) {
  try {
    return fs.readdirSync(dir, { withFileTypes: true });
  } catch (error) {
    return [];
  }
}

function isDir(dir, entry) {
  if (entry.isDirectory()) return true;
  if (!entry.isSymbolicLink()) return false;
  try {
    return fs.statSync(path.join(dir, entry.name)).isDirectory();
  } catch (error) {
    return false;
  }
}

function isFile(file) {
  try {
    return fs.statSync(file).isFile();
  } catch (error) {
    return false;
  }
}

/** Fichiers d'une ressource désignés par un motif normalisé (chemins relatifs, triés par motif). */
function expand(root, pattern) {
  const parts = pattern.split('/');
  if (!parts.some(hasGlob)) return isFile(path.join(root, pattern)) ? [pattern] : [];
  const found = [];
  const walk = (dir, rel, k) => {
    const join = (name) => (rel ? `${rel}/${name}` : name);
    if (k === parts.length) {
      found.push(rel);
      return;
    }
    const part = parts[k];
    if (part === '**') {
      // comme bash (4.3 et plus) : `**` ne descend pas dans un lien (ni boucle, ni sortie de la ressource)
      if (k === parts.length - 1) {
        // `**` final : tout ce qui est dessous, à toute profondeur
        for (const entry of entriesOf(dir)) {
          if (entry.name.startsWith('.')) continue;
          found.push(join(entry.name));
          if (entry.isDirectory()) walk(path.join(dir, entry.name), join(entry.name), k);
        }
        return;
      }
      walk(dir, rel, k + 1);   // zéro dossier
      for (const entry of entriesOf(dir)) {
        if (!entry.name.startsWith('.') && entry.isDirectory()) walk(path.join(dir, entry.name), join(entry.name), k);
      }
      return;
    }
    if (!hasGlob(part)) {
      walk(path.join(dir, part), join(part), k + 1);
      return;
    }
    const items = compilePart(part);
    for (const entry of entriesOf(dir)) {
      if (entry.name.startsWith('.') && !part.startsWith('.')) continue;
      if (!matchPart(items, entry.name)) continue;
      if (k < parts.length - 1 && !isDir(dir, entry)) continue;
      walk(path.join(dir, entry.name), join(entry.name), k + 1);
    }
  };
  walk(root, '', 0);
  return [...new Set(found)].filter((rel) => rel && isFile(path.join(root, rel))).sort();
}

// Choix des fichiers --------------------------------------------------------------------------------------------------

const isLua = (relative) => relative.toLowerCase().endsWith('.lua');

/** Chaînes du manifeste d'une ressource ({ strings }) ; ou { reason } : absent, trop gros, forme illisible. */
function readManifest(resourceDir) {
  const manifest = path.join(resourceDir, MANIFEST);
  let text;
  try {
    if (fs.statSync(manifest).size > MAX_BYTES) return { reason: 'manifeste trop gros' };
    text = fs.readFileSync(manifest).toString('latin1');
  } catch (error) {
    return { reason: 'manifeste absent' };
  }
  return manifestStrings(text);
}

/**
 * Lua servi par une ressource, d'après son manifeste.
 * `state` : 'lean' (allégé), 'kept-config' (réglage de l'exploitant), 'kept-files' (donnée : files, file, ui_page,
 * loadscreen, vava_conseil_web) ; `council` : fichier du paquet du Conseil (un fichier peut figurer des deux côtés).
 * @param {string} resourceDir
 * @returns {{ ok: true, files: { path: string, state: string, council: boolean }[] } | { ok: false, reason: string }}
 */
function servedLua(resourceDir) {
  const read = readManifest(resourceDir);
  if (!read.strings) return { ok: false, reason: read.reason };
  const files = [{ path: MANIFEST, state: 'lean', council: false }];
  const index = new Map([[`0:${MANIFEST}`, files[0]]]);
  const RANK = { 'kept-files': 0, 'kept-config': 1, lean: 2 };
  for (const { directive, value } of read.strings) {
    if (directive === 'server_script' || directive === 'server_scripts') continue;
    const pattern = normalize(value);
    if (!pattern) continue;
    const council = COUNCIL_SIDE.includes(directive);
    let matched;
    try {
      matched = expand(resourceDir, pattern);
    } catch (error) {
      return { ok: false, reason: `forme illisible (motif ${pattern})` };
    }
    for (const relative of matched) {
      if (!isLua(relative)) continue;
      let state = 'kept-files';
      if (LEAN_DIRECTIVES.includes(directive) || COUNCIL_DIRECTIVES.includes(directive)) state = userOwned(relative) ? 'kept-config' : 'lean';
      else if (!DATA_DIRECTIVES.includes(directive) && directive !== 'vava_conseil_web') continue;
      const key = `${council ? 1 : 0}:${relative}`;
      const known = index.get(key);
      if (known) {
        if (RANK[state] > RANK[known.state]) known.state = state;
        continue;
      }
      const entry = { path: relative, state, council };
      index.set(key, entry);
      files.push(entry);
    }
  }
  return { ok: true, files };
}

/** Sorte d'une page d'après son extension (sans la casse) : 'js', 'css', 'html', ou null. */
function pageKind(relative) {
  const extension = path.posix.extname(relative.toLowerCase());
  return Object.prototype.hasOwnProperty.call(PAGE_KINDS, extension) ? PAGE_KINDS[extension] : null;
}

/** État d'une page servie telle quelle (files…) : réglage, déjà minifiée, ou allégée. */
function pageState(relative) {
  const base = path.posix.basename(relative.toLowerCase());
  if (PAGE_SETTINGS.includes(base)) return 'kept-config';
  if (PAGE_MINIFIED.some((suffix) => base.endsWith(suffix))) return 'kept-min';
  return 'lean';
}

/**
 * Pages servies par une ressource, d'après son manifeste (T-160).
 * kind : 'js' | 'css' | 'html' ; state : 'lean' | 'kept-config' | 'kept-min' | 'kept-script' ;
 * council : fichier du paquet du Conseil (vava_conseil_web).
 * @param {string} resourceDir
 * @returns {{ ok: true, files: { path: string, kind: string, state: string, council: boolean }[] } | { ok: false, reason: string }}
 */
function servedPages(resourceDir) {
  const read = readManifest(resourceDir);
  if (!read.strings) return { ok: false, reason: read.reason };
  const files = [];
  const index = new Map();
  const RANK = { 'kept-script': 0, 'kept-config': 1, 'kept-min': 1, lean: 2 };
  for (const { directive, value } of read.strings) {
    const served = PAGE_DIRECTIVES.includes(directive);
    if (!served && !SCRIPT_DIRECTIVES.includes(directive)) continue;   // server_script(s), vava_conseil_lua
    const pattern = normalize(value);
    if (!pattern) continue;
    let matched;
    try {
      matched = expand(resourceDir, pattern);
    } catch (error) {
      return { ok: false, reason: `forme illisible (motif ${pattern})` };
    }
    const council = COUNCIL_SIDE.includes(directive);
    for (const relative of matched) {
      const kind = pageKind(relative);
      if (!kind || (!served && kind !== 'js')) continue;
      const state = served ? pageState(relative) : 'kept-script';
      const key = `${council ? 1 : 0}:${relative}`;
      const known = index.get(key);
      if (known) {
        if (RANK[state] > RANK[known.state]) known.state = state;
        continue;
      }
      const entry = { path: relative, kind, state, council };
      index.set(key, entry);
      files.push(entry);
    }
  }
  return { ok: true, files };
}

// Allègement ----------------------------------------------------------------------------------------------------------

/** Le fichier est-il un vrai fichier de `root` (ni lien, ni chemin qui en sort) ? */
function inside(root, file) {
  try {
    if (!fs.lstatSync(file).isFile()) return false;
    const real = fs.realpathSync.native(file);
    const base = fs.realpathSync.native(root);
    const relative = path.relative(base, real);
    return relative !== '' && !relative.startsWith('..') && !path.isAbsolute(relative);
  } catch (error) {
    return false;
  }
}

/**
 * Allège un contenu de fichier (octets) : refusé au-delà de MAX_BYTES.
 * @param {Buffer} buffer
 * @returns {{ ok: true, buffer: Buffer, changed: boolean, before: number, after: number } | { ok: false, line: number, reason: string }}
 */
function leanText(buffer) {
  if (buffer.length > MAX_BYTES) return { ok: false, line: 0, reason: 'fichier trop gros' };
  const text = buffer.toString('latin1');
  const result = luastrip.strip(text);
  if (!result.ok) return { ok: false, line: result.line, reason: result.reason };
  const changed = result.text !== text;
  const out = changed ? Buffer.from(result.text, 'latin1') : buffer;
  return { ok: true, buffer: out, changed, before: buffer.length, after: out.length };
}

/**
 * Allège un fichier sur place : refusé au-delà de MAX_BYTES ; réécrit seulement si le texte change (écriture
 * atomique ; une erreur d'écriture est levée).
 * @returns {{ ok: true, before: number, after: number } | { ok: false, line: number, reason: string }}
 */
function leanFile(file) {
  const read = readBounded(file);
  if (!read.buffer) return read;
  const result = leanText(read.buffer);
  if (!result.ok) return result;
  if (result.changed) writeAtomic(file, result.buffer);
  return { ok: true, before: result.before, after: result.after };
}

/**
 * Écrit à côté puis renomme : un arrêt brutal ne laisse jamais un fichier à moitié écrit (S-4) ; une erreur d'écriture
 * est levée (l'opération échoue, l'original reste), le temporaire retiré s'il a été créé ici. Le temporaire est créé en
 * exclusivité (`wx`) : un fichier, un dossier ou un lien déjà à sa place fait échouer l'écriture, jamais suivi ni
 * écrasé (relecture sécurité S-5 de T-160).
 */
function writeAtomic(file, buffer) {
  const temporary = `${file}.tmp`;
  let created = false;
  try {
    fs.writeFileSync(temporary, buffer, { flag: 'wx' });
    created = true;
    fs.renameSync(temporary, file);
  } catch (error) {
    if (created) {
      try {
        fs.rmSync(temporary, { force: true });
      } catch (ignored) {
        // rien à retirer
      }
    }
    throw error;
  }
}

/** Fichier lu en octets, borné à MAX_BYTES : { buffer } ; ou { ok: false, line: 0, reason }. */
function readBounded(file) {
  try {
    if (fs.statSync(file).size > MAX_BYTES) return { ok: false, line: 0, reason: 'fichier trop gros' };
    return { buffer: fs.readFileSync(file) };
  } catch (error) {
    return { ok: false, line: 0, reason: 'fichier illisible' };
  }
}

// Pages (T-160) -------------------------------------------------------------------------------------------------------

/** Ligne d'une erreur de compilation de V8 (`nom:ligne` en tête de sa pile), ou 0. */
function errorLine(error, name) {
  const head = String((error && error.stack) || '').split('\n')[0];
  const prefix = `${name}:`;
  if (!head.startsWith(prefix)) return 0;
  const value = Number.parseInt(head.slice(prefix.length), 10);
  return Number.isInteger(value) && value > 0 ? value : 0;
}

/**
 * Le texte se compile-t-il en script classique ? Compilé par V8 (`vm.Script`), **jamais exécuté** (ni contexte, ni
 * import dynamique). Une erreur de pile d'un texte piégé est un refus comme un autre.
 * @param {string} text  texte décodé en UTF-8
 * @param {string} name  nom donné à V8 (messages)
 * @returns {{ ok: true } | { ok: false, line: number }}
 */
function engineCompiles(text, name) {
  try {
    new vm.Script(text, { filename: name });   // eslint-disable-line no-new
    return { ok: true };
  } catch (error) {
    return { ok: false, line: errorLine(error, name) };
  }
}

/**
 * Allège une page (octets) : refusée au-delà de MAX_BYTES, si le lexeur refuse ou si son contrôle échoue ; pour le
 * JavaScript, refusée aussi si l'original ou l'allégé ne se compile pas (V8, sans exécution).
 * @param {Buffer} buffer
 * @param {'js'|'css'|'html'} kind
 * @param {string} name  chemin donné à V8 (messages)
 * @returns {{ ok: true, buffer: Buffer, changed: boolean, before: number, after: number } | { ok: false, line: number, reason: string }}
 */
function leanPageText(buffer, kind, name) {
  if (buffer.length > MAX_BYTES) return { ok: false, line: 0, reason: 'fichier trop gros' };
  const text = buffer.toString('latin1');
  const result = webstrip.strip(text, kind);
  if (!result.ok) return { ok: false, line: result.line, reason: result.reason };
  const changed = result.text !== text;
  const out = changed ? Buffer.from(result.text, 'latin1') : buffer;
  if (kind === 'js') {
    const original = engineCompiles(buffer.toString('utf8'), name);
    if (!original.ok) return { ok: false, line: original.line, reason: 'original non compilable' };
    if (changed) {
      const lean = engineCompiles(out.toString('utf8'), name);
      if (!lean.ok) return { ok: false, line: lean.line, reason: 'contrôle du moteur après allègement' };
    }
  }
  return { ok: true, buffer: out, changed, before: buffer.length, after: out.length };
}

/**
 * Allège une page sur place : refusée au-delà de MAX_BYTES ; réécrite seulement si le texte change (écriture atomique ;
 * une erreur d'écriture est levée).
 * @returns {{ ok: true, before: number, after: number } | { ok: false, line: number, reason: string }}
 */
function leanPage(file, kind) {
  const read = readBounded(file);
  if (!read.buffer) return read;
  const result = leanPageText(read.buffer, kind, path.basename(file));
  if (!result.ok) return result;
  if (result.changed) writeAtomic(file, result.buffer);
  return { ok: true, before: result.before, after: result.after };
}

/**
 * Allège ce qui est livré par chaque ressource (dossiers d'une copie, jamais le dépôt) : ses pages (`web`, T-160), puis
 * son Lua (`lua`, T-154), le manifeste en dernier. `options` absent : le Lua seul, comme T-154 (ses appelants et ses
 * essais inchangés) ; donné : `lua` et `web` vrais sauf `false`. Résumé du Lua inchangé ; celui des pages dans `pages`.
 * Une ressource au manifeste illisible est laissée telle quelle (une entrée `skipped`, pour les deux).
 * @param {{ name: string, dir: string }[]} resources
 * @param {{ lua?: boolean, web?: boolean }} [options]
 * @returns {{ resources: number, files: number, before: number, after: number,
 *   refused: { file: string, line: number, reason: string }[], skipped: { resource: string, reason: string }[],
 *   pages: { files: number, before: number, after: number, refused: { file: string, line: number, reason: string }[] } }}
 */
function leanResources(resources, options) {
  const lua = options === undefined || options.lua !== false;
  const web = options !== undefined && options.web !== false;
  const pages = { files: 0, before: 0, after: 0, refused: [] };
  const summary = { resources: 0, files: 0, before: 0, after: 0, refused: [], skipped: [], pages };
  for (const resource of resources) {
    const served = lua ? servedLua(resource.dir) : null;
    const page = web ? servedPages(resource.dir) : null;
    const unreadable = [served, page].find((read) => read && !read.ok);
    if (unreadable) {
      summary.skipped.push({ resource: resource.name, reason: unreadable.reason });
      continue;
    }
    summary.resources += 1;
    if (page) {
      // une page servie aux joueurs et au Conseil n'est allégée qu'une fois
      const seen = new Set();
      for (const entry of page.files) {
        if (entry.state !== 'lean' || seen.has(entry.path)) continue;
        seen.add(entry.path);
        const file = path.join(resource.dir, entry.path);
        const name = `${resource.name}/${entry.path}`;
        if (!inside(resource.dir, file)) {
          pages.refused.push({ file: name, line: 0, reason: 'lien ou chemin hors de la ressource' });
          continue;
        }
        const result = leanPage(file, entry.kind);
        if (!result.ok) {
          pages.refused.push({ file: name, line: result.line, reason: result.reason });
          continue;
        }
        pages.files += 1;
        pages.before += result.before;
        pages.after += result.after;
      }
    }
    if (!served) continue;
    const lean = [...new Set(served.files.filter((f) => f.state === 'lean').map((f) => f.path))];
    lean.push(...lean.splice(lean.indexOf(MANIFEST), 1));
    for (const relative of lean) {
      const file = path.join(resource.dir, relative);
      if (!inside(resource.dir, file)) {
        summary.refused.push({ file: `${resource.name}/${relative}`, line: 0, reason: 'lien ou chemin hors de la ressource' });
        continue;
      }
      const result = leanFile(file);
      if (!result.ok) {
        summary.refused.push({ file: `${resource.name}/${relative}`, line: result.line, reason: result.reason });
        continue;
      }
      summary.files += 1;
      summary.before += result.before;
      summary.after += result.after;
    }
  }
  return summary;
}

module.exports = {
  TRACKED_DIRECTIVES, LEAN_DIRECTIVES, COUNCIL_DIRECTIVES, MAX_BYTES, userOwned, normalize, manifestStrings, expand,
  servedLua, leanText, leanFile, leanResources,
  PAGE_DIRECTIVES, PAGE_KINDS, PAGE_SETTINGS, pageKind, servedPages, engineCompiles, leanPageText, leanPage,
};
