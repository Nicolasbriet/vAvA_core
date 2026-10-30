'use strict';
/*
 * vava_atelier/web/dev/essais.js
 * Rôle : essais des fonctions pures de l'interface (format.js, lifecycle.js, contrôles de confort de form.js, textes
 *        de strings.js) et d'app.js sur une page factice (libellés de read, étiquettes de l'accueil, confirmation de
 *        sortie ; cycle d'une fiche : enregistrer, essayer, publier, reprendre, changement venu d'ailleurs),
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
load('lifecycle.js', ['Lifecycle']);
load('form.js', ['Form']);
const { Format: F, STRINGS: S, Form, Lifecycle: L } = ctx;

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
  const view = () => ({ el: {}, focus() {}, setData() {}, setError() {}, clearSearch: () => false, hideOk() {}, setBusy() {}, flashOk() {}, setCompare() {}, setTitle() {} });
  const kind = { id: 'panneau', layout: 'page', form: { fields: [{ id: 'offrande', widget: 'item' }, { id: 'quartier', widget: 'select', source: 'quartiers' }] } };
  const replies = {
    home: () => ({ version: 'h1', tags: homeTags, drafts: [], journal: [], rank: '' }),
    editor: () => ({ version: 'e1', descriptor: { label: 'Panneaux', kinds: [kind] } }),
    read: () => ({ title: 'Panneau', values: { s: { offrande: 'pain', quartier: 'marche' } }, labels: { offrande: { label: 'Pain' }, quartier: { label: 'Le marché' } } }),
    check: () => ({ valid: true }),
    list: () => ({ entries: [] }),
  };
  const page = vm.createContext({
    STRINGS: S, errorText: ctx.errorText, Format: F, Lifecycle: L, window: {},
    document: { getElementById: (id) => (nodes[id] = nodes[id] || node()), addEventListener() {} },
    Bridge: { inGame: false, onMessage: (handler) => { onMessage = handler; }, post: async (name, data) => { posts.push(name); return replies[name] ? { ok: true, data: replies[name](data) } : { ok: true, data: {} }; } },
    UI: { Toast: { show() {} }, Confirm: { ask: async (texts) => { asked.push(texts); return false; }, isOpen: () => false, cancel() {} },
      Picker: { close() {}, isOpen: () => false }, Banner: { show() {}, hide() {} }, Keys: { show() {}, hide() {} } },
    Form: { build: (k, values, e) => { env = e; current = values.offrande; return { titleField: '', snapshot: () => js({ s: { offrande: current } }), packet: () => ({ s: { offrande: current } }), validate: () => true, clear() {}, focusFirst() {} }; } },
    HomeView: { render: (model) => { homeModel = model; return view(); } },
    ListView: { render: view }, EntryView: { render: view }, JournalView: { render: view }, HistoryView: { render: view },
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

// Cycle d'une fiche (lifecycle.js) ----------------------------------------------------------------------------------
const nb = (text) => text.replace(/\u00a0/g, ' ');
const B = (id, label, more) => ({ id, label, ...more });

// Pied d'une fiche nouvelle : enregistrer (gardé) ou vérifier (atelier en lecture, T-100)
eq(js(L.newFooter({ stored: true }).map((b) => [b.id, b.primary === true, b.link === true])), js([['save', true, false], ['check', false, true]]));
eq(js(L.newFooter({}).map((b) => [b.id, b.primary === true])), js([['check', true]]));
eq(L.newFooter(null)[0].label, 'Vérifier');

// Pied rendu : commandes (primaire en dernier), liens, phrase de publication
const draftFoot = [B('publish', 'Dresser le panneau', { primary: true }), B('save', 'Enregistrer le brouillon'), B('trial', 'Voir le panneau'),
  B('history', 'Historique', { link: true }), B('discard', 'Abandonner le brouillon', { link: true }), B('check', 'Vérifier', { link: true }), null, { id: 'x' }, { label: 'sans id' }];
const foot = L.foot(draftFoot, { tone: 'draft', publishHint: 'Dresser le panneau le rend lisible aux passants.' });
eq(js(foot.commands.map((b) => b.id)), js(['save', 'trial', 'publish']), 'primaire en dernier');
eq(js(foot.links.map((b) => b.id)), js(['history', 'discard', 'check']));
eq(foot.hint, 'Dresser le panneau le rend lisible aux passants.');
eq(L.foot([B('publish', 'Publier le retrait', { primary: true }), B('discard', 'Renoncer au retrait', { link: true })], { tone: 'removal', publishHint: 'x' }).hint, '', 'pas de phrase sous un retrait');
eq(L.foot([B('save', 'Enregistrer le brouillon', { primary: true }), B('history', 'Historique', { link: true })], { tone: 'live', publishHint: 'x' }).hint, '', 'phrase seulement avec la publication');
eq(L.foot([B('check', 'Vérifier', { primary: true })], {}).hint, S.entry.checkHint, 'atelier en lecture');
eq(L.foot([B('take', 'Reprendre le brouillon', { primary: true }), B('history', 'Historique', { link: true })], { tone: 'draft' }).commands.length, 1);
eq(js(L.foot({}, {})), js({ commands: [], links: [], hint: '' }), 'pied vide reçu en objet');
eq(L.label(draftFoot, 'publish'), 'Dresser le panneau');
eq(L.label(draftFoot, 'restore', 'Revenir'), 'Revenir');

// Lecture seule et ligne du tenant
eq(L.readOnly(null, false), false, 'fiche nouvelle');
eq(L.readOnly({ state: { tone: 'live' } }, false), false);
eq(L.readOnly({ holder: { label: 'Moi', mine: true } }, false), false);
eq(L.readOnly({ holder: { label: 'Sénéchal Aldric Morn', mine: false } }, false), true, 'brouillon d\'un autre');
eq(L.readOnly({ holder: { label: 'X' } }, false), true, 'tenant sans mine : lecture');
eq(L.readOnly({ removal: true }, false), true);
eq(L.readOnly({ removal: 1 }, false), true);
eq(L.readOnly({ removal: 0, state: { tone: 'draft' } }, false), false);
eq(L.readOnly({ state: { tone: 'removal' } }, false), true);
eq(L.readOnly({}, true), true, 'version archivée');
eq(L.stateLine({ holder: { label: 'Sénéchal Aldric Morn', mine: false, at: 'il y a 3 min' } }), 'Brouillon de Sénéchal Aldric Morn, enregistré il y a 3 min');
eq(L.stateLine({ holder: { label: 'Sénéchal Aldric Morn', mine: false, at: 12 } }), 'Brouillon de Sénéchal Aldric Morn');
eq(L.stateLine({ holder: { label: 'Moi', mine: true, at: 'à l\'instant' } }), '');
eq(L.stateLine({ state: { line: 'Ligne du serveur' }, holder: { label: 'X', mine: false } }), 'Ligne du serveur');
eq(L.stateLine({}), '');

// Noms et accords
const zone = { noun: 'zone', article: 'la', feminine: true }, panneau = { noun: 'panneau', article: 'le', feminine: false };
const affiche = { noun: 'affiche', article: 'l\'', feminine: true }, arbre = { noun: 'arbre', article: 'l’' };
eq([L.ofNoun(zone), L.ofNoun(panneau), L.ofNoun(affiche), L.ofNoun(arbre), L.ofNoun({ noun: 'filons', article: 'les' })].join('|'), 'de la zone|du panneau|de l\'affiche|de l’arbre|des filons');
eq([L.theNoun(zone), L.theNoun(panneau), L.theNoun(affiche)].join('|'), 'la zone|le panneau|l\'affiche');
eq([L.feminine(zone), L.feminine(panneau), L.feminine(arbre), L.feminine({ article: 'la' }), L.feminine({ article: 'l\'', feminine: true })].join(), 'true,false,false,true,true');

// Boîtes : publication (résumé, avertissements, phrase), erreurs, rétablissement, retrait, reprise, abandon
const fieldsOf = [{ id: 'titre', label: 'Nom du panneau' }, { id: 'texte', label: 'Ce qui est écrit' }];
const pub = L.confirmOf('publish', { valid: true, token: 'abc', lines: ['Forêt de Brume : rayon de 120 m à 140 m', '2 points ajoutés, 1 retiré', 'La version 3 sera archivée ; celle-ci deviendra la version 4.', 7, ''],
  warnings: ['Un point est à moins de 2 m d\'un autre.'] }, { label: 'Publier la zone', publishHint: 'Publier rend les nouveaux points visibles aux joueurs proches.', fields: fieldsOf });
eq(nb(pub.title), 'Publier la zone ?');
eq(pub.title.includes('\u00a0?'), true, 'espace insécable avant le point d\'interrogation');
eq(pub.lines.length, 3, 'lignes non textuelles écartées');
eq(js([pub.warnings, pub.hint, pub.cancel, pub.ok]), js([['Un point est à moins de 2 m d\'un autre.'], 'Publier rend les nouveaux points visibles aux joueurs proches.', 'Rester', 'Publier la zone']));
eq(L.confirmOf('publish', { valid: true, lines: Array(12).fill('l'), warnings: Array(9).fill('w') }, { label: 'P' }).lines.length, 8);
eq(L.confirmOf('publish', { valid: true, lines: [], warnings: Array(9).fill('w') }, { label: 'P' }).warnings.length, 4);
eq(L.confirmOf('publish', { valid: true, lines: [] }, { label: 'Publier le retrait', removal: true, publishHint: 'x' }).hint, '');
const bad = L.confirmOf('publish', { valid: false, errors: [{ field: 'titre', text: 'Un panneau porte déjà ce nom.' }, { text: 'Le port est fermé.' }, { field: 'texte' }, 'x'] }, { label: 'Dresser le panneau', fields: fieldsOf });
eq(js([nb(bad.title), bad.text, bad.errors, bad.cancel, bad.ok]), js(['Dresser le panneau ?', 'Quelques réglages sont à corriger avant de publier.',
  ['Nom du panneau : Un panneau porte déjà ce nom.', 'Le port est fermé.'], 'Revenir à la fiche', '']));
eq(L.confirmOf('publish', undefined, { label: 'P' }).ok, '', 'réponse vide : un seul bouton');
const back = L.confirmOf('restore', { valid: true, lines: ['La version 2 sera rétablie et deviendra la version 5.'] }, { version: 2 });
eq(js([nb(back.title), back.lines, back.hint, back.ok]), js(['Revenir à la version 2 ?', ['La version 2 sera rétablie et deviendra la version 5.'], '', 'Revenir à cette version']));
eq(L.errorLines(Array(20).fill({ text: 'e' }), []).length, 16);
eq(js([nb(L.confirmRetire(zone).title), L.confirmRetire(zone).text, L.confirmRetire(zone).ok]), js(['Préparer le retrait de la zone ?',
  'Rien ne change en jeu avant que le retrait soit publié ; la zone pourra être rétablie depuis son historique.', 'Préparer le retrait']));
eq(L.confirmRetire(panneau).text, 'Rien ne change en jeu avant que le retrait soit publié ; le panneau pourra être rétabli depuis son historique.');
eq(nb(L.confirmRetire(affiche).title), 'Préparer le retrait de l\'affiche ?');
const takeBox = L.confirmTake('Sénéchal Aldric Morn');
eq(js([nb(takeBox.title), takeBox.text, takeBox.cancel, takeBox.ok]), js(['Reprendre le brouillon de Sénéchal Aldric Morn ?', 'Il en sera averti.', 'Rester', 'Reprendre le brouillon']));
eq(js([nb(S.confirm.discard.title), S.confirm.discard.text, S.confirm.discard.cancel, S.confirm.discard.ok]), js(['Abandonner ce brouillon ?', 'Rien de ce qu\'il contient ne sera gardé.', 'Garder', 'Abandonner']));

// Historique : étiquettes, version rétablie, retrait, auteur et âge, versions illisibles écartées
const rows = L.history({ 1: { version: 6, status: 'published', removal: 0, origin: 'atelier', summary: 'Hauteur de 1,5 m à 2 m', author: 'Sénéchal Aldric Morn', when: 'il y a 2 h' },
  2: { version: 4, status: 'archived', removal: 0, origin: 'restore', restoredFrom: 2, author: 'Souveraine Ysolde', when: 'hier' },
  3: { version: 3, status: 'archived', removal: 1, summary: 'et ses 2 affiches', author: 'Console', when: '' },
  4: { version: 0, status: 'archived' }, 5: null, 6: { version: 'x' }, 7: { version: 1, status: 'archived', removal: false, author: '', when: 'le 12/10' } });
eq(js(rows.map((r) => [r.version, r.tone, r.tag, r.title, r.canRestore])), js([[6, 'live', 'Publiée', 'Version 6', false], [4, 'archived', 'Archivée', 'Version 4', true],
  [3, 'removal', 'Retrait', 'Version 3', false], [1, 'archived', 'Archivée', 'Version 1', true]]));
eq(js(rows.map((r) => [r.who, r.from, r.summary])), js([['Sénéchal Aldric Morn, il y a 2 h', '', 'Hauteur de 1,5 m à 2 m'], ['Souveraine Ysolde, hier', 'rétablie de la version 2', ''],
  ['Console', '', 'et ses 2 affiches'], ['le 12/10', '', '']]));
eq(L.history(undefined).length, 0);

// Changement venu d'ailleurs : rien, relire ou avertir
const open = { mode: 'entry', editor: 'm:a', kind: { id: 'panneau' }, id: 'place' };
const msg = { editor: 'm:a', kind: 'panneau', id: 'place', what: 'published' };
eq(L.changed(open, msg, false), 'reload');
eq(L.changed(open, msg, true), 'notice');
eq(L.changed(open, { ...msg, id: 'autre' }, false), 'none');
eq(L.changed(open, { ...msg, kind: 'affiche' }, false), 'none');
eq(L.changed({ ...open, mode: 'version' }, msg, false), 'none', 'version archivée en lecture : rien');
eq(L.changed({ ...open, id: '' }, { ...msg, id: '' }, false), 'none', 'fiche nouvelle');
eq(L.changed(null, msg, false), 'none');

// Codes de refus de T-101
eq(ctx.errorText('unchanged'), 'Rien n\'a changé depuis la version publiée.');
eq(ctx.errorText('db_error'), 'Les registres de l\'Atelier ne répondent pas : réessayez dans un instant.');
for (const code of ['draft_taken', 'draft_open', 'not_holder', 'no_draft', 'not_stored', 'too_large', 'full', 'parent_missing', 'trial_busy', 'no_trial', 'syncing', 'unknown_version', 'not_archived', 'unreadable']) {
  eq(ctx.errorText(code) !== S.errors.default, true, code);
}
eq(S.states.holder('Sénéchal Aldric Morn', 'il y a 3 min'), 'Brouillon de Sénéchal Aldric Morn, enregistré il y a 3 min');

// app.js : enchaînements d'une fiche gardée sur une page factice
async function cycleEssais() {
  const posts = [], asked = [], notices = [], footers = [];
  let answer = true, snap = 'a', onMessage = null;
  const replies = {
    editor: () => ({ version: 'e1', descriptor: { label: 'Panneaux', stored: true, hasTrial: true, texts: { publish: 'Dresser le panneau' }, kinds: [{ id: 'panneau', noun: 'panneau', article: 'le', layout: 'page', form: { titleField: 'titre', fields: [{ id: 'titre', label: 'Nom' }] } }] } }),
    read: () => ({ title: 'Panneau', values: { s: { titre: 'Panneau' } }, rev: 3, version: 2, holder: { label: 'Moi', mine: true }, state: { label: 'Brouillon', tone: 'draft' },
      footer: [B('save', 'Enregistrer le brouillon'), B('trial', 'Voir'), B('publish', 'Dresser le panneau', { primary: true })] }),
    save: (d) => ({ done: true, id: d.id || 'lanterne_du_port', rev: d.rev + 1, title: 'Lanterne', state: { label: 'Brouillon', tone: 'draft' }, footer: [B('publish', 'Dresser le panneau', { primary: true })] }),
    trial: (d) => (d.rev === 4 ? { done: true, rev: 4, state: { label: 'Essai, version 3', tone: 'trial' }, footer: [] } : null),
    preview: () => ({ valid: true, token: '0123456789abcdef', lines: ['Texte repeint'], warnings: [] }),
    publish: () => ({ done: true, version: 3, state: { label: 'Publiée, version 3', tone: 'live' }, footer: [] }),
    take: () => ({ done: true, rev: 6, state: { label: 'Brouillon', tone: 'draft' }, footer: [] }),
  };
  const stub = () => ({ el: {}, focus() {}, setData() {}, setError() {}, hideOk() {}, setBusy() {}, flashOk() {}, setCompare() {}, setTitle() {}, setReadOnly() {},
    setState() {}, setFooter: (f) => footers.push(f), setNotice: (text) => notices.push(text) });
  const page = vm.createContext({
    STRINGS: S, errorText: ctx.errorText, Format: F, Lifecycle: L, window: {},
    document: { getElementById: () => ({ hidden: false, replaceChildren() {} }), addEventListener() {} },
    Bridge: { inGame: false, onMessage: (h) => { onMessage = h; }, post: async (name, data) => {
      posts.push([name, data]);
      if (name === 'trial' && data.rev !== 4) return { ok: false, error: 'stale' };
      return { ok: true, data: replies[name] ? replies[name](data) : {} };
    } },
    UI: { Toast: { show() {} }, Confirm: { ask: async (box) => { asked.push(box); return answer; }, isOpen: () => false, cancel() {} },
      Picker: { close() {}, isOpen: () => false }, Banner: { show() {}, hide() {} }, Keys: { show() {}, hide() {} } },
    Form: { build: () => ({ titleField: 'titre', snapshot: () => snap, packet: () => ({ s: { titre: snap } }), validate: () => true, clear() {}, focusFirst() {}, showErrors() {}, focusFirstError() {}, title: () => 'Panneau' }) },
    HomeView: { render: stub }, ListView: { render: stub }, EntryView: { render: stub }, JournalView: { render: stub }, HistoryView: { render: stub },
  });
  vm.runInContext(fs.readFileSync(path.join(JS, 'app.js'), 'utf8'), page);
  const A = page.window.Atelier;
  const names = () => posts.map((x) => x[0]);
  onMessage('open', { version: 'h1', content: { families: [], cards: [] }, tags: {}, drafts: [], journal: [] });
  await new Promise((resolve) => setImmediate(resolve));

  // fiche nouvelle : « Enregistrer le brouillon » (id '' et révision 0), puis l'identifiant tiré du nom
  await A.openEntry('m:a', 'panneau', '');
  eq(js(A.state.entry.footer.map((b) => b.id)), js(['save', 'check']));
  posts.length = 0;
  await A.run('save');
  eq(js(posts[0]), js(['save', { editor: 'm:a', kind: 'panneau', id: '', rev: 0, values: { s: { titre: 'a' } } }]));
  eq([A.state.entry.id, A.state.entry.rev], ['lanterne_du_port', 1]);
  eq(js(footers[footers.length - 1].map((b) => b.id)), js(['publish']));

  // fiche modifiée : l'essai enregistre d'abord, à la révision lue, puis essaie à la nouvelle
  await A.openEntry('m:a', 'panneau', 'place');
  eq(A.state.entry.rev, 3);
  snap = 'b';
  posts.length = 0;
  await A.run('trial');
  eq(js(names()), js(['save', 'trial']));
  eq([posts[0][1].rev, posts[1][1].rev, A.state.entry.tone], [3, 4, 'trial']);

  // non modifiée : publier = résumé, boîte, publication avec le jeton ; refus : rien n'est publié
  posts.length = 0;
  asked.length = 0;
  await A.run('publish');
  eq(js(names()), js(['preview', 'publish']));
  eq(js(posts[0][1]), js({ editor: 'm:a', kind: 'panneau', id: 'place', what: 'publish', ref: 4 }));
  eq(posts[1][1].token, '0123456789abcdef');
  eq(nb(asked[0].title), 'Dresser le panneau ?');
  eq([A.state.entry.tone, A.state.entry.rev], ['live', 0]);
  answer = false;
  posts.length = 0;
  await A.run('publish');
  eq(js(names()), js(['preview']), '« Rester » : pas de publication');
  answer = true;

  // révision dépassée : avis sur la fiche avec « Relire »
  A.state.entry.rev = 9;
  notices.length = 0;
  await A.run('trial');
  eq(notices[0], S.entryStale);

  // changement venu d'ailleurs : relue si rien n'a changé, avertie sinon
  posts.length = 0;
  onMessage('entryChanged', { editor: 'm:a', kind: 'panneau', id: 'place', what: 'published' });
  await new Promise((resolve) => setImmediate(resolve));
  eq(js(names()), js(['read']), 'fiche intacte relue');
  snap = 'c';
  posts.length = 0;
  notices.length = 0;
  onMessage('entryChanged', { editor: 'm:a', kind: 'panneau', id: 'place', what: 'taken' });
  eq([posts.length, notices[0]], [0, S.changed.dirty]);
  onMessage('entryChanged', { editor: 'm:a', kind: 'panneau', id: 'autre', what: 'taken' });
  eq(notices.length, 1, 'autre fiche : rien');

  // reprise du brouillon d'un autre : boîte nommant le tenant, révision vue
  replies.read = () => ({ title: 'Panneau', values: {}, rev: 5, holder: { label: 'Sénéchal Aldric Morn', mine: false }, state: { label: 'Brouillon', tone: 'draft' }, footer: [B('take', 'Reprendre le brouillon', { primary: true })] });
  snap = 'a';
  await A.openEntry('m:a', 'panneau', 'nord');
  posts.length = 0;
  asked.length = 0;
  await A.run('take');
  eq(nb(asked[0].title), 'Reprendre le brouillon de Sénéchal Aldric Morn ?');
  eq(js(posts[0]), js(['take', { editor: 'm:a', kind: 'panneau', id: 'nord', rev: 5 }]));
  eq([A.state.entry.rev, A.state.entry.holder], [6, null]);
}

appEssais().then(cycleEssais).then(() => console.log(`${passed} essais passés`), (error) => { console.error(error); process.exitCode = 1; });
