'use strict';
/*
 * vava_atelier/web/dev/essais.js
 * Rôle : essais des fonctions pures de l'interface (format.js, contrôles de confort de form.js, textes de strings.js)
 *        et d'app.js sur une page factice (libellés de read, étiquettes de l'accueil, confirmation de sortie),
 *        hors jeu, sans navigateur : `node modules/vava_atelier/web/dev/essais.js`. Jamais livré (dossier dev/).
 */

const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert');

const JS = path.join(__dirname, '..', 'js');
const ctx = vm.createContext({ TextEncoder, Intl, UI: { h: () => null } });
const load = (file, names) => vm.runInContext(`${fs.readFileSync(path.join(JS, file), 'utf8')}\n${names.map((n) => `this.${n} = ${n};`).join(' ')}`, ctx);
load('strings.js', ['STRINGS', 'errorText']);
load('format.js', ['Format']);
load('form.js', ['Form']);
const { Format: F, STRINGS: S, Form } = ctx;

let passed = 0;
const eq = (actual, expected, label) => { assert.deepStrictEqual(actual, expected, label); passed += 1; };
const sp = (text) => text.replace(/[\u00a0\u202f]/g, ' ');

// Durées lues
eq(sp(F.duration(600)), '10 minutes');
eq(sp(F.duration(5400)), '1 h 30 min');
eq(sp(F.duration(604800)), '7 jours');
eq(sp(F.duration(86400)), '1 jour');
eq(sp(F.duration(3600)), '1 heure');
eq(sp(F.duration(1)), '1 seconde');
eq(sp(F.duration(90061)), '1 j 1 h 1 min 1 s');
eq(F.durationUnit(['h', 'j'], 604800), 'j');
eq(F.durationUnit(['h', 'j'], 5400), 'h');
eq(F.durationUnit(['min', 'h'], 600), 'min');
eq(F.parseAmount('1,5'), 1.5);
eq(F.parseAmount(' 10 '), 10);
eq(Number.isNaN(F.parseAmount('-2')), true);
eq(Number.isNaN(F.parseAmount('')), true);

// Curseurs : pas, bornes, entiers, affichage
const height = { min: 0.5, max: 3, step: 0.1, decimals: 1, unit: 'm' };
eq(F.snap(height, 1.55), 1.6);
eq(F.snap(height, 1.4999999), 1.5);
eq(F.snap(height, 99), 3);
eq(F.snap(height, NaN), 0.5);
eq(F.snap({ min: 0, max: 1, step: 0.1 }, 0.30000000000000004), 0.3);
eq(F.snap({ min: 1, max: 10, step: 1, integer: true }, 2.5), 3);
eq(sp(F.measure(height, 1.5)), '1,5 m');
eq(sp(F.measure({ min: 10, max: 180, step: 1, unit: '°' }, 70)), '70°');
eq(sp(F.measure({ min: 0.5, max: 2, step: 0.1, decimals: 1, prefix: '×' }, 1)), '× 1,0');
eq(sp(F.measure({ min: 0, max: 3, step: 0.1, unit: 's' }, 0.6)), '0,6 s');
eq(sp(F.measure({ min: 0, max: 100000, step: 1 }, 12000)), '12 000');
eq(F.stepDecimals(0.25), 2);

// Textes : caractères, repli, bornes en octets des schémas du serveur, listes reçues du Lua
eq(F.chars('Forêt'), 5);
eq(F.fold('Forêt ÉCLAT'), 'foret eclat');
eq(F.clip('ééé', 4), 'éé');
eq(new TextEncoder().encode(F.query('é'.repeat(40))).length <= 48, true);
eq(F.query(' <b>x</b>\u0007 '), 'bx/b');
eq(JSON.stringify(F.list({})), '[]');
eq(F.list({ 1: 'a', 2: 'b' }).join(), 'a,b');
eq(F.list(null).length, 0);

// Contrôles de confort (form.js) : le serveur refait tout
const name = { widget: 'text', min: 3, max: 40, charset: 'name' };
eq(Form.localError(name, 'Forêt de Brume'), '');
eq(Form.localError(name, 'L\'Ancre-Rouge'), '');
eq(Form.localError(name, ''), S.fields.required);
eq(Form.localError(name, 'ab'), S.fields.length(3, 40));
eq(Form.localError(name, '<b>Essai</b>'), S.fields.charset.free);
eq(Form.localError(name, 'Essai !'), S.fields.charset.name);
eq(Form.localError({ widget: 'text', min: 1, max: 32, charset: 'id' }, 'Foret'), S.fields.charset.id);
eq(Form.localError({ widget: 'text', min: 0, max: 300, multiline: true, optional: true }, ''), '');
eq(Form.localError({ widget: 'text', min: 0, max: 300, multiline: true }, '1\n2\n3\n4\n5\n6\n7\n8\n9'), S.fields.lines(8));
eq(Form.localError({ widget: 'text', min: 0, max: 80 }, 'a\u0007b'), S.fields.charset.free);
eq(Form.localError({ widget: 'text', min: 3, max: 5 }, 'éééé'), '');
const lasting = { widget: 'duration', min: 3600, max: 2592000 };
eq(Form.localError(lasting, 7200), '');
eq(Form.localError(lasting, NaN), S.fields.required);
eq(sp(Form.localError(lasting, 60)), 'Entre 1 heure et 30 jours.');
eq(Form.localError({ widget: 'item', optional: true }, ''), '');
eq(Form.localError({ widget: 'item' }, ''), S.fields.required);
eq(Form.localError({ widget: 'model', free: true }, 'prop sign'), S.fields.model);
eq(Form.localError({ widget: 'model', free: true }, 'prop_sign_01a'), '');
eq(Form.localError({ widget: 'slider' }, 3), '');

// Textes de l'interface
eq(S.list.create('panneau', 'Nouveau panneau'), 'Créer un panneau');
eq(S.list.create('zone', 'Nouvelle zone'), 'Créer une zone');
eq(S.list.create('arbre', 'Nouvel arbre'), 'Créer un arbre');
eq(S.list.count(1, 'panneau', 'panneaux'), '1 panneau');
eq(S.list.count(3, 'panneau', 'panneaux'), '3 panneaux');
eq(ctx.errorText('not_allowed'), 'L\'Atelier est réservé au Conseil.');
eq(ctx.errorText('code_inconnu'), S.errors.default);

// Étiquettes des cartes : reçues à part (`tags`), posées par-dessus le contenu gardé
const js = (v) => JSON.stringify(v);
const tags = { 'm:a': { text: '3 panneaux' }, 'm:b': { text: '1 en essai', tone: 'trial' }, 'm:c': { text: 'x', tone: 'rouge' }, 'm:d': { tone: 'trial' } };
eq(js(F.cardTag({ editor: 'm:a' }, tags)), js({ text: '3 panneaux', tone: 'count' }));
eq(js(F.cardTag({ editor: 'm:b' }, tags)), js({ text: '1 en essai', tone: 'trial' }));
eq(js(F.cardTag({ editor: 'm:c' }, tags)), js({ text: 'x', tone: 'count' }));
eq(F.cardTag({ editor: 'm:d' }, tags), null);
eq(F.cardTag({ editor: 'm:z' }, tags), null);
eq(F.cardTag({ editor: 'toString' }, tags), null);
eq(F.cardTag({ editor: 'm:a', tag: 'ancienne' }, {}), null);
eq(F.cardTag({ editor: 'm:a' }, []), null);
eq(js(F.cardTag({ editor: 'm:a', upcoming: true }, tags)), js({ text: S.upcoming, tone: 'upcoming' }));

// Libellés d'une fiche lue (`labels` de read) : seulement les champs connus dont la valeur est une chaîne non vide
const fields = [{ id: 'offrande', widget: 'item' }, { id: 'quartier', widget: 'select', source: 'quartiers' }, { id: 'vide', widget: 'item' }, { id: 'sans', widget: 'item' }];
const got = F.fieldLabels(fields, { offrande: 'pain', quartier: 'marche', vide: '', sans: 'x' },
  { offrande: { label: 'Pain', image: 'nui://vava_inventory/web/items/pain.webp' }, quartier: { label: 'Le marché', provisional: true }, vide: { label: 'Rien' }, sans: {}, autre: { label: 'Autre' } });
eq(js(got.map((g) => [g.field.id, g.value, g.item])), js([
  ['offrande', 'pain', { value: 'pain', label: 'Pain', image: 'nui://vava_inventory/web/items/pain.webp', provisional: false }],
  ['quartier', 'marche', { value: 'marche', label: 'Le marché', image: '', provisional: true }],
]));
eq(F.fieldLabels(fields, { offrande: 'pain' }, []).length, 0);
eq(F.fieldLabels(fields, { offrande: 'pain' }, undefined).length, 0);

// app.js chargé sur une page factice : libellés pris dans `read` sans RPC options, étiquettes renouvelées à chaque
// accueil, confirmation de sortie dès qu'une valeur a changé depuis l'ouverture, même après « Vérifier »
async function appEssais() {
  const posts = [], asked = [];
  let homeTags = { 'm:a': { text: '3 panneaux' } }, current = '', homeModel = null, env = null, onMessage = null;
  const node = () => ({ hidden: false, replaceChildren() {} });
  const nodes = {};
  const view = () => ({ el: {}, focus() {}, setData() {}, setError() {}, clearSearch: () => false, hideOk() {}, setChecking() {}, flashOk() {}, setCompare() {}, setTitle() {} });
  const kind = { id: 'panneau', layout: 'page', form: { fields: [{ id: 'offrande', widget: 'item' }, { id: 'quartier', widget: 'select', source: 'quartiers' }] } };
  const replies = {
    home: () => ({ version: 'h1', tags: homeTags, drafts: [], journal: [], rank: '' }),
    editor: () => ({ version: 'e1', descriptor: { label: 'Panneaux', kinds: [kind] } }),
    read: () => ({ title: 'Panneau', values: { s: { offrande: 'pain', quartier: 'marche' } }, labels: { offrande: { label: 'Pain' }, quartier: { label: 'Le marché' } } }),
    check: () => ({ valid: true }),
    list: () => ({ entries: [] }),
  };
  const page = vm.createContext({
    STRINGS: S, errorText: ctx.errorText, Format: F, window: {},
    document: { getElementById: (id) => (nodes[id] = nodes[id] || node()), addEventListener() {} },
    Bridge: { inGame: false, onMessage: (handler) => { onMessage = handler; }, post: async (name, data) => { posts.push(name); return replies[name] ? { ok: true, data: replies[name](data) } : { ok: true, data: {} }; } },
    UI: { Toast: { show() {} }, Confirm: { ask: async (texts) => { asked.push(texts); return false; }, isOpen: () => false, cancel() {} },
      Picker: { close() {}, isOpen: () => false }, Banner: { show() {}, hide() {} }, Keys: { show() {}, hide() {} } },
    Form: { build: (k, values, e) => { env = e; current = values.offrande; return { titleField: '', snapshot: () => js({ s: { offrande: current } }), packet: () => ({ s: { offrande: current } }), validate: () => true, clear() {}, focusFirst() {} }; } },
    HomeView: { render: (model) => { homeModel = model; return view(); } },
    ListView: { render: view }, EntryView: { render: view }, JournalView: { render: view },
  });
  vm.runInContext(fs.readFileSync(path.join(JS, 'app.js'), 'utf8'), page);
  const A = page.window.Atelier;
  const tick = () => new Promise((resolve) => setImmediate(resolve));

  onMessage('open', { version: 'h1', content: { families: [], cards: [] }, tags: homeTags, drafts: [], journal: [], rank: '' });
  await tick();
  eq(js(homeModel.tags), js({ 'm:a': { text: '3 panneaux' } }));
  homeTags = { 'm:a': { text: '4 panneaux' } };
  await A.openEditor('m:a');
  await A.back();
  await tick();
  eq(js(homeModel.tags), js({ 'm:a': { text: '4 panneaux' } }), 'étiquettes de la nouvelle réponse');
  eq(homeModel.content !== null, true, 'contenu gardé');

  posts.length = 0;
  await A.openEntry('m:a', 'panneau', 'place');
  eq(posts.includes('options'), false, 'aucun RPC options à l\'ouverture');
  eq(env.known(kind.form.fields[0], 'pain').label, 'Pain');
  eq(env.known(kind.form.fields[1], 'marche').label, 'Le marché');
  eq(env.known(kind.form.fields[0], 'pomme'), null);

  current = 'pomme';
  await A.check();
  eq(posts.includes('check'), true);
  await A.back();
  eq(asked.length, 1, 'confirmation après « Vérifier »');
  eq(A.state.screen, 'entry');
  current = 'pain';
  await A.back();
  eq(asked.length, 1, 'rien de changé : pas de question');
  eq(A.state.screen, 'list');
}

appEssais().then(() => console.log(`${passed} essais passés`), (error) => { console.error(error); process.exitCode = 1; });
