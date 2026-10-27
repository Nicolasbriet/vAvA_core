'use strict';
/*
 * web/js/ui.js
 * Rôle : briques de l'interface : création d'éléments (texte seulement, jamais de HTML), boutons, titres à
 *        lettrine, champs de formulaire, tampons, pages, mot éphémère, dialogue de confirmation (vrai ou faux) et
 *        dialogue de formulaire (valeurs saisies, ou null).
 */

const UI = (() => {
  const SLIP_MS = 3600;
  let slipTimer = null;
  let refs = null;
  let resolveDialog = null;
  // champs du formulaire ouvert, ou null pour une simple confirmation
  let formFields = null;

  /** Élément : classes, texte, enfants (les valeurs nulles sont ignorées). */
  function el(tag, className, text, children) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    if (children) node.append(...children.filter(Boolean));
    return node;
  }

  /** Bouton : `kind` = ink (trait d'encre), seal (cire, action lourde), green (cire verte) ou plain. */
  function button(label, onClick, kind = 'ink') {
    const classes = { seal: 'seal-button', green: 'seal-button is-green', plain: 'plain-button' };
    const node = el('button', classes[kind] || 'ink-button', label);
    node.type = 'button';
    if (onClick) node.addEventListener('click', onClick);
    return node;
  }

  /** Titre de page : la première lettre est enluminée. */
  function heading(text, aside) {
    const letters = Array.from(text);
    return el('header', 'page-heading', null, [
      el('h2', 'page-title', null, [el('span', 'lettrine', letters[0]), document.createTextNode(letters.slice(1).join(''))]),
      aside ? el('span', 'page-aside', aside) : null,
    ]);
  }

  /**
   * Champ : { name, label, type?, value?, placeholder?, help?, options?, max?, min?, wide?, autocomplete? }.
   * Renvoie { node, input }.
   */
  function field(def) {
    const id = `field-${def.name.replace(/\W/g, '-')}`;
    const label = el('label', 'field-label', def.label);
    label.htmlFor = id;
    let input;
    if (def.type === 'select') {
      input = el('select', 'field-input');
      for (const [value, text] of Object.entries(def.options)) {
        const option = el('option', null, text);
        option.value = value;
        input.append(option);
      }
    } else if (def.type === 'textarea') {
      input = el('textarea', 'field-input field-lines');
      input.rows = 6;
      input.spellcheck = false;
      if (def.max) input.maxLength = def.max;
    } else {
      input = el('input', 'field-input');
      input.type = def.type || 'text';
      if (def.type === 'number') {
        input.min = String(def.min);
        input.max = String(def.max);
        input.step = '1';
      } else if (def.max) {
        input.maxLength = def.max;
      }
      input.spellcheck = false;
    }
    input.id = id;
    input.name = def.name;
    if (def.autocomplete) input.autocomplete = def.autocomplete;
    if (def.placeholder) input.placeholder = def.placeholder;
    if (def.value !== undefined && def.value !== null) input.value = String(def.value);
    const node = el('div', `field${def.wide ? ' is-wide' : ''}`, null, [label, input, def.help ? el('span', 'field-help', def.help) : null]);
    return { node, input };
  }

  /** Case à cocher avec libellé et aide. Renvoie { node, input }. */
  function choice(labelText, checked, help) {
    const input = el('input');
    input.type = 'checkbox';
    input.checked = Boolean(checked);
    const node = el('label', 'choice', null, [input, el('span', 'choice-text', null, [el('span', 'choice-label', labelText), help ? el('span', 'field-help', help) : null])]);
    return { node, input };
  }

  function slip(message) {
    refs.slip.textContent = message;
    refs.slip.hidden = false;
    clearTimeout(slipTimer);
    slipTimer = setTimeout(() => { refs.slip.hidden = true; }, SLIP_MS);
  }

  /** Résultat d'une requête : mot d'erreur, ou mot de réussite facultatif. Renvoie result.ok. */
  function report(result, success) {
    if (!result.ok) slip(STRINGS.error(result.error, result.field));
    else if (success) slip(success);
    return result.ok;
  }

  function finish(value) {
    refs.dialog.hidden = true;
    formFields = null;
    if (resolveDialog) {
      const resolve = resolveDialog;
      resolveDialog = null;
      resolve(value);
    }
  }

  function open({ title, text, confirm: label }) {
    finish(formFields ? null : false);
    refs.dialogTitle.textContent = title;
    refs.dialogText.textContent = text || '';
    refs.dialogText.hidden = !text;
    refs.confirm.textContent = label;
    refs.cancel.textContent = STRINGS.server.cancel;
    refs.dialog.hidden = false;
  }

  /** Confirmation : { title, text, confirm } → vrai si confirmé. */
  function confirm(options) {
    open(options);
    refs.dialogBody.replaceChildren();
    refs.confirm.focus();
    return new Promise((resolve) => { resolveDialog = resolve; });
  }

  /** Tampons à choix unique (durées, effets) : renvoie { node, value() }. */
  function stamps(options, selected) {
    const node = el('div', 'stamps');
    node.setAttribute('role', 'radiogroup');
    let current = selected !== undefined ? selected : options[0] && options[0].value;
    for (const option of options) {
      const stamp = el('button', `stamp${option.value === current ? ' is-selected' : ''}`, option.label);
      stamp.type = 'button';
      stamp.setAttribute('role', 'radio');
      stamp.addEventListener('click', () => {
        current = option.value;
        for (const other of node.children) other.classList.toggle('is-selected', other === stamp);
      });
      node.append(stamp);
    }
    return { node, value: () => current };
  }

  /**
   * Champ du formulaire : { name, label, type, value?, options?, help?, optional?, … } → { node, read() }.
   * read() renvoie la valeur, ou undefined si elle est refusée (champ marqué).
   */
  function formField(def) {
    if (def.type === 'stamps') {
      const choice = stamps(def.options, def.value);
      return { node: el('div', 'field is-wide', null, [el('span', 'field-label', def.label), choice.node]), read: choice.value };
    }
    if (def.type === 'checks') {
      const boxes = def.options.map((option) => ({ option, made: choice(option.label, option.checked, option.help) }));
      return {
        node: el('div', 'field is-wide', null, [el('span', 'field-label', def.label), ...boxes.map((b) => b.made.node)]),
        read: () => boxes.filter((b) => b.made.input.checked).map((b) => b.option.value),
      };
    }
    const made = field(def.type === 'select'
      ? { ...def, options: Object.fromEntries(def.options.map((o) => [o.value, o.label])) }
      : def);
    if (def.type === 'select' && def.value !== undefined) made.input.value = String(def.value);
    made.node.classList.add('is-wide');
    return {
      node: made.node,
      read() {
        const input = made.input;
        input.classList.remove('is-invalid');
        let value = def.type === 'password' ? input.value : input.value.trim();
        if (def.type === 'number') {
          value = Number(value);
          if (input.value.trim() === '' || !Number.isFinite(value) || (def.min !== undefined && value < def.min) || (def.max !== undefined && value > def.max)) {
            input.classList.add('is-invalid');
            return undefined;
          }
          if (def.integer) value = Math.floor(value);
        } else if (!def.optional && def.type !== 'select' && value === '') {
          input.classList.add('is-invalid');
          return undefined;
        }
        return value;
      },
    };
  }

  /** Formulaire : { title, text?, confirm, fields } → valeurs { nom: valeur }, ou null si annulé. */
  function form(options) {
    open(options);
    formFields = options.fields.map((def) => ({ def, field: formField(def) }));
    refs.dialogBody.replaceChildren(...formFields.map((f) => f.field.node));
    const first = refs.dialogBody.querySelector('input, textarea, select');
    if (first) first.focus();
    else refs.confirm.focus();
    return new Promise((resolve) => { resolveDialog = resolve; });
  }

  /** Valeur reçue du serveur de jeu : liste, que la table soit arrivée en tableau ou en objet. */
  function list(value) {
    if (Array.isArray(value)) return value;
    return value && typeof value === 'object' ? Object.values(value) : [];
  }

  /** Pages : précédente, numéro, suivante (une page pleine laisse supposer une suite). */
  function pager(page, count, pageSize, onChange) {
    const previous = button(STRINGS.pages.previous, () => onChange(page - 1));
    previous.disabled = page === 0;
    const next = button(STRINGS.pages.next, () => onChange(page + 1));
    next.disabled = count < pageSize;
    return el('div', 'pager', null, [previous, el('span', 'pager-page', STRINGS.pages.page(page + 1)), next]);
  }

  function init() {
    refs = {
      slip: document.querySelector('.slip'),
      dialog: document.querySelector('.dialog'),
      dialogTitle: document.querySelector('.dialog-title'),
      dialogText: document.querySelector('.dialog-text'),
      dialogBody: document.querySelector('.dialog-body'),
      confirm: document.querySelector('[data-dialog="confirm"]'),
      cancel: document.querySelector('[data-dialog="cancel"]'),
    };
    document.querySelector('.dialog-card').addEventListener('submit', (event) => {
      event.preventDefault();
      if (!formFields) {
        finish(true);
        return;
      }
      const values = {};
      let valid = true;
      for (const { def, field: made } of formFields) {
        const value = made.read();
        if (value === undefined) valid = false;
        values[def.name] = value;
      }
      if (valid) finish(values);
    });
    refs.cancel.addEventListener('click', () => finish(formFields ? null : false));
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && !refs.dialog.hidden) finish(formFields ? null : false);
    });
  }

  return { el, button, heading, field, choice, slip, report, confirm, form, stamps, list, pager, init };
})();
