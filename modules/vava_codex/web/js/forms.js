'use strict';
/*
 * web/js/forms.js
 * Rôle : formulaire d'une commande selon le type de chaque argument : joueur en jeu, clé d'un registre ou liste d'un
 *        module (liste déroulante filtrable, valeurs demandées au serveur), choix fixe (pastilles), nombre (curseur et
 *        champ, sans valeur d'office, borné et arrondi), texte ; composition de la ligne lancée et contrôle des
 *        arguments requis.
 */

const Forms = (() => {
  const el = (tag, className, text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  };

  // valeurs déjà demandées pour un argument dynamique, pour la durée d'une ouverture
  const optionCache = new Map();
  const MAX_SHOWN = 40;

  function clearCache() {
    optionCache.clear();
  }

  async function options(row, index) {
    const key = `${row.entry.name}|${row.action ? row.action.id || '' : ''}|${index}`;
    if (optionCache.has(key)) return optionCache.get(key);
    const result = await Bridge.post('options', { name: row.entry.name, action: row.action ? row.action.id || '' : '', index });
    const list = result.ok ? Model.list(result.options) : [];
    optionCache.set(key, list);
    return list;
  }

  /** Champ d'un argument : { node, get(), focus(), valid() }. `onChange` est appelé à chaque modification. */
  function field(row, arg, index, onChange) {
    const wrap = el('div', `field field-${arg.type}`);
    wrap.dataset.arg = String(index);
    const head = el('div', 'field-head');
    head.append(el('span', 'field-name', arg.name));
    if (arg.optional) head.append(el('span', 'field-optional', STRINGS.detail.optional));
    wrap.append(head);
    let api;
    if (arg.type === 'choice') api = choiceField(wrap, arg, onChange);
    else if (arg.type === 'integer' || arg.type === 'number') api = numberField(wrap, arg, onChange);
    else if (arg.type === 'player' || arg.type === 'registry' || arg.type === 'list') api = pickerField(wrap, row, arg, index, onChange);
    else api = textField(wrap, arg, onChange);
    if (arg.hint) wrap.append(el('p', 'field-hint', arg.hint));
    api.node = wrap;
    api.arg = arg;
    return api;
  }

  function textField(wrap, arg, onChange) {
    const input = el('input', `field-input${arg.rest ? ' is-rest' : ''}`);
    input.type = 'text';
    input.autocomplete = 'off';
    input.spellcheck = false;
    input.placeholder = STRINGS.detail.placeholder(arg.name);
    input.maxLength = arg.rest ? 200 : 64;
    input.addEventListener('input', onChange);
    wrap.append(input);
    return { get: () => input.value.trim(), focus: () => input.focus(), first: input };
  }

  /** Bornes déclarées d'un argument nombre : entier ou non, min, max, pas (1 d'office pour un entier) ; null : aucune. */
  function numberBounds(arg) {
    const integer = arg.type === 'integer';
    return {
      integer,
      min: Number.isFinite(arg.min) ? arg.min : null,
      max: Number.isFinite(arg.max) ? arg.max : null,
      step: Number.isFinite(arg.step) && arg.step > 0 ? arg.step : (integer ? 1 : null),
    };
  }

  /** Décimales écrites d'un nombre (0,25 → 2) ; null pour une écriture exponentielle. */
  function decimalsOf(value) {
    const text = String(value);
    if (text.includes('e')) return null;
    const dot = text.indexOf('.');
    return dot < 0 ? 0 : text.length - dot - 1;
  }

  /** Saisie bornée, arrondie au pas compté depuis min (puis à l'entier) ; null si ce n'est pas un nombre. */
  function normalizeNumber(raw, bounds) {
    const text = String(raw).trim().replace(',', '.');
    if (text === '') return null;
    let value = Number(text);
    if (!Number.isFinite(value)) return null;
    const { integer, min, max, step } = bounds;
    const clamp = (v) => Math.min(max === null ? v : max, Math.max(min === null ? v : min, v));
    value = clamp(value);
    if (step !== null) {
      const origin = min === null ? 0 : min;
      // nombre de pas arrondi avant l'entier : 0,35 / 0,1 vaut 3,4999… en flottant, et doit donner 4
      value = origin + Math.round(Number(((value - origin) / step).toFixed(9))) * step;
      if (max !== null && value > max) value -= step;
      if (min !== null && value < min) value += step;
      // sans reste de calcul flottant (0,1 × 3 = 0,30000000000000004)
      const decimals = Math.max(decimalsOf(step) ?? 0, decimalsOf(origin) ?? 0);
      value = Number(value.toFixed(Math.min(decimals, 10)));
    }
    if (integer) value = Math.round(value);
    return clamp(value);
  }

  /** Nombre : curseur et champ sans valeur d'office (rempli seulement par le joueur) ; lancé via normalizeNumber. */
  function numberField(wrap, arg, onChange) {
    const bounds = numberBounds(arg);
    // le curseur a besoin de bornes : défauts si l'argument n'en déclare pas (la saisie, elle, ne suit que les siennes)
    const min = bounds.min === null ? 0 : bounds.min;
    const max = bounds.max === null ? (bounds.integer ? 100 : 1) : bounds.max;
    const step = bounds.step === null ? 0.1 : bounds.step;
    if (bounds.min !== null && bounds.max !== null) {
      wrap.querySelector('.field-head').append(el('span', 'field-bounds', STRINGS.detail.bounds(bounds.min, bounds.max)));
    }
    const row = el('div', 'field-row');
    const range = el('input', 'field-range is-unset');
    range.type = 'range';
    range.min = String(min);
    range.max = String(max);
    range.step = String(step);
    range.value = String(min);
    const number = el('input', 'field-number');
    number.type = 'number';
    number.min = String(min);
    number.max = String(max);
    number.step = String(step);
    number.placeholder = STRINGS.detail.unset;
    let value = null;
    const choose = (next) => {
      value = next;
      range.classList.toggle('is-unset', next === null);
      onChange();
    };
    range.addEventListener('input', () => {
      const next = normalizeNumber(range.value, bounds);
      number.value = next === null ? '' : String(next);
      choose(next);
    });
    // pendant la frappe, le texte reste celui du joueur ; la ligne lancée montre déjà la valeur bornée
    number.addEventListener('input', () => {
      const next = normalizeNumber(number.value, bounds);
      if (next !== null) range.value = String(next);
      choose(next);
    });
    // en quittant le champ : la valeur s'affiche telle qu'elle partira
    number.addEventListener('change', () => { number.value = value === null ? '' : String(value); });
    row.append(range, number);
    wrap.append(row);
    return {
      get: () => (value === null ? '' : String(value)),
      focus: () => number.focus(), first: number,
    };
  }

  function choiceField(wrap, arg, onChange) {
    const chips = el('div', 'chips');
    let value = '';
    for (const choice of Model.list(arg.choices)) {
      const chip = el('button', 'chip', (arg.labels && arg.labels[choice]) || choice);
      chip.type = 'button';
      chip.dataset.value = choice;
      chip.addEventListener('click', () => {
        value = value === choice && arg.optional ? '' : choice;
        for (const node of chips.children) node.classList.toggle('is-active', node.dataset.value === value);
        onChange();
      });
      chips.append(chip);
    }
    wrap.append(chips);
    return { get: () => value, focus: () => chips.firstChild && chips.firstChild.focus(), first: chips.firstChild };
  }

  /** Liste déroulante filtrable : les valeurs viennent du serveur ; une saisie sans correspondance reste permise. */
  function pickerField(wrap, row, arg, index, onChange) {
    const input = el('input', 'field-input');
    input.type = 'text';
    input.autocomplete = 'off';
    input.spellcheck = false;
    input.placeholder = STRINGS.detail.placeholder(arg.name);
    input.maxLength = 64;
    input.setAttribute('role', 'combobox');
    const menu = el('div', 'picker-menu');
    menu.hidden = true;
    let loaded = [];
    let chosen = null;   // { value, label } choisi dans la liste
    let active = -1;
    let shown = [];

    function render() {
      const needle = fold(input.value);
      shown = (needle && !chosen ? loaded.filter((option) => fold(option.label).includes(needle) || fold(option.value).includes(needle)) : loaded).slice(0, MAX_SHOWN);
      menu.replaceChildren(...shown.map((option, i) => {
        const item = el('div', `picker-item${i === active ? ' is-active' : ''}`);
        item.dataset.index = String(i);
        item.append(el('span', 'picker-label', option.label));
        if (option.label !== option.value) item.append(el('span', 'picker-value', option.value));
        item.addEventListener('pointerdown', (event) => { event.preventDefault(); pick(option); });
        return item;
      }));
      menu.hidden = shown.length === 0 || document.activeElement !== input;
    }

    function pick(option) {
      chosen = option;
      input.value = option.label;
      active = -1;
      menu.hidden = true;
      onChange();
    }

    input.addEventListener('focus', async () => {
      if (loaded.length === 0) loaded = await options(row, index);
      active = -1;
      render();
    });
    input.addEventListener('blur', () => { menu.hidden = true; });
    input.addEventListener('input', () => {
      chosen = null;
      active = -1;
      render();
      onChange();
    });
    input.addEventListener('keydown', (event) => {
      if (menu.hidden || shown.length === 0) return;
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault();
        event.stopPropagation();
        active = (active + (event.key === 'ArrowDown' ? 1 : -1) + shown.length) % shown.length;
        render();
      } else if (event.key === 'Enter' && active >= 0) {
        event.preventDefault();
        event.stopPropagation();
        pick(shown[active]);
      } else if (event.key === 'Escape') {
        event.stopPropagation();
        menu.hidden = true;
      }
    });
    wrap.append(input, menu);
    return {
      get: () => (chosen ? chosen.value : input.value.trim()),
      focus: () => input.focus(), first: input,
    };
  }

  /** Ligne lancée (sans « / ») et validité : { line, missing } ; un facultatif vide est omis. */
  function compose(row, fields) {
    const parts = [row.entry.name];
    if (row.action && row.action.id) parts.push(row.action.id);
    let missing = null;
    for (const api of fields) {
      const value = api.get();
      if (value === '') {
        if (!api.arg.optional && !missing) missing = api.arg.name;
        continue;
      }
      parts.push(value);
    }
    return { line: parts.join(' '), missing };
  }

  return { field, compose, clearCache, normalizeNumber, numberBounds };
})();
