'use strict';
/*
 * web/js/composer.js
 * Rôle : parchemin d'écriture d'un murmure : contacts gardés (cercle limité selon le niveau ; un seul au niveau 1 à
 *        3), message compté en signes, position jointe dès le niveau 3, coût en mana. Ctrl+Entrée envoie. Le jeu
 *        revérifie tout ; le serveur décide.
 */

(() => {
  function render(root, data) {
    const texts = UI.t('composer');
    const contacts = Array.isArray(data.contacts) ? data.contacts : [];
    const circle = Math.max(1, Number(data.circle) || 1);
    const maxLength = Math.max(1, Number(data.maxLength) || 1);
    const chosen = new Set();

    const chips = UI.el('div', 'contacts');
    const send = UI.button(texts.send, 'seal-button', () => submit());
    const textarea = UI.el('textarea', 'message');
    textarea.placeholder = texts.placeholder || '';
    textarea.rows = 4;
    textarea.dataset.autofocus = '';
    const counter = UI.el('span', 'counter');
    const position = UI.el('input');
    position.type = 'checkbox';
    position.disabled = !data.waypoint;

    function refresh() {
      for (const chip of chips.children) {
        const index = Number(chip.dataset.index);
        chip.classList.toggle('is-chosen', chosen.has(index));
        chip.disabled = !chosen.has(index) && chosen.size >= circle && circle > 1;
      }
      counter.textContent = UI.format(texts.count, UI.length(textarea.value), maxLength);
      send.disabled = chosen.size === 0 || textarea.value.trim() === '';
    }

    for (const contact of contacts) {
      const chip = UI.button(contact.name, 'contact', () => {
        if (chosen.has(contact.index)) {
          chosen.delete(contact.index);
        } else {
          // un seul contact : choisir l'un remplace l'autre
          if (circle === 1) chosen.clear();
          if (chosen.size < circle) chosen.add(contact.index);
        }
        refresh();
      });
      chip.dataset.index = String(contact.index);
      chips.append(chip);
    }

    textarea.addEventListener('input', () => {
      const trimmed = UI.truncate(textarea.value, maxLength);
      if (trimmed !== textarea.value) textarea.value = trimmed;
      refresh();
    });
    textarea.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' && event.ctrlKey) {
        event.preventDefault();
        submit();
      }
    });

    function submit() {
      if (send.disabled) return;
      const targets = contacts.filter((c) => chosen.has(c.index)).map((c) => c.index);
      Modal.close();
      Bridge.post('composer:send', { targets, text: textarea.value, position: position.checked });
    }

    root.append(
      UI.title(texts.title),
      UI.el('p', 'hint', UI.format(texts.circle, circle)),
      UI.el('h3', 'field-label', texts.to),
      contacts.length ? chips : UI.el('p', 'empty', texts.noContacts),
      UI.el('h3', 'field-label', texts.message),
      textarea,
      UI.el('div', 'row-between', null, [
        UI.el('label', `toggle${position.disabled ? ' is-locked' : ''}`, null, [position, UI.el('span', null, data.waypoint ? texts.position : texts.positionLocked)]),
        counter,
      ]),
      UI.el('div', 'sheet-actions', null, [
        UI.el('span', 'cost', UI.format(texts.cost, data.cost || 0)),
        UI.el('span', 'spacer'),
        UI.button(texts.close, 'ink-button', () => Modal.dismiss()),
        send,
      ]),
    );
    refresh();
  }

  Modal.register('composer', render);
})();
