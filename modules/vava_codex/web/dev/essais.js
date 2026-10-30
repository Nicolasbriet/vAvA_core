/*
 * vava_codex/web/dev/essais.js
 * Rôle : essais des fonctions pures de l'onglet Lecture (js/reader.js : index et blocs reçus, jetons, liens, cible
 *        d'un openAt, pages voisines, pages gardées par empreinte, rendu des blocs dans un faux document), de l'état
 *        de lecture de js/model.js et des textes de js/strings.js. Sans dépendance :
 *        `node modules/vava_codex/web/dev/essais.js` (code de sortie 1 au moindre échec). Jamais livré.
 * Dépendances : js/strings.js, js/reader.js, js/model.js (chargés comme dans la page, scripts classiques)
 */
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const web = path.join(__dirname, '..');
// scripts classiques de la page : leurs `const` de premier niveau deviennent des noms globaux de ce contexte
for (const file of ['js/strings.js', 'js/reader.js', 'js/model.js']) {
  vm.runInThisContext(fs.readFileSync(path.join(web, file), 'utf8'), { filename: file });
}
const STRINGS = vm.runInThisContext('STRINGS');
const Model = vm.runInThisContext('Model');
const R = globalThis.CodexReader;
const required = require('../js/reader.js');

let passed = 0;
let failed = 0;
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
function eq(actual, expected, what) {
  if (!same(actual, expected)) throw new Error(`${what || 'valeur'} : attendu ${JSON.stringify(expected)}, obtenu ${JSON.stringify(actual)}`);
}
function check(cond, what) { if (!cond) throw new Error(what); }
function test(name, fn) {
  try { fn(); passed += 1; console.log(`  ok    ${name}`); } catch (error) { failed += 1; console.log(`  ÉCHEC ${name} — ${error.message}`); }
}
const group = (name) => console.log(name);

// Index témoin, dans l'ordre du serveur (chapitres, puis pages par chapitre et rang)
const rawIndex = {
  chapters: [{ id: 'premiers_pas', label: 'Premiers pas' }, { id: 'metiers', label: 'Les métiers' }, { id: 'royaume', label: 'Le royaume' }],
  pages: [
    { id: 'bienvenue', chapter: 'premiers_pas', title: 'Vivre à Eldoria', summary: 'Une cité sans pièce.', hash: '9f1c2a7b3d4e5f60' },
    { id: 'troquer', chapter: 'premiers_pas', title: 'Troquer et partager', summary: 'On donne, on rend service.', hash: '0a1b2c3d4e5f6071' },
    { id: 'apprendre', chapter: 'metiers', title: 'Apprendre un métier', summary: 'Maîtres et apprentis, grenier commun.', hash: '1b2c3d4e5f607182' },
    { id: 'conseil_sieger', chapter: 'royaume', title: 'Siéger au Conseil', summary: '', hash: '2c3d4e5f60718293', staff: true },
  ],
};
const reading = R.normalizeIndex(rawIndex);
const pagesById = new Map(reading.pages.map((page) => [page.id, page]));

group('chargement');
test('reader.js : même objet par require (node) et par nom global (page)', () => {
  check(typeof required.normalizeBody === 'function', 'module.exports absent');
  check(typeof R.normalizeBody === 'function', 'CodexReader absent');
});

group('normalizeBody');
test('blocs valides gardés à l\'identique (tous les blocs et jetons)', () => {
  const body = [
    ['h', 'Donner un objet'],
    ['p', 'Ouvrez votre besace (', ['key', 'vava_inventory'], ').'],
    ['note', 'Un sac au sol ', ['em', 'finit'], ' par disparaître.'],
    ['ul', ['Le forgeron : ', ['page', 'artisanat', 'l’artisanat']], ['Le cultivateur']],
    ['ol', ['Appuyez sur ', ['kbd', 'Clic droit'], '.'], ['Tapez ', ['cmd', 'metiers', 'voir'], ' ou ', ['cmd', 'me', ''], ' ; voir ', ['page', 'troquer', ''], '.']],
  ];
  eq(R.normalizeBody(JSON.parse(JSON.stringify(body))), body);
});
test('type de bloc inconnu, segment numérique ou inconnu retirés', () => {
  eq(R.normalizeBody([['script', 'x'], ['p', 'a', 5, ['foo', 'bar'], 'b'], 42, null, 'p']), [['p', 'ab']]);
});
test('jetons hors motif retirés : page « Bad Id », commande « a b », touche de 17 octets, action invalide', () => {
  eq(R.normalizeBody([['p', 'x', ['page', 'Bad Id', ''], ['cmd', 'a b', ''], ['kbd', 'x'.repeat(17)], ['cmd', 'me', 'a b'], ['key', 'a b'], 'y']]), [['p', 'xy']]);
});
test('bornes en octets : touche de 16 octets gardée, « é » × 9 (18 octets) retirée ; libellé de 48 / 49 octets', () => {
  eq(R.normalizeBody([['p', ['kbd', 'x'.repeat(16)]]]), [['p', ['kbd', 'x'.repeat(16)]]]);
  eq(R.normalizeBody([['p', 'a', ['kbd', 'é'.repeat(9)]]]), [['p', 'a']]);
  eq(R.normalizeBody([['p', ['page', 'troquer', 'x'.repeat(48)]]]), [['p', ['page', 'troquer', 'x'.repeat(48)]]]);
  eq(R.normalizeBody([['p', 'a', ['page', 'troquer', 'x'.repeat(49)]]]), [['p', 'a']]);
});
test('touche littérale avec « : », « [ », « | » ou « * » retirée ; libellé de lien avec « ] » retiré', () => {
  eq(R.normalizeBody([['p', 'a', ['kbd', 'touche:x'], ['kbd', '[F1'], ['kbd', 'a|b'], ['kbd', '*']]]), [['p', 'a']]);
  eq(R.normalizeBody([['p', 'a', ['page', 'troquer', 'x]']]]), [['p', 'a']]);
});
test('action et libellé absents lus comme « »', () => {
  eq(R.normalizeBody([['p', ['cmd', 'me'], ['page', 'troquer']]]), [['p', ['cmd', 'me', ''], ['page', 'troquer', '']]]);
});
test('objet { 0: \'p\', 1: \'x\' } (liste msgpack) lu comme une liste, à chaque niveau ; liste vide en objet', () => {
  eq(R.normalizeBody({ 0: { 0: 'p', 1: 'x', 2: { 0: 'em', 1: 'y' } } }), [['p', 'x', ['em', 'y']]]);
  eq(R.normalizeBody({ 0: { 0: 'ul', 1: { 0: 'a' }, 2: {} } }), [['ul', ['a']]]);
  eq(R.normalizeBody({}), []);
  eq(R.normalizeBody(null), []);
  eq(R.normalizeBody('p'), []);
});
test('50 blocs → 40 ; 13 éléments de liste → 12', () => {
  eq(R.normalizeBody(Array.from({ length: 50 }, (_, i) => ['p', `p${i}`])).length, 40);
  const items = Array.from({ length: 13 }, (_, i) => [`e${i}`]);
  eq(R.normalizeBody([['ul', ...items]])[0].length - 1, 12);
});
test('chaîne de 5 000 caractères → 1 200 (paragraphe, intertitre, italique)', () => {
  const long = 'a'.repeat(5000);
  const body = R.normalizeBody([['p', long], ['h', long], ['p', ['em', long]]]);
  eq(body[0][1].length, 1200);
  eq(body[1][1].length, 1200);
  eq(body[2][1][1].length, 1200);
});
test('paragraphe, note ou liste vidés par le nettoyage : retirés ; intertitre vide retiré', () => {
  eq(R.normalizeBody([['p', 7], ['note'], ['ul', [5], []], ['h', ''], ['h', 3], ['p', '']]), []);
});
test('les chaînes voisines restent jointes après le retrait d\'un segment', () => {
  eq(R.normalizeBody([['p', 'a', ['bad'], 'b', ['em', 'c'], 'd']]), [['p', 'ab', ['em', 'c'], 'd']]);
});

group('normalizeIndex');
test('absent ou faux → null (pages fermées) ; liste vide en objet → listes vides', () => {
  eq(R.normalizeIndex(undefined), null);
  eq(R.normalizeIndex('x'), null);
  eq(R.normalizeIndex([]), null);
  eq(R.normalizeIndex({ chapters: {}, pages: {} }), { chapters: [], pages: [] });
});
test('index valide gardé dans l\'ordre ; staff seulement s\'il vaut true ; résumé absent → « »', () => {
  eq(reading.chapters.map((c) => c.id), ['premiers_pas', 'metiers', 'royaume']);
  eq(reading.pages.map((p) => p.id), ['bienvenue', 'troquer', 'apprendre', 'conseil_sieger']);
  eq(reading.pages.map((p) => p.staff), [false, false, false, true]);
  const raw = { chapters: [{ id: 'a', label: 'A' }], pages: [{ id: 'p', chapter: 'a', title: 'T', hash: 'ab', staff: 'oui' }] };
  eq(R.normalizeIndex(raw).pages[0], { id: 'p', chapter: 'a', title: 'T', summary: '', hash: 'ab', staff: false });
});
test('page hors motif, en double, sans chapitre connu, sans titre ou empreinte invalide : retirée ; chapitre sans page omis', () => {
  const raw = {
    chapters: [{ id: 'a', label: 'A' }, { id: 'vide', label: 'Vide' }, { id: 'B', label: 'b' }, { id: 'c' }],
    pages: [
      { id: 'p1', chapter: 'a', title: 'Un', hash: '0f' },
      { id: 'p1', chapter: 'a', title: 'Doublon', hash: '0f' },
      { id: 'Bad', chapter: 'a', title: 'x', hash: '0f' },
      { id: 'p2', chapter: 'zz', title: 'x', hash: '0f' },
      { id: 'p3', chapter: 'a', title: '', hash: '0f' },
      { id: 'p4', chapter: 'a', title: 'x', hash: 'XYZ' },
      { id: 'a', chapter: 'a', title: 'même id qu\'un chapitre', hash: '0f' },
    ],
  };
  const index = R.normalizeIndex(raw);
  eq(index.chapters, [{ id: 'a', label: 'A' }]);
  eq(index.pages.map((p) => p.id), ['p1']);
});

group('focusTarget (openAt : page, chapitre de lecture, puis module)');
const moduleChapters = [{ id: 'vava_inventory', label: 'Inventaire' }, { id: 'vava_chat', label: 'Chat' }];
test('« bienvenue » → Lecture, cette page, tranche sur « Tout »', () => {
  eq(R.focusTarget('bienvenue', reading, moduleChapters), { tab: 'reading', chapter: '', page: 'bienvenue' });
});
test('« premiers_pas » (contrat de T-022) → Lecture, chapitre, première page « bienvenue »', () => {
  eq(R.focusTarget('premiers_pas', reading, moduleChapters), { tab: 'reading', chapter: 'premiers_pas', page: 'bienvenue' });
  eq(R.focusTarget('metiers', reading, moduleChapters), { tab: 'reading', chapter: 'metiers', page: 'apprendre' });
});
test('« vava_inventory » (chapitre de commandes) → Commandes', () => {
  eq(R.focusTarget('vava_inventory', reading, moduleChapters), { tab: 'commands', chapter: 'vava_inventory' });
});
test('inconnu, vide ou non chaîne → null', () => {
  eq(R.focusTarget('inconnu', reading, moduleChapters), null);
  eq(R.focusTarget('', reading, moduleChapters), null);
  eq(R.focusTarget(null, reading, moduleChapters), null);
});
test('ordre de résolution : page avant chapitre de lecture avant module', () => {
  // impossible avec des données validées (ids uniques, jamais « vava… ») : forcé ici pour fixer l'ordre
  const forced = { chapters: [{ id: 'x', label: 'X' }, { id: 'y', label: 'Y' }], pages: [{ id: 'x', chapter: 'y', title: 'X', summary: '', hash: '0f' }] };
  const modules = [{ id: 'x' }, { id: 'y' }];
  eq(R.focusTarget('x', forced, modules), { tab: 'reading', chapter: '', page: 'x' });
  eq(R.focusTarget('y', forced, modules), { tab: 'reading', chapter: 'y', page: 'x' });
});
test('pages de lecture fermées (index null) : un module reste trouvé, une page non', () => {
  eq(R.focusTarget('vava_chat', null, moduleChapters), { tab: 'commands', chapter: 'vava_chat' });
  eq(R.focusTarget('premiers_pas', null, moduleChapters), null);
});

group('neighbours');
test('première page : pas de précédente ; dernière : pas de suivante', () => {
  eq(R.neighbours(reading.pages, 'bienvenue'), { previous: null, next: 'troquer' });
  eq(R.neighbours(reading.pages, 'conseil_sieger'), { previous: 'apprendre', next: null });
});
test('passage d\'un chapitre à l\'autre ; page inconnue : ni l\'une ni l\'autre', () => {
  eq(R.neighbours(reading.pages, 'troquer'), { previous: 'bienvenue', next: 'apprendre' });
  eq(R.neighbours(reading.pages, 'nulle'), { previous: null, next: null });
});

group('linkText');
test('libellé donné ; sinon titre de la cible ; cible absente → null (texte brut : libellé, sinon id lisible)', () => {
  eq(R.linkText(['page', 'troquer', 'le troc'], pagesById), 'le troc');
  eq(R.linkText(['page', 'troquer', ''], pagesById), 'Troquer et partager');
  eq(R.linkText(['page', 'magie', 'la magie'], pagesById), null);
  eq(R.plainText(['page', 'magie', 'la magie']), 'la magie');
  eq(R.plainText(['page', 'faim_soif', '']), 'faim soif');
});

group('pages gardées par empreinte');
test('gardée à la même empreinte ; autre empreinte → rien', () => {
  const cache = new Map();
  check(R.store(cache, 'troquer', '0a1b2c3d4e5f6071', [['p', 'x']]), 'store refusé');
  eq(R.cached(cache, 'troquer', '0a1b2c3d4e5f6071'), [['p', 'x']]);
  eq(R.cached(cache, 'troquer', 'ffffffffffffffff'), null);
  eq(R.cached(cache, 'bienvenue', '9f1c2a7b3d4e5f60'), null);
});
test('empreinte ou identifiant invalide : rien n\'est gardé', () => {
  const cache = new Map();
  check(!R.store(cache, 'troquer', 'pas-hexa', []), 'empreinte acceptée');
  check(!R.store(cache, 'Bad', '0f', []), 'id accepté');
  eq(cache.size, 0);
});
test('prune : page disparue ou empreinte changée oubliée, les autres gardées', () => {
  const cache = new Map();
  R.store(cache, 'bienvenue', '9f1c2a7b3d4e5f60', [['p', 'a']]);
  R.store(cache, 'troquer', '0000000000000000', [['p', 'b']]);
  R.store(cache, 'magie', '1111111111111111', [['p', 'c']]);
  eq(R.prune(cache, pagesById), 2);
  eq([...cache.keys()], ['bienvenue']);
});

group('renderBlocks (faux document : createElement, createTextNode, textContent)');
function fakeDocument() {
  const created = [];
  function element(tag) {
    const node = {
      tagName: tag.toUpperCase(), className: '', dataset: {}, title: '', type: '', children: [], own: '',
      appendChild(child) { this.children.push(child); return child; },
      set textContent(value) { this.own = String(value); this.children = []; },
      get textContent() { return this.own + this.children.map((child) => child.textContent).join(''); },
      set innerHTML(value) { throw new Error(`innerHTML écrit (${value})`); },
    };
    created.push(node);
    return node;
  }
  return { created, createElement: element, createTextNode: (text) => ({ tagName: '#text', textContent: String(text) }) };
}
const keyLabels = { codex: 'J', vava_inventory: 'I' };
const commands = { me: [], metiers: ['voir'] };
const ctx = {
  strings: STRINGS.reader,
  pagesById,
  keyLabel: (name) => keyLabels[name] || null,
  commandVisible: (name, action) => Boolean(commands[name]) && (!action || commands[name].includes(action)),
};
const shape = (node) => (node.tagName === '#text' ? node.textContent : { tag: node.tagName, cls: node.className, ...(Object.keys(node.dataset).length ? { data: node.dataset } : {}), ...(node.title ? { title: node.title } : {}), ...(node.children.length ? { in: node.children.map(shape) } : { text: node.own }) });
test('chaque bloc à son élément : h3.reader-h, p.reader-p, p.reader-note, ul / ol.reader-list et li', () => {
  const doc = fakeDocument();
  const nodes = R.renderBlocks([['h', 'Titre'], ['p', 'a'], ['note', 'n'], ['ul', ['x'], ['y']], ['ol', ['z']]], ctx, doc);
  eq(nodes.map((n) => `${n.tagName}.${n.className}`), ['H3.reader-h', 'P.reader-p', 'P.reader-note', 'UL.reader-list', 'OL.reader-list']);
  eq(nodes[3].children.map((n) => `${n.tagName}.${n.className}:${n.textContent}`), ['LI.reader-item:x', 'LI.reader-item:y']);
});
test('touches : littérale ; liée par le joueur ; absente → « ? » et « Touche indisponible »', () => {
  const [p] = R.renderBlocks([['p', ['kbd', 'F1'], ['key', 'codex'], ['key', 'vava_health_giveup']]], ctx, fakeDocument());
  eq(p.children.map(shape), [
    { tag: 'KBD', cls: 'reader-kbd', text: 'F1' },
    { tag: 'KBD', cls: 'reader-kbd', text: 'J' },
    { tag: 'KBD', cls: 'reader-kbd is-missing', title: 'Touche indisponible', text: '?' },
  ]);
});
test('commandes : visible → bouton data-command / data-action ; invisible → code sans lien', () => {
  const [p] = R.renderBlocks([['p', ['cmd', 'metiers', 'voir'], ' ', ['cmd', 'me', ''], ' ', ['cmd', 'recolte', 'zones']]], ctx, fakeDocument());
  eq(p.children.map(shape), [
    { tag: 'BUTTON', cls: 'reader-cmd', data: { command: 'metiers', action: 'voir' }, text: '/metiers voir' }, ' ',
    { tag: 'BUTTON', cls: 'reader-cmd', data: { command: 'me', action: '' }, text: '/me' }, ' ',
    { tag: 'CODE', cls: 'reader-cmd is-plain', text: '/recolte zones' },
  ]);
  eq(p.children[0].type, 'button');
});
test('liens : libellé ou titre de la cible (bouton data-page) ; cible absente → texte brut', () => {
  const [p] = R.renderBlocks([['p', ['page', 'troquer', ''], ['page', 'apprendre', 'un maître'], ['page', 'magie', ''], ['page', 'conseil', 'le Conseil']]], ctx, fakeDocument());
  eq(p.children.map(shape), [
    { tag: 'BUTTON', cls: 'reader-link', data: { page: 'troquer' }, text: 'Troquer et partager' },
    { tag: 'BUTTON', cls: 'reader-link', data: { page: 'apprendre' }, text: 'un maître' },
    'magie', 'le Conseil',
  ]);
});
test('italique, et texte venu du serveur jamais lu comme du HTML', () => {
  const doc = fakeDocument();
  const [p] = R.renderBlocks([['p', '<b>gras</b> ', ['em', '<i>x</i>']]], ctx, doc);
  eq(p.children.map(shape), ['<b>gras</b> ', { tag: 'EM', cls: '', text: '<i>x</i>' }]);
  eq(doc.created.filter((n) => n.tagName === 'B' || n.tagName === 'I').length, 0);
});
test('page entière (normalizeBody puis renderBlocks) : texte rendu dans l\'ordre', () => {
  const blocks = R.normalizeBody([['p', 'Ouvrez votre besace (', ['key', 'vava_inventory'], '), puis ', ['page', 'troquer', 'donnez'], '.']]);
  const [p] = R.renderBlocks(blocks, ctx, fakeDocument());
  eq(p.textContent, 'Ouvrez votre besace (I), puis donnez.');
});

group('model.js : état de lecture');
const payload = (index, extra) => ({
  version: 'v1',
  content: { entries: [{ name: 'me', kind: 'command', module: 'vava_chat', chapter: 'Chat', label: 'Action', scope: 'player', runnable: true }], chapters: [{ id: 'vava_chat', label: 'Chat' }], undeclared: [], staff: false, reading: index },
  prefs: { favorites: [], recent: [], keepOpen: true }, keys: {}, closeKey: 'F1', recentMax: 12, ...extra,
});
test('onglet de départ : Commandes ; l\'index de lecture est rangé', () => {
  Model.load(payload(JSON.parse(JSON.stringify(rawIndex))));
  eq(Model.state.tab, 'commands');
  eq(Model.state.reading.pages.length, 4);
  check(Model.state.pageById.has('troquer'), 'pageById');
});
test('onglet Lecture : une ligne par page (« #page:id »), sections par chapitre, ordre de l\'index', () => {
  Model.setTab('reading');
  eq(Model.state.rows.map((row) => row.id), ['#page:bienvenue', '#page:troquer', '#page:apprendre', '#page:conseil_sieger']);
  eq(Model.sections().map((s) => `${s.id}:${s.rows.length}`), ['premiers_pas:2', 'metiers:1', 'royaume:1']);
  eq(Model.pageOfRow('#page:troquer').title, 'Troquer et partager');
  eq(Model.pageOfRow('me|'), null);
});
test('recherche dans le titre, le résumé et le nom du chapitre (sans accents) ; chapitre de lecture', () => {
  Model.setQuery('grenier');
  eq(Model.state.rows.map((row) => row.page.id), ['apprendre']);
  Model.setQuery('METIERS');
  eq(Model.state.rows.map((row) => row.page.id), ['apprendre']);
  Model.setQuery('');
  Model.setChapter('premiers_pas');
  eq(Model.state.rows.map((row) => row.page.id), ['bienvenue', 'troquer']);
  eq(Model.state.chapter, '');
  Model.setChapter('');
});
test('nouvel index : page d\'empreinte changée oubliée du cache, page disparue déchoisie, chapitre disparu remis à « Tout »', () => {
  R.store(Model.state.pageCache, 'bienvenue', '9f1c2a7b3d4e5f60', [['p', 'a']]);
  R.store(Model.state.pageCache, 'troquer', '0a1b2c3d4e5f6071', [['p', 'b']]);
  R.store(Model.state.pageCache, 'conseil_sieger', '2c3d4e5f60718293', [['p', 'c']]);
  Model.choosePage('conseil_sieger');
  Model.setChapter('royaume');
  const next = JSON.parse(JSON.stringify(rawIndex));
  next.pages = next.pages.filter((page) => page.id !== 'conseil_sieger');
  next.pages[1].hash = 'ffffffffffffffff';
  Model.load(payload(next, { version: 'v2' }));
  eq([...Model.state.pageCache.keys()], ['bienvenue']);
  eq(Model.state.page, null);
  eq(Model.state.readingChapter, '');
  eq(Model.state.reading.chapters.map((c) => c.id), ['premiers_pas', 'metiers']);
});
test('ouverture sans contenu (gardé par la page) : index et cache inchangés', () => {
  Model.load({ version: 'v2', keys: {}, closeKey: 'F1', recentMax: 12 });
  eq(Model.state.reading.pages.length, 3);
  eq([...Model.state.pageCache.keys()], ['bienvenue']);
});
test('pages de lecture fermées (index absent) : retour à l\'onglet Commandes, onglet Lecture refusé', () => {
  Model.load(payload(undefined, { version: 'v3' }));
  eq(Model.state.reading, null);
  eq(Model.state.tab, 'commands');
  Model.setTab('reading');
  eq(Model.state.tab, 'commands');
  eq(Model.state.pageCache.size, 0);
});

group('strings.js');
test('chaque texte de l\'onglet Lecture existe et n\'est pas vide', () => {
  const keys = [
    STRINGS.tabs.reading, STRINGS.search.readingPlaceholder, STRINGS.reader.empty, STRINGS.reader.loading, STRINGS.reader.failed,
    STRINGS.reader.previous, STRINGS.reader.next, STRINGS.reader.noKey, STRINGS.reader.noKeyHint, STRINGS.errors.unknown_page,
    STRINGS.errors.disabled,
  ];
  keys.forEach((value, i) => check(typeof value === 'string' && value.length > 0, `texte ${i} vide`));
  eq(STRINGS.tabs.reading, 'Lecture');
  eq(STRINGS.readingHints.length > 0, true);
});
test('pageCount : « 0 page », « 1 page », « 12 pages »', () => {
  eq([0, 1, 12].map(STRINGS.search.pageCount), ['0 page', '1 page', '12 pages']);
});

console.log(`\n${passed} essais réussis, ${failed} échoué${failed > 1 ? 's' : ''}`);
process.exit(failed > 0 ? 1 : 0);
