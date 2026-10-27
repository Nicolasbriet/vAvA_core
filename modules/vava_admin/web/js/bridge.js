'use strict';
/*
 * web/js/bridge.js
 * Rôle : échanges avec le jeu : demandes relayées au serveur (le jeu n'en accepte qu'une liste fermée), messages
 *        reçus. Hors jeu, l'aperçu simulé répond à la place du serveur.
 */

const Bridge = (() => {
  const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;

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

  /** Demande au serveur : { ok, result } ou { ok: false, error }. */
  const request = (name, ...args) => post('request', { name, args });

  function onMessage(handler) {
    window.addEventListener('message', (event) => {
      const data = event.data || {};
      if (typeof data.action === 'string') handler(data.action, data.payload || {});
    });
  }

  return { post, request, onMessage, inGame: Boolean(resource) };
})();
