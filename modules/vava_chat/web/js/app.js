'use strict';
/*
 * web/js/app.js
 * Rôle : assemblage de l'interface : textes et réglages reçus de la config, ordres du jeu distribués aux vues, page
 *        prête annoncée au jeu (qui envoie alors son état et les ordres arrivés avant).
 */

(() => {
  Lines.setHandlers({
    // nom d'un auteur : « /mp <n°> » préparé dans la saisie
    who: (id) => { if (Chat.isOpen()) Composer.prefill(`/mp ${id} `); },
    // ligne privée de Général : sa conversation s'ouvre
    conversation: (chat) => { if (Chat.isOpen()) Tabs.activate(`mp:${chat}`); },
  });

  Tabs.onChange((tab) => {
    Composer.target(tab);
    if (Chat.isOpen()) Composer.focus();
  });

  Bridge.on('init', (payload) => {
    UI.setup(payload);
    Tabs.setup();
    Composer.setup({ submit: Chat.submit });
    Layout.setup();
  });
  Bridge.on('layout', (payload) => Layout.set(payload));
  Bridge.on('profile', (payload) => Tabs.setProfile(payload));
  Bridge.on('message', (payload) => {
    Tabs.receive(payload);
    Chat.activity();
  });
  Bridge.on('notice', (payload) => {
    Tabs.notice(payload.tab, payload.text);
    Chat.activity();
  });
  Bridge.on('gone', (payload) => Tabs.gone(payload.chat));
  Bridge.on('suggestions', (payload) => Suggest.add(payload.list));
  Bridge.on('suggestion:remove', (payload) => Suggest.remove(payload.name));
  Bridge.on('commands', (payload) => Suggest.setCommands(payload.names));
  Bridge.on('open', () => Chat.show());
  Bridge.on('close', () => Chat.hide(false));
  Bridge.on('visible', (payload) => Chat.setVisible(payload.visible));
  Bridge.on('clear', () => Tabs.clear());
  Bridge.on('reset', () => {
    Chat.hide(false);
    Tabs.reset();
  });

  Bridge.post('ready');
})();
