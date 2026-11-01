'use strict';
/*
 * vava_atelier/web/dev/essais.js
 * Rôle : essais des fonctions pures de l'interface (format.js, lifecycle.js, contrôles de confort de form.js, textes
 *        de strings.js) et d'app.js sur une page factice (libellés de read, étiquettes de l'accueil, confirmation de
 *        sortie ; cycle d'une fiche : enregistrer, essayer, publier, reprendre, changement venu d'ailleurs), et de
 *        l'amorce boot.js (T-157 : bornes, noms, ordre, insertion unique, refus, sourceURL ; pages et manifeste),
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
load('placing.js', ['Placing']);
const { Format: F, STRINGS: S, Form, Lifecycle: L, Placing: PL } = ctx;

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
// refus : texte du serveur s'il est reçu, sinon les seuls codes de la page, sinon « Action impossible. »
eq(ctx.errorText('not_allowed', 'L\'Atelier est réservé au Conseil.'), 'L\'Atelier est réservé au Conseil.');
eq(ctx.errorText('not_allowed'), S.errors.default);
eq(ctx.errorText('stale', 'Cette fiche a changé depuis que vous l\'avez ouverte.'), 'Cette fiche a changé depuis que vous l\'avez ouverte.');
eq(ctx.errorText('stale'), S.errors.stale, 'relais désaccordé : texte de la page');
eq(ctx.errorText('stale', ''), S.errors.stale);
eq(ctx.errorText('timeout', 7), S.errors.timeout, 'texte non textuel ignoré');
eq(ctx.errorText('code_inconnu'), S.errors.default);
eq(JSON.stringify(Object.keys(S.errors).sort()), JSON.stringify(['client_error', 'default', 'invalid_args', 'invalid_response', 'stale', 'timeout', 'unknown_kind']));

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

// Placement (T-102) : fonctions pures de placing.js, textes de la maquette Recolte
const ZONE = { id: 'zone', noun: 'zone', nounPlural: 'zones', article: 'la', placement: 'circle', steps: ['La zone', 'Les points', 'Publier'], rules: { radius: { min: 10, max: 300, default: 60 } } };
const NODE = { id: 'node', noun: 'point', nounPlural: 'points', article: 'le', parent: 'zone', placement: 'oriented', rules: { inside: { slack: 5 }, spacing: 2 },
  template: ['ressource', 'charges', 'repousse'], autoTitle: 'ressource',
  ghost: { field: 'ressource', models: { chene: { model: 'prop_tree_oak_01', label: 'chêne de GTA', provisional: true }, fer: { model: 'prop_rock_1_a', label: 'rocher' } } } };
const BORNE = { id: 'borne', noun: 'borne', nounPlural: 'bornes', article: 'la', parent: 'enclos', placement: 'point' };
eq(PL.placeable(ZONE), true);
eq(PL.placeable({ placement: 'door' }), false, 'porte : T-106');
eq(PL.placeable({}), false);
eq(PL.childOf({ kinds: [ZONE, NODE] }, ZONE).id, 'node');
eq(PL.childOf({ kinds: [ZONE, { id: 'affiche', parent: 'zone' }] }, ZONE), null, 'enfant sans lieu : pas de liste');
eq(js(PL.cleanPlace('oriented', { x: 1, y: 2, z: 3, h: 90, r: 5, model: 'x' })), js({ x: 1, y: 2, z: 3, h: 90 }));
eq(js(PL.cleanPlace('circle', { x: 1, y: 2, r: 60 })), js({ x: 1, y: 2, z: 0, r: 60 }));
eq(PL.cleanPlace('circle', { x: NaN, y: 2 }), null);
eq(PL.cleanPlace('point', 'x'), null);
eq(PL.cleanPlace('polygon', { z: 1, points: [{ x: 0, y: 0 }, { x: 1, y: 0 }] }), null, 'deux sommets');
eq(js(PL.center(PL.cleanPlace('polygon', { z: 1, points: [{ x: 0, y: 0 }, { x: 4, y: 0 }, { x: 4, y: 4 }, { x: 0, y: 4 }] }))), js({ x: 2, y: 2 }));
eq(js(PL.center({ x: 5, y: 6, z: 1 })), js({ x: 5, y: 6 }));
eq(PL.lieuLine(ZONE, null), 'Pas encore placée.');
eq(PL.lieuLine(NODE, null), 'Pas encore placé.');
eq(sp(PL.lieuLine(ZONE, { x: 0, y: 0, r: 120 }, 32.4)), 'Posée à 32 m de vous, rayon 120 m', 'maquette');
eq(sp(PL.lieuLine(ZONE, { x: 0, y: 0, r: 81.5 }, 1500)), 'Posée à 1,5 km de vous, rayon 81,5 m');
eq(PL.lieuLine(ZONE, { x: 0, y: 0, r: 120 }), 'Posée, rayon 120 m', 'distance inconnue');
eq(sp(PL.lieuLine(NODE, { x: 0, y: 0, h: 0 }, 4)), 'Posé à 4 m de vous');
eq(PL.lieuLine({ placement: 'polygon', article: 'l\'', feminine: false }, { z: 0, points: [{}, {}, {}, {}, {}, {}] }), 'Posé, 6 sommets');
const nodes5 = ['live', 'live', 'live', 'live', 'new'].map((tone, i) => PL.cleanRow({ id: `n${i}`, title: `Chêne ${i + 1}`, tone, hint: '3 récoltes', place: { x: i, y: 0, z: 0, h: 0 } }, NODE));
eq(PL.countLine(nodes5, NODE), '5 points, dont 1 nouveau', 'maquette');
eq(PL.countLine(nodes5.map((r) => ({ ...r, tone: 'new' })), NODE), '5 points, dont 5 nouveaux');
eq(PL.countLine(nodes5.slice(0, 1), NODE), '1 point');
eq(PL.countLine(nodes5.slice(0, 2).map((r) => ({ ...r, tone: 'new' })), BORNE), '2 bornes, dont 2 nouvelles');
eq(PL.countLine([{ tone: 'removal' }], NODE), 'Aucun point pour l\'instant.', 'retrait non compté');
eq(PL.cleanRow({ id: 'x', tone: 'piege', title: 3 }, NODE).tone, 'live');
eq(PL.cleanRow({ id: 'x', title: 3 }, NODE).title, 'x', 'titre non textuel : identifiant');
eq(PL.cleanRow({ title: 'sans id' }, NODE), null);
eq(js(PL.mark({ tone: 'new' }, NODE)), js({ text: 'nouveau', tone: 'new' }));
eq(js(PL.mark({ tone: 'removal' }, BORNE)), js({ text: 'retirée', tone: 'removal' }));
eq(PL.mark({ tone: 'other' }, NODE).text, 'brouillon d\'un autre membre');
eq(PL.mark({ tone: 'live' }, NODE), null);
eq(['new', 'live', 'draft', 'removal', 'other'].map((tone) => PL.removal({ tone })).join(), 'discard,retire,retire,,');
eq(PL.stepStates(3, { placed: false, children: false }).join(), 'current,todo,todo');
eq(PL.stepStates(3, { placed: true, children: false }).join(), 'done,current,todo');
eq(PL.stepStates(3, { placed: true, children: true }).join(), 'done,done,current');
eq(PL.stepStates(3, { placed: false, children: true }).join(), 'current,todo,todo', 'des points sans zone placée : étape 1');
eq(js(PL.ghostOf(NODE, 'chene')), js({ model: 'prop_tree_oak_01', label: 'chêne de GTA', provisional: true }));
eq(PL.ghostOf(NODE, 'inconnu'), null);
eq(PL.ghostOf(NODE, 'toString'), null, 'clé héritée ignorée');
eq(js(PL.ghostOf({ ghost: { field: 'modele' } }, 'prop_sign_road_01a', { label: 'Panneau de bois', provisional: true })), js({ model: 'prop_sign_road_01a', label: 'Panneau de bois', provisional: true }));
eq(PL.lookLine(PL.ghostOf(NODE, 'chene')), 'Apparence : chêne de GTA, modèle provisoire. Il sera remplacé automatiquement quand le modèle médiéval sera ajouté.', 'maquette');
eq(PL.lookLine(PL.ghostOf(NODE, 'fer')), 'Apparence : rocher.');
eq(PL.lookLine(null), '');
eq(js(PL.startPayload({ editor: 'g:z', kind: ZONE, child: NODE, id: 'foret_brume', rev: 3, mode: 'children', title: 'Forêt de Brume', template: { s: { ressource: 'chene' } }, label: 'Chêne', ghost: { model: 'm' } })),
  js({ editor: 'g:z', kind: 'node', id: '', rev: 0, mode: 'children', shape: 'oriented', rules: NODE.rules, title: 'Forêt de Brume', parent: 'foret_brume', parentRev: 3, template: { s: { ressource: 'chene' } }, label: 'Chêne', ghost: { model: 'm' } }));
eq(js(PL.startPayload({ editor: 'g:z', kind: ZONE, child: NODE, id: 'foret_brume', rev: 3, mode: 'self', title: 'Forêt de Brume' })),
  js({ editor: 'g:z', kind: 'zone', id: 'foret_brume', rev: 3, mode: 'self', shape: 'circle', rules: ZONE.rules, title: 'Forêt de Brume' }));
eq(PL.upsert(nodes5, { id: 'n1', title: 'Chêne 9' }).length, 5, 'ligne remplacée');
eq(PL.upsert(nodes5, { id: 'n9' }).length, 6, 'ligne ajoutée');
eq(S.place.next(false, 'point'), 'Prochain point à poser');
eq(S.place.next(true, 'borne'), 'Prochaine borne à poser');
eq(S.place.many('points'), 'Poser des points');
eq(S.place.list('points', L.ofNoun(ZONE)), 'Points de la zone');
eq(S.place.put(L.theNoun(ZONE)), 'Placer la zone');
eq(S.place.move(L.theNoun(NODE)), 'Déplacer le point');

// Amorce de la page (T-157, web/boot.js) : bornes copiées de CODEPACK, noms, ordre, insertion unique, refus, sourceURL,
// compte rendu ; page factice dont les scripts insérés s'exécutent vraiment (vm), avec leurs erreurs
function bootEssais() {
  const WEB = path.join(__dirname, '..');
  const MODULE = path.join(WEB, '..');
  const bootCtx = vm.createContext({});
  vm.runInContext(`${fs.readFileSync(path.join(WEB, 'boot.js'), 'utf8')}\nthis.Boot = Boot;`, bootCtx);
  const B = bootCtx.Boot;
  const js = (v) => JSON.stringify(v);

  // bornes : copies exactes de VavaAtelier.CODEPACK (shared/constants.lua)
  const constants = fs.readFileSync(path.join(MODULE, 'shared', 'constants.lua'), 'utf8');
  const codepack = (constants.match(/VavaAtelier\.CODEPACK\s*=\s*\{([\s\S]*?)\n\}/) || [])[1] || '';
  for (const key of ['MAX_PIECES', 'MAX_BYTES', 'MAX_NAME', 'MAX_DEPTH']) {
    const lua = codepack.match(new RegExp(`\\b${key}\\s*=\\s*(\\d+)`));
    eq(Boolean(lua) && Number(lua[1]) === B.LIMITS[key], true, `${key} de boot.js égal à CODEPACK`);
  }

  // noms : la règle de codepack.validName
  for (const [name, kind] of [['web/css/style.css', 'css'], ['web/js/app.js', 'js'], ['web/js/view-home.js', 'js'], ['web/js/a_b-c.js', 'js'],
    ['a.js', 'js'], ['a/b/c/d/e.js', 'js'], [`web/js/${'a'.repeat(86)}.js`, 'js']]) eq(B.validName(name, kind), true, name);
  for (const [name, kind] of [['../x.js', 'js'], ['/x.js', 'js'], ['web\\js\\x.js', 'js'], ['web/js/A.js', 'js'], ['Web/js/a.js', 'js'],
    ['web/js/a.css', 'js'], ['web/css/style.css', 'js'], ['web/js/a.js', 'css'], ['web/js/a.js', 'html'], ['web/js/a.js', 'toString'],
    ['web/js/.js', 'js'], ['web/js/a.b.js', 'js'], ['web/js/a', 'js'], ['web//a.js', 'js'], ['web/js/', 'js'], ['', 'js'],
    ['a/b/c/d/e/f.js', 'js'], [`web/js/${'a'.repeat(87)}.js`, 'js'], ['web/js/é.js', 'js'], ['web/js/a.js ', 'js'], [7, 'js'], [null, 'js']]) {
    eq(B.validName(name, kind), false, String(name));
  }

  // Boot.accept (pur) : le fichier suivant attendu seulement
  const piece = (index, name = `web/js/f${index}.js`, kind = 'js', code = '') => ({ index, kind, name, code });
  const st = B.newState();
  eq(js(B.accept(st, piece(0, 'web/css/style.css', 'css', 'a{}'))), js({ ok: true }));
  eq(js(B.accept(st, piece(0, 'web/js/a.js', 'js', 'é'))), js({ ok: true }));
  eq(js(st), js(B.newState()), 'accept ne change rien');
  const reason = (state, message) => B.accept(state, message).reason;
  eq(reason(st, piece(1)), 'bad_index', 'premier index : 0');
  eq(reason(st, piece(-1)), 'bad_index');
  eq(reason(st, piece(0.5)), 'bad_index');
  eq(reason(st, { ...piece(0), index: '0' }), 'bad_index');
  eq(reason(st, piece(0, 'web/js/a.js', 'html')), 'bad_kind');
  eq(reason(st, piece(0, 'web/js/a.js', 'css')), 'bad_name', 'extension du genre');
  eq(reason(st, piece(0, '../a.js')), 'bad_name');
  eq(reason(st, piece(0, 'web/js/a.js', 'js', 7)), 'bad_code');
  eq(reason(st, { index: 0, kind: 'js', name: 'web/js/a.js' }), 'bad_code');
  eq(reason(st, null), 'not_object');
  eq(reason(st, [piece(0)]), 'not_object');
  eq(reason(st, 'x'), 'not_object');
  eq(reason(null, piece(0)), 'bad_state');
  const two = { ...B.newState(), pieces: [piece(0), piece(1)], size: 0 };
  eq(B.accept(two, piece(2)).ok, true);
  eq(reason(two, piece(1, 'web/js/x.js')), 'bad_index', 'pas de retour en arrière');
  eq(reason(two, piece(3)), 'bad_index', 'pas de trou');
  eq(reason(two, piece(2, 'web/js/f0.js')), 'duplicate');
  const full = { ...B.newState(), pieces: Array.from({ length: B.LIMITS.MAX_PIECES }, (_, i) => piece(i)) };
  eq(reason(full, piece(B.LIMITS.MAX_PIECES)), 'too_many');
  const heavy = { ...B.newState(), pieces: [piece(0)], size: B.LIMITS.MAX_BYTES - 2 };
  eq(B.accept(heavy, piece(1, 'web/js/b.js', 'js', 'ab')).ok, true, 'jusqu\'à MAX_BYTES compris');
  eq(reason(heavy, piece(1, 'web/js/b.js', 'js', 'abc')), 'too_large');
    eq(reason({ ...heavy, size: B.LIMITS.MAX_BYTES }, piece(1, 'web/js/b.js', 'js', 'a')), 'too_large');
  eq(reason({ ...two, ended: true }, piece(2)), 'ended');

  // Boot.finish (pur)
  eq(js(B.finish(two, { count: 2 })), js({ insert: true }));
  eq(js(B.finish(two, { count: 3 })), js({ insert: false, result: { ok: false, piece: 'refus' } }), 'compte faux');
  eq(js(B.finish(two, { count: '2' })), js({ insert: false, result: { ok: false, piece: 'refus' } }));
  eq(js(B.finish(two, null)), js({ insert: false, result: { ok: false, piece: 'refus' } }));
  eq(js(B.finish({ ...two, refused: 'bad_name' }, { count: 2 })), js({ insert: false, result: { ok: false, piece: 'refus' } }), 'un refus : rien');
  eq(js(B.finish(B.newState(), { count: 0 })), js({ insert: false, result: { ok: false, piece: 'refus' } }), 'aucun fichier');
  eq(js(B.finish({ ...two, ended: true, result: { ok: true, count: 2 } }, { count: 2 })), js({ insert: false, result: null }), 'une seule fin');

  // page factice : <style> et <script> enregistrés ; un <script> inséré s'exécute aussitôt dans la page (vm), une
  // erreur (syntaxe ou exécution) est signalée à l'évènement `error` de la fenêtre, comme dans le navigateur
  function fakePage() {
    const listeners = { message: [], error: [] };
    const page = vm.createContext({});
    page.window = page;
    page.addEventListener = (type, fn) => { (listeners[type] = listeners[type] || []).push(fn); };
    page.removeEventListener = (type, fn) => { listeners[type] = (listeners[type] || []).filter((f) => f !== fn); };
    const head = [], body = [], posts = [], logs = [];
    const doc = {
      createElement: (tag) => ({ tag, textContent: '' }),
      head: { appendChild: (el) => { head.push(el); return el; } },
      body: {
        appendChild: (el) => {
          body.push(el);
          if (el.tag === 'script') {
            try { vm.runInContext(el.textContent, page); } catch (error) {
              for (const fn of listeners.error) fn({ message: `${error.name}: ${error.message}`, lineno: 0 });
            }
          }
          return el;
        },
      },
    };
    const send = B.attach(page, doc, (name, data) => posts.push([name, data]), (text) => logs.push(text));
    const say = (action, payload) => send({ data: { action, payload } });
    return { page, head, body, posts, logs, say, listeners, send };
  }

  // amorce : « prête » au chargement et à chaque hello ; un seul écouteur de messages
  const p = fakePage();
  eq(js(p.posts), js([['pageReady', {}]]));
  eq(p.listeners.message.length, 1);
  p.say('hello', {});
  eq(js(p.posts[1]), js(['pageReady', {}]));
  // messages étrangers ignorés
  p.send({ data: null });
  p.send({ data: { action: 7 } });
  p.send({});
  p.say('open', {});
  eq(p.posts.length, 2);
  // relecture sécurité S-2 : un message venu d'un autre cadre (autre source que la page ou son parent) est ignoré ;
  // celui de la page elle-même ou de son parent est lu
  p.send({ data: { action: 'hello', payload: {} }, source: { autreCadre: true } });
  eq(p.posts.length, 2, 'hello venu d\'un autre cadre ignoré');
  p.send({ data: { action: 'hello', payload: {} }, source: p.page });
  eq(js(p.posts[2]), js(['pageReady', {}]), 'hello de la page elle-même lu');
  p.posts.pop();
  // feuille puis deux scripts, le second lit la constante de premier niveau du premier (comme des <script src>)
  const CSS = '.app { color: red; }\n';
  const A_JS = '\'use strict\';\nconst Premier = { n: 1 };\n';
  const B_JS = '\'use strict\';\nwindow.vu = Premier.n + 1; // fin sans saut de ligne';
  p.say('bootPiece', { index: 0, kind: 'css', name: 'web/css/style.css', code: CSS });
  p.say('bootPiece', { index: 1, kind: 'js', name: 'web/js/a.js', code: A_JS });
  p.say('bootPiece', { index: 2, kind: 'js', name: 'web/js/b.js', code: B_JS });
  eq([p.head.length, p.body.length, p.posts.length], [0, 0, 2], 'rien d\'inséré avant bootEnd');
  p.say('bootEnd', { count: 3 });
  eq(js(p.posts[2]), js(['booted', { ok: true, count: 3 }]));
  eq(js(p.head.map((el) => el.tag)), js(['style']));
  eq(p.head[0].textContent, `${CSS}\n/*# sourceURL=vava_atelier/web/css/style.css */`);
  eq(js(p.body.map((el) => el.tag)), js(['script', 'script']), 'dans l\'ordre');
  eq(p.body[0].textContent, `${A_JS}\n;window.__vavaBootMark(1);\n//# sourceURL=vava_atelier/web/js/a.js`);
  eq(p.body[1].textContent.startsWith(B_JS), true, 'rien ajouté devant : lignes d\'origine');
  eq(p.body[1].textContent.endsWith('\n//# sourceURL=vava_atelier/web/js/b.js'), true);
  eq(p.page.vu, 2, 'scripts exécutés dans l\'ordre, constantes partagées');
  eq(Object.prototype.hasOwnProperty.call(p.page, '__vavaBootMark'), false, 'marque retirée');
  eq(p.listeners.error.length, 0, 'écouteur d\'erreurs retiré');
  eq(p.logs.length, 0);
  // insertion unique : après bootEnd, ni bootPiece ni bootEnd ne sont relus ; hello rend le même compte rendu
  p.say('bootPiece', { index: 3, kind: 'js', name: 'web/js/c.js', code: 'window.vu = 99;' });
  p.say('bootPiece', { index: 0, kind: 'js', name: 'web/js/a2.js', code: 'window.vu = 98;' });
  p.say('bootEnd', { count: 1 });
  p.say('bootEnd', { count: 4 });
  eq([p.head.length, p.body.length, p.posts.length, p.page.vu], [1, 2, 3, 2], 'aucune réinsertion');
  p.say('hello', {});
  eq(js(p.posts[3]), js(['booted', { ok: true, count: 3 }]), 'page muette pour le Lua : même compte rendu');

  // un message mal formé : ignoré, rien d'inséré, booted { ok: false, piece: 'refus' }
  for (const bad of [
    { index: 1, kind: 'js', name: 'web/js/a.js', code: '' },               // hors d'ordre
    { index: 0, kind: 'js', name: 'web/js/a.css', code: '' },              // extension
    { index: 0, kind: 'html', name: 'web/a.html', code: '' },              // genre
    { index: 0, kind: 'js', name: '../../vava_admin/web/js/x.js', code: '' },
    { index: 0, kind: 'js', name: 'web/js/a.js', code: { toString: () => 'x' } },
    null,
  ]) {
    const q = fakePage();
    q.say('bootPiece', bad);
    q.say('bootPiece', { index: 0, kind: 'js', name: 'web/js/ok.js', code: 'window.vu = 1;' });
    q.say('bootEnd', { count: 1 });
    eq(js(q.posts.slice(1)), js([['booted', { ok: false, piece: 'refus' }]]), js(bad));
    eq([q.head.length, q.body.length, q.page.vu], [0, 0, undefined], 'rien d\'inséré');
    eq(q.logs.length >= 1 && q.logs[0].startsWith('[vava_atelier] fichier de la page refusé'), true);
  }
  // compte faux : rien d'inséré
  const r = fakePage();
  r.say('bootPiece', { index: 0, kind: 'js', name: 'web/js/a.js', code: 'window.vu = 1;' });
  r.say('bootEnd', { count: 2 });
  eq([js(r.posts[1]), r.body.length], [js(['booted', { ok: false, piece: 'refus' }]), 0]);
  r.say('hello', {});
  eq(js(r.posts[2]), js(['booted', { ok: false, piece: 'refus' }]));

  // un script en erreur (exécution, puis syntaxe) : on s'arrête à lui et on le nomme ; les suivants ne sont pas insérés
  for (const [code, word] of [['throw new Error(\'essai\');', 'essai'], ['const = ;', 'SyntaxError']]) {
    const e = fakePage();
    e.say('bootPiece', { index: 0, kind: 'js', name: 'web/js/a.js', code: 'window.vu = 1;' });
    e.say('bootPiece', { index: 1, kind: 'js', name: 'web/js/widgets.js', code });
    e.say('bootPiece', { index: 2, kind: 'js', name: 'web/js/c.js', code: 'window.vu = 3;' });
    e.say('bootEnd', { count: 3 });
    eq(js(e.posts[1]), js(['booted', { ok: false, piece: 'web/js/widgets.js' }]), word);
    eq([e.body.length, e.page.vu], [2, 1], 'arrêt au fichier fautif');
    eq(e.logs.length === 1 && e.logs[0].includes('web/js/widgets.js') && e.logs[0].includes(word), true, e.logs[0]);
    eq(Object.prototype.hasOwnProperty.call(e.page, '__vavaBootMark'), false);
    eq(e.listeners.error.length, 0);
  }

  // pages : l'amorce livrée garde le balisage de la page de développement et ne charge que boot.js ; la page de
  // développement charge la feuille et les scripts dans l'ordre de vava_conseil_web, chacun présent, aucun oublié
  const lf = (text) => text.replace(/\r\n/g, '\n');   // copie de travail en CRLF sous Windows (core.autocrlf)
  const amorce = lf(fs.readFileSync(path.join(WEB, 'index.html'), 'utf8'));
  const dev = lf(fs.readFileSync(path.join(WEB, 'dev', 'index.html'), 'utf8'));
  const markup = (html) => (html.match(/<div id="app"[\s\S]*?\n {2}<\/div>\n/) || [''])[0];
  eq(markup(amorce).length > 0 && markup(amorce) === markup(dev), true, 'même balisage');
  eq(js(Array.from(amorce.matchAll(/<script\b[^>]*>/g), (m) => m[0])), js(['<script src="boot.js">']));
  eq(js(Array.from(amorce.matchAll(/<link\b[^>]*>/g), (m) => m[0])), js(['<link rel="stylesheet" href="nui://vava_ui/web/css/vava_ui.css">']));
  eq(/devmock|horsjeu|GetParentResourceName|css\/style|js\//.test(amorce.replace(/<!--[\s\S]*?-->/g, '')), false);
  const devOrder = Array.from(dev.matchAll(/(?:href|src)="\.\.\/((?:css|js)\/[^"]+)"/g), (m) => `web/${m[1]}`);
  const onDisk = [...fs.readdirSync(path.join(WEB, 'css')).filter((f) => f.endsWith('.css')).map((f) => `web/css/${f}`),
    ...fs.readdirSync(path.join(WEB, 'js')).filter((f) => f.endsWith('.js')).map((f) => `web/js/${f}`)];
  eq(js([...devOrder].sort()), js(onDisk.sort()), 'chaque fichier de la page, une fois');
  // directive en table, ou une ligne par fichier (spec § 3.2) ; commentaires Lua retirés
  const manifest = fs.readFileSync(path.join(MODULE, 'fxmanifest.lua'), 'utf8').replace(/--\[(=*)\[[\s\S]*?\]\1\]/g, '').replace(/--[^\n]*/g, '');
  const block = (manifest.match(/\bvava_conseil_web\s*\{([^}]*)\}/) || [])[1];
  const listed = block !== undefined ? Array.from(block.matchAll(/'([^']+)'/g), (m) => m[1])
    : Array.from(manifest.matchAll(/\bvava_conseil_web\s*'([^']+)'/g), (m) => m[1]);
  eq(listed.length > 0, true, 'directive vava_conseil_web au manifeste');
  eq(js(listed), js(devOrder), 'ordre de vava_conseil_web = ordre de web/dev/index.html');
  for (const name of devOrder) eq(B.validName(name, name.endsWith('.css') ? 'css' : 'js'), true, name);
}

// app.js chargé sur une page factice : libellés pris dans `read` sans RPC options, étiquettes renouvelées à chaque
// accueil, confirmation de sortie dès qu'une valeur a changé depuis l'ouverture, même après « Vérifier »
async function appEssais() {
  const posts = [], asked = [];
  let homeTags = { 'm:a': { text: '3 panneaux' } }, current = '', homeModel = null, env = null, onMessage = null;
  const node = () => ({ hidden: false, replaceChildren() {}, classList: { toggle() {}, remove() {} } });
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
    STRINGS: S, errorText: ctx.errorText, Format: F, Lifecycle: L, Placing: PL, window: {}, setTimeout, clearTimeout,
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
eq(js([nb(takeBox.title), takeBox.text, takeBox.cancel, takeBox.ok]), js(['Reprendre le brouillon de Sénéchal Aldric Morn ?', 'La reprise sera inscrite au journal du Conseil.', 'Rester', 'Reprendre le brouillon']));
eq(js([nb(S.confirm.discard.title), S.confirm.discard.text, S.confirm.discard.cancel, S.confirm.discard.ok]), js(['Abandonner ce brouillon ?', 'Rien de ce qu\'il contient ne sera gardé.', 'Garder', 'Abandonner']));

// Historique : étiquettes, version rétablie, retrait, auteur et âge, versions illisibles écartées
const rows = L.history({ 1: { version: 6, status: 'published', removal: 0, summary: 'Hauteur de 1,5 m à 2 m', author: 'Sénéchal Aldric Morn', when: 'il y a 2 h' },
  2: { version: 4, status: 'archived', removal: 0, restoredFrom: 2, author: 'Souveraine Ysolde', when: 'hier' },
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
    publish: () => ({ done: true, version: 3, state: { label: 'Version 3, publiée', tone: 'live' }, footer: [] }),
    take: () => ({ done: true, rev: 6, state: { label: 'Brouillon', tone: 'draft' }, footer: [] }),
  };
  const stub = () => ({ el: {}, focus() {}, setData() {}, setError() {}, hideOk() {}, setBusy() {}, flashOk() {}, setCompare() {}, setTitle() {}, setReadOnly() {},
    setState() {}, setFooter: (f) => footers.push(f), setNotice: (text) => notices.push(text) });
  const page = vm.createContext({
    STRINGS: S, errorText: ctx.errorText, Format: F, Lifecycle: L, Placing: PL, window: {}, setTimeout, clearTimeout,
    document: { getElementById: () => ({ hidden: false, replaceChildren() {}, classList: { toggle() {}, remove() {} } }), addEventListener() {} },
    Bridge: { inGame: false, onMessage: (h) => { onMessage = h; }, post: async (name, data) => {
      posts.push([name, data]);
      if (name === 'trial' && data.rev !== 4) return { ok: false, error: 'stale', text: 'Texte du refus reçu du serveur.' };
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
  eq(notices[0], 'Texte du refus reçu du serveur.', 'avis : texte du serveur');

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

// placement (T-102) : liste des enfants lue à l'ouverture, visée demandée au jeu avec le modèle, poses et refus reçus,
// bandeau et barre des touches de la visée, essai joué, arrêt de la visée en quittant la fiche, corbeille d'une ligne
async function placementEssais() {
  const posts = [], asked = [], banners = [], keysShown = [], steps = [], messages = [], built = [];
  let onMessage = null, snap = 'a', rows = [];
  const descriptor = { label: 'Récolte', stored: true, hasTrial: true, trialPlay: true, texts: { trialLine: 'Mode essai : vous seul voyez ces points' },
    kinds: [{ ...ZONE, layout: 'side', form: { titleField: 'nom', fields: [{ id: 'nom', label: 'Nom' }] } }, { ...NODE, layout: 'side', form: { titleField: 'nom', fields: [] } }] };
  const replies = {
    editor: () => ({ version: 'e1', descriptor }),
    read: (d) => ({ title: d.id === 'chene_5' ? 'Chêne 5' : 'Forêt de Brume', values: { s: { nom: 'Forêt de Brume' } }, rev: d.id === 'chene_5' ? 2 : 3, place: { x: 1, y: 2, z: 3, r: 120 }, distance: 32,
      state: { label: 'Brouillon', tone: 'draft' }, footer: [B('save', 'Enregistrer le brouillon'), B('trial', 'Tester la récolte'), B('publish', 'Publier la zone', { primary: true })] }),
    children: () => ({ self: { place: { x: 1, y: 2, z: 3, r: 120 } }, rows: [{ kind: 'node', id: 'chene_1', title: 'Chêne 1', tone: 'live', hint: '3 récoltes', place: { x: 1, y: 2, z: 3, h: 0 } }] }),
    save: (d) => ({ done: true, id: d.id || 'bois_des_essais', rev: d.rev + 1, title: 'Bois des Essais', state: { label: 'Brouillon', tone: 'draft' }, footer: [] }),
    trial: () => ({ done: true, rev: 3, state: { label: 'Essai, version 2', tone: 'trial' }, footer: [] }),
    discard: () => ({ done: true, gone: true }),
  };
  const fakePlacer = (model, actions) => {
    const p = { model, actions, place: model.place, rows: [], el: {},
      setPlace(value, far) { p.place = value; p.far = far; }, setRows(got) { p.rows = got; rows = got; }, upsert(row) { p.rows = p.rows.concat([row]); }, drop(id) { p.rows = p.rows.filter((r) => r.id !== id); },
      failed() {}, progress: () => ({ placed: Boolean(p.place), children: p.rows.length > 0 }), message: (mode, text) => messages.push([mode, text]),
      template: () => ({ s: { ressource: 'chene' }, n: { charges: 3 } }), ghost: () => ({ model: 'prop_tree_oak_01' }), label: () => 'Chêne' };
    built.push(p);
    return p;
  };
  const stub = () => ({ el: {}, focus() {}, setData() {}, setError() {}, hideOk() {}, setBusy() {}, flashOk() {}, setCompare() {}, setTitle() {}, setReadOnly() {},
    setState() {}, setFooter() {}, setNotice() {}, setSteps: (s) => steps.push(s.join()) });
  const page = vm.createContext({
    STRINGS: S, errorText: ctx.errorText, Format: F, Lifecycle: L, Placing: { ...PL, build: fakePlacer }, window: {}, setTimeout, clearTimeout,
    document: { getElementById: () => ({ hidden: false, replaceChildren() {}, classList: { toggle() {}, remove() {} } }), addEventListener() {} },
    Bridge: { inGame: false, onMessage: (h) => { onMessage = h; }, post: async (name, data) => { posts.push([name, data]); return { ok: true, data: replies[name] ? replies[name](data) : {} }; } },
    UI: { Toast: { show() {} }, Confirm: { ask: async (box) => { asked.push(box); return true; }, isOpen: () => false, cancel() {} },
      Picker: { close() {}, isOpen: () => false }, Banner: { show: (...a) => banners.push(a), hide() {} }, Keys: { show: (k) => keysShown.push(k), hide: () => keysShown.push(null) } },
    Form: { build: (k, v, env) => ({ titleField: 'nom', between: env.between, snapshot: () => snap, packet: () => ({ s: { nom: snap } }), validate: () => true, clear() {}, focusFirst() {}, showErrors() {}, focusFirstError() {}, title: () => 'Forêt de Brume' }) },
    HomeView: { render: stub }, ListView: { render: stub }, EntryView: { render: stub }, JournalView: { render: stub }, HistoryView: { render: stub },
  });
  vm.runInContext(fs.readFileSync(path.join(JS, 'app.js'), 'utf8'), page);
  const A = page.window.Atelier;
  const names = () => posts.map((x) => x[0]);
  const tick = () => new Promise((resolve) => setImmediate(resolve));
  onMessage('open', { version: 'h1', content: { families: [], cards: [] }, tags: {}, drafts: [], journal: [] });
  await tick();

  // ouverture : lieu de read, enfants demandés une fois, étapes cochées
  posts.length = 0;
  await A.openEntry('g:z', 'zone', 'foret_brume');
  await tick();
  eq(js(names()), js(['editor', 'read', 'children']));
  eq(js(posts[2][1]), js({ editor: 'g:z', kind: 'zone', id: 'foret_brume' }));
  const zone = built[built.length - 1];
  eq([zone.model.child.id, zone.place.r, zone.model.distance, rows.length], ['node', 120, 32, 1]);
  eq(steps[steps.length - 1], 'done,done,current');

  // « Poser des points » : fiche intacte, rien d'enregistré ; visée demandée avec le modèle
  posts.length = 0;
  await zone.actions.start('children');
  eq(js(posts), js([['placeStart', { editor: 'g:z', kind: 'node', id: '', rev: 0, mode: 'children', shape: 'oriented', rules: NODE.rules, title: 'Forêt de Brume',
    parent: 'foret_brume', parentRev: 3, template: { s: { ressource: 'chene' }, n: { charges: 3 } }, label: 'Chêne', ghost: { model: 'prop_tree_oak_01' } }]]));

  // visée : bandeau d'édition, barre du mode ; touches de la page ignorées
  const keys = [{ keys: ['Clic'], label: 'Poser ici' }, { keys: ['Ctrl', 'Z'], label: 'Annuler' }];
  onMessage('placing', { on: true, mode: 'children', shape: 'oriented', keys });
  eq(js(banners[banners.length - 1].slice(0, 2)), js(['Récolte', S.place.editLine]));
  eq(js(keysShown[keysShown.length - 1]), js(keys));

  // pose reçue : ligne ajoutée, révision et pied de la fiche parent repris ; refus sous le bloc
  onMessage('placed', { kind: 'node', id: 'chene_5', rev: 1, title: 'Chêne 5', row: { kind: 'node', id: 'chene_5', title: 'Chêne 5', tone: 'new' },
    parent: { id: 'foret_brume', rev: 4, state: { label: 'Brouillon', tone: 'draft' }, footer: [] } });
  eq([A.state.entry.rev, zone.rows.length], [4, 2]);
  onMessage('placed', { kind: 'node', id: 'chene_6', rev: 1, row: { kind: 'node', id: 'chene_6', title: 'Chêne 6', tone: 'new' } });
  eq([A.state.entry.rev, zone.rows.length], [4, 3], 'parent absent : ligne ajoutée pendant la visée des points');
  onMessage('placeRefused', { text: 'Trop près de « Chêne 2 » (1,4 m).' });
  eq(js(messages[messages.length - 1]), js(['children', 'Trop près de « Chêne 2 » (1,4 m).']));
  onMessage('undone', { kind: 'node', id: 'chene_6', gone: true });
  eq(zone.rows.length, 2, 'annulation : ligne retirée');
  onMessage('placing', { on: false });
  eq(keysShown[keysShown.length - 1], null, 'fin de visée : barre cachée');

  // déplacer la zone : lieu repris de la pose, distance oubliée
  posts.length = 0;
  await zone.actions.start('self');
  eq(js(posts[0][1]), js({ editor: 'g:z', kind: 'zone', id: 'foret_brume', rev: 4, mode: 'self', shape: 'circle', rules: ZONE.rules, title: 'Forêt de Brume' }));
  onMessage('placing', { on: true, mode: 'self', shape: 'circle', keys });
  onMessage('placed', { kind: 'zone', id: 'foret_brume', rev: 5, place: { x: 9, y: 9, z: 3, r: 140 }, state: { label: 'Brouillon', tone: 'draft' }, footer: [] });
  eq([A.state.entry.rev, zone.place.r, zone.far], [5, 140, null]);

  // quitter la fiche pendant la visée : visée arrêtée
  posts.length = 0;
  await A.back();
  eq(names().includes('placeStop'), true);
  eq(A.state.placing.on, false);

  // corbeille d'un point jamais publié : boîte, révision relue, abandon, liste relue
  await A.openEntry('g:z', 'zone', 'foret_brume');
  await tick();
  const again = built[built.length - 1];
  posts.length = 0;
  asked.length = 0;
  await again.actions.remove({ kind: 'node', id: 'chene_5', title: 'Chêne 5', tone: 'new' }, 'discard');
  eq(asked.length, 1);
  eq(js(posts.slice(0, 3)), js([['read', { editor: 'g:z', kind: 'node', id: 'chene_5' }], ['discard', { editor: 'g:z', kind: 'node', id: 'chene_5', rev: 2 }], ['children', { editor: 'g:z', kind: 'zone', id: 'foret_brume' }]]));

  // ouvrir un point depuis la liste, puis revenir : la fiche de la zone
  posts.length = 0;
  await again.actions.open({ kind: 'node', id: 'chene_5' });
  eq([A.state.entry.kind.id, A.state.entry.id], ['node', 'chene_5']);
  await tick();
  eq(names().includes('children'), false, 'relecture réseau R-4 : un point ouvert ne charge pas les lieux de ses frères');
  await A.back();
  await tick();
  eq([A.state.entry.kind.id, A.state.entry.id], ['zone', 'foret_brume']);

  // relecture réseau R-10 : trois poses d'un autre membre (avis `saved`) font une seule relecture, 800 ms après la dernière
  posts.length = 0;
  for (let i = 0; i < 3; i += 1) onMessage('entryChanged', { editor: 'g:z', kind: 'zone', id: 'foret_brume', what: 'saved' });
  eq(posts.length, 0, 'aucune relecture tout de suite');
  await new Promise((resolve) => setTimeout(resolve, 900));
  await tick();
  eq(names().filter((n) => n === 'read').length, 1, 'une seule relecture groupée');
  await tick();

  // zone nouvelle : « Placer la zone » enregistre d'abord
  await A.openEntry('g:z', 'zone', '');
  posts.length = 0;
  await built[built.length - 1].actions.start('self');
  eq(js(names()), js(['save', 'placeStart']));
  eq(posts[1][1].id, 'bois_des_essais');

  // essai joué : la page demande à se mettre de côté ; bandeau seul, sans retour
  posts.length = 0;
  await A.run('trial');
  eq(names().slice(-1)[0], 'suspend');
  onMessage('suspended', { on: true });
  const last = banners[banners.length - 1];
  eq([last[1], last[2]], ['Mode essai : vous seul voyez ces points · F9 : revenir à l\'Atelier', null]);
  eq(keysShown[keysShown.length - 1], null);
  onMessage('suspended', { on: false });
  eq(A.state.suspended, false);
}

bootEssais();
appEssais().then(cycleEssais).then(placementEssais).then(() => console.log(`${passed} essais passés`), (error) => { console.error(error); process.exitCode = 1; });
