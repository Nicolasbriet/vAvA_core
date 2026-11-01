'use strict';
/*
 * lib/delivery.js
 * Rôle : ce qui est livré aux joueurs et allégé de ses commentaires (T-154). D'après le manifeste de chaque ressource :
 *        le Lua des `shared_script(s)` et `client_script(s)`, celui du paquet du Conseil (`vava_conseil_lua`, T-157,
 *        `config_conseil.lua` compris) et le `fxmanifest.lua` lui-même. Jamais : les réglages de l'exploitant
 *        (`config.lua`, `config_client.lua`, `config/…`), le Lua du seul serveur, les `files`, le web. Le manifeste est
 *        lu comme par scripts/lib/manifeste.awk (recoupé à chaque vérification) ; une forme illisible laisse toute la
 *        ressource telle quelle. Chaque fichier n'est réécrit qu'après son propre contrôle (lib/luastrip.js).
 *        Utilisé par l'installeur (copie téléchargée, avant les empreintes) et par scripts/livraison.js.
 * Dépendances : fs, path, ./luastrip.
 */

const fs = require('fs');
const path = require('path');
const luastrip = require('./luastrip');

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
const MAX_BYTES = 4 * 1024 * 1024;
const MANIFEST = 'fxmanifest.lua';

/** Fichier de réglages, que son propriétaire a pu adapter ? */
function userOwned(relative) {
  return ['config.lua', 'config_client.lua'].includes(path.posix.basename(relative)) || relative.startsWith('config/');
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
const SKIPPED = new Set(['ws', 'eol', 'comment', 'bom', 'shebang']);

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

/** Une partie de chemin à jokers en expression régulière (`*`, `?`, `[…]`, `[!…]`). */
function partRegex(part) {
  let out = '';
  for (let i = 0; i < part.length; i += 1) {
    const c = part[i];
    if (c === '*') out += '[^/]*';
    else if (c === '?') out += '[^/]';
    else if (c === '[' && part.indexOf(']', i + 2) > 0) {
      const close = part.indexOf(']', i + 2);
      let body = part.slice(i + 1, close);
      if (body[0] === '!' || body[0] === '^') body = `^${body.slice(1)}`;
      out += `[${body.replace(/\\/g, '\\\\')}]`;
      i = close;
    } else out += c.replace(/[.+^${}()|\\\]]/g, '\\$&');
  }
  return new RegExp(`^${out}$`);
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
    const regex = partRegex(part.replace(/\*\*+/g, '*'));
    for (const entry of entriesOf(dir)) {
      if (entry.name.startsWith('.') && !part.startsWith('.')) continue;
      if (!regex.test(entry.name)) continue;
      if (k < parts.length - 1 && !isDir(dir, entry)) continue;
      walk(path.join(dir, entry.name), join(entry.name), k + 1);
    }
  };
  walk(root, '', 0);
  return [...new Set(found)].filter((rel) => rel && isFile(path.join(root, rel))).sort();
}

// Choix des fichiers --------------------------------------------------------------------------------------------------

const isLua = (relative) => relative.toLowerCase().endsWith('.lua');

/**
 * Lua servi par une ressource, d'après son manifeste.
 * `state` : 'lean' (allégé), 'kept-config' (réglage de l'exploitant), 'kept-files' (donnée : files, file, ui_page,
 * loadscreen, vava_conseil_web) ; `council` : fichier du paquet du Conseil (un fichier peut figurer des deux côtés).
 * @param {string} resourceDir
 * @returns {{ ok: true, files: { path: string, state: string, council: boolean }[] } | { ok: false, reason: string }}
 */
function servedLua(resourceDir) {
  const manifest = path.join(resourceDir, MANIFEST);
  let text;
  try {
    if (fs.statSync(manifest).size > MAX_BYTES) return { ok: false, reason: 'manifeste trop gros' };
    text = fs.readFileSync(manifest).toString('latin1');
  } catch (error) {
    return { ok: false, reason: 'manifeste absent' };
  }
  const read = manifestStrings(text);
  if (!read.strings) return { ok: false, reason: read.reason };
  const files = [{ path: MANIFEST, state: 'lean', council: false }];
  const index = new Map([[`0:${MANIFEST}`, files[0]]]);
  const RANK = { 'kept-files': 0, 'kept-config': 1, lean: 2 };
  for (const { directive, value } of read.strings) {
    if (directive === 'server_script' || directive === 'server_scripts') continue;
    const pattern = normalize(value);
    if (!pattern) continue;
    const council = COUNCIL_SIDE.includes(directive);
    for (const relative of expand(resourceDir, pattern)) {
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
 * Allège un fichier sur place : refusé au-delà de MAX_BYTES ; réécrit seulement si le texte change.
 * @returns {{ ok: true, before: number, after: number } | { ok: false, line: number, reason: string }}
 */
function leanFile(file) {
  let buffer;
  try {
    if (fs.statSync(file).size > MAX_BYTES) return { ok: false, line: 0, reason: 'fichier trop gros' };
    buffer = fs.readFileSync(file);
  } catch (error) {
    return { ok: false, line: 0, reason: 'fichier illisible' };
  }
  const result = leanText(buffer);
  if (!result.ok) return result;
  if (result.changed) fs.writeFileSync(file, result.buffer);
  return { ok: true, before: result.before, after: result.after };
}

/**
 * Allège le Lua livré de chaque ressource (dossiers d'une copie, jamais le dépôt) : le manifeste en dernier.
 * @param {{ name: string, dir: string }[]} resources
 * @returns {{ resources: number, files: number, before: number, after: number,
 *   refused: { file: string, line: number, reason: string }[], skipped: { resource: string, reason: string }[] }}
 */
function leanResources(resources) {
  const summary = { resources: 0, files: 0, before: 0, after: 0, refused: [], skipped: [] };
  for (const resource of resources) {
    const served = servedLua(resource.dir);
    if (!served.ok) {
      summary.skipped.push({ resource: resource.name, reason: served.reason });
      continue;
    }
    summary.resources += 1;
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
};
