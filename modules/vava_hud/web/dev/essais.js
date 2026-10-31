/*
 * vava_hud/web/dev/essais.js
 * Rôle : essais des règles pures de la page du HUD (js/numbers.js : chiffres des coups, T-155), des garde-fous de la
 *        page (aucune écriture de HTML, aucune boucle par image, aucune adresse externe) et de son poids livré. Sans
 *        dépendance : `node modules/vava_hud/web/dev/essais.js` (code de sortie 1 au moindre échec). Jamais livré.
 *        Le texte d'un chiffre, son mot, l'arrondi, la cascade et le filtre du réglage sont décidés par le Lua
 *        (shared/numbers.lua, essayé par tests/spec/hud_numbers_spec.lua) ; ici, ce que la page relit et borne.
 * Dépendances : js/numbers.js (chargé par require, comme module.exports)
 */
'use strict';

const fs = require('fs');
const path = require('path');
const assert = require('assert');

const web = path.join(__dirname, '..');
const N = require('../js/numbers.js');

let passed = 0;
let failed = 0;
function test(name, fn) {
  try {
    fn();
    passed += 1;
  } catch (error) {
    failed += 1;
    console.log(`ÉCHEC vava_hud : ${name}\n  ${error.message}`);
  }
}
const eq = (actual, expected) => assert.deepStrictEqual(actual, expected);
const number = (extra) => ({ id: 1, x: 0.5, y: 0.4, text: '12', cls: 'dealt', ...extra });

// Rythme -------------------------------------------------------------------------------------------------------

test('rythme : valeurs de base sans init.numbers', () => {
  eq(N.rules(undefined), { durationMs: 900, riseVh: 5, followMs: 100, maxAlive: 10, maxPerSecond: 16 });
  eq(N.rules('900'), N.DEFAULTS);
});
test('rythme : valeurs reçues dans leurs bornes, les autres gardent la base', () => {
  eq(N.rules({ durationMs: 1200, riseVh: 7.5, followMs: 200, maxAlive: 4, maxPerSecond: 30 }),
    { durationMs: 1200, riseVh: 7.5, followMs: 200, maxAlive: 4, maxPerSecond: 30 });
  eq(N.rules({ durationMs: 100, riseVh: 50, followMs: 0, maxAlive: 31, maxPerSecond: NaN }), N.DEFAULTS);
  eq(N.rules({ durationMs: '1200', maxAlive: Infinity }), N.DEFAULTS);
  eq(N.rules({ maxAlive: 4.6 }).maxAlive, 5);
});

// Message `number` ----------------------------------------------------------------------------------------------

test('chiffre : lu tel quel, décalage de cascade à 0 s\'il manque', () => {
  eq(N.read(number({ sub: 'Bloqué', cls: 'dealt' })),
    { id: 1, x: 0.5, y: 0.4, dx: 0, dy: 0, text: '12', sub: 'Bloqué', cls: ['dealt'] });
  eq(N.read(number({ dx: -1.2, dy: -2.6 })).dx, -1.2);
  eq(N.read(number({ dx: -1.2, dy: -2.6 })).dy, -2.6);
});
test('chiffre : sans identifiant entier positif, position, texte ou côté, rien n\'est montré', () => {
  for (const bad of [{ id: 0 }, { id: -3 }, { id: 1.5 }, { id: '7' }, { x: NaN }, { y: undefined }, { x: '0.5' },
    { text: '' }, { text: '   ' }, { text: 12 }, { cls: '' }, { cls: 'word big' }, { cls: 'witness' }]) {
    eq(N.read(number(bad)), null);
  }
  eq(N.read(null), null);
  eq(N.read([1, 0.5, 0.4]), null);
});
test('chiffre : position ramenée à l\'écran, décalage borné à 20 vw ou vh', () => {
  const n = N.read(number({ x: -0.3, y: 1.7, dx: 90, dy: -Infinity }));
  eq([n.x, n.y, n.dx, n.dy], [0, 1, 20, 0]);
});
test('chiffre : classes permises seulement, un côté et une taille, dans l\'ordre côté, taille, mot', () => {
  eq(N.classes('dealt big'), ['dealt', 'big']);
  eq(N.classes('word taken huge'), ['taken', 'huge', 'word']);
  eq(N.classes(['dealt', 'small']), ['dealt', 'small']);
  eq(N.classes('dealt taken small big'), ['dealt', 'small']);
  eq(N.classes('dealt onclick=x number-body'), ['dealt']);
  eq(N.classes('dealt" onclick="x'), null);
  eq(N.classes('taken  word'), ['taken', 'word']);
  eq(N.classes(42), null);
});
test('chiffre : texte et mot coupés à 32 caractères, gardés comme texte (posés par textContent)', () => {
  const hostile = '<img src=x onerror="alert(1)">';
  const n = N.read(number({ text: hostile, sub: 'É'.repeat(40) }));
  eq(n.text, hostile);
  eq(Array.from(n.sub).length, 32);
  eq(N.read(number({ text: '  12  ' })).text, '12');
  eq(N.read(number({ sub: 7 })).sub, null);
});
test('chiffre : les issues de la spec passent telles que le Lua les compose', () => {
  const sent = [
    ['12', null, 'dealt'], ['7', 'Bloqué', 'dealt'], ['Paré', null, 'dealt word'], ['22', 'Chancelle', 'dealt big'],
    ['18', 'À terre', 'taken huge'], ['3', null, 'taken small'], ['Esquivé', null, 'taken word'],
    ['Absorbé', null, 'dealt word'], ['4', 'Garde brisée', 'dealt'], ['Sans effet', null, 'dealt word'], ['7,2', null, 'dealt'],
  ];
  for (const [text, sub, cls] of sent) {
    const n = N.read(number({ text, ...(sub ? { sub } : {}), cls }));
    assert.ok(n, `${text} refusé`);
    eq([n.text, n.sub, n.cls.join(' ')], [text, sub, cls]);
  }
});

// Message `numbersMove` -----------------------------------------------------------------------------------------

test('suivi : entrées valides gardées, position exigée sauf pour un chiffre caché', () => {
  eq(N.moves({ list: [{ id: 1, x: 0.4, y: 0.3 }, { id: 2, hidden: true }, { id: 3 }, { id: 0, x: 0.1, y: 0.1 }, 'x', null] }),
    [{ id: 1, x: 0.4, y: 0.3, hidden: false }, { id: 2, x: null, y: null, hidden: true }]);
  eq(N.moves({ list: [{ id: 4, x: 2, y: -1, hidden: 'oui' }] }), [{ id: 4, x: 1, y: 0, hidden: false }]);
});
test('suivi : liste absente ou malformée → rien ; 30 entrées au plus', () => {
  eq(N.moves(undefined), []);
  eq(N.moves({ list: 'nope' }), []);
  eq(N.moves([{ id: 1, x: 0, y: 0 }]), []);
  eq(N.moves({ list: Array.from({ length: 50 }, (_, i) => ({ id: i + 1, x: 0.5, y: 0.5 })) }).length, 30);
});

// Plafonds de la page (filets : le Lua a les mêmes) -----------------------------------------------------------

test('à l\'écran : 10 au plus, les plus anciens cèdent la place', () => {
  const ten = Array.from({ length: 10 }, (_, i) => i + 1);
  eq(N.evict(ten, 10), [1]);
  eq(N.evict(ten.slice(0, 9), 10), []);
  eq(N.evict(ten.concat([11, 12]), 10), [1, 2, 3]);
  eq(N.evict([5, 6, 7], 1), [5, 6, 7]);
  eq(N.evict(ten, 0), [1]);
});
test('par seconde : 16 admis, le 17e refusé, admis de nouveau une seconde après le premier', () => {
  let times = [];
  for (let i = 0; i < 16; i += 1) {
    const gate = N.admit(times, 1000 + i * 10, 16);
    assert.ok(gate.ok, `chiffre ${i + 1} refusé`);
    times = gate.times;
  }
  const refused = N.admit(times, 1200, 16);
  eq(refused.ok, false);
  eq(refused.times.length, 16);
  const later = N.admit(refused.times, 2000, 16);
  eq(later.ok, true);
  eq(later.times.length, 16);
  eq(N.admit(null, 0, 'x').ok, true);
});

// Position --------------------------------------------------------------------------------------------------

test('position : transform seul, décalage de cascade ajouté, arrondi au millième', () => {
  eq(N.place(0.5, 0.4, 0, 0), 'translate3d(50vw, 40vh, 0)');
  eq(N.place(0.5, 0.4, -1.2, -2.6), 'translate3d(48.8vw, 37.4vh, 0)');
  eq(N.place(0.123456, 0.987654), 'translate3d(12.346vw, 98.765vh, 0)');
});

// Garde-fous de la page -----------------------------------------------------------------------------------------

test('page : aucun innerHTML ni document.write dans js/ ; aucune boucle par image ni minuterie répétée', () => {
  for (const file of fs.readdirSync(path.join(web, 'js'))) {
    const source = fs.readFileSync(path.join(web, 'js', file), 'utf8');
    assert.ok(!/innerHTML|outerHTML|insertAdjacentHTML|document\.write/.test(source), `${file} : écriture de HTML`);
    assert.ok(!/requestAnimationFrame|setInterval/.test(source), `${file} : boucle par image ou minuterie répétée`);
  }
});
test('page : chiffres animés par transform et opacité seulement, suivis par transform (jamais left ni top)', () => {
  const css = fs.readFileSync(path.join(web, 'css', 'style.css'), 'utf8').replace(/\/\*[\s\S]*?\*\//g, '');
  const rise = css.match(/@keyframes number-rise \{([\s\S]*?)\n\}/);
  assert.ok(rise, 'animation number-rise absente');
  const props = new Set([...rise[1].matchAll(/([a-z-]+)\s*:/g)].map((m) => m[1]));
  eq([...props].sort(), ['opacity', 'transform']);
  const anchor = css.match(/\n\.number \{([\s\S]*?)\}/);
  assert.ok(anchor && /transition: transform/.test(anchor[1]) && !/transition:[^;]*(left|top)/.test(anchor[1]), 'ancre');
  assert.ok(!/(^|[^-])filter\s*:|backdrop-filter|blur\(/.test(css), 'style.css : filtre ou flou');
});
test('page : calque des chiffres présent, numbers.js chargé avant hud.js, aucune adresse externe', () => {
  const html = fs.readFileSync(path.join(web, 'index.html'), 'utf8');
  assert.ok(/<div id="numbers" class="numbers" aria-hidden="true"><\/div>/.test(html), 'calque');
  assert.ok(html.indexOf('js/numbers.js') > 0 && html.indexOf('js/numbers.js') < html.indexOf('js/hud.js'), 'ordre des scripts');
  for (const file of ['index.html', 'css/style.css', 'js/hud.js', 'js/numbers.js']) {
    // seules adresses permises : l'espace de noms SVG et le rappel NUI `ready` de la ressource elle-même
    assert.ok(!/https?:\/\/(?!www\.w3\.org|\$\{)/.test(fs.readFileSync(path.join(web, file), 'utf8')), `${file} : adresse externe`);
  }
});

// fichiers livrés : ceux des `files` du manifeste (web/index.html, web/css/*.css, web/js/*.js)
test('poids de la page livrée ≤ 32 Ko', () => {
  const files = ['index.html'];
  for (const [dir, ext] of [['css', '.css'], ['js', '.js']]) {
    for (const file of fs.readdirSync(path.join(web, dir))) if (file.endsWith(ext)) files.push(`${dir}/${file}`);
  }
  const total = files.reduce((sum, file) => sum + fs.statSync(path.join(web, file)).size, 0);
  console.log(`vava_hud : page livrée ${total} octets (${files.length} fichiers)`);
  assert.ok(total <= 32 * 1024, `${total} octets`);
});

console.log(`vava_hud : ${passed} essais réussis, ${failed} en échec`);
if (failed > 0) process.exit(1);
