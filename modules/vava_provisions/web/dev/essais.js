'use strict';
/*
 * vava_provisions/web/dev/essais.js
 * Rôle : essais de la lecture des messages de l'invite (ProvisionsPrompt.read, .text de js/app.js), hors jeu, sans
 *        navigateur : `node modules/vava_provisions/web/dev/essais.js` (code de sortie 1 au moindre échec). Jamais
 *        livré (dossier dev/).
 */

const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert');

const ctx = vm.createContext({});
vm.runInContext(`${fs.readFileSync(path.join(__dirname, '..', 'js', 'app.js'), 'utf8')}\nthis.P = ProvisionsPrompt;`, ctx);
const { read, text } = ctx.P;

let passed = 0;
const eq = (actual, expected, label) => { assert.deepStrictEqual(JSON.parse(JSON.stringify(actual)), expected, label); passed += 1; };

try {
  // message de la spec (à plat)
  eq(read({ action: 'prompt', key: 'E', verb: 'Puiser ou boire', label: 'Fontaine du bourg' }),
    { hidden: false, key: 'E', verb: 'Puiser ou boire', label: 'Fontaine du bourg' }, 'invite');
  eq(read({ action: 'prompt', hidden: true }), { hidden: true }, 'cachée');
  // enveloppe { action, payload } admise (forme des autres modules)
  eq(read({ action: 'prompt', payload: { key: 'G', verb: 'Puiser', label: 'Puits du lavoir' } }),
    { hidden: false, key: 'G', verb: 'Puiser', label: 'Puits du lavoir' }, 'enveloppe');
  eq(read({ action: 'prompt', payload: { hidden: true } }), { hidden: true }, 'enveloppe cachée');
  // touche absente : E ; rien à dire : cachée
  eq(read({ action: 'prompt', verb: 'Puiser', label: 'Source' }).key, 'E', 'touche par défaut');
  eq(read({ action: 'prompt', verb: '', label: '   ' }), { hidden: true }, 'vide');
  eq(read({ action: 'prompt', verb: { x: 1 }, label: ['a'] }), { hidden: true }, 'types refusés');
  eq(read({ action: 'prompt', hidden: 'true', verb: 'Puiser', label: 'Puits' }).hidden, false, 'hidden strictement booléen');
  // autres messages ignorés
  eq(read({ action: 'menu', verb: 'Puiser' }), null, 'autre action');
  eq(read(null), null, 'null');
  eq(read('prompt'), null, 'chaîne');
  // texte : contrôle retiré, coupe en caractères (pas en unités UTF-16)
  eq(text('Puits\n du\tlavoir', 48), 'Puits  du lavoir', 'contrôles');
  eq(text('é'.repeat(60), 48), 'é'.repeat(48), 'coupe 48');
  eq(Array.from(text('💧'.repeat(50), 48)).length, 48, 'coupe sans briser un caractère');
  eq(text(3, 12), '3', 'nombre');
  eq(read({ action: 'prompt', key: 'ABCDEFGHIJKLMNOP', verb: 'Puiser', label: 'x' }).key, 'ABCDEFGHIJKL', 'touche 12');
  eq(read({ action: 'prompt', verb: 'Puiser', label: '<b>Puits</b>' }).label, '<b>Puits</b>', 'balises gardées en texte');
} catch (error) {
  console.error(`ÉCHEC : ${error.message}`);
  process.exit(1);
}
console.log(`vava_provisions/web : ${passed} essais réussis`);
