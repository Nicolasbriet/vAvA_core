'use strict';
/*
 * lib/webstrip.js
 * Rôle : retirer des pages servies aux joueurs (JavaScript, CSS, HTML) ce que le navigateur ignore, en gardant chaque fin
 *        de ligne à sa place : une erreur dans la console d'une interface désigne la même ligne que le dépôt (T-160).
 *        JavaScript : commentaires et blancs de fin de ligne ; chaînes, gabarits (imbriqués) et expressions régulières
 *        lus pour ne rien y toucher ; la barre `/` est tranchée d'après le lexème précédent, et ce qui ne se tranche pas
 *        (`/` après `}` ou après un mot contextuel) est refusé. CSS : commentaires (seulement s'ils touchent un blanc : en
 *        CSS un commentaire n'est pas un blanc) et blancs de fin de ligne ; chaînes et `url()` non cités lus d'un bloc.
 *        HTML : commentaires seulement, entre deux blancs, jamais dans `<pre>` ni au prix d'un nœud de texte créé ; aucun
 *        blanc retiré ; contenus de `<script>`, `<style>`, `<textarea>`, `<title>` jamais touchés ; balises lues par les
 *        états d'attributs de WHATWG ; dans du SVG ou du MathML en ligne, tout commentaire ou élément brut est refusé ; un
 *        commentaire de plusieurs lignes n'est retiré qu'avant `<body>`. Refusé (fichier laissé
 *        tel quel par l'appelant) : tout ce qui n'est pas tranché sûrement (§ 6 de la spec T-160). Chaque allègement se
 *        contrôle lui-même (signature : même suite de lexèmes, chacun à sa ligne). Le texte est lu en latin1 : un
 *        caractère = un octet, rien n'est interprété. Temps linéaire : un seul passage, fermetures cherchées par
 *        `indexOf` depuis la position courante, recherches en avant monotones, aucune expression régulière sur le texte ;
 *        imbrication bornée. La preuve indépendante est faite par scripts/lib/meme-page.js et par V8 (lib/delivery.js).
 * Dépendances : aucune (fonctions pures).
 */

const BOM = '\xEF\xBB\xBF';
// pile des `(`, `[`, `{`, `${` (JavaScript) et gabarits imbriqués : au-delà, refus (mémoire et pile bornées)
const MAX_DEPTH = 1024;
const MAX_TEMPLATES = 64;

const isDigit = (c) => c >= '0' && c <= '9';
const isHex = (c) => isDigit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
const isLetter = (c) => (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
const isIdStart = (c) => isLetter(c) || c === '_' || c === '$';
const isIdPart = (c) => isIdStart(c) || isDigit(c);
// fins de ligne : JavaScript et HTML `\n`, `\r` ; CSS aussi `\f`
const isNewline = (c) => c === '\n' || c === '\r';
const isCssNewline = (c) => c === '\n' || c === '\r' || c === '\f';

/** Longueur d'une fin de ligne en `i` : `\r\n` et `\n\r` comptent pour une (deux octets), comme lib/luastrip.js. */
function newlineLength(text, i) {
  const c = text[i];
  const next = text[i + 1];
  return (c === '\r' && next === '\n') || (c === '\n' && next === '\r') ? 2 : 1;
}

/** Fins de ligne d'un morceau de texte, dans l'ordre et telles quelles. */
function newlinesOf(text, start, end, newline = isNewline) {
  const out = [];
  let i = start;
  while (i < end) {
    if (newline(text[i])) {
      const size = i + 1 < end ? newlineLength(text, i) : 1;
      out.push(text.slice(i, i + size));
      i += size;
    } else i += 1;
  }
  return out;
}

/** Numéro de ligne de l'octet `index` (un seul passage, pour un refus). */
function lineAt(text, index, newline = isNewline) {
  return newlinesOf(text, 0, index, newline).length + 1;
}

// JavaScript ------------------------------------------------------------------------------------------------------------

const JS_BLANK = (c) => c === ' ' || c === '\t' || c === '\v' || c === '\f';
// après ces mots, `/` ouvre une expression régulière (`extends` : relecture sécurité S-4)
const REGEX_AFTER = new Set(['return', 'typeof', 'instanceof', 'in', 'new', 'delete', 'void', 'throw', 'case', 'do', 'else',
  'extends']);
// mots contextuels : `/` après eux ne se tranche pas sans analyse complète
const UNDECIDABLE = new Set(['of', 'yield', 'await', 'let', 'static', 'async', 'get', 'set']);
// `(` après ces mots : `/` après la `)` appariée ouvre une expression régulière (`if (x) /re/.test(y)`)
const PAREN_KEYWORDS = new Set(['if', 'while', 'for', 'with']);
const CLOSERS = { ')': '(', ']': '[', '}': '{' };

/**
 * `/` en mode code : expression régulière (true), division (false), ou raison du refus (chaîne), d'après le lexème
 * significatif précédent. `++`/`--` suffixe (`a++ / 2`) : division ; préfixe (là où une expression commence) : refus
 * (relecture sécurité S-4). Limite connue, sans refus : après `for await (…)`, `/` est lu comme une division (`await`
 * n'est pas suivi comme `for`) ; une expression régulière à cet endroit garde son texte ou fait refuser la page (contrôle,
 * V8, preuve), jamais rien d'autre.
 */
function slashOpensRegex(prev) {
  if (!prev) return true;
  if (prev.kind === 'punct') {
    if (prev.text === ')') return prev.keyword === true;
    if ((prev.text === '++' || prev.text === '--') && prev.prefix) return `« / » après « ${prev.text} » préfixe : indécidable`;
    if (prev.text === ']' || prev.text === '++' || prev.text === '--') return false;
    if (prev.text === '}') return '« / » après « } » : division ou expression régulière indécidable';
    return true;
  }
  if (prev.kind === 'name') {
    if (prev.property) return false;
    if (REGEX_AFTER.has(prev.text)) return true;
    if (UNDECIDABLE.has(prev.text)) return `« / » après « ${prev.text} » : indécidable`;
    return false;
  }
  return false;   // nombre, chaîne, fin de gabarit, expression régulière
}

/**
 * Évènements JavaScript dans l'ordre : { kind, start, end, line } ; kind : 'bom' | 'ws' | 'eol' | 'comment' (`long`,
 * `keep`, `lines`) | 'string' | 'template' | 'regex' | 'number' | 'name' | 'punct' ; ou { kind: 'error', line, reason }
 * en dernier.
 * @param {string} text  texte lu en latin1
 */
function scanJs(text) {
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
  if (text[i] === '#' && text[i + 1] === '!') return fail(1, 'première ligne « #! » refusée');
  // U+2028 et U+2029 (en UTF-8) : fins de ligne pour V8, pas pour ce lexeur
  for (const separator of ['\xE2\x80\xA8', '\xE2\x80\xA9']) {
    const at = text.indexOf(separator);
    if (at >= 0) return fail(lineAt(text, at), 'séparateur de ligne Unicode');
  }
  const stack = [];   // { open: '(' | '[' | '{' | '${', keyword }
  let templates = 0;
  let prev = null;    // dernier lexème significatif : { kind, text, keyword, property }
  // morceau de gabarit depuis `from` (après la contre-apostrophe ou la `}` d'un `${`) ; null si tout va bien
  const template = (start, from, at) => {
    let j = from;
    for (;;) {
      if (j >= n) return 'gabarit non fermé';
      const c = text[j];
      if (c === '\\') {
        j += 1;
        if (j >= n) return 'gabarit non fermé';
        if (isNewline(text[j])) {
          j += newlineLength(text, j);
          line += 1;
        } else j += 1;
      } else if (c === '`') {
        j += 1;
        templates -= 1;
        push('template', start, j, at);
        prev = { kind: 'template', text: '`' };
        i = j;
        return null;
      } else if (c === '$' && text[j + 1] === '{') {
        j += 2;
        if (stack.length >= MAX_DEPTH) return 'imbrication trop profonde';
        stack.push({ open: '${' });
        push('template', start, j, at);
        prev = { kind: 'punct', text: '${' };
        i = j;
        return null;
      } else if (isNewline(c)) {
        j += newlineLength(text, j);
        line += 1;
      } else j += 1;
    }
  };
  while (i < n) {
    const c = text[i];
    const start = i;
    const at = line;
    if (JS_BLANK(c)) {
      while (i < n && JS_BLANK(text[i])) i += 1;
      push('ws', start, i, at);
    } else if (isNewline(c)) {
      i += newlineLength(text, i);
      line += 1;
      push('eol', start, i, at);
    } else if (c === '/' && text[i + 1] === '/') {
      i += 2;
      while (i < n && !isNewline(text[i])) i += 1;
      const mark = text[start + 2];
      push('comment', start, i, at, { long: false, keep: mark === '#' || mark === '@', lines: 0 });
    } else if (c === '/' && text[i + 1] === '*') {
      const close = text.indexOf('*/', i + 2);
      if (close < 0) return fail(at, 'commentaire non fermé');
      i = close + 2;
      const lines = newlinesOf(text, start, i).length;
      line += lines;
      const mark = text[start + 2];
      push('comment', start, i, at, { long: true, keep: mark === '!' || mark === '#' || mark === '@', lines });
    } else if (c === '<' && text.startsWith('!--', i + 1)) {
      return fail(at, '« <!-- » hors chaîne (commentaire HTML de JavaScript)');
    } else if (c === '-' && text[i + 1] === '-' && text[i + 2] === '>') {
      return fail(at, '« --> » hors chaîne');
    } else if (c === '\'' || c === '"') {
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
        i += 1;   // la barre ; puis le caractère échappé (une fin de ligne échappée compte une ligne)
        if (i >= n) return fail(at, 'chaîne non fermée');
        if (isNewline(text[i])) {
          i += newlineLength(text, i);
          line += 1;
        } else i += 1;
      }
      push('string', start, i, at);
      prev = { kind: 'string', text: c };
    } else if (c === '`') {
      templates += 1;
      if (templates > MAX_TEMPLATES) return fail(at, 'imbrication trop profonde');
      const reason = template(start, i + 1, at);
      if (reason) return fail(at, reason);
    } else if (c === '}' && stack.length && stack[stack.length - 1].open === '${') {
      // fin d'une substitution : la `}` appartient au gabarit, qui reprend
      stack.pop();
      const reason = template(start, i + 1, at);
      if (reason) return fail(at, reason);
    } else if (c === '/') {
      const regex = slashOpensRegex(prev);
      if (typeof regex === 'string') return fail(at, regex);
      if (regex) {
        i += 1;
        let inClass = false;
        for (;;) {
          if (i >= n || isNewline(text[i])) return fail(at, 'expression régulière non fermée');
          const d = text[i];
          if (d === '\\') {
            i += 1;
            if (i >= n || isNewline(text[i])) return fail(at, 'expression régulière non fermée');
            i += 1;
          } else if (inClass) {
            if (d === ']') inClass = false;
            i += 1;
          } else if (d === '[') {
            inClass = true;
            i += 1;
          } else if (d === '/') {
            i += 1;
            break;
          } else i += 1;
        }
        while (i < n && isIdPart(text[i])) i += 1;   // drapeaux
        push('regex', start, i, at);
        prev = { kind: 'regex', text: '/' };
      } else {
        i += 1;
        push('punct', start, i, at);
        prev = { kind: 'punct', text: '/' };
      }
    } else if (isDigit(c) || (c === '.' && isDigit(text[i + 1] || ''))) {
      const hex = c === '0' && (text[i + 1] === 'x' || text[i + 1] === 'X');
      i += 1;
      for (;;) {
        const d = text[i];
        if (d === undefined || !(isLetter(d) || isDigit(d) || d === '_' || d === '.')) break;
        i += !hex && (d === 'e' || d === 'E') && (text[i + 1] === '+' || text[i + 1] === '-') ? 2 : 1;
      }
      push('number', start, i, at);
      prev = { kind: 'number', text: '0' };
    } else if (isIdStart(c) || c === '\\' || (c === '#' && (isIdStart(text[i + 1] || '') || text[i + 1] === '\\'))) {
      if (c === '#') i += 1;   // nom privé
      for (;;) {
        const d = text[i];
        if (d !== undefined && isIdPart(d)) {
          i += 1;
          continue;
        }
        if (d !== '\\') break;
        // échappement \uXXXX ou \u{X…} dans un nom ; toute autre barre hors chaîne est refusée
        if (text[i + 1] !== 'u') return fail(at, '« \\ » hors chaîne');
        if (text[i + 2] === '{') {
          let j = i + 3;
          while (j < n && j < i + 12 && isHex(text[j])) j += 1;
          if (text[j] !== '}' || j === i + 3) return fail(at, '« \\ » hors chaîne');
          i = j + 1;
        } else {
          for (let k = 2; k < 6; k += 1) if (!isHex(text[i + k] || '')) return fail(at, '« \\ » hors chaîne');
          i += 6;
        }
      }
      const word = text.slice(start, i);
      const property = prev !== null && prev.kind === 'punct' && prev.text === '.';
      push('name', start, i, at);
      prev = { kind: 'name', text: word, property };
    } else if (c >= '\x80') {
      return fail(at, 'caractère non ASCII hors chaîne ou commentaire');
    } else if (c === '(' || c === '[' || c === '{') {
      if (stack.length >= MAX_DEPTH) return fail(at, 'imbrication trop profonde');
      const keyword = c === '(' && prev !== null && prev.kind === 'name' && !prev.property && PAREN_KEYWORDS.has(prev.text);
      stack.push({ open: c, keyword });
      i += 1;
      push('punct', start, i, at);
      prev = { kind: 'punct', text: c };
    } else if (c === ')' || c === ']' || c === '}') {
      const top = stack.pop();
      if (!top || top.open !== CLOSERS[c]) return fail(at, 'parenthèses mal appariées');
      i += 1;
      push('punct', start, i, at);
      prev = { kind: 'punct', text: c, keyword: top.keyword };
    } else if ((c === '+' || c === '-') && text[i + 1] === c) {
      i += 2;
      push('punct', start, i, at);
      // préfixe là où une expression commence (là où `/` ouvrirait une expression régulière), ou indécidable
      prev = { kind: 'punct', text: c + c, prefix: slashOpensRegex(prev) !== false };
    } else {
      i += 1;
      push('punct', start, i, at);
      prev = { kind: 'punct', text: c };
    }
  }
  if (stack.length) return fail(line, stack.some((s) => s.open === '${') ? 'gabarit non fermé' : 'parenthèses mal appariées');
  return events;
}

// CSS -------------------------------------------------------------------------------------------------------------------

const CSS_BLANK = (c) => c === ' ' || c === '\t';
const isCssNameChar = (c) => c !== undefined && (isLetter(c) || isDigit(c) || c === '_' || c === '-' || c >= '\x80');

/** `url(` (sans la casse) en `i`, précédé d'un caractère qui n'est pas de nom ? */
function urlAt(text, i) {
  const c = text[i];
  if (c !== 'u' && c !== 'U') return false;
  if (text.slice(i, i + 4).toLowerCase() !== 'url(') return false;
  return i === 0 || !isCssNameChar(text[i - 1]);
}

/**
 * Évènements CSS dans l'ordre : { kind, start, end, line } ; kind : 'bom' | 'ws' | 'eol' | 'comment' (`keep`, `lines`)
 * | 'string' | 'url' | 'other' (suite d'octets sans rien de particulier) ; ou { kind: 'error', line, reason } en dernier.
 * @param {string} text  texte lu en latin1
 */
function scanCss(text) {
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
  // un octet qui commence quelque chose de particulier (fin d'une suite `other`)
  const special = (j) => {
    const d = text[j];
    return CSS_BLANK(d) || isCssNewline(d) || d === '"' || d === '\'' || d === '\\' || (d === '/' && text[j + 1] === '*') || urlAt(text, j);
  };
  while (i < n) {
    const c = text[i];
    const start = i;
    const at = line;
    if (CSS_BLANK(c)) {
      while (i < n && CSS_BLANK(text[i])) i += 1;
      push('ws', start, i, at);
    } else if (isCssNewline(c)) {
      i += newlineLength(text, i);
      line += 1;
      push('eol', start, i, at);
    } else if (c === '/' && text[i + 1] === '*') {
      const close = text.indexOf('*/', i + 2);
      if (close < 0) return fail(at, 'commentaire non fermé');
      i = close + 2;
      const lines = newlinesOf(text, start, i, isCssNewline).length;
      line += lines;
      const mark = text[start + 2];
      push('comment', start, i, at, { keep: mark === '!' || mark === '#', lines });
    } else if (c === '"' || c === '\'') {
      i += 1;
      for (;;) {
        if (i >= n || isCssNewline(text[i])) return fail(at, 'chaîne non fermée');
        const d = text[i];
        if (d === c) {
          i += 1;
          break;
        }
        if (d !== '\\') {
          i += 1;
          continue;
        }
        i += 1;   // la barre ; puis le caractère échappé (une fin de ligne échappée continue la chaîne)
        if (i >= n) return fail(at, 'chaîne non fermée');
        if (isCssNewline(text[i])) {
          i += newlineLength(text, i);
          line += 1;
        } else i += 1;
      }
      push('string', start, i, at);
    } else if (c === '\\') {
      // échappement hors chaîne : le caractère suivant est pris avec la barre (`.a\/\*b` n'ouvre aucun commentaire)
      if (i + 1 >= n) return fail(at, 'échappement en fin de fichier');
      if (isCssNewline(text[i + 1])) return fail(at, 'échappement d\'une fin de ligne');
      i += 2;
      push('other', start, i, at);
    } else if (urlAt(text, i)) {
      let j = i + 4;
      while (j < n && CSS_BLANK(text[j])) j += 1;
      if (text[j] === '"' || text[j] === '\'') {
        // url("…") : une fonction suivie d'une chaîne
        i += 4;
        push('other', start, i, at);
        continue;
      }
      // url() non cité : une seule adresse jusqu'à `)`, aucun commentaire cherché dedans
      for (;;) {
        if (j >= n) return fail(at, 'url() non cité mal formé');
        const d = text[j];
        if (d === ')') {
          j += 1;
          break;
        }
        if (d === '"' || d === '\'' || d === '(' || isCssNewline(d)) return fail(at, 'url() non cité mal formé');
        if (d === '\\') {
          if (j + 1 >= n || isCssNewline(text[j + 1])) return fail(at, 'url() non cité mal formé');
          j += 2;
        } else j += 1;
      }
      i = j;
      push('url', start, i, at);
    } else {
      i += 1;
      while (i < n && !special(i)) i += 1;
      push('other', start, i, at);
    }
  }
  return events;
}

// HTML ------------------------------------------------------------------------------------------------------------------

const HTML_BLANK = (c) => c === ' ' || c === '\t' || c === '\f';
// contenus jamais modifiés : texte brut (et script), RCDATA
const RAW_ELEMENTS = new Set(['script', 'style', 'xmp', 'iframe', 'noembed', 'noframes', 'noscript', 'title', 'textarea']);
const PRE_ELEMENTS = new Set(['pre', 'listing']);
// contenu étranger (relecture sécurité S-1) : `<style>`, `<title>`, `<textarea>` n'y sont pas bruts et un commentaire y
// change de sens ; tout commentaire ou élément brut y est refusé (la page est laissée telle quelle)
const FOREIGN_ELEMENTS = new Set(['svg', 'math']);

/**
 * Évènements HTML dans l'ordre : { kind, start, end, line } ; kind : 'bom' | 'text' | 'eol' | 'comment' (`pre`,
 * `body` : après la balise `<body>`, `lines`) | 'decl' | 'tag' | 'raw' ; ou { kind: 'error', line, reason } en dernier.
 * @param {string} text  texte lu en latin1
 */
function scanHtml(text) {
  const events = [];
  const n = text.length;
  let i = 0;
  let line = 1;
  let pre = false;
  let body = false;   // balise `<body>` déjà lue (relecture sécurité S-3)
  let foreign = 0;    // profondeur de `<svg>` et `<math>` ouverts (relecture sécurité S-1)
  let selfClosing = false;   // la dernière balise lue finit par `/>` (posé par tagEnd)
  let lower = null;   // texte en minuscules (même longueur en latin1), calculé au premier élément brut
  let bang = null;    // position du prochain `--!>` (recherche monotone)
  const push = (kind, start, end, at, extra) => events.push({ kind, start, end, line: at, ...extra });
  const fail = (at, reason) => {
    events.push({ kind: 'error', line: at, reason });
    return events;
  };
  if (text.startsWith(BOM)) {
    push('bom', 0, 3, 1);
    i = 3;
  }
  // fin (exclue) d'une balise dont les attributs commencent en `from`, selon les états d'attributs de WHATWG (relecture
  // sécurité S-2) : un guillemet n'ouvre une valeur qu'après un `=` qui suit un nom d'attribut ; -1 si absente.
  // `selfClosing` : la balise finit par `/>` hors d'une valeur sans guillemets
  const tagEnd = (from) => {
    let j = from;
    let state = 'before';   // before | name | afterName | beforeValue | unquoted
    selfClosing = false;
    for (;;) {
      if (j >= n) return -1;
      const d = text[j];
      const blank = HTML_BLANK(d) || isNewline(d);
      if (isNewline(d)) {
        j += newlineLength(text, j);
        line += 1;
      } else j += 1;
      if (state === 'unquoted') {
        if (d === '>') return j;
        if (blank) state = 'before';
      } else if (state === 'beforeValue') {
        if (blank) continue;
        if (d === '>') return j;
        if (d === '"' || d === '\'') {
          const close = text.indexOf(d, j);
          if (close < 0) return -1;
          line += newlinesOf(text, j, close).length;
          j = close + 1;
          state = 'before';
        } else state = 'unquoted';
      } else if (d === '>') {
        return j;
      } else if (d === '/') {
        if (text[j] === '>') {
          selfClosing = true;
          return j + 1;
        }
        state = 'before';
      } else if (blank) {
        if (state === 'name') state = 'afterName';
      } else if (d === '=' && (state === 'name' || state === 'afterName')) {
        state = 'beforeValue';
      } else state = 'name';   // nom d'attribut (un `=`, un guillemet en tête en font partie)
    }
  };
  // début de la balise de fin `</nom` suivie d'un blanc, de `/` ou de `>` (sans la casse), depuis `from` ; -1 si absente
  const closing = (name, from) => {
    const needle = `</${name}`;
    let k = from;
    for (;;) {
      k = lower.indexOf(needle, k);
      if (k < 0) return -1;
      const after = text[k + needle.length];
      if (after === '>' || after === '/' || HTML_BLANK(after) || isNewline(after)) return k;
      k += 1;
    }
  };
  while (i < n) {
    const c = text[i];
    const start = i;
    const at = line;
    if (c === '<' && text.startsWith('!--', i + 1)) {
      const from = i + 4;
      if (text[from] === '>' || (text[from] === '-' && text[from + 1] === '>')) return fail(at, 'commentaire HTML abrupt');
      const close = text.indexOf('-->', from);
      if (close < 0) return fail(at, 'commentaire HTML non fermé');
      if (bang === null || (bang >= 0 && bang < from)) bang = text.indexOf('--!>', from);
      if (bang >= 0 && bang < close) return fail(at, '« --!> » dans un commentaire HTML');
      if (foreign > 0) return fail(at, 'commentaire dans du SVG ou du MathML en ligne');
      i = close + 3;
      const lines = newlinesOf(text, start, i).length;
      line += lines;
      push('comment', start, i, at, { pre, body, lines });
    } else if (c === '<' && text.startsWith('![CDATA[', i + 1)) {
      return fail(at, 'CDATA refusé');
    } else if (c === '<' && (text[i + 1] === '!' || text[i + 1] === '?')) {
      const close = text.indexOf('>', i + 2);
      if (close < 0) return fail(at, 'déclaration non fermée');
      i = close + 1;
      line += newlinesOf(text, start, i).length;
      push('decl', start, i, at);
    } else if (c === '<' && text[i + 1] === '/' && isLetter(text[i + 2] || '')) {
      let j = i + 2;
      while (j < n && (isLetter(text[j]) || isDigit(text[j]) || text[j] === '-' || text[j] === ':')) j += 1;
      const name = text.slice(i + 2, j).toLowerCase();
      const end = tagEnd(j);
      if (end < 0) return fail(at, 'balise non fermée');
      i = end;
      push('tag', start, i, at);
      if (PRE_ELEMENTS.has(name)) pre = false;
      if (FOREIGN_ELEMENTS.has(name) && foreign > 0) foreign -= 1;
    } else if (c === '<' && isLetter(text[i + 1] || '')) {
      let j = i + 1;
      while (j < n && (isLetter(text[j]) || isDigit(text[j]) || text[j] === '-' || text[j] === ':')) j += 1;
      const name = text.slice(i + 1, j).toLowerCase();
      const end = tagEnd(j);
      if (end < 0) return fail(at, 'balise non fermée');
      i = end;
      push('tag', start, i, at);
      if (name === 'plaintext') return fail(at, '<plaintext> refusé');
      if (name === 'body') body = true;
      if (foreign > 0 && (RAW_ELEMENTS.has(name) || PRE_ELEMENTS.has(name))) {
        return fail(at, `élément <${name}> dans du SVG ou du MathML en ligne`);
      }
      if (FOREIGN_ELEMENTS.has(name) && !selfClosing) foreign += 1;
      if (RAW_ELEMENTS.has(name)) {
        if (lower === null) {
          lower = text.toLowerCase();
          if (lower.length !== n) return fail(at, 'texte illisible');
        }
        const close = closing(name, i);
        if (close < 0) return fail(at, `élément <${name}> non fermé`);
        if (name === 'script' && text.slice(i, close).includes('<!--')) return fail(at, '« <!-- » dans un <script>');
        const rawAt = line;
        line += newlinesOf(text, i, close).length;
        push('raw', i, close, rawAt);
        i = close;
      } else if (PRE_ELEMENTS.has(name)) pre = true;
    } else if (isNewline(c)) {
      i += newlineLength(text, i);
      line += 1;
      push('eol', start, i, at);
    } else {
      i += 1;
      while (i < n && text[i] !== '<' && !isNewline(text[i])) i += 1;
      push('text', start, i, at);
    }
  }
  return events;
}

const isHtmlBlank = (text, start, end) => {
  for (let k = start; k < end; k += 1) if (!HTML_BLANK(text[k]) && !isNewline(text[k])) return false;
  return true;
};

/**
 * Pour chaque commentaire HTML : retirable ? (textes voisins blancs, hors `<pre>`, aucun nœud blanc créé ; s'il a une fin
 * de ligne, seulement avant `<body>`).
 */
function removableComments(text, events) {
  // runs[m] : texte entre le balisage m-1 (ou le début) et le balisage m ; le dernier va jusqu'à la fin
  const runs = [{ empty: true, blank: true }];
  const markupOf = new Map();
  events.forEach((e, k) => {
    if (e.kind === 'text' || e.kind === 'eol') {
      const run = runs[runs.length - 1];
      run.empty = false;
      if (run.blank && !isHtmlBlank(text, e.start, e.end)) run.blank = false;
    } else if (e.kind !== 'bom') {
      markupOf.set(k, runs.length - 1);
      runs.push({ empty: true, blank: true });
    }
  });
  const removable = new Set();
  events.forEach((e, k) => {
    if (e.kind !== 'comment' || e.pre) return;
    const m = markupOf.get(k);
    const before = runs[m];
    const after = runs[m + 1];
    if (!before.blank || !after.blank) return;
    if (e.lines && before.empty && after.empty) return;
    // une fin de ligne retirée dans le corps pourrait se voir (élément en `white-space: pre` posé par le CSS) : un
    // commentaire de plusieurs lignes n'est retiré qu'avant `<body>` (relecture sécurité S-3)
    if (e.lines && e.body) return;
    removable.add(k);
  });
  return removable;
}

// Allègement, signature, contrôle -------------------------------------------------------------------------------------

const SCANNERS = { js: scanJs, css: scanCss, html: scanHtml };
const NEWLINE = { js: isNewline, css: isCssNewline, html: isNewline };

function stripJs(text, events) {
  const out = [];
  let blanks = '';
  for (const e of events) {
    const slice = text.slice(e.start, e.end);
    if (e.kind === 'ws') blanks += slice;
    else if (e.kind === 'eol') {
      blanks = '';
      out.push(slice);
    } else if (e.kind === 'comment' && !e.keep) {
      if (!e.long) continue;
      if (e.lines) {
        blanks = '';
        out.push(newlinesOf(text, e.start, e.end).join(''));
      } else if (blanks === '') blanks = ' ';   // `typeof/**/a` → `typeof a`, jamais `typeofa`
    } else {
      out.push(blanks, slice);
      blanks = '';
    }
  }
  return out.join('');
}

function stripCss(text, events) {
  const out = [];
  const n = text.length;
  const first = text.startsWith(BOM) ? 3 : 0;
  const blankAt = (k) => CSS_BLANK(text[k]) || isCssNewline(text[k]);
  let blanks = '';
  for (const e of events) {
    const slice = text.slice(e.start, e.end);
    if (e.kind === 'ws') blanks += slice;
    else if (e.kind === 'eol') {
      blanks = '';
      out.push(slice);
    } else if (e.kind === 'comment' && !e.keep
      && (e.start === first || blankAt(e.start - 1) || e.end === n || blankAt(e.end))) {
      // en CSS un commentaire n'est pas un blanc : retiré seulement s'il touche un blanc (sinon gardé tel quel)
      if (e.lines) {
        blanks = '';
        out.push(newlinesOf(text, e.start, e.end, isCssNewline).join(''));
      }
    } else {
      out.push(blanks, slice);
      blanks = '';
    }
  }
  return out.join('');
}

function stripHtml(text, events) {
  const removable = removableComments(text, events);
  return events.map((e, k) => (removable.has(k) ? newlinesOf(text, e.start, e.end).join('') : text.slice(e.start, e.end))).join('');
}

const STRIPPERS = { js: stripJs, css: stripCss, html: stripHtml };

/** Signature tirée d'évènements déjà lus, et nombre de fins de ligne ; null si le texte ne se lit pas. */
function signatureOf(text, events, kind) {
  const tokens = [];
  const last = events[events.length - 1];
  if (last && last.kind === 'error') return null;
  if (kind === 'html') {
    // balises, déclarations, contenus bruts ; textes fusionnés par-dessus les commentaires ; un texte blanc devient la
    // marque `blanc` (sans ligne : un commentaire retiré allonge le blanc voisin de ses fins de ligne)
    let pending = '';
    let pendingLine = 0;
    const flush = () => {
      if (pending === '') return;
      if (isHtmlBlank(pending, 0, pending.length)) tokens.push([0, 'blanc', '']);
      else tokens.push([pendingLine, 'text', pending]);
      pending = '';
    };
    for (const e of events) {
      if (e.kind === 'comment') continue;
      if (e.kind === 'text' || e.kind === 'eol') {
        if (pending === '') pendingLine = e.line;
        pending += text.slice(e.start, e.end);
        continue;
      }
      flush();
      tokens.push([e.line, e.kind, text.slice(e.start, e.end)]);
    }
    flush();
  } else {
    // [ligne, écart, lexème] ; JavaScript : écart 1 après un blanc, une fin de ligne ou un commentaire ; CSS : 1 après un
    // blanc ou une fin de ligne, 2 après un commentaire seul (un commentaire n'est pas un blanc en CSS), 0 sinon
    let gap = 1;
    for (const e of events) {
      if (e.kind === 'ws' || e.kind === 'eol') {
        gap = 1;
        continue;
      }
      if (e.kind === 'comment' && !e.keep) {
        if (kind === 'js') gap = 1;
        else if (gap === 0) gap = 2;
        continue;
      }
      tokens.push([e.line, gap, text.slice(e.start, e.end)]);
      gap = e.kind === 'bom' ? 1 : 0;   // le BOM est le début du texte (comme pour l'allègement)
    }
  }
  return { tokens, lines: newlinesOf(text, 0, text.length, NEWLINE[kind]).length };
}

/**
 * Signature comparable d'une page : [ligne, écart, lexème] (JS, CSS) ou [ligne, sorte, texte] (HTML) ; null si le texte
 * ne se lit pas.
 */
function signature(text, kind) {
  if (!SCANNERS[kind]) return null;
  const sig = signatureOf(text, SCANNERS[kind](text), kind);
  return sig ? sig.tokens : null;
}

/** Ligne de la première différence entre deux signatures, ou 0. */
function firstDifference(a, b) {
  const size = Math.max(a.tokens.length, b.tokens.length);
  for (let k = 0; k < size; k += 1) {
    const x = a.tokens[k];
    const y = b.tokens[k];
    if (!x || !y || x[0] !== y[0] || x[1] !== y[1] || x[2] !== y[2]) return (x || y)[0] || 1;
  }
  return a.lines === b.lines ? 0 : Math.min(a.lines, b.lines) + 1;
}

function controlWith(text, events, result, kind) {
  const before = signatureOf(text, events, kind);
  const after = before && signatureOf(result, SCANNERS[kind](result), kind);
  const line = after ? firstDifference(before, after) : 1;
  if (!after || line) return { ok: false, line: line || 1, reason: 'contrôle après allègement' };
  return { ok: true };
}

/**
 * Contrôle d'un allègement : même signature, même nombre de fins de ligne. Utilisé par `strip` ; exporté pour les
 * essais (un allègement faussé doit être refusé).
 * @returns {{ ok: true } | { ok: false, line: number, reason: string }}
 */
function control(text, result, kind) {
  if (!SCANNERS[kind]) return { ok: false, line: 0, reason: 'sorte de page inconnue' };
  return controlWith(text, SCANNERS[kind](text), result, kind);
}

/**
 * La page sans ses commentaires (et, en JS et CSS, sans ses blancs de fin de ligne), chaque fin de ligne gardée,
 * contrôlée.
 * @param {string} text  texte lu en latin1
 * @param {'js'|'css'|'html'} kind
 * @returns {{ ok: true, text: string, removed: number } | { ok: false, line: number, reason: string }}
 */
function strip(text, kind) {
  if (!SCANNERS[kind]) return { ok: false, line: 0, reason: 'sorte de page inconnue' };
  const events = SCANNERS[kind](text);
  const last = events[events.length - 1];
  if (last && last.kind === 'error') return { ok: false, line: last.line, reason: last.reason };
  const result = STRIPPERS[kind](text, events);
  const checked = controlWith(text, events, result, kind);
  if (!checked.ok) return checked;
  return { ok: true, text: result, removed: text.length - result.length };
}

module.exports = { scanJs, scanCss, scanHtml, strip, signature, control, MAX_DEPTH, MAX_TEMPLATES };
