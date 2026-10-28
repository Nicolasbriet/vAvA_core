'use strict';
/*
 * web/js/view-prompt.js
 * Rôle : l'invite près d'une station (« [E] Ouvrir — Forge du bourg », type, occupation, combustible). Rien n'est
 *        animé en continu : l'invite ne change que quand le jeu l'envoie.
 */

const PromptView = (() => {
  const prompt = document.getElementById('prompt');
  const refs = {
    key: prompt.querySelector('.prompt-key'),
    verb: prompt.querySelector('.prompt-verb'),
    label: prompt.querySelector('.prompt-label'),
    type: prompt.querySelector('.prompt-type'),
    help: prompt.querySelector('.prompt-help'),
  };

  /** Invite pour une station : { key, label, typeLabel, busy, fuel = { stock, capacity } | null }. */
  function show(payload) {
    const P = STRINGS.prompt;
    refs.key.textContent = payload.key || 'E';
    refs.verb.textContent = P.verb;
    refs.label.textContent = payload.label || '';
    refs.type.textContent = payload.typeLabel ? `· ${payload.typeLabel}` : '';
    const parts = [];
    if (payload.fuel) parts.push(P.fuel(Number(payload.fuel.stock) || 0, Number(payload.fuel.capacity) || 0));
    if (payload.busy) parts.push(P.busy);
    else if (payload.fuel && (Number(payload.fuel.stock) || 0) <= 0) parts.push(P.noFuel);
    refs.help.textContent = parts.join(' — ');
    refs.help.hidden = parts.length === 0;
    prompt.classList.toggle('is-blocked', Boolean(payload.busy));
    prompt.classList.toggle('is-warning', !payload.busy && Boolean(payload.fuel) && (Number(payload.fuel.stock) || 0) <= 0);
    prompt.hidden = false;
  }

  function hide() {
    prompt.hidden = true;
  }

  return { show, hide };
})();
