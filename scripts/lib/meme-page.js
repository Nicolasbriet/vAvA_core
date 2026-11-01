'use strict';
/*
 * scripts/lib/meme-page.js
 * Rôle : preuve de l'allègement des pages livrées (T-160), indépendante du lexeur de la Chancellerie
 *        (chancellerie/lib/webstrip.js, jamais lu ici) : chaque page est relue avant et après par un second lecteur écrit
 *        d'après les normes, sur le texte décodé en UTF-8 (le premier lit des octets).
 *        - JavaScript : grammaire lexicale d'ECMAScript (noms Unicode et échappés, nombres à séparateurs, BigInt,
 *          ponctuations par plus longue correspondance, chaînes, gabarits imbriqués, expressions régulières, commentaires
 *          dont ceux de l'Annexe B, fins de ligne U+2028 et U+2029) ; `/` tranché par le contexte des accolades (algorithme
 *          « read » de Sweet.js : une `{` ouvre un bloc ou un objet selon ce qui la précède) ; et les deux textes compilés
 *          par V8 (`vm.Script`, jamais exécutés).
 *        - CSS : « consume a token » de CSS Syntax Level 3 (jetons typés : chaînes, url non citées, nombres, dimensions,
 *          noms échappés, CDO/CDC, délimiteurs).
 *        - HTML : tokenizer WHATWG pour ce qu'il faut (balises et attributs analysés, commentaires et leurs états,
 *          doctype, texte brut, RCDATA, données de script avec leurs états échappés).
 *        Même page : mêmes jetons hors commentaires (JS : avec l'écart blanc ou non devant chacun ; CSS : blancs
 *        consécutifs fusionnés en une marque ; HTML : textes fusionnés par-dessus les commentaires, marque « blanc »),
 *        chacun à la même ligne (les marques de blanc n'ont pas de ligne : un commentaire retiré allonge le blanc
 *        voisin de ses fins de ligne), même nombre de fins de ligne.
 *        Module : compare(original, allege, kind, chemin) → { same: true } | { same: false, reason } (l'allégé
 *        diffère) | { same: null, reason } (l'original ne se lit pas ou, en JS, ne se compile pas).
 *        Ligne de commande, depuis n'importe où : node scripts/lib/meme-page.js <dossier> < sortie de
 *        `node scripts/livraison.js --essai-pages <dossier>` ; « ÉCART chemin : raison » par écart (page allégée qui
 *        diffère, page livrée non prouvable ou refusée par la livraison), puis le bilan ; code 1 au moindre écart ou si
 *        l'entrée est vide. Hors livraison, un refus du premier lecteur et un original non compilable sont notés.
 * Dépendances : node ≥ 18 ; fs, path, vm seulement.
 */

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.resolve(__dirname, '..', '..');

// Fins de ligne -------------------------------------------------------------------------------------------------------

/** Positions des fins de ligne (`\r\n` compté une fois, à son `\r`) d'après l'ensemble donné. */
function lineBreaks(src, breaks) {
  const out = [];
  for (let i = 0; i < src.length; i += 1) {
    const c = src[i];
    if (!breaks.has(c)) continue;
    out.push(i);
    if (c === '\r' && src[i + 1] === '\n') i += 1;
  }
  return out;
}

/** Numéro de ligne d'une position (recherche dichotomique dans les fins de ligne). */
function lineOf(breaks, index) {
  let lo = 0;
  let hi = breaks.length;
  while (lo < hi) {
    const mid = (lo + hi) >> 1;
    if (breaks[mid] < index) lo = mid + 1;
    else hi = mid;
  }
  return lo + 1;
}

// JavaScript ----------------------------------------------------------------------------------------------------------

const JS_BREAKS = new Set(['\n', '\r', '\u2028', '\u2029']);
const ID_START = /^[\p{ID_Start}$_]$/u;
const ID_CONTINUE = /^[\p{ID_Continue}$\u200C\u200D]$/u;
const SPACE_SEPARATOR = /^\p{Zs}$/u;
const PUNCTUATORS = ['>>>=', '...', '===', '!==', '**=', '<<=', '>>=', '>>>', '&&=', '||=', '??=', '=>', '==', '!=', '<=',
  '>=', '&&', '||', '??', '?.', '++', '--', '+=', '-=', '*=', '%=', '&=', '|=', '^=', '<<', '>>', '**', '{', '}', '(', ')',
  '[', ']', ';', ',', '<', '>', '+', '-', '*', '%', '&', '|', '^', '!', '~', '?', ':', '=', '.', '@'];
// mots après lesquels vient une expression (donc `/` ouvre une expression régulière) ; yield et await lus comme mots-clés
const EXPRESSION_KEYWORDS = new Set(['return', 'typeof', 'instanceof', 'in', 'new', 'delete', 'void', 'throw', 'case',
  'do', 'else', 'yield', 'await', 'extends']);
const PAREN_KEYWORDS = new Set(['if', 'while', 'for', 'with']);
const BLOCK_KEYWORDS = new Set(['else', 'do', 'try', 'finally']);
const OPERATOR_KEYWORDS = new Set(['typeof', 'instanceof', 'in', 'of', 'new', 'delete', 'void', 'throw', 'case', 'await',
  'extends']);

const isJsSpace = (ch) => ch === '\t' || ch === '\v' || ch === '\f' || ch === ' ' || ch === '\u00A0' || ch === '\uFEFF'
  || SPACE_SEPARATOR.test(ch);
const charAt = (src, i) => {
  const cp = src.codePointAt(i);
  return cp === undefined ? '' : String.fromCodePoint(cp);
};

/**
 * Jetons significatifs d'un script : [{ text, gap, line }] (gap : 1 si un blanc, une fin de ligne ou un commentaire
 * le précède), et nombre de fins de ligne ; ou { error }.
 */
function readJs(src) {
  const breaks = lineBreaks(src, JS_BREAKS);
  const tokens = [];
  const n = src.length;
  let pos = 0;
  let gap = 1;
  let newline = true;       // une fin de ligne depuis le dernier jeton (ou début du texte)
  let lineStart = true;     // seuls des blancs et commentaires depuis le début de la ligne (Annexe B : `-->`)
  let prev = null;
  let pendingFunction = null;
  const stack = [{ type: 'top', q: 0 }];
  const top = () => stack[stack.length - 1];

  // contexte après `prev` : 'block' (début d'instruction) ou 'expr'
  const contextAfter = (before, nl, forBrace) => {
    if (!before) return 'block';
    if (before.kind === 'punct') {
      switch (before.text) {
        case ';': case '}': return 'block';
        case ')': return 'block';
        case '{': return before.opener && before.opener.brace === 'expr' ? 'expr' : 'block';
        case '=>': return forBrace ? 'block' : 'expr';
        case ':':
          if (before.ternary) return 'expr';
          return top().type === '{' && top().brace === 'expr' ? 'expr' : 'block';
        default: return 'expr';
      }
    }
    if (before.kind === 'name') {
      if (before.property) return 'expr';
      if (before.text === 'return' || before.text === 'yield') return nl ? 'block' : 'expr';
      if (BLOCK_KEYWORDS.has(before.text)) return 'block';
      if (OPERATOR_KEYWORDS.has(before.text)) return 'expr';
      return 'block';
    }
    return 'block';
  };
  const regexAllowed = (before) => {
    if (!before) return true;
    if (before.kind === 'punct') {
      if (before.text === ')') return Boolean(before.opener && before.opener.keyword);
      if (before.text === ']' || before.text === '++' || before.text === '--') return false;
      if (before.text === '}') return Boolean(before.opener && before.opener.brace === 'block');
      return true;
    }
    if (before.kind === 'name') return !before.property && EXPRESSION_KEYWORDS.has(before.text);
    return false;
  };
  const emit = (start, kind, extra = {}) => {
    const token = { text: src.slice(start, pos), gap, line: lineOf(breaks, start), kind, ...extra };
    tokens.push(token);
    const nl = newline;
    gap = 0;
    newline = false;
    lineStart = false;
    // fonction en attente : `function`, `*`, nom, puis `(`
    if (pendingFunction && !(kind === 'name' || (kind === 'punct' && (token.text === '*' || token.text === '(')))) pendingFunction = null;
    if (kind === 'name' && !token.property && token.text === 'function') {
      pendingFunction = { expr: contextAfter(prev, nl, false) === 'expr' };
    }
    if (kind === 'punct') {
      const t = token.text;
      if (t === '(') {
        stack.push({
          type: '(', q: 0, function: pendingFunction,
          keyword: Boolean(prev && prev.kind === 'name' && !prev.property && PAREN_KEYWORDS.has(prev.text)),
        });
        pendingFunction = null;
      } else if (t === '[') stack.push({ type: '[', q: 0 });
      else if (t === '{') {
        let brace = contextAfter(prev, nl, true);
        // corps d'une fonction expression : après sa `}`, `/` divise
        if (prev && prev.kind === 'punct' && prev.text === ')' && prev.opener && prev.opener.function) {
          brace = prev.opener.function.expr ? 'expr' : 'block';
        }
        stack.push({ type: '{', q: 0, brace });
        token.opener = top();
      } else if (t === ')' || t === ']' || t === '}') {
        const want = { ')': '(', ']': '[', '}': '{' }[t];
        if (top().type !== want) return 'parenthèses mal appariées';
        token.opener = stack.pop();
      } else if (t === '?') top().q += 1;
      else if (t === ':' && top().q > 0) {
        top().q -= 1;
        token.ternary = true;
      }
    }
    prev = token;
    return null;
  };
  const skipBreak = (i) => (src[i] === '\r' && src[i + 1] === '\n' ? i + 2 : i + 1);
  // morceau de gabarit depuis `pos` ; null, ou une erreur
  const template = () => {
    for (;;) {
      if (pos >= n) return 'gabarit non fermé';
      const c = src[pos];
      if (c === '\\') {
        pos = JS_BREAKS.has(src[pos + 1]) ? skipBreak(pos + 1) : pos + 2;
      } else if (c === '`') {
        pos += 1;
        return null;
      } else if (c === '$' && src[pos + 1] === '{') {
        pos += 2;
        stack.push({ type: '${', q: 0 });
        return null;
      } else pos += 1;
    }
  };
  if (src.startsWith('#!')) {
    while (pos < n && !JS_BREAKS.has(src[pos])) pos += 1;
  }
  while (pos < n) {
    const c = src[pos];
    const start = pos;
    if (JS_BREAKS.has(c)) {
      pos = skipBreak(pos);
      gap = 1;
      newline = true;
      lineStart = true;
    } else if (isJsSpace(c)) {
      pos += 1;
      gap = 1;
    } else if (src.startsWith('//', pos) || src.startsWith('<!--', pos) || (lineStart && src.startsWith('-->', pos))) {
      while (pos < n && !JS_BREAKS.has(src[pos])) pos += 1;
      gap = 1;
    } else if (src.startsWith('/*', pos)) {
      const end = src.indexOf('*/', pos + 2);
      if (end < 0) return { error: 'commentaire non fermé' };
      pos = end + 2;
      gap = 1;
      for (let k = start; k < pos; k += 1) {
        if (JS_BREAKS.has(src[k])) {
          newline = true;
          lineStart = true;
        }
      }
    } else if (c === '"' || c === '\'') {
      pos += 1;
      for (;;) {
        if (pos >= n || src[pos] === '\n' || src[pos] === '\r') return { error: 'chaîne non fermée' };
        if (src[pos] === c) {
          pos += 1;
          break;
        }
        if (src[pos] === '\\') pos = JS_BREAKS.has(src[pos + 1]) ? skipBreak(pos + 1) : pos + 2;
        else pos += 1;
      }
      emit(start, 'string');
    } else if (c === '`' || (c === '}' && top().type === '${')) {
      if (c === '}') stack.pop();
      pos += 1;
      const error = template();
      if (error) return { error };
      emit(start, 'template', { open: src[pos - 1] === '{' });
      if (src[pos - 1] === '{') prev = { kind: 'punct', text: '${' };
    } else if (c === '/') {
      if (regexAllowed(prev)) {
        pos += 1;
        let inClass = false;
        for (;;) {
          const d = src[pos];
          if (d === undefined || JS_BREAKS.has(d)) return { error: 'expression régulière non fermée' };
          if (d === '\\') {
            if (src[pos + 1] === undefined || JS_BREAKS.has(src[pos + 1])) return { error: 'expression régulière non fermée' };
            pos += 2;
          } else if (d === '[') {
            inClass = true;
            pos += 1;
          } else if (d === ']') {
            inClass = false;
            pos += 1;
          } else if (d === '/' && !inClass) {
            pos += 1;
            break;
          } else pos += 1;
        }
        for (let ch = charAt(src, pos); ch && ID_CONTINUE.test(ch); ch = charAt(src, pos)) pos += ch.length;
        emit(start, 'regex');
      } else {
        pos += src[pos + 1] === '=' ? 2 : 1;
        const error = emit(start, 'punct');
        if (error) return { error };
      }
    } else if ((c >= '0' && c <= '9') || (c === '.' && src[pos + 1] >= '0' && src[pos + 1] <= '9')) {
      const digits = (re) => {
        while (pos < n && re.test(src[pos])) pos += 1;
      };
      if (c === '0' && /[xXoObB]/.test(src[pos + 1] || '')) {
        pos += 2;
        digits(/[0-9a-fA-F_]/);
      } else {
        digits(/[0-9_]/);
        if (src[pos] === '.') {
          pos += 1;
          digits(/[0-9_]/);
        }
        if (src[pos] === 'e' || src[pos] === 'E') {
          let q = pos + 1;
          if (src[q] === '+' || src[q] === '-') q += 1;
          if (src[q] >= '0' && src[q] <= '9') {
            pos = q;
            digits(/[0-9_]/);
          }
        }
      }
      if (src[pos] === 'n') pos += 1;
      emit(start, 'number');
    } else if (ID_START.test(charAt(src, pos)) || (c === '\\' && src[pos + 1] === 'u') || c === '#') {
      if (c === '#') pos += 1;
      let first = true;
      for (;;) {
        const ch = charAt(src, pos);
        if (ch && (first ? ID_START : ID_CONTINUE).test(ch)) pos += ch.length;
        else if (ch === '\\' && src[pos + 1] === 'u') {
          if (src[pos + 2] === '{') {
            const close = src.indexOf('}', pos + 3);
            if (close < 0 || close > pos + 12) return { error: 'échappement illisible' };
            pos = close + 1;
          } else pos += 6;
        } else break;
        first = false;
      }
      if (pos === start + 1 && c === '#') return { error: '« # » isolé' };
      const property = Boolean(prev && prev.kind === 'punct' && (prev.text === '.' || prev.text === '?.'));
      emit(start, 'name', { property });
    } else {
      const punct = PUNCTUATORS.find((p) => src.startsWith(p, pos)
        && !(p === '?.' && src[pos + 2] >= '0' && src[pos + 2] <= '9'));
      if (!punct) return { error: `caractère inattendu (ligne ${lineOf(breaks, pos)})` };
      pos += punct.length;
      const error = emit(start, 'punct');
      if (error) return { error };
    }
  }
  return { tokens, lines: breaks.length };
}

/** Le texte se compile-t-il en script classique ? (V8, jamais exécuté) */
function compiles(src, name) {
  try {
    new vm.Script(src, { filename: name });   // eslint-disable-line no-new
    return true;
  } catch (error) {
    return false;
  }
}

// CSS -----------------------------------------------------------------------------------------------------------------

const CSS_BREAKS = new Set(['\n', '\r', '\f']);
const isCssSpace = (c) => c === ' ' || c === '\t' || CSS_BREAKS.has(c);
const isCssNameStart = (c) => c !== undefined && (/[A-Za-z_]/.test(c) || c >= '\u0080');
const isCssName = (c) => isCssNameStart(c) || (c !== undefined && /[0-9-]/.test(c));
const isCssDigit = (c) => c !== undefined && c >= '0' && c <= '9';
const validEscape = (a, b) => a === '\\' && b !== undefined && !CSS_BREAKS.has(b);

/** Jetons CSS (« consume a token ») : [{ type, text, line }] ; commentaires compris (type 'comment'). */
function readCss(src) {
  const breaks = lineBreaks(src, CSS_BREAKS);
  const tokens = [];
  const n = src.length;
  let pos = 0;
  const startsIdent = (i) => {
    const a = src[i];
    if (a === '-') return isCssNameStart(src[i + 1]) || src[i + 1] === '-' || validEscape(src[i + 1], src[i + 2]);
    if (isCssNameStart(a)) return true;
    return validEscape(a, src[i + 1]);
  };
  const startsNumber = (i) => {
    const a = src[i];
    if (a === '+' || a === '-') return isCssDigit(src[i + 1]) || (src[i + 1] === '.' && isCssDigit(src[i + 2]));
    if (a === '.') return isCssDigit(src[i + 1]);
    return isCssDigit(a);
  };
  const consumeEscape = () => {
    // après la barre
    if (/[0-9a-fA-F]/.test(src[pos] || '')) {
      let k = 0;
      while (k < 6 && /[0-9a-fA-F]/.test(src[pos] || '')) {
        pos += 1;
        k += 1;
      }
      if (src[pos] === '\r' && src[pos + 1] === '\n') pos += 2;
      else if (isCssSpace(src[pos])) pos += 1;
    } else if (pos < n) pos += 1;
  };
  const consumeName = () => {
    for (;;) {
      if (isCssName(src[pos])) pos += 1;
      else if (validEscape(src[pos], src[pos + 1])) {
        pos += 1;
        consumeEscape();
      } else return;
    }
  };
  const consumeNumber = () => {
    if (src[pos] === '+' || src[pos] === '-') pos += 1;
    while (isCssDigit(src[pos])) pos += 1;
    if (src[pos] === '.' && isCssDigit(src[pos + 1])) {
      pos += 1;
      while (isCssDigit(src[pos])) pos += 1;
    }
    if ((src[pos] === 'e' || src[pos] === 'E')
      && (isCssDigit(src[pos + 1]) || ((src[pos + 1] === '+' || src[pos + 1] === '-') && isCssDigit(src[pos + 2])))) {
      pos += 2;
      while (isCssDigit(src[pos])) pos += 1;
    }
  };
  const consumeBadUrl = () => {
    while (pos < n && src[pos] !== ')') {
      if (validEscape(src[pos], src[pos + 1])) {
        pos += 1;
        consumeEscape();
      } else pos += 1;
    }
    if (pos < n) pos += 1;
    return 'bad-url';
  };
  const consumeUrl = () => {
    while (isCssSpace(src[pos])) pos += 1;
    for (;;) {
      const c = src[pos];
      if (c === undefined) return 'url';
      if (c === ')') {
        pos += 1;
        return 'url';
      }
      if (isCssSpace(c)) {
        while (isCssSpace(src[pos])) pos += 1;
        if (src[pos] === ')' || src[pos] === undefined) {
          if (src[pos] === ')') pos += 1;
          return 'url';
        }
        return consumeBadUrl();
      }
      if (c === '"' || c === '\'' || c === '(' || /[\u0000-\u0008\u000B\u000E-\u001F\u007F]/.test(c)) return consumeBadUrl();
      if (c === '\\') {
        if (!validEscape(c, src[pos + 1])) return consumeBadUrl();
        pos += 1;
        consumeEscape();
      } else pos += 1;
    }
  };
  while (pos < n) {
    const start = pos;
    const c = src[pos];
    let type;
    if (c === '/' && src[pos + 1] === '*') {
      const end = src.indexOf('*/', pos + 2);
      pos = end < 0 ? n : end + 2;
      type = 'comment';
    } else if (isCssSpace(c)) {
      while (isCssSpace(src[pos])) pos += 1;
      type = 'ws';
    } else if (c === '"' || c === '\'') {
      pos += 1;
      type = 'string';
      for (;;) {
        const d = src[pos];
        if (d === undefined) break;
        if (d === c) {
          pos += 1;
          break;
        }
        if (CSS_BREAKS.has(d)) {
          type = 'bad-string';
          break;
        }
        if (d === '\\') {
          if (src[pos + 1] === undefined) pos += 1;
          else if (CSS_BREAKS.has(src[pos + 1])) pos = src[pos + 1] === '\r' && src[pos + 2] === '\n' ? pos + 3 : pos + 2;
          else {
            pos += 1;
            consumeEscape();
          }
        } else pos += 1;
      }
    } else if (c === '#' && (isCssName(src[pos + 1]) || validEscape(src[pos + 1], src[pos + 2]))) {
      pos += 1;
      consumeName();
      type = 'hash';
    } else if ('()[]{},:;'.includes(c)) {
      pos += 1;
      type = c;
    } else if (startsNumber(pos)) {
      consumeNumber();
      if (startsIdent(pos)) {
        consumeName();
        type = 'dimension';
      } else if (src[pos] === '%') {
        pos += 1;
        type = 'percentage';
      } else type = 'number';
    } else if (src.startsWith('<!--', pos)) {
      pos += 4;
      type = 'cdo';
    } else if (src.startsWith('-->', pos)) {
      pos += 3;
      type = 'cdc';
    } else if (c === '@' && startsIdent(pos + 1)) {
      pos += 1;
      consumeName();
      type = 'at';
    } else if (startsIdent(pos)) {
      consumeName();
      const name = src.slice(start, pos);
      if (src[pos] === '(' && name.toLowerCase() === 'url') {
        pos += 1;
        let k = pos;
        while (isCssSpace(src[k])) k += 1;
        if (src[k] === '"' || src[k] === '\'') type = 'function';
        else type = consumeUrl();
      } else if (src[pos] === '(') {
        pos += 1;
        type = 'function';
      } else type = 'ident';
    } else {
      pos += c.length;
      type = 'delim';
    }
    tokens.push({ type, text: src.slice(start, pos), line: lineOf(breaks, start) });
  }
  return { tokens, lines: breaks.length };
}

// HTML ----------------------------------------------------------------------------------------------------------------

const HTML_BREAKS = new Set(['\n', '\r']);
const isHtmlSpace = (c) => c === ' ' || c === '\t' || c === '\n' || c === '\f' || c === '\r';
const isAsciiLetter = (c) => c !== undefined && /[A-Za-z]/.test(c);
const RAWTEXT = new Set(['style', 'xmp', 'iframe', 'noembed', 'noframes', 'noscript']);
const RCDATA = new Set(['title', 'textarea']);

/** Jetons HTML (tokenizer WHATWG) : texte, balises (attributs analysés), commentaires, doctype, contenus bruts. */
function readHtml(src) {
  const breaks = lineBreaks(src, HTML_BREAKS);
  const tokens = [];
  const n = src.length;
  let pos = 0;
  const at = (i) => lineOf(breaks, i);
  const lower = (s) => s.replace(/[A-Z]/g, (ch) => ch.toLowerCase());
  // fin (exclue) d'un commentaire commencé en `p` (après `<!--`), selon les états du commentaire
  const comment = (from) => {
    let p = from;
    let state = 'start';
    for (;;) {
      const c = src[p];
      if (c === undefined) return n;
      switch (state) {
        case 'start':
          if (c === '-') { state = 'startDash'; p += 1; } else if (c === '>') return p + 1; else state = 'comment';
          break;
        case 'startDash':
          if (c === '-') { state = 'end'; p += 1; } else if (c === '>') return p + 1; else state = 'comment';
          break;
        case 'comment':
          if (c === '<') state = 'lt'; else if (c === '-') state = 'endDash';
          p += 1;
          break;
        case 'lt':
          if (c === '!') { state = 'ltBang'; p += 1; } else if (c === '<') p += 1; else state = 'comment';
          break;
        case 'ltBang':
          if (c === '-') { state = 'ltBangDash'; p += 1; } else state = 'comment';
          break;
        case 'ltBangDash':
          if (c === '-') { state = 'ltBangDashDash'; p += 1; } else state = 'endDash';
          break;
        case 'ltBangDashDash':
          state = 'end';
          break;
        case 'endDash':
          if (c === '-') { state = 'end'; p += 1; } else state = 'comment';
          break;
        case 'end':
          if (c === '>') return p + 1;
          if (c === '!') { state = 'endBang'; p += 1; } else if (c === '-') p += 1; else state = 'comment';
          break;
        case 'endBang':
          if (c === '-') { state = 'endDash'; p += 1; } else if (c === '>') return p + 1; else state = 'comment';
          break;
        default:
          return n;
      }
    }
  };
  // balise depuis le premier caractère de son nom : { name, attrs, self, end } ; null si le fichier finit dedans
  const tag = (from) => {
    let p = from;
    while (p < n && !isHtmlSpace(src[p]) && src[p] !== '/' && src[p] !== '>') p += 1;
    const name = lower(src.slice(from, p));
    const attrs = [];
    let self = false;
    for (;;) {
      while (isHtmlSpace(src[p])) p += 1;
      const c = src[p];
      if (c === undefined) return null;
      if (c === '>') return { name, attrs, self, end: p + 1 };
      if (c === '/') {
        if (src[p + 1] === '>') return { name, attrs, self: true, end: p + 2 };
        p += 1;
        continue;
      }
      const nameStart = p;
      p += 1;   // un `=` en tête fait partie du nom
      while (p < n && !isHtmlSpace(src[p]) && src[p] !== '/' && src[p] !== '>' && src[p] !== '=') p += 1;
      const attr = lower(src.slice(nameStart, p));
      while (isHtmlSpace(src[p])) p += 1;
      let value = '';
      if (src[p] === '=') {
        p += 1;
        while (isHtmlSpace(src[p])) p += 1;
        const q = src[p];
        if (q === '"' || q === '\'') {
          const close = src.indexOf(q, p + 1);
          if (close < 0) return null;
          value = src.slice(p + 1, close);
          p = close + 1;
        } else if (q !== '>') {
          const valueStart = p;
          while (p < n && !isHtmlSpace(src[p]) && src[p] !== '>') p += 1;
          value = src.slice(valueStart, p);
        }
      }
      attrs.push([attr, value]);
      self = false;
    }
  };
  // début de `</nom` suivie d'un blanc, de `/` ou de `>` depuis `from` (texte brut, RCDATA) ; n si absente
  const appropriateEnd = (name, from) => {
    let p = from;
    for (;;) {
      p = src.indexOf('</', p);
      if (p < 0) return n;
      const candidate = lower(src.slice(p + 2, p + 2 + name.length));
      const after = src[p + 2 + name.length];
      if (candidate === name && (after === '>' || after === '/' || isHtmlSpace(after))) return p;
      p += 2;
    }
  };
  // fin des données d'un script, états échappés et doublement échappés compris
  const scriptEnd = (from) => {
    let p = from;
    let state = 'data';
    let buffer = '';
    const endTagAt = (q) => {
      const after = src[q + 8];
      return lower(src.slice(q + 2, q + 8)) === 'script' && (after === '>' || after === '/' || isHtmlSpace(after));
    };
    for (;;) {
      const c = src[p];
      if (c === undefined) return n;
      switch (state) {
        case 'data':
          if (c === '<') {
            if (src[p + 1] === '/' && endTagAt(p)) return p;
            if (src.startsWith('!--', p + 1)) {
              state = 'escapedDashDash';
              p += 4;
              break;
            }
          }
          p += 1;
          break;
        case 'escaped':
          if (c === '-') state = 'escapedDash';
          else if (c === '<') state = 'escapedLt';
          p += 1;
          break;
        case 'escapedDash':
          if (c === '-') state = 'escapedDashDash';
          else if (c === '<') state = 'escapedLt';
          else state = 'escaped';
          p += 1;
          break;
        case 'escapedDashDash':
          if (c === '<') state = 'escapedLt';
          else if (c === '>') state = 'data';
          else if (c !== '-') state = 'escaped';
          p += 1;
          break;
        case 'escapedLt':
          // `<` déjà lu
          if (c === '/') {
            if (endTagAt(p - 1)) return p - 1;
            state = 'escaped';
            p += 1;
          } else if (isAsciiLetter(c)) {
            buffer = '';
            state = 'doubleStart';
          } else state = 'escaped';
          break;
        case 'doubleStart':
          if (isHtmlSpace(c) || c === '/' || c === '>') {
            state = buffer === 'script' ? 'double' : 'escaped';
            p += 1;
          } else if (isAsciiLetter(c)) {
            buffer += c.toLowerCase();
            p += 1;
          } else state = 'escaped';
          break;
        case 'double':
          if (c === '-') state = 'doubleDash';
          else if (c === '<') state = 'doubleLt';
          p += 1;
          break;
        case 'doubleDash':
          if (c === '-') state = 'doubleDashDash';
          else if (c === '<') state = 'doubleLt';
          else state = 'double';
          p += 1;
          break;
        case 'doubleDashDash':
          if (c === '<') state = 'doubleLt';
          else if (c === '>') state = 'data';
          else if (c !== '-') state = 'double';
          p += 1;
          break;
        case 'doubleLt':
          if (c === '/') {
            buffer = '';
            state = 'doubleEnd';
            p += 1;
          } else state = 'double';
          break;
        case 'doubleEnd':
          if (isHtmlSpace(c) || c === '/' || c === '>') {
            state = buffer === 'script' ? 'escaped' : 'double';
            p += 1;
          } else if (isAsciiLetter(c)) {
            buffer += c.toLowerCase();
            p += 1;
          } else state = 'double';
          break;
        default:
          return n;
      }
    }
  };
  const bogus = (from) => {
    const end = src.indexOf('>', from);
    return end < 0 ? n : end + 1;
  };
  while (pos < n) {
    const next = src.indexOf('<', pos);
    const stop = next < 0 ? n : next;
    if (stop > pos) tokens.push({ type: 'text', data: src.slice(pos, stop), line: at(pos) });
    pos = stop;
    if (pos >= n) break;
    const start = pos;
    const c1 = src[pos + 1];
    if (c1 === '!') {
      if (src.startsWith('--', pos + 2)) {
        pos = comment(pos + 4);
        tokens.push({ type: 'comment' });
      } else if (lower(src.slice(pos + 2, pos + 9)) === 'doctype') {
        pos = bogus(pos + 2);
        tokens.push({ type: 'doctype', data: src.slice(start, pos), line: at(start) });
      } else {
        pos = bogus(pos + 2);
        tokens.push({ type: 'comment' });
      }
    } else if (c1 === '?') {
      pos = bogus(pos + 1);
      tokens.push({ type: 'comment' });
    } else if (c1 === '/') {
      if (isAsciiLetter(src[pos + 2])) {
        const t = tag(pos + 2);
        if (!t) break;
        pos = t.end;
        tokens.push({ type: 'end', name: t.name, line: at(start) });
      } else if (src[pos + 2] === '>') pos += 3;
      else if (pos + 2 >= n) {
        tokens.push({ type: 'text', data: src.slice(pos), line: at(pos) });
        pos = n;
      } else {
        pos = bogus(pos + 2);
        tokens.push({ type: 'comment' });
      }
    } else if (isAsciiLetter(c1)) {
      const t = tag(pos + 1);
      if (!t) break;
      pos = t.end;
      tokens.push({ type: 'start', name: t.name, attrs: t.attrs, self: t.self, line: at(start) });
      let end = -1;
      if (t.name === 'script') end = scriptEnd(pos);
      else if (RAWTEXT.has(t.name) || RCDATA.has(t.name)) end = appropriateEnd(t.name, pos);
      else if (t.name === 'plaintext') end = n;
      if (end >= 0) {
        tokens.push({ type: 'raw', data: src.slice(pos, end), line: at(pos) });
        pos = end;
      }
    } else {
      tokens.push({ type: 'text', data: '<', line: at(pos) });
      pos += 1;
    }
  }
  return { tokens, lines: breaks.length };
}

// Comparaison ---------------------------------------------------------------------------------------------------------

const isBlankText = (s) => /^[ \t\n\f\r]*$/.test(s);

/** Suite comparable : [forme, ligne] par élément (ligne 0 pour une marque de blanc). */
function comparable(kind, read) {
  const out = [];
  if (kind === 'js') {
    for (const t of read.tokens) out.push([JSON.stringify([t.text, t.gap]), t.line]);
    return out;
  }
  if (kind === 'css') {
    let blank = false;
    const flush = () => {
      if (blank) out.push(['blanc', 0]);
      blank = false;
    };
    for (const t of read.tokens) {
      if (t.type === 'comment') continue;
      if (t.type === 'ws') {
        blank = true;
        continue;
      }
      flush();
      out.push([JSON.stringify([t.type, t.text]), t.line]);
    }
    flush();
    return out;
  }
  let text = null;
  const flush = () => {
    if (text === null) return;
    if (isBlankText(text.data)) out.push(['blanc', 0]);
    else out.push([JSON.stringify(['text', text.data]), text.line]);
    text = null;
  };
  for (const t of read.tokens) {
    if (t.type === 'comment') continue;
    if (t.type === 'text') {
      if (text) text.data += t.data;
      else text = { data: t.data, line: t.line };
      continue;
    }
    flush();
    if (t.type === 'start') out.push([JSON.stringify(['start', t.name, t.attrs, t.self]), t.line]);
    else if (t.type === 'end') out.push([JSON.stringify(['end', t.name]), t.line]);
    else out.push([JSON.stringify([t.type, t.data]), t.line]);
  }
  flush();
  return out;
}

const READERS = { js: readJs, css: readCss, html: readHtml };

/**
 * Même page ? { same: true } ; { same: false, reason } si l'allégé diffère ; { same: null, reason } si l'original ne
 * se lit pas ou, en JS, ne se compile pas.
 * @param {string} original  texte décodé en UTF-8
 * @param {string} allege
 * @param {'js'|'css'|'html'} kind
 * @param {string} chemin
 */
function compare(original, allege, kind, chemin) {
  const reader = READERS[kind];
  if (!reader) return { same: null, reason: 'sorte inconnue' };
  if (kind === 'js') {
    if (!compiles(original, chemin)) return { same: null, reason: 'original non compilable' };
    if (!compiles(allege, chemin)) return { same: false, reason: 'allégé non compilable' };
  }
  const a = reader(original);
  if (a.error) return { same: null, reason: `original illisible : ${a.error}` };
  const b = reader(allege);
  if (b.error) return { same: false, reason: `allégé illisible : ${b.error}` };
  const x = comparable(kind, a);
  const y = comparable(kind, b);
  if (x.length !== y.length || x.some((item, k) => item[0] !== y[k][0])) return { same: false, reason: 'code différent' };
  if (x.some((item, k) => item[1] !== y[k][1])) return { same: false, reason: 'numéros de ligne différents' };
  if (a.lines !== b.lines) return { same: false, reason: 'nombre de lignes différent' };
  return { same: true };
}

const KINDS = { '.js': 'js', '.css': 'css', '.html': 'html', '.htm': 'html' };
const kindOf = (chemin) => KINDS[path.posix.extname(chemin.toLowerCase())] || null;

/** Ligne de commande : lit la sortie de `--essai-pages` ; renvoie le code de sortie. */
function run(dossier, input, write = (s) => process.stdout.write(s)) {
  let gaps = 0;
  let proved = 0;
  let delivered = 0;
  let seen = 0;
  const refused = [];
  const unread = [];
  const gap = (chemin, reason) => {
    gaps += 1;
    write(`ÉCART ${chemin} : ${reason}\n`);
  };
  for (const raw of input.split(/\r?\n/)) {
    if (!raw) continue;
    const [status, chemin, line, reason, side] = raw.split('\t');
    if (!chemin || !['livre', 'depot', 'refuse'].includes(status)) {
      gap(raw, 'ligne illisible');
      continue;
    }
    seen += 1;
    if (status === 'refuse') {
      // refus prudent du premier lecteur : permis hors livraison ; une page livrée refusée est un écart (on ne livre
      // pas allégé ce qu'on ne peut prouver, et la livraison l'a déjà dit)
      if (side === 'depot') refused.push(`${chemin} (ligne ${line} : ${reason})`);
      else gap(chemin, `page livrée refusée par la livraison (ligne ${line} : ${reason})`);
      continue;
    }
    const kind = kindOf(chemin);
    let original;
    let allege;
    try {
      original = fs.readFileSync(path.join(ROOT, chemin), 'utf8');
    } catch (error) {
      gap(chemin, 'original introuvable');
      continue;
    }
    try {
      allege = fs.readFileSync(path.join(dossier, chemin), 'utf8');
    } catch (error) {
      gap(chemin, 'fichier allégé introuvable');
      continue;
    }
    const result = kind ? compare(original, allege, kind, chemin) : { same: null, reason: 'sorte inconnue' };
    if (result.same) {
      proved += 1;
      if (status === 'livre') delivered += 1;
    } else if (result.same === null && status === 'depot') unread.push(chemin);
    else if (result.same === null) gap(chemin, `${result.reason} (livré : on ne livre pas ce qu'on ne peut prouver)`);
    else gap(chemin, result.reason);
  }
  return { gaps, proved, delivered, seen, refused, unread };
}

function main(argv) {
  const dossier = argv[0];
  if (!dossier || argv.length !== 1) {
    process.stderr.write('usage : node scripts/lib/meme-page.js <dossier> < sortie de livraison.js --essai-pages\n');
    return 2;
  }
  let input = '';
  try {
    input = fs.readFileSync(0, 'utf8');
  } catch (error) {
    input = '';
  }
  const r = run(path.resolve(dossier), input);
  if (r.gaps > 0) {
    process.stdout.write(`MÊME PAGE : ÉCHEC (${r.gaps} écart(s) ; ${r.proved} fichiers prouvés, dont ${r.delivered} livrés)\n`);
    return 1;
  }
  if (r.seen === 0) {
    process.stdout.write('MÊME PAGE : ÉCHEC (aucun fichier lu sur l\'entrée)\n');
    return 1;
  }
  const list = (items) => (items.length ? ` : ${items.slice(0, 10).join(', ')}${items.length > 10 ? ', …' : ''}` : '');
  process.stdout.write(`MÊME PAGE : OK (${r.proved} fichiers prouvés, dont ${r.delivered} livrés ; ${r.refused.length} refusés `
    + `hors livraison${list(r.refused)} ; ${r.unread.length} non lus hors livraison${list(r.unread)})\n`);
  return 0;
}

if (require.main === module) process.exitCode = main(process.argv.slice(2));

module.exports = { compare, readJs, readCss, readHtml, run };
