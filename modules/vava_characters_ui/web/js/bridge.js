'use strict';
/*
 * web/js/bridge.js
 * Rôle : pont vers le Lua. Appels (fetch NUI), messages entrants, et planification des aperçus :
 *        pour une même clé, seul le dernier changement part, au plus un par image affichée et une seule requête
 *        en vol. Faire glisser un curseur ne noie donc jamais le client sous les appels.
 */

const Bridge = (() => {
  const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;

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

  const pending = new Map();
  const queued = new Map();
  const inFlight = new Set();
  let frameRequested = false;

  function start(key, run) {
    inFlight.add(key);
    Promise.resolve(run()).finally(() => {
      inFlight.delete(key);
      const next = queued.get(key);
      if (next) {
        queued.delete(key);
        start(key, next);
      }
    });
  }

  function flush() {
    frameRequested = false;
    for (const [key, run] of pending) {
      if (inFlight.has(key)) queued.set(key, run);
      else start(key, run);
    }
    pending.clear();
  }

  /** Planifie un envoi : le dernier par clé l'emporte. `run` renvoie la promesse de l'appel. */
  function schedule(key, run) {
    pending.set(key, run);
    if (!frameRequested) {
      frameRequested = true;
      requestAnimationFrame(flush);
    }
  }

  return { post, onMessage, schedule, inGame: resource !== null };
})();
