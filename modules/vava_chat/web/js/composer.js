'use strict';
/*
 * web/js/composer.js
 * Rôle : la saisie : son étiquette et son texte d'attente suivent l'onglet (hors-RP, actions, Conseil, « Écrire
 *        à … », fermée quand le correspondant est parti), compteur de signes près de la limite, historique des
 *        lignes envoyées (↑ ↓), complétion des commandes (Tab), envoi (Entrée).
 */

const Composer = (() => {
  const input = document.getElementById('composer-input');
  const tag = document.getElementById('composer-tag');
  const count = document.getElementById('composer-count');
  const hint = document.getElementById('chat-hint');
  // part de la limite à partir de laquelle le compteur se montre
  const COUNT_FROM = 0.8;

  const history = [];
  let position = -1;
  let draft = '';
  let onSubmit = () => {};

  function setup(handlers) {
    onSubmit = handlers.submit;
    input.maxLength = UI.config().inputMax || 300;
    hint.textContent = UI.t().hint;
  }

  /** Signes du message lui-même : sans « /commande » (ni le numéro d'un /mp). */
  function messageLength(value) {
    if (!value.startsWith('/')) return UI.length(value);
    const command = value.slice(1).split(' ', 1)[0].toLowerCase();
    const prefix = command === UI.config().mpCommand ? /^\/\S+ *\d* */ : /^\/\S+ */;
    return UI.length(value.replace(prefix, ''));
  }

  function refresh() {
    const max = UI.config().maxLength || 250;
    const used = messageLength(input.value);
    count.hidden = used < max * COUNT_FROM;
    count.textContent = UI.format(UI.t().counter, used, max);
    count.classList.toggle('is-full', used > max);
    Suggest.update(input.value);
  }

  /** Onglet actif : { kind, label, gone }. */
  function target(tab) {
    const texts = UI.t();
    const placeholders = texts.placeholder;
    let label = texts.tags.ooc;
    let placeholder = placeholders.general;
    if (tab.kind === 'actions') {
      label = texts.tabs.actions;
      placeholder = placeholders.actions;
    } else if (tab.kind === 'staff') {
      label = texts.tags.staff;
      placeholder = placeholders.staff;
    } else if (tab.kind === 'mp') {
      label = texts.tags.mp;
      placeholder = UI.format(tab.gone ? placeholders.gone : placeholders.mp, tab.label);
    }
    tag.textContent = label;
    input.placeholder = placeholder;
    input.disabled = tab.kind === 'mp' && tab.gone;
  }

  function focus() {
    if (!input.disabled) input.focus();
  }

  function clear() {
    input.value = '';
    position = -1;
    draft = '';
    count.hidden = true;
    Suggest.hide();
    input.blur();
  }

  /** Texte préparé (« /mp 12 »), curseur à la fin. */
  function prefill(value) {
    input.value = value;
    focus();
    input.setSelectionRange(value.length, value.length);
    refresh();
  }

  function remember(value) {
    if (history[history.length - 1] !== value) history.push(value);
    const max = UI.config().historyMax || 30;
    while (history.length > max) history.shift();
  }

  function browse(step) {
    if (!history.length) return;
    if (position === -1) {
      if (step > 0) return;
      draft = input.value;
      position = history.length;
    }
    position = Math.min(Math.max(position + step, 0), history.length);
    input.value = position === history.length ? draft : history[position];
    if (position === history.length) position = -1;
    input.setSelectionRange(input.value.length, input.value.length);
    refresh();
  }

  input.addEventListener('input', () => {
    position = -1;
    refresh();
  });

  input.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      const value = input.value.trim();
      if (value) remember(value);
      onSubmit(value);
    } else if (event.key === 'Tab') {
      event.preventDefault();
      const completed = Suggest.complete(input.value);
      if (completed !== null) {
        input.value = completed;
        refresh();
      }
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      browse(-1);
    } else if (event.key === 'ArrowDown') {
      event.preventDefault();
      browse(1);
    }
  });

  return { setup, target, focus, clear, prefill };
})();
