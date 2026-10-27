'use strict';
/*
 * web/js/bridge.js
 * Rôle : échanges avec le jeu : retours d'interface (le jeu n'en accepte qu'une liste fermée), messages reçus.
 *        Hors jeu, l'aperçu simulé répond à la place du jeu.
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

  /** Abonne un traitement aux messages du jeu dont l'action commence par ce préfixe (« capture: », « wall: »). */
  function on(prefix, handlers) {
    window.addEventListener('message', (event) => {
      const data = event.data || {};
      if (typeof data.action !== 'string' || !data.action.startsWith(prefix)) return;
      const handler = handlers[data.action.slice(prefix.length)];
      if (handler) handler(data.payload || {});
    });
  }

  return { post, on, inGame: Boolean(resource) };
})();
