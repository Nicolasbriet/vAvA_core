'use strict';
/*
 * web/js/feedback.js
 * Rôle : fenêtre de confirmation (promesse) et messages éphémères.
 */

const Feedback = (() => {
  const TOAST_MS = 4200;
  let toastTimer = null;
  let resolveModal = null;

  const modal = () => document.getElementById('modal');
  const toast = () => document.getElementById('toast');

  function closeModal(result) {
    modal().hidden = true;
    if (resolveModal) {
      const resolve = resolveModal;
      resolveModal = null;
      resolve(result);
    }
  }

  /** Demande une confirmation ; se résout à true (confirmé) ou false (annulé, Échap). */
  function confirm({ title, message, confirmLabel, cancelLabel, danger }) {
    if (resolveModal) closeModal(false);
    const root = modal();
    root.querySelector('.modal-title').textContent = title;
    root.querySelector('.modal-message').textContent = message;
    const confirmButton = root.querySelector('[data-modal="confirm"]');
    confirmButton.textContent = confirmLabel;
    confirmButton.classList.toggle('button-danger', Boolean(danger));
    root.querySelector('[data-modal="cancel"]').textContent = cancelLabel;
    root.hidden = false;
    confirmButton.focus();
    return new Promise((resolve) => { resolveModal = resolve; });
  }

  function isModalOpen() {
    return resolveModal !== null;
  }

  function show(message) {
    const node = toast();
    node.textContent = message;
    node.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { node.hidden = true; }, TOAST_MS);
  }

  function init() {
    const root = modal();
    root.querySelector('[data-modal="confirm"]').addEventListener('click', () => closeModal(true));
    root.querySelector('[data-modal="cancel"]').addEventListener('click', () => closeModal(false));
    root.addEventListener('click', (event) => { if (event.target === root) closeModal(false); });
  }

  return { init, confirm, isModalOpen, closeModal, show };
})();
