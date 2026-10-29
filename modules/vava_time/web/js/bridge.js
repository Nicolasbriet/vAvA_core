'use strict';
/*
 * web/js/bridge.js
 * Rôle : échanges avec le jeu : demandes au client Lua (qui relaie au serveur ce qui doit l'être), messages reçus.
 *        Hors jeu, l'aperçu simulé répond à la place du jeu.
 */

const Bridge = (() => {
  const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;

  /** Réponse : { ok, result } ou { ok: false, error }. */
  async function post(name, data = {}) {
    if (!resource) return DevMock.handle(name, data);
    try {
      const response = await fetch(`https://${resource}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
      });
      return await response.json();
    } catch (error) {
      return { ok: false, error: 'client_error' };
    }
  }

  function onMessage(handler) {
    window.addEventListener('message', (event) => {
      const data = event.data || {};
      if (typeof data.action === 'string') handler(data.action, data.payload || {});
    });
  }

  return { post, onMessage, inGame: Boolean(resource) };
})();
