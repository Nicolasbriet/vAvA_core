/*
 * vava_pause/web/dev/essais.js
 * Rôle : essais des règles pures de la page (js/model.js et js/strings.js) et de son poids livré. Sans dépendance :
 *        `node modules/vava_pause/web/dev/essais.js` (code de sortie 1 au moindre échec), lancé par scripts/verifier.sh.
 *        Jamais livré.
 * Dépendances : js/strings.js, js/model.js (chargés par require, comme module.exports)
 */
'use strict';

const fs = require('fs');
const path = require('path');
const assert = require('assert');

const web = path.join(__dirname, '..');
const S = require('../js/strings.js');
const M = require('../js/model.js');

let passed = 0;
let failed = 0;
function test(name, fn) {
  try {
    fn();
    passed += 1;
  } catch (error) {
    failed += 1;
    console.log(`ÉCHEC vava_pause : ${name}\n  ${error.message}`);
  }
}
const eq = (actual, expected) => assert.deepStrictEqual(actual, expected);

const skill = (label, level, rank, rankLabel) => ({ id: label.toLowerCase(), label, level, rank, rankLabel });
const sample = [
  skill('Herboristerie', 46, 'compagnon', 'Compagnon'), skill('Alchimie', 31, 'apprenti', 'Apprenti'),
  skill('Cuisine', 22, 'apprenti', 'Apprenti'), skill('Agriculture', 12, 'novice', 'Novice'),
  skill('Minage', 7, 'novice', 'Novice'), skill('Forge', 5, 'novice', 'Novice'),
];

// Bannière ------------------------------------------------------------------------------------------------

test('entrées : sept rubriques et un filet hors terre', () => {
  eq(M.entries(false).map((entry) => entry.id), ['reprendre', 'personnage', 'codex', 'carte', 'reglages', 'conseil', 'sep', 'parametres', 'quitter']);
});
test('à terre : Reprendre, Paramètres du jeu, Quitter seulement (absentes, pas grisées)', () => {
  eq(M.entries(true).map((entry) => entry.id), ['reprendre', 'sep', 'parametres', 'quitter']);
});
test('rubrique de départ : panneau demandé, sinon Personnage ; à terre : aucune', () => {
  eq(M.startRubric('reglages', false), 'reglages');
  eq(M.startRubric('codex', false), 'personnage');
  eq(M.startRubric('quitter', false), 'personnage');
  eq(M.startRubric('<b>', false), 'personnage');
  eq(M.startRubric('conseil', true), null);
});
test('couleurs : seul #rrggbb passe', () => {
  eq(M.color('#6E2116'), '#6e2116');
  for (const bad of ['#fff', 'red', '#6e2116;background:url(x)', 'url(x)', '', null, 12]) eq(M.color(bad), null);
});
test('teintes : royales par défaut, de la confrérie si valides, une couleur invalide reprend la royale', () => {
  eq(M.banner(null, null), { cloth: '#6e2116', clothDark: '#4a150d', field: '#273b56', charge: 'croix' });
  const guild = M.guild({ label: 'Guérisseurs d\'Eldoria', short: 'Guérisseurs', grade: 'Soignante', cloth: '#2c4527', clothDark: 'nope', field: '#5c1a12', charge: 'licorne' });
  eq(M.banner(null, guild), { cloth: '#2c4527', clothDark: '#4a150d', field: '#5c1a12', charge: 'croix' });
  eq(M.banner({ cloth: '#111111', charge: 'inconnu' }, null).cloth, '#111111');
  eq(M.banner({ charge: 'inconnu' }, null).charge, 'croix');
});
test('confrérie : sans libellé ou nom court, aucune ; bornes de longueur', () => {
  eq(M.guild({ short: 'X' }), null);
  eq(M.guild('Guérisseurs'), null);
  const long = M.guild({ label: 'L'.repeat(80), short: 'S'.repeat(30) });
  eq([long.label.length, long.short.length, long.grade], [48, 16, null]);
});

// Personnage ----------------------------------------------------------------------------------------------

test('savoir-faire : lignes malformées écartées, niveau borné', () => {
  eq(M.skills([{ label: 'A', level: 140 }, { label: 'B' }, null, { level: 3 }, { label: 'C', level: -2 }]).map((s) => [s.label, s.level]), [['A', 100], ['C', 0]]);
  eq(M.skills('nope'), []);
});
test('métier principal : plus haut niveau, égalité à l\'ordre reçu', () => {
  eq(M.mainSkill([skill('A', 30), skill('B', 30), skill('C', 10)]).label, 'A');
  eq(M.mainSkill([]), null);
});
test('sous-titre : confrérie, sinon rang en métier, sinon nouveau venu', () => {
  eq(M.subtitle(sample, { label: 'Guérisseurs d\'Eldoria', grade: 'Soignante' }), 'Soignante, Guérisseurs d\'Eldoria');
  eq(M.subtitle(sample, { label: 'Guérisseurs d\'Eldoria', grade: null }), 'Guérisseurs d\'Eldoria');
  eq(M.subtitle(sample, null), 'Compagnon en herboristerie');
  eq(M.subtitle([skill('Forge', 19, 'novice', 'Novice')], null), 'Nouveau venu dans le royaume');
  eq(M.subtitle([], null), 'Nouveau venu dans le royaume');
});
test('tableau : au-dessus de Novice, six au plus', () => {
  const view = M.table(sample, false);
  eq(view.rows.map((s) => s.label), ['Herboristerie', 'Alchimie', 'Cuisine']);
  eq([view.hidden, view.hiddenNovice], [3, 3]);
  const many = Array.from({ length: 9 }, (_, i) => skill(`S${i}`, 90 - i * 5));
  const capped = M.table(many, false);
  eq([capped.rows.length, capped.hidden, capped.hiddenNovice], [6, 3, 0]);
});
test('tableau : aucun au-dessus de Novice → les quatre plus hauts ; tout déplié', () => {
  const novices = [skill('A', 3), skill('B', 9), skill('C', 1), skill('D', 9), skill('E', 0)];
  eq(M.table(novices, false).rows.map((s) => s.label), ['B', 'D', 'A', 'C']);
  eq(M.table(novices, true).rows.length, 5);
  eq(M.table(novices, true).hidden, 0);
});
test('nombres en lettres jusqu\'à vingt', () => {
  eq([M.numberWord(1), M.numberWord(13), M.numberWord(17), M.numberWord(20), M.numberWord(21)], ['un', 'treize', 'dix-sept', 'vingt', '21']);
});
test('phrase sous le tableau', () => {
  eq(M.restLine(0, 0), null);
  eq(M.restLine(1, 1), 'L\'autre savoir-faire est au rang Novice.');
  eq(M.restLine(9, 9), 'Les neuf autres savoir-faire sont au rang Novice.');
  eq(M.restLine(3, 1), 'Trois autres savoir-faire sont inscrits au registre.');
  eq(S.personnage.showAll(M.numberWord(13)), 'voir les treize savoir-faire');
});
test('jauges : part de 0 à 1, absente si la valeur manque', () => {
  eq([M.fraction(0.82, 1), M.fraction(64, 100), M.fraction(140, 100), M.fraction(-1, 100), M.fraction(undefined, 1), M.fraction(NaN, 1)], [0.82, 0.64, 1, 0, null, null]);
});

// Le Conseil ----------------------------------------------------------------------------------------------

test('encart de la demande', () => {
  eq(M.requestCard({ id: 12, state: 'sent', age: 190 }), { tone: 'sent', title: 'Votre demande n° 12 est entre les mains du Conseil.', text: 'Envoyée il y a 3 min. Un membre la prendra dès que possible.' });
  eq(M.requestCard({ id: 12, state: 'claimed' }).title, 'Votre demande précédente est prise en charge.');
  eq(M.requestCard({ state: 'closed' }).text, 'Si quelque chose demeure, écrivez de nouveau.');
  eq(M.requestCard({ state: 'autre' }), null);
  eq(M.requestCard(null), null);
  eq(M.requestCard({ id: '<b>', state: 'sent', age: 0 }).title, 'Votre demande n° ? est entre les mains du Conseil.');
});
test('âge d\'une demande', () => {
  eq([M.ageText(0), M.ageText(59), M.ageText(60), M.ageText(3599), M.ageText(7300), M.ageText(-5)], ['à l\'instant', 'à l\'instant', 'il y a 1 min', 'il y a 59 min', 'il y a 2 h', 'à l\'instant']);
});
test('refus du Conseil', () => {
  eq(M.councilError('too_soon', 49.2), 'Patientez encore 50 s avant une nouvelle demande.');
  eq(M.councilError('too_many'), 'Vos demandes attendent déjà le Conseil : patientez qu\'il y réponde.');
  eq(M.councilError('too_short'), 'Quelques mots de plus, s\'il vous plaît.');
  eq(M.councilError('council_unavailable'), 'Le Conseil ne siège pas en ce moment : revenez plus tard.');
  eq(M.councilError('full'), 'La demande n\'a pas pu partir.');
  eq(M.councilError(undefined), 'La demande n\'a pas pu partir.');
});
test('octets UTF-8 et coupe sans casser un caractère', () => {
  eq([M.bytes('abc'), M.bytes('é'), M.bytes('€'), M.bytes('𝄞')], [3, 2, 3, 4]);
  eq(M.clipBytes('é'.repeat(300), 500).length, 250);
  eq(M.clipBytes('aé', 2), 'a');
  eq(M.bytes(M.clipBytes('𝄞'.repeat(200), 500)), 500);
});
test('avant envoi : 10 caractères au moins (accents comptés comme un), nature connue', () => {
  eq(M.councilCheck('question', 'ééééééé é'), 'too_short');
  eq(M.councilCheck('question', 'éééééééé é'), null);
  eq(M.councilCheck('question', '   aide      moi   '), 'too_short');
  eq(M.councilCheck('vol', 'Un message assez long.'), 'invalid_kind');
  eq(M.councilCheck('bug', 'x'.repeat(501)), 'invalid_text');
  eq(M.positionForced('player'), true);
  eq(M.positionForced('question'), false);
});

// Plaque, réglages, touches ----------------------------------------------------------------------------

test('plaque : parties absentes omises, habitants mis en forme', () => {
  eq(M.plaque({ plaque: { time: 'Soir, 19 h', season: 'Automne' } }, { people: 28 }), ['Soir, 19 h', 'Automne', '28 habitants présents']);
  eq(M.plaque({ plaque: { time: 'Nuit, 2 h' } }, { people: 1 }), ['Nuit, 2 h', '1 habitant présent']);
  eq(M.plaque({ plaque: {} }, { plaque: { people: '3 habitants présents' } }), ['3 habitants présents']);
  eq(M.plaque(null, null), []);
  eq(M.plaque({ plaque: { time: 'Matin, 8 h' } }, { people: -1 }), ['Matin, 8 h']);
});
test('portée de la voix et échelle', () => {
  eq([M.meters(5), M.meters(1.5), M.meters(-1), M.meters('5')], ['5 m', '1,5 m', null, null]);
  eq([M.scale(115), M.scale(90), M.scale(100), M.scale(500), M.scale('115')], [1.15, 0.9, 1, 1, 1]);
  eq([M.rollMs(0), M.rollMs(250), M.rollMs(99999), M.rollMs(undefined)], [0, 250, 1000, 250]);
});
test('réglages : définitions relues, valeurs hors liste → défaut', () => {
  const defs = M.settingDefs([
    { key: 'ui.scale', tab: 'interface', kind: 'choice', default: 100, choices: [90, 100, 115], labels: ['90 %', '100 %', '115 %'], label: 'Taille' },
    { key: 'voice.circle', tab: 'voix', kind: 'lever', default: true, label: 'Cercle' },
    { key: 'x', tab: 'ailleurs', kind: 'lever' }, { key: 'y', tab: 'voix', kind: 'curseur' }, { tab: 'voix', kind: 'lever' },
    { key: 'z', tab: 'interface', kind: 'choice', choices: [] },
  ]);
  eq(defs.map((def) => def.key), ['ui.scale', 'voice.circle']);
  eq(M.settingValue(defs[0], { 'ui.scale': 115 }), 115);
  eq(M.settingValue(defs[0], { 'ui.scale': '115' }), 100);
  eq(M.settingValue(defs[1], { 'voice.circle': false }), false);
  eq(M.settingValue(defs[1], { 'voice.circle': 'non' }), true);
  eq(M.settingValue(defs[1], null), true);
});
test('touches : groupées par chapitre, touche liée d\'abord, entrée malformée écartée', () => {
  const keys = [
    { name: 'codex', label: 'Ouvrir le Codex', chapter: 'Codex', module: 'vava_codex', key: 'F1' },
    { name: 'vava_skills', label: 'Livre', chapter: 'Compétences', module: 'vava_skills', key: 'K' },
    { name: 'roue', label: 'Roue', chapter: 'Compétences', module: 'vava_magic', key: 'TAB', keyDisplay: 'Tab', hold: true },
    { label: 'sans nom' }, 'nope',
    { name: 'vava_voice_portee', label: 'Portée', chapter: 'Voix', module: 'vava_voice', key: 'Z' },
  ];
  const groups = M.keyGroups(keys, { vava_skills: 'L' });
  eq(groups.map((group) => [group.chapter, group.rows.map((row) => row.key)]), [['Codex', ['F1']], ['Compétences', ['L', 'Tab']], ['Voix', ['Z']]]);
  eq(groups[1].rows[1].hold, true);
  eq(M.voiceKey(keys, { vava_voice_portee: 'V' }), 'V');
  eq(M.voiceKey(keys.slice(0, 3), {}), null);
});

// Textes et poids -------------------------------------------------------------------------------------------

test('textes : commandes en bas-de-casse comme la spec les écrit', () => {
  eq([S.personnage.sheet, S.carte.open, S.reglages.reset, S.reglages.voiceSettings, S.reglages.keysChange],
    ['ouvrir la fiche complète', 'ouvrir la carte (provisoire)', 'revenir aux valeurs par défaut', 'ouvrir les paramètres du jeu', 'changer une touche']);
  eq([S.conseil.send, S.quitter.stay, S.quitter.disconnect, S.quitter.quit], ['Sceller et envoyer', 'Rester à Eldoria', 'Se déconnecter', 'Quitter le jeu']);
  eq(Object.values(S.rubrics), ['Reprendre', 'Personnage', 'Codex', 'Carte', 'Réglages', 'Le Conseil', 'Paramètres du jeu', 'Quitter Eldoria']);
});

test('page : aucun innerHTML, insertAdjacentHTML ni outerHTML ; aucun filtre, flou ni color-mix ; aucune adresse externe', () => {
  for (const file of fs.readdirSync(path.join(web, 'js'))) {
    const source = fs.readFileSync(path.join(web, 'js', file), 'utf8');
    assert.ok(!/innerHTML|outerHTML|insertAdjacentHTML|document\.write/.test(source), `${file} : écriture de HTML`);
  }
  const css = fs.readFileSync(path.join(web, 'css', 'pause.css'), 'utf8').replace(/\/\*[\s\S]*?\*\//g, '');
  assert.ok(!/(^|[^-])filter\s*:|backdrop-filter|blur\(|color-mix|:has\(/.test(css), 'pause.css : filtre, flou, color-mix ou :has');
  for (const file of ['index.html', 'css/pause.css']) {
    assert.ok(!/https?:\/\/(?!www\.w3\.org)/.test(fs.readFileSync(path.join(web, file), 'utf8')), `${file} : adresse externe`);
  }
});

// fichiers livrés : ceux des `files` du manifeste (web/index.html, web/css/*.css, web/js/*.js, web/img/*.svg)
test('poids de la page livrée ≤ 100 Ko', () => {
  const files = ['index.html'];
  for (const [dir, ext] of [['css', '.css'], ['js', '.js'], ['img', '.svg']]) {
    for (const file of fs.readdirSync(path.join(web, dir))) if (file.endsWith(ext)) files.push(`${dir}/${file}`);
  }
  const total = files.reduce((sum, file) => sum + fs.statSync(path.join(web, file)).size, 0);
  console.log(`vava_pause : page livrée ${total} octets (${files.length} fichiers)`);
  assert.ok(total <= 100 * 1024, `${total} octets`);
});

console.log(`vava_pause : ${passed} essais réussis, ${failed} en échec`);
if (failed > 0) process.exit(1);
