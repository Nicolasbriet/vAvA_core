'use strict';
/*
 * web/js/ui.js
 * Rôle : briques de l'interface : création d'éléments, boutons, mot du registre (message éphémère), dialogue de
 *        saisie (motif, durée, objet…) qui se résout aux valeurs saisies ou à null.
 */

const UI = (() => {
  const SLIP_MS = 3200;
  let slipTimer = null;
  let refs = null;
  let resolveDialog = null;

  /** Élément : classes, texte (jamais de HTML), enfants. */
  function el(tag, className, text, children) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    if (children) node.append(...children.filter(Boolean));
    return node;
  }

  /** Bouton : `kind` = ink (trait d'encre), seal (cire, action lourde) ou plain. */
  function button(label, onClick, kind = 'ink') {
    const node = el('button', kind === 'seal' ? 'seal-button' : kind === 'plain' ? 'plain-button' : 'ink-button', label);
    node.type = 'button';
    node.addEventListener('click', onClick);
    return node;
  }

  /** Titre de page avec lettrine : la première lettre est enluminée. */
  function heading(text, extra) {
    const letters = Array.from(text);
    return el('header', 'page-heading', null, [
      el('h2', 'page-title', null, [el('span', 'lettrine', letters[0]), document.createTextNode(letters.slice(1).join(''))]),
      extra || null,
    ]);
  }

  function slip(message) {
    refs.slip.textContent = message;
    refs.slip.hidden = false;
    clearTimeout(slipTimer);
    slipTimer = setTimeout(() => { refs.slip.hidden = true; }, SLIP_MS);
  }

  /** Résultat d'une demande : mot d'erreur, ou mot de réussite facultatif. */
  function report(result, success) {
    if (!result.ok) slip(errorMessage(result.error));
    else if (success) slip(success);
    return result.ok;
  }

  function finish(value) {
    refs.dialog.hidden = true;
    if (resolveDialog) {
      const resolve = resolveDialog;
      resolveDialog = null;
      resolve(value);
    }
  }

  function field(def) {
    const id = `field-${def.name}`;
    const label = el('label', 'field-label', def.label);
    label.htmlFor = id;
    let input;
    if (def.type === 'durations') {
      input = el('div', 'stamps');
      input.setAttribute('role', 'radiogroup');
      def.options.forEach((hours, index) => {
        const option = el('button', `stamp${index === 0 ? ' is-selected' : ''}`, STRINGS.duration(hours));
        option.type = 'button';
        option.dataset.value = String(hours);
        option.setAttribute('role', 'radio');
        option.addEventListener('click', () => {
          for (const other of input.children) other.classList.toggle('is-selected', other === option);
        });
        input.append(option);
      });
      label.htmlFor = '';
    } else if (def.type === 'textarea') {
      input = el('textarea', 'field-input field-lines');
      input.rows = 3;
      input.maxLength = def.max || 500;
    } else {
      input = el('input', 'field-input');
      input.type = def.type === 'number' ? 'number' : 'text';
      if (def.type === 'number') { input.min = String(def.min || 1); input.max = String(def.max || 1000); }
      if (def.max && def.type !== 'number') input.maxLength = def.max;
    }
    input.id = id;
    input.dataset.field = def.name;
    if (def.value !== undefined && def.type !== 'durations') input.value = String(def.value);
    return el('div', 'field', null, [label, input]);
  }

  function readFields() {
    const values = {};
    for (const node of refs.dialogBody.querySelectorAll('[data-field]')) {
      if (node.classList.contains('stamps')) {
        const selected = node.querySelector('.is-selected');
        values[node.dataset.field] = selected ? Number(selected.dataset.value) : null;
      } else if (node.type === 'number') {
        values[node.dataset.field] = Math.floor(Number(node.value));
      } else {
        values[node.dataset.field] = node.value.trim();
      }
    }
    return values;
  }

  /** Dialogue : { title, text?, confirm, fields: [{ name, type, label, … }] } → valeurs, ou null si annulé. */
  function dialog({ title, text, confirm, fields = [] }) {
    finish(null);
    refs.dialogTitle.textContent = title;
    refs.dialogText.textContent = text || '';
    refs.dialogText.hidden = !text;
    refs.dialogBody.replaceChildren(...fields.map(field));
    refs.confirm.textContent = confirm;
    refs.cancel.textContent = STRINGS.dialogs.cancel;
    refs.dialog.hidden = false;
    const first = refs.dialogBody.querySelector('textarea, input');
    if (first) first.focus();
    else refs.confirm.focus();
    return new Promise((resolve) => { resolveDialog = resolve; });
  }

  function isDialogOpen() {
    return !refs.dialog.hidden;
  }

  function init(root) {
    refs = {
      slip: root.querySelector('.slip'),
      dialog: root.querySelector('.dialog'),
      dialogTitle: root.querySelector('.dialog-title'),
      dialogText: root.querySelector('.dialog-text'),
      dialogBody: root.querySelector('.dialog-body'),
      confirm: root.querySelector('[data-dialog="confirm"]'),
      cancel: root.querySelector('[data-dialog="cancel"]'),
    };
    root.querySelector('.dialog-card').addEventListener('submit', (event) => {
      event.preventDefault();
      const values = readFields();
      // une saisie de texte vide n'est pas un motif
      const empty = Object.entries(values).some(([, value]) => value === '' || Number.isNaN(value));
      if (empty) return;
      finish(values);
    });
    refs.cancel.addEventListener('click', () => finish(null));
  }

  return { el, button, heading, slip, report, dialog, isDialogOpen, cancelDialog: () => finish(null), init };
})();
