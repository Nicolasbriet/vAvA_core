'use strict';
/*
 * vava_pause/web/js/bridge.js
 * Rôle : seul fichier qui parle au client Lua : rappels NUI (fetch vers https://vava_pause/<nom>) et messages reçus
 *        ({ action, payload }). Hors jeu, les rappels vont aux données simulées de dev/devmock.js.
 * Dépendances : aucune (DevMock hors jeu seulement)
 */

const Bridge = (() => {
  const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;

  /** Rappel NUI ; rend toujours un objet `{ ok, … }`, jamais une exception. */
  async function post(name, data = {}) {
    if (!resource) return typeof DevMock === 'object' ? DevMock.handle(name, data) : { ok: false, error: 'client_error' };
    try {
      const response = await fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
      });
      const result = await response.json();
      return result && typeof result === 'object' ? result : { ok: false, error: 'client_error' };
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
