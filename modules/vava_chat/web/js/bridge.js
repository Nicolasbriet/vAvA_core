'use strict';
/*
 * web/js/bridge.js
 * Rôle : pont avec le client Lua : messages reçus du jeu ({ action, payload }) distribués aux vues, retours envoyés
 *        au jeu (NUI callbacks). Hors du jeu (navigateur), les retours vont à DevMock.
 */

const Bridge = (() => {
  const inGame = typeof window.GetParentResourceName === 'function';
  const resource = inGame ? window.GetParentResourceName() : 'vava_chat';
  const handlers = {};

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data.action !== 'string') return;
    const handler = handlers[data.action];
    if (handler) handler(data.payload || {});
  });

  /** Retour vers le jeu ; renvoie la réponse du client Lua ({ ok, … }). */
  async function post(name, body = {}) {
    if (!inGame) return window.DevMock ? window.DevMock.answer(name, body) : { ok: true };
    try {
      const response = await fetch(`https://${resource}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(body),
      });
      return await response.json();
    } catch (error) {
      return { ok: false, error: 'unreachable' };
    }
  }

  /** Une action du jeu → une fonction de vue. */
  function on(action, handler) {
    handlers[action] = handler;
  }

  /** Simule un message du jeu (aperçu hors du jeu). */
  function emit(action, payload) {
    const handler = handlers[action];
    if (handler) handler(payload || {});
  }

  return { inGame, post, on, emit };
})();
