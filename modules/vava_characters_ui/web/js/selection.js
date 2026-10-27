'use strict';
/*
 * web/js/selection.js
 * Rôle : écran de sélection : un emplacement par personnage possible (personnage existant ou emplacement libre),
 *        jouer, supprimer (avec confirmation), créer. Les boutons sont bloqués pendant une action en cours.
 */

const Selection = (() => {
  const S = STRINGS.selection;
  let list = null;
  let counter = null;
  let handlers = null;
  let busy = false;

  const firstLetter = (text) => (Array.from(text || '')[0] || '').toUpperCase();

  function setBusy(value) {
    busy = value;
    list.classList.toggle('is-busy', value);
    for (const button of list.querySelectorAll('button')) button.disabled = value;
  }

  async function run(action) {
    if (busy) return;
    setBusy(true);
    try {
      await action();
    } finally {
      setBusy(false);
    }
  }

  function characterCard(character) {
    const fullName = `${character.firstName} ${character.lastName}`;
    const play = UI.el('button', {
      type: 'button', class: 'button button-primary',
      onclick: () => run(async () => {
        play.textContent = S.playing;
        await handlers.onPlay(character);
        play.textContent = S.play;
      }),
    }, [S.play]);
    return UI.el('article', { class: 'slot', tabindex: '-1' }, [
      UI.el('div', { class: 'emblem', 'aria-hidden': 'true', text: `${firstLetter(character.firstName)}${firstLetter(character.lastName)}` }),
      UI.el('div', { class: 'slot-body' }, [
        UI.el('h2', { class: 'slot-name', text: fullName }),
        UI.el('p', { class: 'slot-meta', text: `${STRINGS.sexes[character.sex] || ''} · ${S.reference(character.id)}` }),
      ]),
      UI.el('div', { class: 'slot-actions' }, [
        play,
        UI.iconButton('trash', `${S.delete} ${fullName}`, () => run(() => handlers.onDelete(character)), 'icon-button-danger'),
      ]),
    ]);
  }

  function emptyCard() {
    return UI.el('button', { type: 'button', class: 'slot slot-empty', onclick: () => run(() => handlers.onCreate()) }, [
      UI.el('div', { class: 'emblem emblem-empty', 'aria-hidden': 'true' }, [UI.icon('plus')]),
      UI.el('div', { class: 'slot-body' }, [
        UI.el('h2', { class: 'slot-name', text: S.create }),
        UI.el('p', { class: 'slot-meta', text: S.emptySlot }),
      ]),
    ]);
  }

  function init(root, callbacks) {
    handlers = callbacks;
    root.querySelector('.brand-title').textContent = S.title;
    root.querySelector('.brand-subtitle').textContent = S.subtitle;
    list = root.querySelector('.slots');
    counter = root.querySelector('.slots-counter');
  }

  /** Affiche la liste renvoyée par le serveur. */
  function render({ characters = [], max = characters.length }) {
    const cards = characters.map(characterCard);
    const free = Math.max(0, max - characters.length);
    for (let i = 0; i < free; i += 1) cards.push(emptyCard());
    list.replaceChildren(...cards);
    counter.textContent = S.slotsLeft(free);
    const first = list.querySelector('button');
    if (first) first.focus();
  }

  return { init, render };
})();
