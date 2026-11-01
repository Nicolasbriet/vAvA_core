'use strict';
/*
 * lib/luastrip.js
 * Rôle : retirer d'un fichier Lua 5.4 ce que Lua ignore (commentaires, blancs de fin de ligne) en gardant chaque fin de
 *        ligne à sa place : une erreur en jeu désigne la même ligne que le dépôt (T-154). Lexeur calqué sur llex.c :
 *        chaînes courtes (échappements, `\z`, fin de ligne échappée), chaînes et commentaires longs de tout niveau,
 *        nombres, noms, BOM et première ligne `#` ; la contre-apostrophe de CfxLua est lue comme une chaîne. Chaque
 *        allègement se contrôle lui-même (même suite de lexèmes, chacun à sa ligne) ; sinon le fichier est rendu tel
 *        quel par l'appelant. Le texte est lu en latin1 : un caractère = un octet, rien n'est interprété.
 *        La preuve indépendante est faite par le compilateur Lua (scripts/lib/meme-code.lua).
 * Dépendances : aucune (fonctions pures).
 */

const BOM = '\xEF\xBB\xBF';

const isBlank = (c) => c === ' ' || c === '\t' || c === '\f' || c === '\v';
const isNewline = (c) => c === '\n' || c === '\r';
const isDigit = (c) => c >= '0' && c <= '9';
const isHex = (c) => isDigit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
const isAlpha = (c) => (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c === '_';

/** Longueur d'une fin de ligne en `i` : `\r\n` et `\n\r` comptent pour une (deux octets), comme inclinenumber. */
function newlineLength(text, i) {
  const c = text[i];
  const next = text[i + 1];
  return isNewline(next) && next !== c ? 2 : 1;
}

/** Niveau d'un crochet long ouvrant `[==[` en `i` (nombre de `=`), ou -1. */
function longLevel(text, i) {
  if (text[i] !== '[') return -1;
  let j = i + 1;
  while (text[j] === '=') j += 1;
  return text[j] === '[' ? j - i - 1 : -1;
}

/** Fins de ligne d'un morceau de texte, dans l'ordre et telles quelles. */
function newlinesOf(text, start, end) {
  const out = [];
  let i = start;
  while (i < end) {
    if (isNewline(text[i])) {
      const size = i + 1 < end ? newlineLength(text, i) : 1;
      out.push(text.slice(i, i + size));
      i += size;
    } else i += 1;
  }
  return out;
}

/**
 * Évènements dans l'ordre : { kind, start, end, line } (`long: true` pour un commentaire long) ; kind : 'bom' |
 * 'shebang' | 'ws' | 'eol' | 'comment' | 'string' | 'long' | 'number' | 'name' | 'punct' ; ou { kind: 'error', line,
 * reason } en dernier.
 * @param {string} text  texte lu en latin1
 */
function scan(text) {
  const events = [];
  const n = text.length;
  let i = 0;
  let line = 1;
  const push = (kind, start, end, at, extra) => events.push({ kind, start, end, line: at, ...extra });
  const fail = (at, reason) => {
    events.push({ kind: 'error', line: at, reason });
    return events;
  };
  if (text.startsWith(BOM)) {
    push('bom', 0, 3, 1);
    i = 3;
  }
  if (text[i] === '#') {
    let j = i;
    while (j < n && !isNewline(text[j])) j += 1;
    push('shebang', i, j, 1);
    i = j;
  }
  // fin (exclue) d'un bloc long de niveau `level` dont le contenu commence en `from`, ou -1
  const closeLong = (from, level) => {
    const close = `]${'='.repeat(level)}]`;
    const at = text.indexOf(close, from);
    return at < 0 ? -1 : at + close.length;
  };
  while (i < n) {
    const c = text[i];
    const start = i;
    const at = line;
    if (isBlank(c)) {
      while (i < n && isBlank(text[i])) i += 1;
      push('ws', start, i, at);
    } else if (isNewline(c)) {
      i += newlineLength(text, i);
      line += 1;
      push('eol', start, i, at);
    } else if (c === '-' && text[i + 1] === '-') {
      const level = longLevel(text, i + 2);
      if (level >= 0) {
        const end = closeLong(i + 2 + level + 2, level);
        if (end < 0) return fail(at, 'commentaire long non fermé');
        line += newlinesOf(text, start, end).length;
        i = end;
        push('comment', start, end, at, { long: true });
      } else {
        while (i < n && !isNewline(text[i])) i += 1;
        push('comment', start, i, at, { long: false });
      }
    } else if (c === '"' || c === '\'' || c === '`') {
      i += 1;
      for (;;) {
        if (i >= n || isNewline(text[i])) return fail(at, 'chaîne non fermée');
        const d = text[i];
        if (d === c) {
          i += 1;
          break;
        }
        if (d !== '\\') {
          i += 1;
          continue;
        }
        i += 1;   // la barre ; puis le caractère échappé
        if (i >= n) return fail(at, 'chaîne non fermée');
        const e = text[i];
        if (isNewline(e)) {
          i += newlineLength(text, i);
          line += 1;
        } else if (e === 'z') {
          i += 1;
          while (i < n && (isBlank(text[i]) || isNewline(text[i]))) {
            if (isNewline(text[i])) {
              i += newlineLength(text, i);
              line += 1;
            } else i += 1;
          }
        } else i += 1;
      }
      push('string', start, i, at);
    } else if (c === '[') {
      const level = longLevel(text, i);
      if (level >= 0) {
        const end = closeLong(i + level + 2, level);
        if (end < 0) return fail(at, 'chaîne longue non fermée');
        line += newlinesOf(text, start, end).length;
        i = end;
        push('long', start, end, at);
      } else {
        i += 1;
        push('punct', start, i, at);
      }
    } else if (isDigit(c) || (c === '.' && isDigit(text[i + 1] || ''))) {
      // read_numeral : exposant (et son signe), chiffres hexadécimaux, points ; une lettre collée est prise
      let expo = 'Ee';
      i += 1;
      if (c === '0' && (text[i] === 'x' || text[i] === 'X')) {
        expo = 'Pp';
        i += 1;
      }
      for (;;) {
        const d = text[i];
        if (d !== undefined && expo.includes(d)) {
          i += 1;
          if (text[i] === '+' || text[i] === '-') i += 1;
        } else if (d !== undefined && (isHex(d) || d === '.')) i += 1;
        else break;
      }
      if (i < n && isAlpha(text[i])) i += 1;
      push('number', start, i, at);
    } else if (isAlpha(c)) {
      i += 1;
      while (i < n && (isAlpha(text[i]) || isDigit(text[i]))) i += 1;
      push('name', start, i, at);
    } else {
      i += 1;
      push('punct', start, i, at);
    }
  }
  return events;
}

const SILENT = new Set(['ws', 'eol', 'comment']);

/** Signature tirée d'évènements déjà lus, et nombre de fins de ligne du texte ; null si le texte ne se lit pas. */
function signatureOf(text, events) {
  const tokens = [];
  let gap = 1;
  for (const e of events) {
    if (e.kind === 'error') return null;
    if (SILENT.has(e.kind)) {
      gap = 1;
      continue;
    }
    tokens.push([e.line, gap, text.slice(e.start, e.end)]);
    gap = 0;
  }
  return { tokens, lines: newlinesOf(text, 0, text.length).length };
}

/**
 * [ligne, écart, lexème] de chaque lexème hors blancs et commentaires ; écart = 1 si un blanc, une fin de ligne ou un
 * commentaire le précède (ou s'il est le premier). null si le texte ne se lit pas.
 */
function signature(text) {
  const sig = signatureOf(text, scan(text));
  return sig ? sig.tokens : null;
}

/** Ligne de la première différence entre deux signatures, ou 0. */
function firstDifference(a, b) {
  const size = Math.max(a.tokens.length, b.tokens.length);
  for (let k = 0; k < size; k += 1) {
    const x = a.tokens[k];
    const y = b.tokens[k];
    if (!x || !y || x[0] !== y[0] || x[1] !== y[1] || x[2] !== y[2]) return (x || y)[0];
  }
  return a.lines === b.lines ? 0 : Math.min(a.lines, b.lines) + 1;
}

// contrôle d'un allègement, les évènements de l'original déjà lus
function controlWith(text, events, result) {
  const before = signatureOf(text, events);
  const after = before && signatureOf(result, scan(result));
  const line = after ? firstDifference(before, after) : 1;
  if (!after || line) return { ok: false, line: line || 1, reason: 'contrôle après allègement' };
  return { ok: true };
}

/**
 * Contrôle d'un allègement : même suite de lexèmes, chacun à la même ligne et avec le même écart, même nombre de fins
 * de ligne. Utilisé par `strip` ; exporté pour les essais (un allègement faussé doit être refusé).
 * @returns {{ ok: true } | { ok: false, line: number, reason: string }}
 */
function control(text, result) {
  return controlWith(text, scan(text), result);
}

/**
 * Le texte sans ses commentaires ni ses blancs de fin de ligne, chaque fin de ligne gardée, contrôlé.
 * @param {string} text  texte lu en latin1
 * @returns {{ ok: true, text: string, removed: number } | { ok: false, line: number, reason: string }}
 */
function strip(text) {
  const events = scan(text);
  const last = events[events.length - 1];
  if (last && last.kind === 'error') return { ok: false, line: last.line, reason: last.reason };
  const out = [];
  let blanks = '';
  for (const e of events) {
    switch (e.kind) {
      case 'ws':
        blanks += text.slice(e.start, e.end);
        break;
      case 'eol':
        blanks = '';
        out.push(text.slice(e.start, e.end));
        break;
      case 'comment': {
        if (!e.long) break;
        const newlines = newlinesOf(text, e.start, e.end);
        if (newlines.length) {
          blanks = '';
          out.push(newlines.join(''));
        } else if (blanks === '') blanks = ' ';
        break;
      }
      default:
        out.push(blanks, text.slice(e.start, e.end));
        blanks = '';
    }
  }
  const result = out.join('');
  const checked = controlWith(text, events, result);
  if (!checked.ok) return checked;
  return { ok: true, text: result, removed: text.length - result.length };
}

module.exports = { scan, strip, signature, control };
