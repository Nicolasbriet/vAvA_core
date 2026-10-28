'use strict';
/*
 * web/js/view-naming.js
 * Rôle : la boîte de baptême d'un chef-d'œuvre : nom à donner (longueur bornée), compte à rebours de la fenêtre
 *        (setInterval d'une seconde, seulement tant que la boîte est visible), « Baptiser » ou « Plus tard ».
 */

const NamingView = (() => {
  const root = document.getElementById('naming');
  const refs = {
    title: root.querySelector('.naming-title'),
    text: root.querySelector('.naming-text'),
    input: root.querySelector('.naming-input'),
    remaining: root.querySelector('.naming-remaining'),
    error: root.querySelector('.naming-error'),
    confirm: root.querySelector('[data-naming="confirm"]'),
    later: root.querySelector('[data-naming="later"]'),
  };
  const N = STRINGS.naming;
  let current = null;   // { instanceId, nameMin, nameMax, endsAt }
  let timer = null;

  function stopTimer() {
    clearInterval(timer);
    timer = null;
  }

  function tick() {
    if (!current) return;
    const left = Math.max(0, Math.ceil((current.endsAt - Date.now()) / 1000));
    refs.remaining.textContent = N.remaining(left);
    if (left <= 0) later();
  }

  /** Ouvre la boîte : { instanceId, label, nameWindowMs, nameMin, nameMax }. */
  function show(payload) {
    stopTimer();
    current = {
      instanceId: payload.instanceId,
      nameMin: Number(payload.nameMin) || 2,
      nameMax: Number(payload.nameMax) || 32,
      endsAt: Date.now() + (Number(payload.nameWindowMs) || 300000),
    };
    refs.title.textContent = N.title;
    refs.text.textContent = N.text(payload.label || '');
    refs.input.value = '';
    refs.input.maxLength = current.nameMax;
    refs.input.placeholder = N.placeholder;
    refs.error.textContent = '';
    refs.error.hidden = true;
    refs.confirm.textContent = N.confirm;
    refs.later.textContent = N.later;
    root.hidden = false;
    refs.input.focus();
    tick();
    timer = setInterval(tick, 1000);
  }

  function hide() {
    stopTimer();
    current = null;
    root.hidden = true;
  }

  /** Fermeture sans baptême : le jeu rend la main. */
  function later() {
    if (!current) return;
    hide();
    Bridge.post('nameLater');
  }

  async function confirm() {
    if (!current) return;
    const name = refs.input.value.trim();
    if (Array.from(name).length < current.nameMin) {
      refs.error.textContent = N.tooShort(current.nameMin);
      refs.error.hidden = false;
      return;
    }
    refs.confirm.disabled = true;
    const result = await Bridge.post('name', { instanceId: current.instanceId, name });
    refs.confirm.disabled = false;
    if (result.ok) {
      hide();
      return;
    }
    refs.error.textContent = errorMessage(result.error);
    refs.error.hidden = false;
  }

  refs.confirm.addEventListener('click', confirm);
  refs.later.addEventListener('click', later);
  refs.input.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') confirm();
  });

  return { show, hide, later, isOpen: () => !root.hidden };
})();
