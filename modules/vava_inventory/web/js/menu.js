'use strict';
/*
 * web/js/menu.js
 * Rôle : menu contextuel (clic droit), choix d'une quantité, messages éphémères.
 */

const Menu = (() => {
  const TOAST_MS = 3200;
  let refs = null;
  let toastTimer = null;
  let resolveQuantity = null;

  function closeContext() {
    refs.context.hidden = true;
    refs.context.replaceChildren();
  }

  /** Ouvre le menu à la position du pointeur. `entries` : [{ label, run, danger }]. */
  function context(x, y, entries) {
    if (entries.length === 0) return;
    refs.context.replaceChildren(...entries.map((entry) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = `context-item${entry.danger ? ' is-danger' : ''}`;
      button.textContent = entry.label;
      button.addEventListener('click', () => {
        closeContext();
        entry.run();
      });
      return button;
    }));
    refs.context.hidden = false;
    const { innerWidth, innerHeight } = window;
    const rect = refs.context.getBoundingClientRect();
    refs.context.style.left = `${Math.min(x, innerWidth - rect.width - 8)}px`;
    refs.context.style.top = `${Math.min(y, innerHeight - rect.height - 8)}px`;
    refs.context.querySelector('button').focus();
  }

  function finishQuantity(value) {
    refs.dialog.hidden = true;
    if (resolveQuantity) {
      const resolve = resolveQuantity;
      resolveQuantity = null;
      resolve(value);
    }
  }

  /** Demande une quantité entre 1 et max ; se résout au nombre choisi ou à null. */
  function quantity({ title, max, value }) {
    finishQuantity(null);
    const S = STRINGS.split;
    refs.dialogTitle.textContent = title;
    refs.range.max = String(max);
    refs.number.max = String(max);
    refs.range.value = String(value);
    refs.number.value = String(value);
    refs.dialog.hidden = false;
    refs.number.focus();
    refs.number.select();
    refs.confirm.textContent = S.confirm;
    refs.cancel.textContent = S.cancel;
    return new Promise((resolve) => { resolveQuantity = resolve; });
  }

  const isOpen = () => !refs.context.hidden || !refs.dialog.hidden;

  /** Ferme ce qui est ouvert ; vrai si quelque chose l'était (Échap). */
  function dismiss() {
    if (!refs.dialog.hidden) {
      finishQuantity(null);
      return true;
    }
    if (!refs.context.hidden) {
      closeContext();
      return true;
    }
    return false;
  }

  function toast(message) {
    refs.toast.textContent = message;
    refs.toast.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { refs.toast.hidden = true; }, TOAST_MS);
  }

  function init(root) {
    refs = {
      context: root.querySelector('.context'),
      dialog: root.querySelector('.dialog'),
      dialogTitle: root.querySelector('.dialog-title'),
      range: root.querySelector('.dialog-range'),
      number: root.querySelector('.dialog-number'),
      confirm: root.querySelector('[data-dialog="confirm"]'),
      cancel: root.querySelector('[data-dialog="cancel"]'),
      toast: root.querySelector('.toast'),
    };
    root.querySelector('.dialog-label').textContent = STRINGS.split.quantity;
    const sync = (from, to) => from.addEventListener('input', () => { to.value = from.value; });
    sync(refs.range, refs.number);
    sync(refs.number, refs.range);
    const submit = () => {
      const value = Math.floor(Number(refs.number.value));
      const max = Number(refs.number.max);
      finishQuantity(value >= 1 && value <= max ? value : null);
    };
    refs.confirm.addEventListener('click', submit);
    refs.cancel.addEventListener('click', () => finishQuantity(null));
    refs.number.addEventListener('keydown', (event) => { if (event.key === 'Enter') submit(); });
    document.addEventListener('pointerdown', (event) => {
      if (!refs.context.hidden && !refs.context.contains(event.target)) closeContext();
    });
  }

  return { init, context, quantity, isOpen, dismiss, toast };
})();
