'use strict';
/*
 * web/js/prompts.js
 * Rôle : petites fenêtres de décision : un sigil tendu (le nommer, confier le sien en retour, ou refuser), un sigil
 *        reçu en retour (le nommer ou refuser), une confirmation (brouiller son sigil). Compte à rebours des offres :
 *        à zéro, la fenêtre ne répond plus et attend que le serveur, qui clôt l'offre, la ferme.
 */

(() => {
  const SECOND_MS = 1000;
  let countdown = null;

  function stopCountdown() {
    clearInterval(countdown);
    countdown = null;
  }

  /** Fenêtre « sigil » : offre (avec retour possible) ou nom du sigil reçu en retour. */
  function sigilPrompt(kind, root, data) {
    const texts = UI.t(kind);
    const nameMax = Math.max(1, Number(data.nameMax) || 24);
    let left = Math.max(1, Number(data.seconds) || 30);
    const remaining = UI.el('span', 'countdown', UI.format(texts.remaining, left));
    const input = UI.el('input', 'name-input');
    input.type = 'text';
    input.placeholder = texts.name || '';
    input.dataset.autofocus = '';
    const giveBack = UI.el('input');
    giveBack.type = 'checkbox';
    const accept = UI.button(texts.accept, 'seal-button', () => answer(true));
    const refuse = UI.button(texts.refuse, 'ink-button', () => answer(false));

    function answer(accepted) {
      if (accepted && input.value.trim() === '') return;
      stopCountdown();
      Modal.close();
      Bridge.post(`${kind}:answer`, { id: data.id, accept: accepted, name: input.value.trim(), giveBack: giveBack.checked });
    }

    input.addEventListener('input', () => {
      const trimmed = UI.truncate(input.value, nameMax);
      if (trimmed !== input.value) input.value = trimmed;
      accept.disabled = input.value.trim() === '';
    });
    input.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') answer(true);
    });
    accept.disabled = true;

    stopCountdown();
    countdown = setInterval(() => {
      left -= 1;
      remaining.textContent = UI.format(texts.remaining, Math.max(0, left));
      if (left <= 0) {
        // le serveur, qui tient l'offre, la clôt et ferme la fenêtre : plus aucune réponse d'ici là
        stopCountdown();
        accept.disabled = true;
        refuse.disabled = true;
        input.disabled = true;
      }
    }, SECOND_MS);

    UI.append(root,
      UI.el('div', 'row-between', null, [UI.title(texts.title), remaining]),
      UI.el('p', 'prose', texts.body),
      input,
      kind === 'offer' ? UI.el('label', 'toggle', null, [giveBack, UI.el('span', null, texts.giveBack)]) : null,
      UI.el('div', 'sheet-actions', null, [UI.el('span', 'spacer'), refuse, accept]),
    );
    return stopCountdown;
  }

  Modal.register('offer', (root, data) => sigilPrompt('offer', root, data));
  Modal.register('naming', (root, data) => sigilPrompt('naming', root, data));

  Modal.register('confirm', (root, data) => {
    const texts = UI.t('confirm');
    const answer = (accepted) => {
      Modal.close();
      Bridge.post('confirm:answer', { kind: data.kind, accept: accepted });
    };
    root.append(
      UI.title(texts.scrambleTitle),
      UI.el('p', 'prose', UI.format(texts.scrambleBody, data.cost || 0)),
      UI.el('div', 'sheet-actions', null, [
        UI.el('span', 'spacer'),
        UI.button(texts.cancel, 'ink-button', () => answer(false)),
        UI.button(texts.confirm, 'seal-button', () => answer(true)),
      ]),
    );
  });
})();
