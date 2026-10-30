'use strict';
/*
 * vava_atelier/web/js/bridge.js
 * Rôle : SEUL pont vers le Lua (client/nui.lua) : retours de la page (fetch NUI) et messages entrants. Les demandes qui
 *        lisent un module (liste, fiche, vérification, valeurs, recherche, journal) partent une à une : le serveur
 *        n'en traite qu'une à la fois par joueur (`busy`). Hors jeu, les appels vont aux données simulées
 *        (web/dev/devmock.js, jamais livré).
 * Réponse toujours de la forme { ok, error?, data? } (§ 9.3 de la spec T-100).
 * Dépendances : aucune (DevMock hors jeu seulement).
 */

const Bridge = (() => {
  const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
  const DIRECT = new Set(['close', 'stale']);   // jamais mis en file : ils ne lisent aucun module
  let queue = Promise.resolve();

  async function send(name, data) {
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

  function normalize(result) {
    if (!result || typeof result !== 'object') return { ok: false, error: 'invalid_response' };
    if (result.ok !== true) return { ok: false, error: typeof result.error === 'string' ? result.error : 'default' };
    return { ok: true, data: result.data && typeof result.data === 'object' ? result.data : {} };
  }

  /** Retour vers le jeu. */
  function post(name, data = {}) {
    if (DIRECT.has(name)) return send(name, data).then(normalize);
    const run = queue.then(() => send(name, data)).then(normalize, () => ({ ok: false, error: 'client_error' }));
    queue = run.then(() => undefined);
    return run;
  }

  /** Messages du Lua : { action, payload } (une charge posée à plat est acceptée aussi). */
  function onMessage(handler) {
    window.addEventListener('message', (event) => {
      const message = event.data;
      if (!message || typeof message.action !== 'string') return;
      const payload = message.payload && typeof message.payload === 'object' ? message.payload : message;
      handler(message.action, payload);
    });
  }

  return { post, onMessage, inGame: resource !== null };
})();
