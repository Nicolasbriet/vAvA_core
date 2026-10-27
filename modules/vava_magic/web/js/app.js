'use strict';
/*
 * web/js/app.js
 * Rôle : assemblage de l'interface : textes reçus de la config, ordres du jeu distribués aux vues, page prête
 *        annoncée au jeu (qui envoie alors les textes et les ordres arrivés avant).
 */

(() => {
  const MODALS = ['composer', 'offer', 'naming', 'confirm', 'grimoire', 'register'];

  Bridge.on('init', (payload) => UI.setTexts(payload.texts));
  Bridge.on('cast:start', (payload) => Castbar.start(payload));
  Bridge.on('cast:end', () => Castbar.done());
  Bridge.on('cast:interrupted', () => Castbar.broken());
  Bridge.on('murmur:show', (payload) => Murmurs.show(payload));
  Bridge.on('threat', (payload) => Threat.show(payload));
  Bridge.on('sound', (payload) => Sound.play(payload.name, payload.volume));
  for (const name of MODALS) Bridge.on(`modal:${name}`, (payload) => Modal.open(name, payload));
  Bridge.on('modal:close', () => Modal.close());

  Bridge.post('ready');
})();
