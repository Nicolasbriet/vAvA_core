'use strict';
/*
 * tests/livraison/essais-pages.js
 * Rôle : essais de l'allègement des pages livrées (T-160, docs/plan/specs/T-160.md § 12.1 et 12.2), lancés par
 *        scripts/verifier.sh (node, module assert intégré, sans dépendance) : lexeurs JavaScript, CSS et HTML
 *        (chancellerie/lib/webstrip.js), signatures et contrôle, choix des pages d'après les manifestes et allègement d'une
 *        copie (lib/delivery.js), installeur (fetchSource de bout en bout, archive servie en HTTP local), modes de
 *        scripts/livraison.js (sur un dépôt factice), second lecteur (scripts/lib/meme-page.js) et cas difficiles
 *        exécutés avant et après. Notation : entrées et sorties en littéraux de chaîne JavaScript (`\n` = une fin de
 *        ligne, `\\` = une barre oblique inverse dans le fichier). Écrit seulement dans des dossiers temporaires.
 *        « ESSAIS PAGES : OK (n) », code 1 au premier échec.
 * Dépendances : node ≥ 18, git et tar de la machine.
 */

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');
const vm = require('vm');
const { spawnSync, execFileSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..', '..');
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'vava-pages-'));
process.env.CHANCELLERIE_HOME = path.join(TMP, 'chancellerie');   // l'installeur ne lit ni n'écrit rien d'autre

const webstrip = require('../../chancellerie/lib/webstrip');
const delivery = require('../../chancellerie/lib/delivery');
const installer = require('../../chancellerie/lib/installer');
const dl = require('../../chancellerie/lib/download');
const livraison = require('../../scripts/livraison');
const memePage = require('../../scripts/lib/meme-page');

let count = 0;
function fail(name, error) {
  process.stdout.write(`ÉCHEC ${name}\n${error.stack || error.message}\n`);
  fs.rmSync(TMP, { recursive: true, force: true });
  process.exit(1);
}
function essai(name, fn) {
  try {
    fn();
    count += 1;
  } catch (error) {
    fail(name, error);
  }
}
async function essaiAsync(name, fn) {
  try {
    await fn();
    count += 1;
  } catch (error) {
    fail(name, error);
  }
}

// texte UTF-8 → texte d'octets (comme un fichier lu en latin1), et retour
const bytes = (s) => Buffer.from(s, 'utf8').toString('latin1');
const utf8 = (s) => Buffer.from(s, 'latin1').toString('utf8');
const newlines = (s) => (s.match(/\r\n|\n\r|\n|\r/g) || []).length;
function lean(input, kind) {
  const result = webstrip.strip(bytes(input), kind);
  if (!result.ok) return result;
  return { ...result, text: utf8(result.text) };
}
function cases(kind, list) {
  for (const [n, input, expected] of list) {
    essai(`${kind}, cas ${n} : ${JSON.stringify(input).slice(0, 90)}`, () => {
      const result = lean(input, kind);
      assert.strictEqual(result.ok, true, `${result.reason} (ligne ${result.line})`);
      assert.strictEqual(result.text, expected === null ? input : expected);
      assert.strictEqual(newlines(result.text), newlines(input), 'nombre de fins de ligne');
      // idempotence
      assert.strictEqual(lean(result.text, kind).text, result.text, 'allégé deux fois');
    });
  }
}
function refusals(kind, list) {
  for (const [input, line, reason] of list) {
    essai(`${kind}, refus : ${JSON.stringify(input).slice(0, 90)}`, () => {
      const result = lean(input, kind);
      assert.strictEqual(result.ok, false, 'refus attendu');
      assert.strictEqual(result.reason, reason);
      assert.strictEqual(result.line, line);
    });
  }
}

// JavaScript (§ 12.1) -------------------------------------------------------------------------------------------------

const BOM = '\uFEFF';
cases('js', [
  [1, 'var a = 1; // note\n', 'var a = 1;\n'],
  [2, '/*\n * en-tête\n */\nvar a;\n', '\n\n\nvar a;\n'],
  [3, 'var s = "a // b"; // c\n', 'var s = "a // b";\n'],
  [4, 'var s = \'/* pas */\'; /* c */\n', 'var s = \'/* pas */\';\n'],
  [5, 'fetch(`https://${r}/${n}`); // c\n', 'fetch(`https://${r}/${n}`);\n'],
  [6, 't = `${a} / ${b}` / 2; // c\n', 't = `${a} / ${b}` / 2;\n'],
  [7, 't = `a${ {x: `b${c /* in */}`}.x }d`;\n', 't = `a${ {x: `b${c }`}.x }d`;\n'],
  [8, 't = `ligne   \n// pas un commentaire\n`; // c\n', 't = `ligne   \n// pas un commentaire\n`;\n'],
  [9, 'r = /\\/\\/ x/g; // c\n', 'r = /\\/\\/ x/g;\n'],
  [10, 'r = /[/*]/.test(x); // c\n', 'r = /[/*]/.test(x);\n'],
  [11, 'q = a / b / c; // c\n', 'q = a / b / c;\n'],
  [11, 'q = (a) / 2; // c\n', 'q = (a) / 2;\n'],
  [11, 'q = a[0] / 2; // c\n', 'q = a[0] / 2;\n'],
  [11, 'q = 3 / 2; // c\n', 'q = 3 / 2;\n'],
  [12, 'if (x) /re/.test(y); // c\n', 'if (x) /re/.test(y);\n'],
  [12, 'while (x) /re/g.exec(y); // c\n', 'while (x) /re/g.exec(y);\n'],
  [12, 'if (x) /a\\/\\/b/.test(y); // c\n', 'if (x) /a\\/\\/b/.test(y);\n'],
  [13, 'x = a ? /b/ : /c/; // c\n', 'x = a ? /b/ : /c/;\n'],
  [13, 'x = [/a/, /b/]; // c\n', 'x = [/a/, /b/];\n'],
  [13, 'f = () => /a/; // c\n', 'f = () => /a/;\n'],
  [13, 'function g(s) { return /a\\//.test(s); } // c\n', 'function g(s) { return /a\\//.test(s); }\n'],
  [14, 'x = a++ / 2; // c\n', 'x = a++ / 2;\n'],
  [15, 'x = typeof/**/a;\n', 'x = typeof a;\n'],
  [16, 'x = 1 /* a */ + 2;\n', 'x = 1  + 2;\n'],
  [17, 'a = 1; /* x\n y */ b = 2;\n', 'a = 1;\n b = 2;\n'],
  [18, '/*! licence */\n//# sourceURL=a.js\n//@ x\n/*# y */\n', null],
  [19, 'a = 1; // c\r\nb = 2;\r\n/* x\r\n y */\r\n', 'a = 1;\r\nb = 2;\r\n\r\n\r\n'],
  [20, 'a = 1;   \t\n', 'a = 1;\n'],
  [21, 's = "a\\\n// dans la chaîne";\n', null],
  [22, '\t\tf(); // c\n', '\t\tf();\n'],
  [23, 'x = 1; //', 'x = 1;'],
  [24, 's = \'\\\\\'; // c\n', 's = \'\\\\\';\n'],
  [25, 'r = /a/g// c\n', 'r = /a/g\n'],
  [25, 'x = 1//c\n', 'x = 1\n'],
  [25, 'x = .5/* c */\n', 'x = .5\n'],
  [25, 'x = 0x1F// c\n', 'x = 0x1F\n'],
  [25, 'x = 1e-5// c\n', 'x = 1e-5\n'],
  [26, 'class A { #x = 1; f() { return this.#x / 2; } } // c\n', 'class A { #x = 1; f() { return this.#x / 2; } }\n'],
  [27, 'while (i-- > 0) {} // c\n', 'while (i-- > 0) {}\n'],
  [28, 's = \'é\'; // c\n', 's = \'é\';\n'],
  [29, `${BOM}// c\nx = 1;\n`, `${BOM}\nx = 1;\n`],
  [30, '', ''],
  [30, '// a\n// b\n// c', '\n\n'],
  // compléments : fin de ligne échappée en CRLF dans une chaîne et un gabarit, nom d'une propriété qui serait un mot-clé
  [31, 's = "a\\\r\n// c"; // c\r\n', 's = "a\\\r\n// c";\r\n'],
  [31, 't = `a\\\r\n${b}`; // c\n', 't = `a\\\r\n${b}`;\n'],
  [31, 'x = o.return / 2; // c\n', 'x = o.return / 2;\n'],
  [31, 'x = a.if(1) / 2; // c\n', 'x = a.if(1) / 2;\n'],
  // relecture sécurité S-4 : expression régulière après `extends` ; `++`/`--` suffixe suivi d'une division
  [32, 'class A extends /a*/ {} /* b */ ;\n', 'class A extends /a*/ {}  ;\n'],
  [32, 'class A extends /[/*]/.constructor {} /*/ ;/*]*/\n', 'class A extends /[/*]/.constructor {}\n'],
  [32, 'x = a-- / 2; y = (b)++ / 2; // c\n', 'x = a-- / 2; y = (b)++ / 2;\n'],
]);

const DEEP = `${'('.repeat(1025)}`;
const nestedTemplates = (k) => `x = ${'`${'.repeat(k)}1${'}`'.repeat(k)};\n`;
refusals('js', [
  ['x = {} / 2;\n', 1, '« / » après « } » : division ou expression régulière indécidable'],
  ['function f() {} /a/.test(s);\n', 1, '« / » après « } » : division ou expression régulière indécidable'],
  ['a;\nb;\nx = {} / 2;\n', 3, '« / » après « } » : division ou expression régulière indécidable'],
  ['x = await /a/;\n', 1, '« / » après « await » : indécidable'],
  ['x = ++/a/.lastIndex; // c\n', 1, '« / » après « ++ » préfixe : indécidable'],
  ['x = 1;\n--/[/*]/.lastIndex; y = [/*/]*/];\n', 2, '« / » après « -- » préfixe : indécidable'],
  ['for (x of /a/g.exec(s)) {}\n', 1, '« / » après « of » : indécidable'],
  ['#!/usr/bin/env node\nx;\n', 1, 'première ligne « #! » refusée'],
  [`${BOM}#!/usr/bin/env node\nx;\n`, 1, 'première ligne « #! » refusée'],
  ['x = a <!-- b\n', 1, '« <!-- » hors chaîne (commentaire HTML de JavaScript)'],
  ['x = y-->0;\n', 1, '« --> » hors chaîne'],
  ['var é = 1;\n', 1, 'caractère non ASCII hors chaîne ou commentaire'],
  ['x = 1;\u00A0y = 2;\n', 1, 'caractère non ASCII hors chaîne ou commentaire'],
  ['x;\ns = "a\u2028b";\n', 2, 'séparateur de ligne Unicode'],
  ['s = "a\u2029b";\n', 1, 'séparateur de ligne Unicode'],
  ['/* x', 1, 'commentaire non fermé'],
  ['s = \'abc', 1, 'chaîne non fermée'],
  ['s = `abc', 1, 'gabarit non fermé'],
  ['s = `a${b', 1, 'gabarit non fermé'],
  ['r = /abc\n', 1, 'expression régulière non fermée'],
  ['r = /a[/]\n', 1, 'expression régulière non fermée'],
  ['s = "a\nb";', 1, 'chaîne non fermée'],
  [')', 1, 'parenthèses mal appariées'],
  ['(]', 1, 'parenthèses mal appariées'],
  ['f(\n', 2, 'parenthèses mal appariées'],
  ['x = a\\b;\n', 1, '« \\ » hors chaîne'],
  [DEEP, 1, 'imbrication trop profonde'],
  [nestedTemplates(65), 1, 'imbrication trop profonde'],
]);

essai('js : 1 024 parenthèses et 64 gabarits imbriqués acceptés (bornes exactes)', () => {
  assert.strictEqual(webstrip.MAX_DEPTH, 1024);
  assert.strictEqual(webstrip.MAX_TEMPLATES, 64);
  assert.strictEqual(lean(`x = ${'('.repeat(1024)}1${')'.repeat(1024)}; // c\n`, 'js').ok, true);
  assert.strictEqual(lean(nestedTemplates(64), 'js').ok, true);
});

essai('js : nom échappé, nombre à exposant, gabarit qui contient `}`', () => {
  assert.strictEqual(lean('var \\u0061b = 1; // c\n', 'js').text, 'var \\u0061b = 1;\n');
  assert.strictEqual(lean('x = 0x1e+5 / 2; // c\n', 'js').text, 'x = 0x1e+5 / 2;\n');
  assert.strictEqual(lean('x = `}{` / 2; // c\n', 'js').text, 'x = `}{` / 2;\n');
});

// CSS (§ 12.1) --------------------------------------------------------------------------------------------------------

cases('css', [
  [1, 'a { color: red; } /* c */\n', 'a { color: red; }\n'],
  [2, '/*\n * en-tête\n */\na {}\n', '\n\n\na {}\n'],
  [3, 'a { content: "/* pas */"; } /* c */\n', 'a { content: "/* pas */"; }\n'],
  [4, 'a { background: url(nui://vava_ui/web/img/x.png); } /* c */\n', 'a { background: url(nui://vava_ui/web/img/x.png); }\n'],
  [5, 'a { background: url(a/*b*/c.png); }\n', null],
  [5, 'a { background: url(x/*y.png); } /* c */\n', 'a { background: url(x/*y.png); }\n'],
  [6, 'div/**/p {}\n', null],
  [6, 'a/*\nx\n*/b {}\n', null],
  [7, 'div /**/p {}\n', 'div p {}\n'],
  [7, 'div/**/ p {}\n', 'div p {}\n'],
  [8, 'a { margin: 1px/* x */ 2px; }\n', 'a { margin: 1px 2px; }\n'],
  [9, '.a\\/\\*b {}\n', null],
  [10, '/*! garde */\n/*# sourceMappingURL=a.map */\n', null],
  [11, 'a {}   \n', 'a {}\n'],
  [11, 'a { content: "x  \\\n y"; }\n', null],
  [12, '<!-- a {} -->\n', null],
  [13, 'a { color: red; } /* c */\r\n', 'a { color: red; }\r\n'],
  [14, '@charset "UTF-8";\n/* c */\n', '@charset "UTF-8";\n\n'],
  [15, 'a { --x: /* c */ 1px; }\n', 'a { --x:  1px; }\n'],
  [16, 'a /* x\n y */ b {}\n', 'a\n b {}\n'],
  // compléments : url() cité (une fonction et une chaîne), commentaire en fin de fichier sans fin de ligne, \f
  [17, 'a { b: url( "x/*y*/.png" ); } /* c */\n', 'a { b: url( "x/*y*/.png" ); }\n'],
  [17, 'a {}/* c */', 'a {}'],
  [17, 'a {}\f/* c */\fb {}\n', 'a {}\f\fb {}\n'],
  [17, `${BOM}/* c */a {}\n`, `${BOM}a {}\n`],
]);

refusals('css', [
  ['/* x', 1, 'commentaire non fermé'],
  ['a { content: "abc\n"; }', 1, 'chaîne non fermée'],
  ['a { b: url(a b\nc); }', 1, 'url() non cité mal formé'],
  ['a { b: url(a"b); }', 1, 'url() non cité mal formé'],
  ['a {}\na { b: url(a(b)); }', 2, 'url() non cité mal formé'],
  ['a\\\nb {}', 1, 'échappement d\'une fin de ligne'],
  ['a\\', 1, 'échappement en fin de fichier'],
]);

// HTML (§ 12.1) -------------------------------------------------------------------------------------------------------

const HORS_JEU_SCRIPT = '<script>typeof GetParentResourceName === \'function\' || document.write(\'<script src="../../vava_ui/web/dev/horsjeu.js"><\\/script><script src="dev/devmock.js"><\\/script>\');</script>\n';
cases('html', [
  [1, '<!doctype html>\n<!-- c -->\n<html>', '<!doctype html>\n\n<html>'],
  [2, '<head>\n  <!--\n  en-tête\n  -->\n  <link rel="stylesheet" href="a.css">\n', '<head>\n  \n\n\n  <link rel="stylesheet" href="a.css">\n'],
  [3, '<p>a<!-- c -->b</p>', null],
  [4, '<div><!-- c --></div>', '<div></div>'],
  [5, '<div><!--\nc\n--></div>', null],
  [6, '<div class="a<!--b-->"></div>', null],
  [6, '<a title=\'x>y<!-- z -->\'></a>', null],
  [6, '<a title="x>\n<!-- z -->\n<b>"></a>', null],
  [7, '<script>x = \'<script src="a"><\\/script>\';</script>\n<!-- c -->\n', '<script>x = \'<script src="a"><\\/script>\';</script>\n\n'],
  [8, '<style>/* c */ a {}</style>', null],
  [8, '<STYLE>/* c */</Style >', null],
  [9, '<textarea><!-- pas un commentaire --></textarea>', null],
  [9, '<title>a <!-- b --></title>', null],
  [10, '<pre>\n<!-- c -->\n</pre>', null],
  [11, '<!-- a -- b -->\n<p></p>', '\n<p></p>'],
  [12, '<ul>\r\n  <!-- c\r\n  -->\r\n</ul>', '<ul>\r\n  \r\n\r\n</ul>'],
  // SVG en ligne : aucun commentaire dedans (relecture sécurité S-1) ; après sa fermeture, ou après `<svg/>`, retiré
  [13, '<svg>\n  <path d="M5 .8"/>\n</svg>\n<!-- c -->\n', '<svg>\n  <path d="M5 .8"/>\n</svg>\n\n'],
  [13, '<svg/>\n<!-- c -->\n<math></math>\n<!-- d -->\n', '<svg/>\n\n<math></math>\n\n'],
  [14, '<!-- a --><!-- b -->', ''],
  [15, '<p>\n  <!-- c -->\n  texte</p>', null],
  [16, `  <!-- hors jeu seulement : … -->\n  ${HORS_JEU_SCRIPT}`, `  \n  ${HORS_JEU_SCRIPT}`],
  // compléments : `<pre>` refermé (les commentaires suivants redeviennent retirables), commentaire avant le doctype
  [17, '<pre><!-- a --></pre>\n<!-- b -->\n', '<pre><!-- a --></pre>\n\n'],
  [17, '<!--\n en-tête\n-->\n<!doctype html>\n', '\n\n\n<!doctype html>\n'],
  [17, '<div>\n<!--\nc\n--></div>', '<div>\n\n\n</div>'],
  // relecture sécurité S-2 : un guillemet n'ouvre une valeur qu'après un `=` qui suit un nom d'attribut
  [18, '<a ="x>\n<!-- c -->\n<b>"></a>', '<a ="x>\n\n<b>"></a>'],
  [18, '<a x= =">\n<!-- c -->\n<b>"></a>', '<a x= =">\n\n<b>"></a>'],
  [18, '<a x = \'y>\n<!-- c -->\n<b>\'></a>', null],
  // relecture sécurité S-3 : dans le corps, un commentaire de plusieurs lignes reste ; sur une ligne, il part
  [19, '<body>\n<ul>\n  <!-- c\n  -->\n</ul>', null],
  [19, '<head>\n<!--\n c\n-->\n</head>\n<body>\n<!-- c -->\n<p></p>', '<head>\n\n\n\n</head>\n<body>\n\n<p></p>'],
]);

refusals('html', [
  ['<!-->', 1, 'commentaire HTML abrupt'],
  ['<!--->', 1, 'commentaire HTML abrupt'],
  ['<!-- a --!> b -->', 1, '« --!> » dans un commentaire HTML'],
  ['<!-- a', 1, 'commentaire HTML non fermé'],
  ['<p>\n<![CDATA[x]]>', 2, 'CDATA refusé'],
  ['<plaintext>', 1, '<plaintext> refusé'],
  ['<script>x', 1, 'élément <script> non fermé'],
  ['<script><!-- x --></script>', 1, '« <!-- » dans un <script>'],
  ['<div title="a', 1, 'balise non fermée'],
  // relecture sécurité S-1 : SVG et MathML en ligne (cas du relecteur : un `<style>` de SVG n'est pas brut, son `<!--`
  // ouvrirait un commentaire que le retrait d'un autre laisserait sans fin)
  ['<svg><style>a { x: "<!--" }</style></svg>\n<!-- c -->\n<p>visible</p>', 1, 'élément <style> dans du SVG ou du MathML en ligne'],
  ['<p></p>\n<svg>\n  <!-- c -->\n</svg>', 3, 'commentaire dans du SVG ou du MathML en ligne'],
  ['<svg><svg></svg>\n<!-- c -->\n</svg>', 2, 'commentaire dans du SVG ou du MathML en ligne'],
  ['<math><title>x</title></math>', 1, 'élément <title> dans du SVG ou du MathML en ligne'],
  ['<svg><pre></pre></svg>', 1, 'élément <pre> dans du SVG ou du MathML en ligne'],
]);

essai('html : recherche de `--!>` monotone (temps linéaire sur 20 000 commentaires)', () => {
  const text = `${'<!-- a -->\n'.repeat(20000)}<!-- z --!> -->`;
  const started = Date.now();
  const result = webstrip.strip(text, 'html');
  assert.ok(Date.now() - started < 1000, `${Date.now() - started} ms`);
  assert.deepStrictEqual([result.ok, result.reason, result.line], [false, '« --!> » dans un commentaire HTML', 20001]);
});

// Signatures et contrôle ----------------------------------------------------------------------------------------------

essai('signature : lexèmes collés, lignes, commentaire CSS qui n\'est pas un blanc, nœud HTML blanc', () => {
  assert.notDeepStrictEqual(webstrip.signature('typeof a', 'js'), webstrip.signature('typeofa', 'js'));
  assert.notDeepStrictEqual(webstrip.signature('a\nb', 'js'), webstrip.signature('a b', 'js'));
  assert.deepStrictEqual(webstrip.signature('x = 1 // c', 'js'), webstrip.signature('x = 1', 'js'));
  assert.notDeepStrictEqual(webstrip.signature('div p{}', 'css'), webstrip.signature('div/**/p{}', 'css'));
  assert.notDeepStrictEqual(webstrip.signature('divp{}', 'css'), webstrip.signature('div/**/p{}', 'css'));
  assert.notDeepStrictEqual(webstrip.signature('<div></div>', 'html'), webstrip.signature('<div>\n</div>', 'html'));
  assert.deepStrictEqual(webstrip.signature('<p> </p>', 'html'), webstrip.signature('<p> <!-- c --> </p>', 'html'));
  assert.strictEqual(webstrip.signature('s = "abc', 'js'), null);
  assert.strictEqual(webstrip.signature('x', 'svg'), null);
});

essai('contrôle : un allègement faussé est refusé, de chaque sorte', () => {
  const bad = [
    ['js', 'x = typeof/**/a;\n', 'x = typeofa;\n'],
    ['js', 'a;\n// c\nb;\n', 'a;\nb;\n'],
    ['js', 's = "a // b";\n', 's = "a ";\n'],
    ['css', 'div/**/p {}\n', 'divp {}\n'],
    ['css', 'a {}\n/* c */\nb {}\n', 'a {}\nb {}\n\n'],
    ['html', '<div><!-- c --></div>', '<div> </div>'],
    ['html', '<p>\n<!-- c -->\n</p>', '<p>\n</p>'],
    ['html', '<p>\n<!--\nc\n-->\n</p>', '<p>\n\n\n</p>\n'],
  ];
  for (const [kind, original, faulty] of bad) {
    const result = webstrip.control(original, faulty, kind);
    assert.strictEqual(result.ok, false, `${kind} : ${JSON.stringify(faulty)}`);
    assert.strictEqual(result.reason, 'contrôle après allègement');
  }
  assert.strictEqual(webstrip.control('x = typeof/**/a;\n', 'x = typeof a;\n', 'js').ok, true);
  assert.strictEqual(webstrip.control('div/**/ p {}\n', 'div p {}\n', 'css').ok, true);
  assert.strictEqual(webstrip.control('<div><!-- c --></div>', '<div></div>', 'html').ok, true);
});

// Choix des pages (servedPages) ---------------------------------------------------------------------------------------

function tree(dir, files) {
  for (const [relative, content] of Object.entries(files)) {
    const file = path.join(dir, relative);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, content);
  }
  return dir;
}
const listOf = (served) => served.files.map((f) => `${f.council ? '@' : ''}${f.path}:${f.kind}:${f.state}`);
const JS = '// en-tête\nvar a = 1; // fin\n';
const JS_LEAN = '\nvar a = 1;\n';
const CSS = '/* en-tête */\na { color: red; } /* fin */\n';
const CSS_LEAN = '\na { color: red; }\n';
const HTML = '<!doctype html>\n<!-- en-tête -->\n<p>a</p>\n';
const HTML_LEAN = '<!doctype html>\n\n<p>a</p>\n';
const LUA = '-- commentaire\nlocal x = 1 -- fin\nreturn x\n';

const pagesDir = tree(path.join(TMP, 'res', 'pages'), {
  'fxmanifest.lua': [
    '-- en-tête',
    "ui_page 'web/index.html'",
    "files { 'web/index.html', 'web/css/*.css', 'web/js/*.js', 'web/img/*.svg', 'web/fonts/*.woff2' }",
    "file 'web/a.HTM'",
    "client_script 'client/x.js'",
    "server_script 'server/y.js'",
    "vava_conseil_web { 'web/css/a.css', 'web/js/b.js' }",
    "vava_conseil_lua 'client/z.lua'",
    "-- 'web/z/z.js'",
    '',
  ].join('\n'),
  'web/index.html': HTML, 'web/css/a.css': CSS, 'web/css/b.MIN.css': CSS, 'web/js/b.js': JS, 'web/js/config.js': JS,
  'web/js/c.min.js': JS, 'web/img/i.svg': '<svg><!-- c --></svg>\n', 'web/fonts/f.woff2': 'x', 'web/a.HTM': HTML,
  'client/x.js': JS, 'server/y.js': JS, 'client/z.lua': LUA, 'web/dev/x.js': JS, 'web/z/z.js': JS,
});

essai('pages : ui_page, files à jokers, file, client_script, server_script, vava_conseil_web, commentaire', () => {
  const served = delivery.servedPages(pagesDir);
  assert.strictEqual(served.ok, true, served.reason);
  assert.deepStrictEqual(listOf(served), [
    'web/index.html:html:lean', 'web/css/a.css:css:lean', 'web/css/b.MIN.css:css:kept-min', 'web/js/b.js:js:lean',
    'web/js/c.min.js:js:kept-min', 'web/js/config.js:js:kept-config', 'web/a.HTM:html:lean', 'client/x.js:js:kept-script',
    '@web/css/a.css:css:lean', '@web/js/b.js:js:lean',
  ]);
});

essai('pages : loadscreen, réglage sans la casse, `.js` à la fois en files et en client_script (allégé)', () => {
  const dir = tree(path.join(TMP, 'res', 'pages2'), {
    'fxmanifest.lua': "loadscreen 'web/index.html'\nclient_script 'web/js/b.js'\nfiles { 'web/js/b.js', 'web/js/Config.JS' }\n",
    'web/index.html': HTML, 'web/js/b.js': JS, 'web/js/Config.JS': JS,
  });
  assert.deepStrictEqual(listOf(delivery.servedPages(dir)), ['web/index.html:html:lean', 'web/js/b.js:js:lean', 'web/js/Config.JS:js:kept-config']);
  assert.strictEqual(delivery.pageKind('web/A.Htm'), 'html');
  assert.strictEqual(delivery.pageKind('web/a.svg'), null);
  assert.deepStrictEqual(delivery.PAGE_SETTINGS, ['config.js']);
  assert.deepStrictEqual(delivery.PAGE_DIRECTIVES, ['files', 'file', 'ui_page', 'loadscreen', 'vava_conseil_web']);
});

essai('pages : forme illisible → ressource refusée ; servedLua inchangée (jeu d\'essai de T-154)', () => {
  const dir = tree(path.join(TMP, 'res', 'illisible'), { 'fxmanifest.lua': 'files { nom }\n', 'web/a.js': JS });
  const served = delivery.servedPages(dir);
  assert.strictEqual(served.ok, false);
  assert.match(served.reason, /forme illisible/);
  // ressource « conseil » de tests/livraison/essais.js : même résultat qu'avant T-160
  const council = tree(path.join(TMP, 'res', 'conseil'), {
    'fxmanifest.lua': "shared_scripts { 'shared/p.lua' }\nserver_scripts { 'config_conseil.lua' }\nvava_conseil_lua { 'config_conseil.lua', 'shared/p.lua', 'client/q.lua' }\nvava_conseil_web { 'web/js/a.js', 'web/css/b.css' }\nfiles { 'web/x.lua' }\n",
    'shared/p.lua': LUA, 'config_conseil.lua': LUA, 'client/q.lua': LUA, 'web/js/a.js': JS, 'web/css/b.css': CSS, 'web/x.lua': LUA,
  });
  assert.deepStrictEqual(delivery.servedLua(council).files.map((f) => `${f.council ? '@' : ''}${f.path}:${f.state}`), [
    'fxmanifest.lua:lean', 'shared/p.lua:lean', '@config_conseil.lua:kept-config', '@shared/p.lua:lean', '@client/q.lua:lean',
    'web/x.lua:kept-files',
  ]);
});

// Allègement (leanResources, leanPageText, leanPage) ------------------------------------------------------------------

function twin(name) {
  return tree(path.join(TMP, 'res', name), {
    'fxmanifest.lua': "-- manifeste\nui_page 'web/index.html'\nfiles { 'web/index.html', 'web/js/*.js', 'web/css/*.css' }\n"
      + "client_script 'client/a.lua'\nvava_conseil_web { 'web/js/b.js' }\n",
    'client/a.lua': LUA, 'web/index.html': HTML, 'web/js/b.js': JS, 'web/js/config.js': JS, 'web/css/a.css': CSS,
  });
}
const read = (dir, relative) => fs.readFileSync(path.join(dir, relative), 'utf8');

essai('allègement : { lua: false, web: true } — pages allégées (une fois, Conseil compris), Lua intact', () => {
  const dir = twin('web-seul');
  const summary = delivery.leanResources([{ name: 'r', dir }], { lua: false, web: true });
  assert.strictEqual(summary.files, 0);
  assert.strictEqual(summary.pages.files, 3);
  assert.deepStrictEqual(summary.pages.refused, []);
  assert.strictEqual(read(dir, 'client/a.lua'), LUA);
  assert.ok(read(dir, 'fxmanifest.lua').startsWith('-- manifeste'));
  assert.strictEqual(read(dir, 'web/js/b.js'), JS_LEAN);
  assert.strictEqual(read(dir, 'web/css/a.css'), CSS_LEAN);
  assert.strictEqual(read(dir, 'web/index.html'), HTML_LEAN);
  assert.strictEqual(read(dir, 'web/js/config.js'), JS);
  const size = Buffer.byteLength;
  assert.strictEqual(summary.pages.before - summary.pages.after,
    (size(JS) - size(JS_LEAN)) + (size(CSS) - size(CSS_LEAN)) + (size(HTML) - size(HTML_LEAN)));
});

essai('allègement : { lua: true, web: false } — pages intactes, résumé du Lua identique à celui de T-154', () => {
  const a = twin('lua-seul');
  const b = twin('lua-t154');
  const summary = delivery.leanResources([{ name: 'r', dir: a }], { lua: true, web: false });
  const reference = delivery.leanResources([{ name: 'r', dir: b }]);
  const luaOnly = (s) => ({ resources: s.resources, files: s.files, before: s.before, after: s.after, refused: s.refused, skipped: s.skipped });
  assert.deepStrictEqual(luaOnly(summary), luaOnly(reference));
  assert.deepStrictEqual(summary.pages, { files: 0, before: 0, after: 0, refused: [] });
  assert.deepStrictEqual(reference.pages, { files: 0, before: 0, after: 0, refused: [] });   // options absentes : le Lua seul (T-154)
  assert.strictEqual(read(a, 'web/js/b.js'), JS);
  assert.strictEqual(read(a, 'client/a.lua'), '\nlocal x = 1\nreturn x\n');
  // les deux ensemble
  const c = twin('les-deux');
  const both = delivery.leanResources([{ name: 'r', dir: c }], {});
  assert.deepStrictEqual([both.files, both.pages.files], [2, 3]);
});

essai('allègement : page refusée laissée telle quelle, original non compilable, trop gros, lien, illisible', () => {
  const broken = 'x = {} / 2; // c\n';
  const uncompilable = 'x = ;\n// c\n';
  const exactly = `/*${'x'.repeat(delivery.MAX_BYTES - 5)}*/\n`;   // 1 Mio tout juste
  const big = `${exactly}\n`;                                         // 1 Mio + 1 octet
  const dir = tree(path.join(TMP, 'res', 'refus'), {
    'fxmanifest.lua': "files { 'web/a.js', 'web/b.js', 'web/grand.css', 'lien/c.js', 'web/d.js' }\n",
    'web/a.js': broken, 'web/b.js': uncompilable, 'web/grand.css': big, 'web/d.js': JS,
  });
  const outside = tree(path.join(TMP, 'dehors'), { 'c.js': JS });
  fs.symlinkSync(outside, path.join(dir, 'lien'), 'junction');
  const unreadable = tree(path.join(TMP, 'res', 'skip'), { 'fxmanifest.lua': 'files { nom } -- c\n', 'web/a.js': JS });
  const summary = delivery.leanResources([{ name: 'refus', dir }, { name: 'skip', dir: unreadable }], { lua: true, web: true });
  assert.deepStrictEqual(summary.pages.refused.map((r) => [r.file, r.line, r.reason]), [
    ['refus/web/a.js', 1, '« / » après « } » : division ou expression régulière indécidable'],
    ['refus/web/b.js', 1, 'original non compilable'],
    ['refus/web/grand.css', 0, 'fichier trop gros'],
    ['refus/lien/c.js', 0, 'lien ou chemin hors de la ressource'],
  ]);
  assert.deepStrictEqual(summary.skipped.map((s) => s.resource), ['skip']);
  assert.strictEqual(read(dir, 'web/a.js'), broken);
  assert.strictEqual(read(dir, 'web/b.js'), uncompilable);
  assert.strictEqual(read(dir, 'web/grand.css'), big);
  assert.strictEqual(read(outside, 'c.js'), JS);
  assert.strictEqual(read(dir, 'web/d.js'), JS_LEAN);
  assert.strictEqual(read(unreadable, 'web/a.js'), JS);
  assert.strictEqual(summary.pages.files, 1);
  assert.strictEqual(Buffer.byteLength(big), delivery.MAX_BYTES + 1);
  const exact = delivery.leanPageText(Buffer.from(exactly, 'latin1'), 'css', 'a.css');
  assert.deepStrictEqual([exact.ok, exact.after], [true, 1]);
  const tooBig = delivery.leanPageText(Buffer.from(big, 'latin1'), 'css', 'a.css');
  assert.deepStrictEqual([tooBig.ok, tooBig.reason], [false, 'fichier trop gros']);
});

essai('allègement : contrôle du moteur après allègement (un allégé qui ne compile plus est refusé)', () => {
  // le lexeur et sa signature ne voient pas `}` d'un gabarit fermé trop tôt si l'on fausse la sortie : simulé ici en
  // appelant engineCompiles directement
  assert.strictEqual(delivery.engineCompiles('x = 1;\n', 'a.js').ok, true);
  const bad = delivery.engineCompiles('x = ;\n', 'a.js');
  assert.deepStrictEqual(bad, { ok: false, line: 1 });
  assert.strictEqual(delivery.engineCompiles(`${'('.repeat(100000)}`, 'a.js').ok, false);
});

essai('allègement : engineCompiles n\'exécute rien', () => {
  delete globalThis.__essai;
  assert.strictEqual(delivery.engineCompiles('globalThis.__essai = 1; throw new Error("x");\n', 'a.js').ok, true);
  assert.strictEqual(globalThis.__essai, undefined);
  const result = delivery.leanPageText(Buffer.from('globalThis.__essai = 2; // c\n'), 'js', 'b.js');
  assert.strictEqual(result.ok, true);
  assert.strictEqual(globalThis.__essai, undefined);
});

essai('allègement : écriture atomique ; une erreur d\'écriture est levée, l\'original reste (S-4)', () => {
  const dir = tree(path.join(TMP, 'res', 'ecriture'), { 'fxmanifest.lua': "files { 'web/a.js' }\n", 'web/a.js': JS, 'web/a.js.tmp/x': 'x' });
  assert.throws(() => delivery.leanPage(path.join(dir, 'web', 'a.js'), 'js'));
  assert.strictEqual(read(dir, 'web/a.js'), JS);
  assert.throws(() => delivery.leanResources([{ name: 'e', dir }], { lua: false, web: true }));
  fs.rmSync(path.join(dir, 'web', 'a.js.tmp'), { recursive: true });
  assert.strictEqual(delivery.leanPage(path.join(dir, 'web', 'a.js'), 'js').ok, true);
  assert.deepStrictEqual(fs.readdirSync(path.join(dir, 'web')).sort(), ['a.js']);
});

essai('allègement : le temporaire est créé en exclusivité, jamais suivi ni écrasé (S-5)', () => {
  const outside = tree(path.join(TMP, 'dehors-tmp'), { 'cible.js': 'cible\n', 'd/x': 'x' });
  const dir = tree(path.join(TMP, 'res', 'tmp-pris'), { 'web/a.js': JS, 'web/a.js.tmp': 'déjà là\n', 'web/b.js': JS, 'web/c.js': JS });
  // un fichier ordinaire déjà à la place du temporaire : refus, rien d'écrasé ni de retiré
  assert.throws(() => delivery.leanPage(path.join(dir, 'web', 'a.js'), 'js'), (error) => error.code === 'EEXIST');
  assert.strictEqual(read(dir, 'web/a.js'), JS);
  assert.strictEqual(read(dir, 'web/a.js.tmp'), 'déjà là\n');
  // une jonction vers un dossier extérieur : refus, le dossier n'est pas touché
  fs.symlinkSync(path.join(outside, 'd'), path.join(dir, 'web', 'b.js.tmp'), 'junction');
  assert.throws(() => delivery.leanPage(path.join(dir, 'web', 'b.js'), 'js'));
  assert.strictEqual(read(dir, 'web/b.js'), JS);
  assert.deepStrictEqual(fs.readdirSync(path.join(outside, 'd')), ['x']);
  assert.ok(fs.lstatSync(path.join(dir, 'web', 'b.js.tmp')).isSymbolicLink());
  // un lien vers un fichier extérieur (si le système permet d'en créer : sous Windows, mode développeur ou administrateur)
  let linked = true;
  try {
    fs.symlinkSync(path.join(outside, 'cible.js'), path.join(dir, 'web', 'c.js.tmp'), 'file');
  } catch (error) {
    if (error.code !== 'EPERM') throw error;
    linked = false;
  }
  if (linked) {
    assert.throws(() => delivery.leanPage(path.join(dir, 'web', 'c.js'), 'js'));
    assert.strictEqual(read(outside, 'cible.js'), 'cible\n');
    assert.strictEqual(read(dir, 'web/c.js'), JS);
  }
  // le Lua (T-154) passe par la même écriture
  const lua = tree(path.join(TMP, 'res', 'tmp-pris-lua'), { 'a.lua': LUA, 'a.lua.tmp': 'déjà là\n' });
  assert.throws(() => delivery.leanFile(path.join(lua, 'a.lua')));
  assert.deepStrictEqual([read(lua, 'a.lua'), read(lua, 'a.lua.tmp')], [LUA, 'déjà là\n']);
});

essai('allègement : idempotent (allégé deux fois → identique)', () => {
  const dir = twin('deux-fois');
  delivery.leanResources([{ name: 'r', dir }], { lua: true, web: true });
  const first = dl.hashTree(dir);
  const again = delivery.leanResources([{ name: 'r', dir }], { lua: true, web: true });
  assert.deepStrictEqual(dl.hashTree(dir), first);
  assert.strictEqual(again.pages.before, again.pages.after);
});

// Cas difficiles (§ 12.2) ---------------------------------------------------------------------------------------------

const leanFileText = (relative, kind) => {
  const buffer = fs.readFileSync(path.join(ROOT, relative));
  const result = delivery.leanPageText(buffer, kind, path.basename(relative));
  assert.strictEqual(result.ok, true, `${relative} : ${result.reason} (ligne ${result.line})`);
  assert.ok(result.after < result.before, `${relative} : rien d'allégé`);
  return { original: buffer.toString('utf8'), lean: result.buffer.toString('utf8') };
};

essai('cas difficiles : cas_difficiles.js exécuté avant et après — mêmes valeurs, même ligne d\'erreur (V8)', () => {
  const { original, lean: allege } = leanFileText('tests/livraison/cas_difficiles.js', 'js');
  const replacer = (key, value) => (Object.prototype.toString.call(value) === '[object RegExp]' ? { source: value.source, flags: value.flags } : value);
  const runOnce = (text) => {
    const result = vm.runInNewContext(text, {}, { filename: 'cas_difficiles.js' });
    let stack = '';
    try {
      result.faute();
    } catch (error) {
      stack = String(error.stack);
    }
    const match = stack.match(/cas_difficiles\.js:(\d+)/);
    return { json: JSON.stringify(result, replacer), line: match ? Number(match[1]) : 0 };
  };
  const before = runOnce(original);
  const after = runOnce(allege);
  assert.strictEqual(after.json, before.json);
  assert.ok(before.line > 0);
  assert.strictEqual(after.line, before.line);
  const throwLine = original.split(/\r?\n/).findIndex((l) => l.includes("throw new Error('faute voulue')")) + 1;
  assert.strictEqual(before.line, throwLine);
  // la licence et la directive restent ; les commentaires ordinaires partent
  assert.ok(allege.includes('/*! licence gardée */') && allege.includes('//@ directive gardée'));
  assert.ok(!allege.includes('plusieurs lignes de commentaire') && !allege.includes('// c'));
  assert.strictEqual(newlines(allege), newlines(original));
});

essai('cas difficiles : cas_difficiles.css et .html allégés, prouvés par le second lecteur', () => {
  for (const [relative, kind] of [['tests/livraison/cas_difficiles.css', 'css'], ['tests/livraison/cas_difficiles.html', 'html'], ['tests/livraison/cas_difficiles.js', 'js']]) {
    const { original, lean: allege } = leanFileText(relative, kind);
    assert.deepStrictEqual(memePage.compare(original, allege, kind, relative), { same: true }, relative);
    assert.strictEqual(newlines(allege), newlines(original), relative);
  }
});

// Second lecteur (scripts/lib/meme-page.js) ---------------------------------------------------------------------------

essai('second lecteur : identique hors commentaires → même page ; chaque écart est vu', () => {
  const same = (a, b, kind) => memePage.compare(a, b, kind, `x.${kind}`);
  assert.deepStrictEqual(same('x = 1; // c\n', 'x = 1;\n', 'js'), { same: true });
  assert.deepStrictEqual(same('a { b: c; } /* d */\n', 'a { b: c; }\n', 'css'), { same: true });
  assert.deepStrictEqual(same('<p>\n<!-- c -->\n</p>', '<p>\n\n</p>', 'html'), { same: true });
  assert.deepStrictEqual(same('x = typeof a;\n', 'x = typeofa;\n', 'js'), { same: false, reason: 'code différent' });
  assert.deepStrictEqual(same('a;\nb;\n', '\na;\nb;', 'js'), { same: false, reason: 'numéros de ligne différents' });
  assert.deepStrictEqual(same('a;\n', 'a;\n\n', 'js'), { same: false, reason: 'nombre de lignes différent' });
  assert.deepStrictEqual(same('r = /ab/g;\n', 'r = /a/g;\n', 'js'), { same: false, reason: 'code différent' });
  assert.deepStrictEqual(same('x = 1;\n', 'x = ;\n', 'js'), { same: false, reason: 'allégé non compilable' });
  assert.strictEqual(same('x = ;\n', 'x = ;\n', 'js').same, null);
  assert.strictEqual(same('a /**/b {}', 'ab {}', 'css').same, false);
  assert.strictEqual(same('a/**/b {}', 'a b {}', 'css').same, false);
  assert.strictEqual(same('<div><!--\n--></div>', '<div>\n</div>', 'html').same, false);
  assert.strictEqual(same('<a href="x"></a>', '<a href="y"></a>', 'html').same, false);
  assert.strictEqual(same('<script>a = 1;</script>', '<script>a = 2;</script>', 'html').same, false);
  assert.strictEqual(same('<p>a<!-- c -->b</p>', '<p>ab</p>', 'html').same, true);   // texte fusionné par-dessus
  assert.strictEqual(same('<p>a<!-- c -->b</p>', '<p>a b</p>', 'html').same, false);
});

essai('second lecteur : division et expression régulière par le contexte des accolades', () => {
  const tokens = (src) => memePage.readJs(src).tokens.map((t) => t.text);
  assert.deepStrictEqual(tokens('x = {} / 2 / 1'), ['x', '=', '{', '}', '/', '2', '/', '1']);
  assert.deepStrictEqual(tokens('{}\n/a b/g.test(s)'), ['{', '}', '/a b/g', '.', 'test', '(', 's', ')']);
  assert.deepStrictEqual(tokens('function f() {}\n/a b/.x'), ['function', 'f', '(', ')', '{', '}', '/a b/', '.', 'x']);
  assert.deepStrictEqual(tokens('x = function () {} / 2'), ['x', '=', 'function', '(', ')', '{', '}', '/', '2']);
  assert.deepStrictEqual(tokens('x = await /a b/'), ['x', '=', 'await', '/a b/']);
  assert.deepStrictEqual(tokens('a = b\n<!-- c\n--> d\ne'), ['a', '=', 'b', 'e']);
});

essai('second lecteur : indépendant (fs, path et vm seulement ; jamais webstrip ni delivery)', () => {
  const source = fs.readFileSync(path.join(ROOT, 'scripts', 'lib', 'meme-page.js'), 'utf8');
  const required = Array.from(source.matchAll(/require\(\s*(['"`])([^'"`]*)\1\s*\)/g), (m) => m[2]).sort();
  assert.deepStrictEqual(required, ['fs', 'path', 'vm']);
  assert.ok(!/webstrip|delivery|luastrip/.test(source.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '')));
});

essai('second lecteur : ligne de commande — écarts, refus, entrée vide (contre-essais de la preuve)', () => {
  const target = path.join(TMP, 'preuve');
  const relative = 'tests/livraison/cas_difficiles.css';
  const { lean: allege } = leanFileText(relative, 'css');
  const write = (text) => tree(target, { [relative]: text });
  const run = (input) => {
    const out = spawnSync(process.execPath, [path.join(ROOT, 'scripts', 'lib', 'meme-page.js'), target], { input, encoding: 'utf8' });
    return { status: out.status, stdout: out.stdout };
  };
  write(allege);
  let out = run(`depot\t${relative}\n`);
  assert.strictEqual(out.status, 0, out.stdout);
  assert.match(out.stdout, /^MÊME PAGE : OK \(1 fichiers prouvés, dont 0 livrés ; 0 refusés hors livraison ; 0 non lus hors livraison\)/);
  // une ligne retirée, une lettre ajoutée dans une chaîne
  write(allege.replace(/\r?\n/, ''));
  out = run(`livre\t${relative}\n`);
  assert.strictEqual(out.status, 1);
  assert.match(out.stdout, /ÉCART tests\/livraison\/cas_difficiles\.css : /);
  write(allege.replace('/* pas */', '/* pas! */'));
  assert.strictEqual(run(`depot\t${relative}\n`).status, 1);
  // une page livrée refusée par la livraison est un écart ; hors livraison, un refus est noté
  out = run(`refuse\t${relative}\t3\traison\tlivre\n`);
  assert.strictEqual(out.status, 1);
  assert.match(out.stdout, /page livrée refusée par la livraison/);
  out = run(`refuse\t${relative}\t3\traison\tdepot\n`);
  assert.strictEqual(out.status, 0);
  assert.match(out.stdout, /1 refusés hors livraison : tests\/livraison\/cas_difficiles\.css \(ligne 3 : raison\)/);
  // entrée vide, fichier allégé absent
  assert.strictEqual(run('').status, 1);
  fs.rmSync(target, { recursive: true });
  assert.strictEqual(run(`depot\t${relative}\n`).status, 1);
});

// scripts/livraison.js ------------------------------------------------------------------------------------------------

/** Dépôt git factice : une ressource à pages, une page livrée refusée, un fichier hors livraison. */
function fakeRepo(name, badPage) {
  const dir = tree(path.join(TMP, name), {
    'fxmanifest.lua': "-- racine\nshared_script 'shared/a.lua'\n",
    'shared/a.lua': LUA,
    'modules/vava_t/fxmanifest.lua': "ui_page 'web/index.html'\nfiles { 'web/index.html', 'web/js/*.js', 'web/css/*.css' }\n",
    'modules/vava_t/web/index.html': HTML, 'modules/vava_t/web/js/a.js': JS, 'modules/vava_t/web/css/b.css': CSS,
    'modules/vava_t/web/js/config.js': JS, 'modules/vava_t/web/dev/essais.js': JS, 'outils/x.js': JS,
    ...(badPage ? { 'modules/vava_t/web/js/bad.js': 'x = {} / 2; // c\n' } : {}),
  });
  execFileSync('git', ['init', '-q'], { cwd: dir, stdio: 'ignore' });
  execFileSync('git', ['-c', 'core.autocrlf=false', 'add', '-A'], { cwd: dir, stdio: 'ignore' });
  return dir;
}
function captured(fn) {
  const out = [];
  const err = [];
  const stdout = process.stdout.write;
  const stderr = process.stderr.write;
  process.stdout.write = (s) => { out.push(String(s)); return true; };
  process.stderr.write = (s) => { err.push(String(s)); return true; };
  let code;
  try {
    code = fn();
  } finally {
    process.stdout.write = stdout;
    process.stderr.write = stderr;
  }
  return { code, out: out.join(''), err: err.join('') };
}

essai('livraison.js --essai-pages : livre, depot, refuse ; code 1 sur une page livrée refusée', () => {
  const repo = fakeRepo('depot-factice', true);
  const r = captured(() => livraison.essaiPages(path.join(TMP, 'essai-factice'), [], repo));
  assert.strictEqual(r.code, 1);
  assert.deepStrictEqual(r.out.trim().split('\n').sort(), [
    'depot\tmodules/vava_t/web/dev/essais.js',
    'depot\tmodules/vava_t/web/js/config.js',
    'depot\toutils/x.js',
    'livre\tmodules/vava_t/web/css/b.css',
    'livre\tmodules/vava_t/web/index.html',
    'livre\tmodules/vava_t/web/js/a.js',
    'refuse\tmodules/vava_t/web/js/bad.js\t1\t« / » après « } » : division ou expression régulière indécidable\tlivre',
  ]);
  assert.match(r.err, /ESSAI DES PAGES : 7 fichiers lus, 1 refusés\./);
  assert.strictEqual(read(path.join(TMP, 'essai-factice'), 'modules/vava_t/web/js/a.js'), JS_LEAN);
  assert.strictEqual(read(repo, 'modules/vava_t/web/js/a.js'), JS);   // le dépôt n'est jamais écrit
  // chemins donnés : ces seuls fichiers
  const only = captured(() => livraison.essaiPages(path.join(TMP, 'essai-partiel'), ['outils/x.js', 'absent.js'], repo));
  assert.deepStrictEqual([only.code, only.out], [0, 'depot\toutils/x.js\n']);
});

essai('livraison.js --sortie : seconde ligne de bilan, refus des pages listés, code 1', () => {
  const repo = fakeRepo('depot-sortie', true);
  const target = path.join(TMP, 'sortie-factice');
  const r = captured(() => livraison.sortie(target, repo));
  assert.strictEqual(r.code, 1);
  const lines = r.out.trim().split('\n');
  assert.deepStrictEqual(lines[0], 'refusé : vava_t/web/js/bad.js (ligne 1 : « / » après « } » : division ou expression régulière indécidable)');
  assert.match(lines[1], /^Livraison dans .* : 2 ressources, 3 fichiers allégés, \d+ → \d+ octets \(− \d+\), 0 refusé\(s\)\.$/);
  assert.match(lines[2], /^Pages : 3 fichiers allégés, \d+ → \d+ octets \(− \d+\), 1 refusée\(s\)\.$/);
  assert.strictEqual(read(target, '[vava]/vava_t/web/js/a.js'), JS_LEAN);
  assert.strictEqual(read(target, '[vava]/vava_t/web/js/config.js'), JS);
  assert.strictEqual(read(target, '[vava]/vava_t/web/dev/essais.js'), JS);   // web/dev posé (essais relancés), jamais allégé
  const clean = captured(() => livraison.sortie(path.join(TMP, 'sortie-propre'), fakeRepo('depot-propre', false)));
  assert.strictEqual(clean.code, 0, clean.out);
  assert.match(clean.out, /Pages : 3 fichiers allégés, .*0 refusée\(s\)\./);
});

essai('livraison.js --liste-pages : états en toutes lettres, côté Conseil', () => {
  const repo = fakeRepo('depot-liste', false);
  const r = captured(() => livraison.listePages(repo));
  assert.strictEqual(r.code, 0);
  assert.strictEqual(r.out, 'vava_t\tweb/index.html\tallégé\nvava_t\tweb/js/a.js\tallégé\nvava_t\tweb/js/config.js\tgardé (réglage)\nvava_t\tweb/css/b.css\tallégé\n');
  // le dépôt lui-même : la page de l'Atelier part dans le paquet du Conseil (T-157)
  const out = spawnSync(process.execPath, [path.join(ROOT, 'scripts', 'livraison.js'), '--liste-pages'], { encoding: 'utf8' });
  assert.strictEqual(out.status, 0, out.stderr);
  assert.ok(out.stdout.includes('vava_loading\tweb/js/config.js\tgardé (réglage)\n'));
  assert.ok(out.stdout.includes('vava_atelier@conseil\tweb/css/style.css\tallégé\n'));
  assert.ok(!/web\/dev\/|\.svg\t/.test(out.stdout));
});

essai('livraison.js --essai-pages : la ligne de commande refuse avant d\'écrire', () => {
  const run = (...args) => spawnSync(process.execPath, [path.join(ROOT, 'scripts', 'livraison.js'), ...args], { encoding: 'utf8' });
  const full = tree(path.join(TMP, 'plein'), { 'x.txt': 'x' });
  let out = run('--essai-pages', full);
  assert.strictEqual(out.status, 1);
  assert.match(out.stderr, /non vide/);
  out = run('--essai-pages', path.join(ROOT, 'jamais-cree'));
  assert.strictEqual(out.status, 1);
  assert.match(out.stderr, /dans le dépôt/);
  out = run('--essai-pages', path.dirname(ROOT));
  assert.match(out.stderr, /contient le dépôt/);
  const clone = tree(path.join(TMP, 'clone'), { '.git/HEAD': 'ref: refs/heads/main\n' });
  out = run('--essai-pages', path.join(clone, 'sortie'));
  assert.strictEqual(out.status, 1);
  assert.match(out.stderr, /copie git/);
  assert.strictEqual(run('--essai-pages').status, 2);
  assert.strictEqual(run('--liste-pages', 'x').status, 2);
  assert.ok(!fs.existsSync(path.join(ROOT, 'jamais-cree')));
  assert.deepStrictEqual(fs.readdirSync(full), ['x.txt']);
  // chemins donnés
  out = run('--essai-pages', path.join(TMP, 'essai-cli'), 'tests/livraison/cas_difficiles.html');
  assert.strictEqual(out.status, 0, out.stderr);
  assert.strictEqual(out.stdout, 'depot\ttests/livraison/cas_difficiles.html\n');
});

// Installeur : fetchSource allège aussi les pages (updates.leanWeb) ----------------------------------------------------

const TAR = process.platform === 'win32' ? path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'tar.exe') : 'tar';

async function fetchEssais() {
  tree(path.join(TMP, 'archive', 'auteur-depot-abc'), {
    'fxmanifest.lua': "-- racine\nshared_script 'shared/a.lua'\n", 'shared/a.lua': LUA,
    'modules/vava_p/fxmanifest.lua': "ui_page 'web/index.html'\nfiles { 'web/index.html', 'web/js/*.js', 'web/css/*.css' }\nclient_script 'client/c.lua'\n",
    'modules/vava_p/web/index.html': HTML, 'modules/vava_p/web/js/a.js': JS, 'modules/vava_p/web/js/config.js': JS,
    'modules/vava_p/web/js/bad.js': 'x = {} / 2; // c\n', 'modules/vava_p/web/css/b.css': CSS, 'modules/vava_p/client/c.lua': LUA,
  });
  const archive = path.join(TMP, 'source.tar.gz');
  execFileSync(TAR, ['-czf', archive, '-C', path.join(TMP, 'archive'), 'auteur-depot-abc'], { windowsHide: true });
  tree(path.join(TMP, 'archive2', 'auteur-depot-lua'), {
    'fxmanifest.lua': "-- racine\nshared_script 'shared/a.lua'\n", 'shared/a.lua': LUA,
  });
  const archive2 = path.join(TMP, 'source2.tar.gz');
  execFileSync(TAR, ['-czf', archive2, '-C', path.join(TMP, 'archive2'), 'auteur-depot-lua'], { windowsHide: true });
  // une page livrée qui ne peut pas être réécrite (un dossier occupe la place de son fichier temporaire)
  tree(path.join(TMP, 'archive3', 'auteur-depot-bad'), {
    'fxmanifest.lua': "files { 'web/a.js' }\n", 'web/a.js': JS, 'web/a.js.tmp/x': 'x',
  });
  const archive3 = path.join(TMP, 'source3.tar.gz');
  execFileSync(TAR, ['-czf', archive3, '-C', path.join(TMP, 'archive3'), 'auteur-depot-bad'], { windowsHide: true });
  const server = http.createServer((request, response) => {
    response.writeHead(200, { 'content-type': 'application/gzip' });
    const chosen = { lua: archive2, bad: archive3 }[request.url.split('/').pop()] || archive;
    fs.createReadStream(chosen).pipe(response);
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const codeload = `http://127.0.0.1:${server.address().port}`;
  const fetch = async (updates, ref) => {
    const said = [];
    const job = { say: (m) => said.push(m), track() {} };
    const root = await installer.fetchSource({ codeload, repo: 'a/b', ...updates }, ref, job);
    return { root, said, job };
  };
  const PAGE_LINE = /^Pages servies aux joueurs allégées de leurs commentaires : 3 fichiers, \d+ → \d+ Ko\.$/;
  const LUA_LINE = /^Lua servi aux joueurs allégé de ses commentaires : 4 fichiers, \d+ → \d+ Ko\.$/;
  const REFUSED = 'Page laissée avec ses commentaires (ligne 1 : « / » après « } » : division ou expression régulière indécidable) : vava_p/web/js/bad.js';
  try {
    await essaiAsync('installeur : leanWeb vrai — pages allégées avant les empreintes, journal et bilan exacts', async () => {
      const { root, said, job } = await fetch({ leanLua: true, leanWeb: true }, 'w1');
      assert.match(said[0], LUA_LINE);
      assert.match(said[1], PAGE_LINE);
      assert.deepStrictEqual(said.slice(2), [REFUSED]);
      assert.strictEqual(job.lean, 'Lua allégé : 4 fichiers, 0 refusés ; pages allégées : 3 fichiers, 1 refusées');
      const p = (relative) => fs.readFileSync(path.join(root, 'modules', 'vava_p', relative), 'utf8');
      assert.strictEqual(p('web/js/a.js'), JS_LEAN);
      assert.strictEqual(p('web/css/b.css'), CSS_LEAN);
      assert.strictEqual(p('web/index.html'), HTML_LEAN);
      assert.strictEqual(p('web/js/config.js'), JS);
      assert.strictEqual(p('web/js/bad.js'), 'x = {} / 2; // c\n');
      const planned = installer.layout(root).resources.find((r) => r.name === 'vava_p');
      assert.strictEqual(dl.hashTree(planned.dir)['web/js/a.js'], dl.hashFile(path.join(planned.dir, 'web', 'js', 'a.js')));
    });
    await essaiAsync('installeur : leanWeb absent vaut vrai', async () => {
      const { root, job } = await fetch({}, 'w2');
      assert.strictEqual(job.lean, 'Lua allégé : 4 fichiers, 0 refusés ; pages allégées : 3 fichiers, 1 refusées');
      assert.strictEqual(fs.readFileSync(path.join(root, 'modules/vava_p/web/js/a.js'), 'utf8'), JS_LEAN);
    });
    await essaiAsync('installeur : leanWeb faux — pages livrées telles quelles, Lua allégé', async () => {
      const { root, said, job } = await fetch({ leanWeb: false }, 'w3');
      assert.strictEqual(said[0], 'Allègement des pages livrées désactivé (updates.leanWeb) : pages livrées avec leurs commentaires.');
      assert.match(said[1], LUA_LINE);
      assert.strictEqual(said.length, 2);
      assert.strictEqual(job.lean, 'Lua allégé : 4 fichiers, 0 refusés');
      assert.strictEqual(fs.readFileSync(path.join(root, 'modules/vava_p/web/js/a.js'), 'utf8'), JS);
      assert.strictEqual(fs.readFileSync(path.join(root, 'shared/a.lua'), 'utf8'), '\nlocal x = 1\nreturn x\n');
    });
    await essaiAsync('installeur : leanLua faux, leanWeb vrai — pages seules', async () => {
      const { root, said, job } = await fetch({ leanLua: false }, 'w4');
      assert.strictEqual(said[0], 'Allègement du Lua livré désactivé (updates.leanLua) : fichiers livrés avec leurs commentaires.');
      assert.match(said[1], PAGE_LINE);
      assert.deepStrictEqual(said.slice(2), [REFUSED]);
      assert.strictEqual(job.lean, 'Pages allégées : 3 fichiers, 1 refusées');
      assert.strictEqual(fs.readFileSync(path.join(root, 'shared/a.lua'), 'utf8'), LUA);
    });
    await essaiAsync('installeur : les deux faux — rien d\'allégé, deux lignes', async () => {
      const { root, said, job } = await fetch({ leanLua: false, leanWeb: false }, 'w5');
      assert.strictEqual(said.length, 2);
      assert.strictEqual(job.lean, undefined);
      assert.strictEqual(fs.readFileSync(path.join(root, 'modules/vava_p/web/js/a.js'), 'utf8'), JS);
    });
    await essaiAsync('installeur : une page qui ne peut être réécrite fait échouer l\'opération avant le serveur (S-4)', async () => {
      await assert.rejects(fetch({ leanLua: false }, 'bad'), (error) => {
        assert.strictEqual(error.code, 'lean_failed');
        assert.match(error.message, /^allègement des fichiers livrés interrompu \(.*\) ; rien n'a été changé sur le serveur$/);
        return true;
      });
    });
    await essaiAsync('installeur : une archive sans page → aucune ligne de pages', async () => {
      const { said, job } = await fetch({ leanWeb: true }, 'lua');
      assert.strictEqual(said.length, 1);
      assert.match(said[0], /^Lua servi aux joueurs allégé de ses commentaires : 2 fichiers/);
      assert.strictEqual(job.lean, 'Lua allégé : 2 fichiers, 0 refusés');
    });
  } finally {
    server.close();
  }
}

fetchEssais().then(() => {
  fs.rmSync(TMP, { recursive: true, force: true });
  process.stdout.write(`ESSAIS PAGES : OK (${count})\n`);
}, (error) => fail('essais de fetchSource', error));
