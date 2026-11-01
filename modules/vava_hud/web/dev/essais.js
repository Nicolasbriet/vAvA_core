/*
 * vava_hud/web/dev/essais.js
 * Rôle : essais des règles pures de la page du HUD (js/numbers.js : chiffres des coups, T-155), des garde-fous de la
 *        page (aucune écriture de HTML, aucune boucle par image, aucune adresse externe) et de son poids livré. Sans
 *        dépendance : `node modules/vava_hud/web/dev/essais.js` (code de sortie 1 au moindre échec). Jamais livré.
 *        Le texte d'un chiffre, son mot, l'arrondi, la cascade, les bornes, le débit et le filtre du réglage sont
 *        décidés par le Lua, seul émetteur (essayé par tests/spec/hud_numbers*_spec.lua) ; ici, ce que la page relit
 *        encore : types, classes permises, plus anciens retirés, position.
 *        Remontée d'une jauge (T-114) : règles pures de js/refill.js (palier, remontée relue, plan, projection), puis
 *        js/hud.js chargé dans un faux DOM à horloge manuelle (dev/fauxdom.js) : transition linéaire différée, classe
 *        is-refilling, un seul minuteur vivant, paliers franchis, annulation par le message suivant, médaillon
 *        Endurance ajouté ou retiré sans décaler les autres.
 * Dépendances : js/numbers.js, js/refill.js (chargés par require, comme module.exports), dev/fauxdom.js
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
  eq(N.rules(undefined), { durationMs: 900, riseVh: 5, followMs: 100, maxAlive: 10 });
  eq(N.rules('900'), N.DEFAULTS);
});
test('rythme : nombres reçus gardés (bornés par le Lua), le reste garde la base', () => {
  eq(N.rules({ durationMs: 1200, riseVh: 7.5, followMs: 200, maxAlive: 4, maxPerSecond: 30 }),
    { durationMs: 1200, riseVh: 7.5, followMs: 200, maxAlive: 4 });
  eq(N.rules({ durationMs: '1200', riseVh: NaN, followMs: null, maxAlive: Infinity }), N.DEFAULTS);
});

// Message `number` ----------------------------------------------------------------------------------------------

test('chiffre : lu tel quel, décalage de cascade à 0 s\'il manque, mot absent → null', () => {
  eq(N.read(number({ sub: 'Bloqué', dx: -1.2, dy: -2.6 })),
    { id: 1, x: 0.5, y: 0.4, dx: -1.2, dy: -2.6, text: '12', sub: 'Bloqué', cls: ['dealt'] });
  eq([N.read(number()).dx, N.read(number()).dy, N.read(number()).sub], [0, 0, null]);
  eq(N.read(number({ dx: '3', dy: NaN, sub: 7 })).dx, 0);
  eq(N.read(number({ sub: 7 })).sub, null);
});
test('chiffre : types attendus, sinon rien n\'est montré', () => {
  for (const bad of [{ id: 1.5 }, { id: '7' }, { x: NaN }, { y: undefined }, { x: '0.5' }, { text: 12 }, { text: null },
    { cls: ['dealt'] }, { cls: 3 }]) {
    eq(N.read(number(bad)), null);
  }
  eq(N.read(null), null);
  eq(N.read([1, 0.5, 0.4]), null);
});
test('chiffre : seules les classes permises passent (aucune autre classe ne peut être posée)', () => {
  eq(N.read(number({ cls: 'dealt big' })).cls, ['dealt', 'big']);
  eq(N.read(number({ cls: 'taken huge word' })).cls, ['taken', 'huge', 'word']);
  eq(N.read(number({ cls: 'dealt number is-hidden witness' })).cls, ['dealt']);
  eq(N.read(number({ cls: 'dealt" onclick="x' })).cls, []);
});
test('chiffre : un texte hostile reste du texte (posé par textContent)', () => {
  const hostile = '<img src=x onerror="alert(1)">';
  eq(N.read(number({ text: hostile, sub: hostile })).text, hostile);
  eq(N.read(number({ text: hostile, sub: hostile })).sub, hostile);
  const hud = fs.readFileSync(path.join(web, 'js', 'hud.js'), 'utf8');
  assert.ok(/span\.textContent = text;/.test(hud), 'texte posé par textContent');
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

test('suivi : entrées à identifiant entier gardées, position absente → null (chiffre caché)', () => {
  eq(N.moves({ list: [{ id: 1, x: 0.4, y: 0.3 }, { id: 2, hidden: true }, { id: 1.5, x: 0.1, y: 0.1 }, 'x', null] }),
    [{ id: 1, x: 0.4, y: 0.3, hidden: false }, { id: 2, x: null, y: null, hidden: true }]);
  eq(N.moves({ list: [{ id: 4, x: '0.2', y: NaN, hidden: 'oui' }] }), [{ id: 4, x: null, y: null, hidden: false }]);
});
test('suivi : liste absente ou malformée → rien', () => {
  eq(N.moves(undefined), []);
  eq(N.moves({ list: 'nope' }), []);
  eq(N.moves({ list: {} }), []);
  eq(N.moves([{ id: 1, x: 0, y: 0 }]), []);
});

// Plafond à l'écran (le Lua oublie ses plus anciens sans message : la page retire les siens) --------------------

test('à l\'écran : maxAlive au plus, les plus anciens cèdent la place', () => {
  const ten = Array.from({ length: 10 }, (_, i) => i + 1);
  eq(N.evict(ten, 10), [1]);
  eq(N.evict(ten.slice(0, 9), 10), []);
  eq(N.evict(ten.concat([11, 12]), 10), [1, 2, 3]);
  eq(N.evict([5, 6, 7], 1), [5, 6, 7]);
});

// Position --------------------------------------------------------------------------------------------------

test('position : transform seul, décalage de cascade ajouté, arrondi au millième', () => {
  eq(N.place(0.5, 0.4, 0, 0), 'translate3d(50vw, 40vh, 0)');
  eq(N.place(0.5, 0.4, -1.2, -2.6), 'translate3d(48.8vw, 37.4vh, 0)');
  eq(N.place(0.123456, 0.987654, 0, 0), 'translate3d(12.346vw, 98.765vh, 0)');
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
  for (const file of ['index.html', 'css/style.css', 'js/hud.js', 'js/numbers.js', 'js/refill.js']) {
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

// Remontée d'une jauge (T-114) : règles pures ----------------------------------------------------------------

const R = require('../js/refill.js');
// jauge Endurance de vava_combat (config_client.lua, gauge) : ambre sous 25 %, rouge sous 10 %
const LOW = 0.25;
const CRIT = 0.1;
const plan = (value, refill) => R.plan(value, refill, LOW, CRIT);

test('palier : rouge jusqu\'à 10 %, ambre jusqu\'à 25 %, laiton au-dessus (bornes comme les autres jauges)', () => {
  eq([0, 0.05, 0.1].map((v) => R.level(v, LOW, CRIT)), ['critical', 'critical', 'critical']);
  eq([0.1001, 0.2, 0.25].map((v) => R.level(v, LOW, CRIT)), ['low', 'low', 'low']);
  eq([0.2501, 0.88, 1].map((v) => R.level(v, LOW, CRIT)), ['ok', 'ok', 'ok']);
  // voix : paliers à 0, jamais d'ambre
  eq([R.level(0, 0, 0), R.level(0.01, 0, 0)], ['critical', 'ok']);
});
test('remontée relue : nombres finis, pente > 0, délai ≥ 0, jauge pas pleine ; sinon aucune', () => {
  eq(R.read({ perSecond: 0.2, delayMs: 1000 }, 0.3), { perSecond: 0.2, delayMs: 1000 });
  eq(R.read({ perSecond: 0.2, delayMs: 0 }, 0), { perSecond: 0.2, delayMs: 0 });
  for (const bad of [null, undefined, [0.2, 1000], 'x', { perSecond: 0, delayMs: 0 }, { perSecond: -1, delayMs: 0 },
    { perSecond: NaN, delayMs: 0 }, { perSecond: Infinity, delayMs: 0 }, { perSecond: '0.2', delayMs: 0 },
    { perSecond: 0.2, delayMs: -1 }, { perSecond: 0.2 }, { delayMs: 1000 }]) {
    eq(R.read(bad, 0.3), null);
  }
  eq(R.read({ perSecond: 0.2, delayMs: 0 }, 1), null);
  eq(R.read({ perSecond: 0.2, delayMs: 0 }, NaN), null);
  // pente si faible que la minuterie déborderait : aucune remontée (sinon le plein partirait aussitôt)
  eq(plan(0, { perSecond: 1e-7, delayMs: 0 }), null);
});
test('plan : départ différé de max(délai, 600 ms), durée (1 − valeur) / pente, plein au bout', () => {
  eq(plan(0.3, { perSecond: 0.2, delayMs: 1000 }),
    { from: 0.3, startMs: 1000, durationMs: 3500, steps: [{ at: 4500, value: 1, level: 'ok' }] });
  eq(plan(0.88, { perSecond: 0.2, delayMs: 0 }).startMs, 600);
  eq(plan(0.88, { perSecond: 0.2, delayMs: 599 }).startMs, 600);
  eq(plan(0.88, { perSecond: 0.2, delayMs: 601 }).startMs, 601);
  eq(plan(0.88, { perSecond: 0.2, delayMs: 1000 }).durationMs, 600);
});
test('plan : paliers franchis en montant (rouge → ambre → laiton), au plus deux, à l\'instant calculé', () => {
  eq(plan(0.05, { perSecond: 0.2, delayMs: 1000 }).steps, [
    { at: 1250, value: 0.1, level: 'low' },
    { at: 2000, value: 0.25, level: 'ok' },
    { at: 5750, value: 1, level: 'ok' },
  ]);
  eq(plan(0.2, { perSecond: 0.2, delayMs: 1000 }).steps.map((s) => s.at), [1250, 5000]);
  // jauge sur un palier : encore de sa couleur, il est franchi dès que la remontée part
  eq(plan(0.25, { perSecond: 0.2, delayMs: 1000 }).steps[0], { at: 1000, value: 0.25, level: 'ok' });
  // paliers confondus (voix à 0) : une seule étape
  eq(R.plan(0, { perSecond: 0.5, delayMs: 0 }, 0, 0).steps, [{ at: 600, value: 0, level: 'ok' }, { at: 2600, value: 1, level: 'ok' }]);
});
test('projection : celle du Lua (gauges.all) pour un délai ≥ 600 ms ; immobile avant le départ, plein au bout', () => {
  const p = plan(0.3, { perSecond: 0.2, delayMs: 1000 });
  eq(R.valueAt(p, 0), 0.3);
  eq(R.valueAt(p, 500), 0.3);
  eq(R.valueAt(p, 1000), 0.3);
  assert.ok(Math.abs(R.valueAt(p, 2000) - 0.5) < 1e-9);
  assert.ok(Math.abs(R.valueAt(p, 3000) - 0.7) < 1e-9);
  eq(R.valueAt(p, 4500), 1);
  eq(R.valueAt(p, 6000), 1);
  eq(R.valueAt(null, 100), null);
  // chaque palier tombe sur sa valeur
  const low = plan(0, { perSecond: 0.2, delayMs: 1000 });
  for (const step of low.steps) assert.ok(Math.abs(R.valueAt(low, step.at) - step.value) < 0.001, `${step.value}`);
});
test('projection : faim ou soif basses ralentissent la pente (vide → plein 5 s, 6,7 s à × 0,75, 10 s à × 0,5)', () => {
  eq([0.2, 0.15, 0.1].map((perSecond) => plan(0, { perSecond, delayMs: 1000 }).durationMs), [5000, 6667, 10000]);
});

// Remontée d'une jauge (T-114) : la page, dans un faux DOM ---------------------------------------------------

const { load } = require('./fauxdom.js');
const icon = (name) => `nui://x/${name}.svg`;
const def = (id, order, value, extra) => ({ id, label: id, icon: icon(id), order, low: 0.3, critical: 0.1, value, ...extra });
const ENDURANCE = 'vava_combat:endurance';
const endurance = (value, extra) => def(ENDURANCE, 60, value, { label: 'Endurance', low: LOW, critical: CRIT, ...extra });
function page(withEndurance = true) {
  const p = load(web, ['js/numbers.js', 'js/refill.js', 'js/hud.js']);
  p.post('init', { visible: true, gauges: [def('vava_health:health', 5, 0.8), def('vava_needs:hunger', 10, 0.62),
    def('vava_needs:thirst', 20, 0.08), { ...def('vava_voice:voice', 40, 0.5), low: 0, critical: 0 }] });
  if (withEndurance) p.post('define', endurance(1));
  p.ring = (id = ENDURANCE) => p.byId.hud.children.find((n) => n.dataset.id === id);
  p.fill = (id) => p.ring(id).children[0].children[1];
  return p;
}
const state = (p) => {
  const fill = p.fill(ENDURANCE);
  return { dash: fill.getAttribute('stroke-dasharray'), transition: fill.style.transition || '',
    refilling: fill.classList.contains('is-refilling'), level: p.ring().dataset.level, aria: p.ring().getAttribute('aria-valuenow'),
    timers: p.timers.size };
};

test('page : médaillon Endurance (ordre 60) en dernier, ajouté puis retiré sans déplacer les autres', () => {
  const p = page(false);
  const before = [...p.byId.hud.children];
  p.post('define', endurance(1));
  const after = p.byId.hud.children;
  eq(after.length, 5);
  before.forEach((node, i) => assert.ok(after[i] === node, `médaillon ${i} déplacé`));
  eq(after[4].dataset.id, ENDURANCE);
  eq([after[4].getAttribute('aria-label'), after[4].dataset.level, after[4].getAttribute('aria-valuenow')], ['Endurance', 'ok', '100']);
  p.post('remove', { id: ENDURANCE });
  eq(p.byId.hud.children.length, 4);
  before.forEach((node, i) => assert.ok(p.byId.hud.children[i] === node, `médaillon ${i} déplacé au retrait`));
});
test('page : dépense puis remontée — baisse peinte, puis UNE transition linéaire différée, classe is-refilling', () => {
  const p = page();
  p.post('value', { id: ENDURANCE, value: 0.3, refill: { perSecond: 0.2, delayMs: 1000 } });
  eq(state(p), { dash: '30 100', transition: '', refilling: false, level: 'ok', aria: '30', timers: 1 });
  p.advance(999);
  eq(state(p).refilling, false);
  p.advance(1);
  eq(state(p), { dash: '100 100', transition: 'stroke-dasharray 3500ms linear', refilling: true, level: 'ok', aria: '30', timers: 1 });
  assert.ok(/^stroke-dasharray \d+ms linear$/.test(state(p).transition));
  p.advance(3499);
  eq(state(p).refilling, true);
  p.advance(1);
  eq(state(p), { dash: '100 100', transition: '', refilling: false, level: 'ok', aria: '100', timers: 0 });
});
test('page : la transition linéaire ne part jamais avant 600 ms (la baisse se voit d\'abord)', () => {
  const p = page();
  p.post('value', { id: ENDURANCE, value: 0.6, refill: { perSecond: 0.2, delayMs: 0 } });
  p.advance(599);
  eq(state(p).refilling, false);
  p.advance(1);
  eq([state(p).refilling, state(p).transition], [true, 'stroke-dasharray 2000ms linear']);
});
test('page : épuisement — rouge, puis ambre, puis laiton aux instants calculés, un seul minuteur vivant', () => {
  const p = page();
  p.post('value', { id: ENDURANCE, value: 0, refill: { perSecond: 0.2, delayMs: 1000 } });
  eq([state(p).level, state(p).dash, state(p).timers], ['critical', '0 100', 1]);
  const seen = [];
  for (let t = 0; t < 7000; t += 50) {
    p.advance(50);
    assert.ok(p.timers.size <= 1, `${p.timers.size} minuteurs à ${t + 50} ms`);
    const s = state(p);
    if (seen.length === 0 || seen[seen.length - 1][1] !== s.level) seen.push([t + 50, s.level, s.aria]);
  }
  eq(seen, [[50, 'critical', '0'], [1500, 'low', '10'], [2250, 'ok', '25']]);
  eq([state(p).aria, state(p).refilling, p.timers.size], ['100', false, 0]);
});
test('page : un nouveau `value` annule la remontée en cours et ses minuteries (coup bloqué en pleine remontée)', () => {
  const p = page();
  p.post('value', { id: ENDURANCE, value: 0.05, refill: { perSecond: 0.2, delayMs: 1000 } });
  p.advance(1300);
  eq([state(p).refilling, state(p).level], [true, 'low']);
  // coup bloqué : nouvelle baisse, nouvelle remontée
  p.post('value', { id: ENDURANCE, value: 0, refill: { perSecond: 0.2, delayMs: 1000 } });
  eq(state(p), { dash: '0 100', transition: '', refilling: false, level: 'critical', aria: '0', timers: 1 });
  p.advance(1000);
  eq([state(p).refilling, state(p).transition], [true, 'stroke-dasharray 5000ms linear']);
  // valeur sans remontée (pleine à la mise à terre) : plus de transition linéaire ni de minuterie
  p.post('value', { id: ENDURANCE, value: 1 });
  eq(state(p), { dash: '100 100', transition: '', refilling: false, level: 'ok', aria: '100', timers: 0 });
  p.post('value', { id: ENDURANCE, value: 0.4, refill: { perSecond: 0.2, delayMs: 1000 } });
  p.post('value', { id: ENDURANCE, value: 0.4 });
  eq([state(p).timers, state(p).refilling], [0, false]);
  p.advance(10000);
  eq(state(p).dash, '40 100');
});
test('page : faim basse — même départ, pente plus douce (durée de la transition allongée)', () => {
  const p = page();
  p.post('value', { id: ENDURANCE, value: 0, refill: { perSecond: 0.15, delayMs: 1000 } });
  p.advance(1000);
  eq(state(p).transition, 'stroke-dasharray 6667ms linear');
});
test('page : remontée mal formée ignorée (valeur posée, aucune minuterie)', () => {
  const p = page();
  for (const refill of [{ perSecond: 0, delayMs: 0 }, { perSecond: 'x', delayMs: 0 }, { perSecond: 0.2, delayMs: -5 }, 'oui', [0.2, 0]]) {
    p.post('value', { id: ENDURANCE, value: 0.5, refill });
    eq([state(p).dash, state(p).timers, state(p).refilling], ['50 100', 0, false]);
  }
  p.post('value', { id: ENDURANCE, value: 1, refill: { perSecond: 0.2, delayMs: 0 } });
  eq(state(p).timers, 0);
});
test('page : retrait, `init` ou redéclaration pendant une remontée → minuteries annulées ; `define` avec remontée repart', () => {
  const p = page();
  p.post('value', { id: ENDURANCE, value: 0.3, refill: { perSecond: 0.2, delayMs: 1000 } });
  p.post('remove', { id: ENDURANCE });
  eq(p.timers.size, 0);
  // page rechargée (gauges.all) : valeur projetée et remontée restante dans l'état complet
  p.post('init', { visible: true, gauges: [endurance(0.5, { refill: { perSecond: 0.2, delayMs: 0 } })] });
  eq([state(p).dash, state(p).timers], ['50 100', 1]);
  p.advance(600);
  eq([state(p).refilling, state(p).transition], [true, 'stroke-dasharray 2500ms linear']);
  p.post('init', { visible: true, gauges: [] });
  eq(p.timers.size, 0);
  p.post('define', endurance(0.2, { refill: { perSecond: 0.2, delayMs: 1000 } }));
  eq([state(p).level, p.timers.size], ['low', 1]);
  p.post('define', endurance(0.2));
  eq([state(p).refilling, p.timers.size], [false, 0]);
});
test('page : une jauge déclarée pendant une remontée ne sort pas l\'Endurance du document (transition gardée)', () => {
  const p = page();
  p.post('value', { id: ENDURANCE, value: 0.3, refill: { perSecond: 0.2, delayMs: 1000 } });
  p.advance(1500);
  const node = p.ring();
  const before = node.detached || 0;
  p.post('define', def('vava_magic:mana', 30, 0.7));
  p.post('define', def('vava_zz:after', 80, 0.7));
  p.post('define', def('vava_needs:hunger', 10, 0.5));
  eq(p.byId.hud.children.map((n) => n.dataset.id), ['vava_health:health', 'vava_needs:hunger', 'vava_needs:thirst',
    'vava_magic:mana', 'vava_voice:voice', ENDURANCE, 'vava_zz:after']);
  eq([node.detached || 0, state(p).refilling], [before, true]);
  // ordre changé (une jauge redéclarée plus loin) : seule celle-ci est déplacée
  p.post('define', def('vava_needs:hunger', 70, 0.5));
  eq(p.byId.hud.children.map((n) => n.dataset.id).slice(-3), [ENDURANCE, 'vava_needs:hunger', 'vava_zz:after']);
  eq(node.detached || 0, before);
  // une jauge ramenée devant : seule elle bouge
  p.post('define', def('vava_zz:after', 1, 0.7));
  eq(p.byId.hud.children.map((n) => n.dataset.id)[0], 'vava_zz:after');
  eq([node.detached || 0, p.byId.hud.children.length], [before, 7]);
});
test('ordre : plus longue suite déjà en place (les nouveaux, -1, jamais gardés)', () => {
  eq(R.steady([]), []);
  eq(R.steady([0, 1, 2]), [0, 1, 2]);
  eq(R.steady([0, 1, -1, 2]), [0, 1, 3]);
  eq(R.steady([0, 2, 3, 4, 5, 1, 6]), [0, 1, 2, 3, 4, 6]);
  eq(R.steady([6, 0, 1, 2, 3, 4, 5]), [1, 2, 3, 4, 5, 6]);
  eq(R.steady([-1, -1]), []);
});
test('page : les autres jauges (sans remontée) se peignent comme avant', () => {
  const p = page();
  p.post('value', { id: 'vava_needs:hunger', value: 0.25 });
  const fill = p.fill('vava_needs:hunger');
  eq([fill.getAttribute('stroke-dasharray'), fill.style.transition || '', p.ring('vava_needs:hunger').dataset.level, p.timers.size],
    ['25 100', '', 'low', 0]);
});
test('page : aucune animation par image ; remontée gardée sous « mouvement réduit », le reste coupé', () => {
  const hud = fs.readFileSync(path.join(web, 'js', 'hud.js'), 'utf8');
  assert.ok(!/requestAnimationFrame|setInterval/.test(hud));
  const css = fs.readFileSync(path.join(web, 'css', 'style.css'), 'utf8').replace(/\/\*[\s\S]*?\*\//g, '');
  const reduced = css.match(/@media \(prefers-reduced-motion: reduce\) \{([\s\S]*?)\n\}/);
  assert.ok(reduced && /\*:not\(\.progress-fill\):not\(\.is-refilling\)/.test(reduced[1]), 'remontée gardée');
  assert.ok(/transition: none !important/.test(reduced[1]), 'le reste coupé');
  const html = fs.readFileSync(path.join(web, 'index.html'), 'utf8');
  assert.ok(html.indexOf('js/refill.js') > 0 && html.indexOf('js/refill.js') < html.indexOf('js/hud.js'), 'refill.js avant hud.js');
});

console.log(`vava_hud : ${passed} essais réussis, ${failed} en échec`);
if (failed > 0) process.exit(1);
