'use strict';
/*
 * web/js/bridge.js
 * Rôle : pont vers le Lua : appels (fetch NUI) et messages entrants. Hors jeu (navigateur), les appels sont routés
 *        vers les données simulées de devmock.js.
 */

const Bridge = (() => {
  const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;

  /** Retour vers le jeu ; renvoie la réponse du client Lua ({ ok, error?, … }). */
  async function post(name, data = {}) {
    if (!resource) return DevMock.handle(name, data);
    try {
      const response = await fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
      });
      return await response.json();
    } catch (error) {
      return { ok: false, error: 'client_error' };
    }
  }

  function onMessage(handler) {
    window.addEventListener('message', (event) => {
      const message = event.data;
      if (message && typeof message.action === 'string') handler(message.action, message.payload || {});
    });
  }

  return { post, onMessage, inGame: resource !== null };
})();
