'use strict';
/*
 * vava_atelier/web/js/widgets.js
 * Rôle : les huit widgets du formulaire (§ 5.3). create(champ, valeur, ctx) → { nodes, after?, get, focus, control } ;
 *        ctx : { changed, lookup, known, remember }.
 * Dépendances : strings.js, format.js, components.js
 */

const Widgets = (() => {
  const { h, icon, image, Picker } = UI;
  const str = Format.str;
  let uid = 0;
  const nextId = () => `fld-${++uid}`;

  const head = (field, id, right, lid) => h('div', { class: 'fh' },
    id ? h('label', { class: 'lb', for: id, text: str(field.label) }) : h('span', { class: 'lb', id: lid, text: str(field.label) }), right || null);

  function radios(box, options, current, onSet) {
    const buttons = options.map((o) => h('button', { type: 'button', role: 'radio', class: 'opt', text: o.label, 'aria-label': o.aria || null, data: { value: o.value },
      onclick: () => { set(o.value); onSet(o.value); } }));
    function set(value) {
      for (const b of buttons) {
        const on = b.dataset.value === value;
        b.classList.toggle('on', on);
        b.setAttribute('aria-checked', String(on));
        b.tabIndex = on ? 0 : -1;
      }
    }
    box.addEventListener('keydown', (event) => {
      const step = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[event.key];
      if (!step) return;
      event.preventDefault();
      const index = buttons.findIndex((b) => b.tabIndex === 0);
      const next = buttons[(index + step + buttons.length) % buttons.length];
      set(next.dataset.value);
      next.focus();
      onSet(next.dataset.value);
    });
    box.append(...buttons);
    set(current);
    if (buttons[0] && !buttons.some((b) => b.tabIndex === 0)) buttons[0].tabIndex = 0;
    return () => (buttons.find((b) => b.tabIndex === 0) || box).focus();
  }

  function slider(field, value, ctx) {
    const id = nextId();
    const out = h('span', { class: 'v' });
    const input = h('input', { type: 'range', id, min: String(field.min), max: String(field.max), step: String(field.step), value: String(Format.snap(field, value)) });
    const get = () => Format.snap(field, Number(input.value));
    const show = () => { out.textContent = Format.measure(field, get()); };
    input.addEventListener('input', () => { show(); ctx.changed(); });
    show();
    return { nodes: [h('div', { class: 'sl' }, head(field, id, out), input)], get, focus: () => input.focus(), control: input };
  }

  function segmented(field, value, ctx) {
    const lid = `${nextId()}-l`;
    const options = Format.list(field.options).filter((o) => o && typeof o.value === 'string').map((o) => ({ value: o.value, label: str(o.label) || o.value }));
    let current = options.some((o) => o.value === value) ? value : (options[0] || {}).value || '';
    const box = h('div', { class: options.length > 4 ? 'gr' : 'seg', role: 'radiogroup', 'aria-labelledby': lid });
    const focus = radios(box, options, current, (v) => { current = v; ctx.changed(); });
    return { nodes: [head(field, null, null, lid), box], get: () => current, focus, control: box };
  }

  function choice(field, value, ctx) {
    const id = nextId(), lid = `${id}-l`;
    const item = field.widget === 'item', model = field.widget === 'model';
    const statics = Format.list(model ? field.choices : field.options).filter((o) => o && typeof o.value === 'string');
    const remote = item || (statics.length === 0 && str(field.source) !== '');
    const free = model && field.free === true;
    const none = field.optional === true ? (item ? STRINGS.fields.noneItem : STRINGS.fields.none) : null;
    let current = str(value);
    const text = h('span', { class: 'pick-text' });
    const thumb = h('span', { class: 'pick-thumb', hidden: true });
    const bid = free ? `${id}-b` : id;
    const button = h('button', { type: 'button', class: 'inp pick', id: bid, 'aria-haspopup': 'listbox', 'aria-expanded': 'false', 'aria-labelledby': `${lid} ${bid}` },
      thumb, text, h('span', { class: 'pick-chevron' }, icon('chevron', 16, 2)));
    const typed = free ? h('input', { class: 'inp', type: 'text', id, maxlength: '64', autocomplete: 'off', spellcheck: 'false', value: current, 'aria-labelledby': lid }) : null;
    const note = model ? h('p', { class: 'hp prov', text: STRINGS.fields.provisional, hidden: true }) : null;
    const find = (v) => (v ? (remote ? ctx.known(field, v) : statics.find((o) => o.value === v)) : null) || null;
    const provisional = () => { if (note) note.hidden = !(find(current) || {}).provisional; };
    function show() {
      const known = find(current);
      provisional();
      text.textContent = free ? STRINGS.fields.chooseModel : (current === '' ? none || STRINGS.fields.choose : (known && str(known.label)) || current);
      button.classList.toggle('empty', !free && current === '');
      const img = item && known ? image(known.image) : null;
      thumb.replaceChildren(...(img ? [img] : []));
      thumb.hidden = !img;
      if (typed && typed.value !== current) typed.value = current;
    }
    button.addEventListener('click', () => {
      if (Picker.isOpen()) { Picker.close(true); return; }
      Picker.open(button, {
        search: remote || statics.length > 12, remote, current, none,
        load: remote ? (q, p) => ctx.lookup(field, q, p) : (q) => {
          const f = Format.fold(q);
          return Promise.resolve({ items: f ? statics.filter((o) => Format.fold(o.label).includes(f)) : statics });
        },
        onPick: (o) => { if (remote && o.value) ctx.remember(field, o); current = o.value; show(); ctx.changed(); },
      });
    });
    if (typed) typed.addEventListener('input', () => { current = typed.value.trim(); provisional(); ctx.changed(); });
    show();
    return { nodes: [head(field, null, null, lid), free ? h('div', { class: 'free' }, typed, button) : button], after: note ? [note] : null,
      get: () => current, focus: () => (typed || button).focus(), control: typed || button };
  }

  function toggle(field, value, ctx) {
    const id = nextId();
    const input = h('input', { type: 'checkbox', id, checked: value === true });
    input.addEventListener('change', () => ctx.changed());
    return { nodes: [h('label', { class: 'sw', for: id }, h('span', { class: 'lb', text: str(field.label) }), input)], get: () => input.checked, focus: () => input.focus(), control: input };
  }

  function text(field, value, ctx) {
    const id = nextId();
    const max = Number(field.max) || 80;
    const counter = h('span', { class: 'count' });
    const input = field.multiline === true
      ? h('textarea', { class: 'inp area', id, rows: '4', maxlength: String(max), spellcheck: 'false', value: str(value) })
      : h('input', { class: 'inp', type: 'text', id, maxlength: String(max), autocomplete: 'off', spellcheck: 'false', value: str(value) });
    const count = () => { counter.textContent = STRINGS.fields.counter(Format.chars(input.value), max); };
    input.addEventListener('input', () => { count(); ctx.changed(); });
    count();
    return { nodes: [head(field, id, counter), input], get: () => input.value, focus: () => input.focus(), control: input };
  }

  function duration(field, value, ctx) {
    const id = nextId();
    const units = Format.UNIT_ORDER.filter((u) => Format.list(field.units).includes(u)).reverse();
    const seconds = Math.round(Number(value) || Number(field.min) || 0);
    let unit = Format.durationUnit(units, seconds);
    const amount = seconds / Format.UNIT_SECONDS[unit];
    const out = h('span', { class: 'v' });
    const input = h('input', { class: 'inp amount', type: 'text', id, inputmode: 'decimal', autocomplete: 'off', 'aria-label': STRINGS.fields.durationAmount,
      value: Format.number(amount, Number.isInteger(amount) ? 0 : 2).replace(/\s/g, '') });
    const get = () => {
      const n = Format.parseAmount(input.value);
      return Number.isFinite(n) ? Math.round(n * Format.UNIT_SECONDS[unit]) : NaN;
    };
    const show = () => { const v = get(); out.textContent = Number.isFinite(v) ? Format.duration(v) : '—'; };
    const box = h('div', { class: 'seg units', role: 'radiogroup', 'aria-label': str(field.label) });
    radios(box, units.map((u) => ({ value: u, label: STRINGS.fields.units[u], aria: STRINGS.fields.unitNames[u] })), unit, (u) => { unit = u; show(); ctx.changed(); });
    input.addEventListener('input', () => { show(); ctx.changed(); });
    show();
    return { nodes: [head(field, id, out), h('div', { class: 'dur' }, input, box)], get, focus: () => input.focus(), control: input };
  }

  const FACTORIES = { slider, segmented, select: choice, toggle, text, duration, item: choice, model: choice };

  /** Carte réseau de chaque widget (§ 6.2) : n nombre, s chaîne, b booléen. */
  const MAP = { slider: 'n', duration: 'n', toggle: 'b', segmented: 's', select: 's', text: 's', item: 's', model: 's' };

  const create = (field, value, ctx) => (FACTORIES[field.widget] ? FACTORIES[field.widget](field, value, ctx) : null);

  function defaultOf(field) {
    const d = field.default;
    const first = (list) => (Format.list(list)[0] || {}).value || '';
    switch (field.widget) {
      case 'slider': return Format.snap(field, d === undefined ? field.min : d);
      case 'duration': return Number.isFinite(Number(d)) && d !== undefined ? Number(d) : Number(field.min) || 0;
      case 'toggle': return d === true;
      case 'segmented': return typeof d === 'string' ? d : first(field.options);
      case 'select': return typeof d === 'string' ? d : (field.optional === true || field.source ? '' : first(field.options));
      case 'model': return typeof d === 'string' ? d : (field.optional === true ? '' : first(field.choices));
      default: return typeof d === 'string' ? d : '';
    }
  }

  return { create, defaultOf, MAP };
})();
