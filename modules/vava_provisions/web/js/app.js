'use strict';
/*
 * web/js/app.js
 * Rôle : l'invite près d'un point d'eau (« [E] Puiser ou boire — Fontaine du bourg »). Reçoit du client Lua
 *        { action = 'prompt', key, verb, label } ou { action = 'prompt', hidden = true } ; rien d'autre, aucun
 *        retour vers le jeu. Textes posés par textContent seulement. Rien n'est animé en continu : l'invite ne change
 *        que quand le jeu l'envoie. read() est pure (web/dev/essais.js).
 */

const ProvisionsPrompt = (() => {
  const MAX = { key: 12, verb: 48, label: 48 };

  /** Texte affichable : chaîne ou nombre, sans caractère de contrôle, coupé à max caractères ; sinon ''. */
  function text(value, max) {
    if (typeof value !== 'string' && typeof value !== 'number') return '';
    const clean = String(value).replace(/[\u0000-\u001f\u007f]/g, ' ').trim();
    return Array.from(clean).slice(0, max).join('').trim();
  }

  /** Message du jeu → { hidden } ou { hidden, key, verb, label } ; null s'il ne s'adresse pas à l'invite. */
  function read(message) {
    if (!message || typeof message !== 'object' || message.action !== 'prompt') return null;
    const src = message.payload && typeof message.payload === 'object' ? message.payload : message;
    if (src.hidden === true) return { hidden: true };
    const verb = text(src.verb, MAX.verb);
    const label = text(src.label, MAX.label);
    if (!verb && !label) return { hidden: true };
    return { hidden: false, key: text(src.key, MAX.key) || 'E', verb, label };
  }

  if (typeof document !== 'undefined') {
    const prompt = document.getElementById('prompt');
    const part = (name) => prompt.querySelector(`.prompt-${name}`);
    const refs = { key: part('key'), verb: part('verb'), sep: part('sep'), label: part('label') };

    window.addEventListener('message', (event) => {
      const state = read(event.data);
      if (!state) return;
      if (state.hidden) {
        prompt.hidden = true;
        return;
      }
      refs.key.textContent = state.key;
      refs.verb.textContent = state.verb;
      refs.label.textContent = state.label;
      refs.sep.hidden = !state.verb || !state.label;
      prompt.hidden = false;
    });
  }

  return { read, text };
})();
