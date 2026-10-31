'use strict';
/*
 * vava_atelier/web/js/components.js — pièces communes (texte TOUJOURS par textContent) : icônes, Picker, Confirm, Toast…
 * Dépendances : strings.js, format.js
 */

const UI = (() => {
  const SVG_NS = 'http://www.w3.org/2000/svg';
  const byId = (id) => document.getElementById(id);

  function h(tag, props, ...children) {
    const el = document.createElement(tag);
    for (const [key, value] of Object.entries(props || {})) {
      if (value === null || value === undefined || value === false) continue;
      if (key === 'class') el.className = value;
      else if (key === 'text') el.textContent = value;
      else if (key === 'data') Object.assign(el.dataset, value);
      else if (key === 'value' || key === 'checked') el[key] = value;
      else if (key.startsWith('on') && typeof value === 'function') el.addEventListener(key.slice(2), value);
      else el.setAttribute(key, value === true ? '' : String(value));
    }
    return append(el, children);
  }

  function append(el, children) {
    for (const child of children) {
      if (child === null || child === undefined || child === false) continue;
      if (Array.isArray(child)) append(el, child);
      else el.append(child instanceof Node ? child : document.createTextNode(String(child)));
    }
    return el;
  }

  // 24 × 24 : une chaîne = un chemin, [cx, cy, r] = un cercle
  const ICONS = {
    recolte: ['M12 3c-3 0-5 2.5-5 5 0 1 .3 2 .8 2.7C6.6 11.5 6 12.7 6 14c0 2.5 2.7 4 6 4s6-1.5 6-4c0-1.3-.6-2.5-1.8-3.3.5-.7.8-1.7.8-2.7 0-2.5-2-5-5-5z', 'M12 18v3'],
    agriculture: ['M12 21V8', 'M12 12c-2-.5-3.5-2-4-4 2 .3 3.5 1.5 4 4zM12 12c2-.5 3.5-2 4-4-2 .3-3.5 1.5-4 4zM12 16c-2-.5-3.5-2-4-4 2 .3 3.5 1.5 4 4zM12 16c2-.5 3.5-2 4-4-2 .3-3.5 1.5-4 4zM12 8c-1-1-1-3 0-5 1 2 1 4 0 5z'],
    artisanat: ['M3 9h13c0 3-2 5-5 5H8', 'M16 9h3c0 2-1 3-3 3', 'M9 14l-1 5h8l-1-5'],
    porte: ['M6 21V5a2 2 0 012-2h8a2 2 0 012 2v16', 'M4 21h16', [14.5, 12, 1]],
    confrerie: ['M6 3v18', 'M6 4h12l-3 4 3 4H6'],
    logis: ['M3 11l9-7 9 7', 'M5 10v10h14V10', 'M10 20v-5h4v5'],
    geste: [[12, 4.5, 1.8], 'M12 7v7M12 14l-3 7M12 14l3 7M7 10l5-1 5 2'],
    combat: ['M4 20L16 8l2-4-4 2L4 18', 'M20 20L8 8 6 4l4 2 10 12'],
    effet: ['M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z', 'M19 17l.7 2 2 .7-2 .7-.7 2-.7-2-2-.7 2-.7z'],
    sort: ['M12 21c-4 0-6-2.5-6-6 0-4 4-6 4-11 3 2 4 5 4 7 1-1 1.5-2 1.5-3 2 2 2.5 4 2.5 7 0 3.5-2 6-6 6z'],
    parchemin: ['M6 4h11a2 2 0 012 2v1h-4', 'M17 4a2 2 0 00-2 2v12a2 2 0 01-2 2H6a2 2 0 01-2-2v-1h9', 'M8 9h5M8 12.5h5'],
    search: [[11, 11, 7], 'M20 20l-4-4'],
    close: ['M6 6l12 12M18 6L6 18'],
    back: ['M15 5l-7 7 7 7'],
    chevron: ['M6 9l6 6 6-6'],
    check: ['M5 12.5l4.5 4.5L19 7.5'],
  };

  function icon(name, size = 22, stroke = 1.6) {
    const node = (tag, attrs) => {
      const el = document.createElementNS(SVG_NS, tag);
      for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, String(v));
      return el;
    };
    const svg = node('svg', { viewBox: '0 0 24 24', width: size, height: size, fill: 'none', stroke: 'currentColor', 'stroke-width': stroke,
      'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'aria-hidden': 'true' });
    for (const part of ICONS[name] || ICONS.parchemin) {
      svg.append(typeof part === 'string' ? node('path', { d: part }) : node('circle', { cx: part[0], cy: part[1], r: part[2] }));
    }
    return svg;
  }

  const round = (name, label, onclick) => h('button', { type: 'button', class: 'round', 'aria-label': label, title: label, onclick }, icon(name, 16, 2));

  const tag = (text, tone = 'count') => h('span', { class: `tag tag-${tone}`, text });

  /** Image d'objet : seulement un chemin nui://, sinon rien. */
  function image(src) {
    if (typeof src !== 'string' || !/^nui:\/\/[\w.-]+\/[\w./-]+$/.test(src)) return null;
    const img = h('img', { class: 'thumb', src, alt: '', draggable: 'false' });
    img.addEventListener('error', () => { img.hidden = true; }, { once: true });
    return img;
  }

  function journalLine(line, editorLabel) {
    const str = Format.str, summary = str(line.summary);
    return h('div', { class: 'jr' },
      h('span', { class: 'jl' }, str(line.lead) ? `${line.lead} ` : '', h('strong', { text: str(line.title) }), summary ? STRINGS.journal.summary(summary) : ''),
      h('span', { class: 'jw' }, STRINGS.journal.who(str(line.actor), str(line.when)), editorLabel ? h('span', { class: 'jed', text: editorLabel }) : null));
  }

  const Toast = (() => {
    let timer = 0;
    return {
      show(text, kind = 'info', ms = 3600) {
        const node = byId('toast');
        node.textContent = String(text || '');
        node.dataset.kind = kind === 'error' || kind === 'danger' ? 'error' : (kind === 'success' ? 'success' : 'info');
        node.hidden = false;
        clearTimeout(timer);
        timer = setTimeout(() => { node.hidden = true; }, ms);
      },
    };
  })();

  const Confirm = (() => {
    let resolver = null, lastFocus = null;
    function settle(value) {
      const resolve = resolver;
      resolver = null;
      byId('confirm').hidden = true;
      byId('confirm').replaceChildren();
      if (lastFocus && document.contains(lastFocus)) lastFocus.focus();
      if (resolve) resolve(value);
    }
    const items = (texts, cls) => (texts && texts.length > 0 ? h('ul', { class: cls }, texts.map((text) => h('li', { text }))) : null);
    function ask({ title, text, lines, warnings, errors, hint, cancel, ok }) {
      if (resolver) settle(false);
      lastFocus = document.activeElement;
      const stay = h('button', { type: 'button', class: ok ? 'btn' : 'btn primary', text: cancel, onclick: () => settle(false) });
      byId('confirm').replaceChildren(h('div', { class: 'dialog', role: 'alertdialog', 'aria-modal': 'true', 'aria-labelledby': 'confirm-title' },
        h('div', { class: 'dialog-sheet' }, h('h2', { id: 'confirm-title', text: title }), text ? h('p', { text }) : null,
          items(lines, 'dialog-lines'), items(errors, 'dialog-lines err'), items(warnings, 'dialog-lines err'), hint ? h('p', { class: 'hp', text: hint }) : null,
          h('div', { class: 'dialog-actions' }, stay, ok ? h('button', { type: 'button', class: 'btn primary', text: ok, onclick: () => settle(true) }) : null))));
      byId('confirm').hidden = false;
      stay.focus();
      return new Promise((resolve) => { resolver = resolve; });
    }
    return { ask, isOpen: () => resolver !== null, cancel: () => settle(false) };
  })();

  // Picker.open(bouton, { search, remote, current, none, load(texte, page) → Promise<{ items, more, error? }>, onPick })
  const Picker = (() => {
    let state = null, timer = 0;
    const options = () => (state ? Array.from(state.list.querySelectorAll('.picker-option')) : []);

    function open(anchor, opts) {
      close();
      const search = opts.search ? h('input', { type: 'search', class: 'picker-search', placeholder: STRINGS.picker.search, 'aria-label': STRINGS.picker.search, autocomplete: 'off', spellcheck: 'false', maxlength: '48' }) : null;
      const list = h('div', { class: 'picker-list', role: 'listbox' });
      const status = h('p', { class: 'picker-status' });
      const more = h('button', { type: 'button', class: 'picker-more', text: STRINGS.picker.more, hidden: true, onclick: () => { state.page += 1; load(false); } });
      state = { anchor, opts, list, status, more, search, page: 1, seq: 0 };
      if (search) {
        search.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(() => load(true), opts.remote ? 300 : 0); });
        search.addEventListener('keydown', (event) => {
          if (event.key === 'ArrowDown' || event.key === 'Enter') { event.preventDefault(); const first = options()[0]; if (first) (event.key === 'Enter' ? first.click() : first.focus()); }
        });
      }
      list.addEventListener('keydown', (event) => {
        if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return;
        event.preventDefault();
        const items = options();
        const next = items.indexOf(document.activeElement) + (event.key === 'ArrowDown' ? 1 : -1);
        if (next < 0 && search) search.focus();
        else if (items.length > 0) items[Math.max(0, Math.min(items.length - 1, next))].focus();
      });
      const box = byId('picker');
      box.replaceChildren(search || '', list, status, more);
      anchor.setAttribute('aria-expanded', 'true');
      box.hidden = false;
      place(box, anchor);
      load(true).then(() => {
        if (!state || state.anchor !== anchor) return;
        const items = options();
        (search || items.find((n) => n.classList.contains('on')) || items[0] || box).focus();
      });
    }

    function place(box, anchor) {
      const rect = anchor.getBoundingClientRect();
      const rem = parseFloat(getComputedStyle(document.documentElement).fontSize) || 16;
      const width = Math.min(Math.max(rect.width, 16 * rem), innerWidth - 2 * rem);
      const below = innerHeight - rect.bottom - rem, above = rect.top - rem;
      const up = below < 12 * rem && above > below;
      Object.assign(box.style, {
        width: `${width}px`, left: `${Math.max(rem / 2, Math.min(rect.left, innerWidth - width - rem / 2))}px`, maxHeight: `${Math.min(22 * rem, up ? above : below)}px`,
        top: up ? '' : `${rect.bottom + rem / 4}px`, bottom: up ? `${innerHeight - rect.top + rem / 4}px` : '',
      });
    }

    async function load(reset) {
      const current = state;
      if (!current) return;
      if (reset) { current.page = 1; current.list.replaceChildren(); }
      const query = current.search ? Format.query(current.search.value) : '';
      const seq = ++current.seq;
      current.status.textContent = STRINGS.picker.loading;
      current.status.hidden = false;
      current.more.hidden = true;
      const result = await current.opts.load(query, current.page);
      if (state !== current || seq !== current.seq) return;
      if (!result || result.error) { current.status.textContent = errorText(result && result.error, result && result.text); return; }
      if (reset && current.opts.none && query === '') current.list.append(option({ value: '', label: current.opts.none }));
      for (const item of Format.list(result.items)) if (item && typeof item.value === 'string') current.list.append(option(item));
      const empty = current.list.childElementCount === 0;
      current.status.textContent = empty ? STRINGS.picker.empty : '';
      current.status.hidden = !empty;
      current.more.hidden = result.more !== true;
    }

    function option(item) {
      const on = item.value === state.opts.current;
      const pick = state.opts.onPick;
      return h('button', { type: 'button', role: 'option', 'aria-selected': String(on), class: `picker-option${on ? ' on' : ''}${item.value === '' ? ' none' : ''}`,
        onclick: () => { close(true); pick(item); } },
        image(item.image), h('span', { class: 'picker-label', text: Format.str(item.label) || item.value }),
        item.provisional === true ? h('span', { class: 'picker-note', text: STRINGS.picker.provisional }) : null);
    }

    function close(refocus) {
      clearTimeout(timer);
      if (!state) return;
      const anchor = state.anchor;
      state = null;
      byId('picker').hidden = true;
      byId('picker').replaceChildren();
      anchor.setAttribute('aria-expanded', 'false');
      if (refocus && document.contains(anchor)) anchor.focus();
    }

    const outside = (event) => { if (state && !byId('picker').contains(event.target) && !state.anchor.contains(event.target)) close(false); };
    document.addEventListener('mousedown', outside);
    document.addEventListener('scroll', (event) => { if (state && !byId('picker').contains(event.target)) place(byId('picker'), state.anchor); }, true);
    window.addEventListener('resize', () => close(false));
    return { open, close, isOpen: () => state !== null };
  })();

  const Banner = {
    show(title, line, back) {
      byId('banner').replaceChildren(round('back', STRINGS.back, back),
        h('span', { class: 'banner-text' }, h('span', { class: 'banner-title', text: title }), line ? h('span', { class: 'banner-line', text: line }) : null));
      byId('banner').hidden = false;
    },
    hide() { byId('banner').hidden = true; },
  };

  const Keys = {
    show(keys) {
      const rows = Format.list(keys).filter((k) => k && typeof k.label === 'string');
      byId('keys').replaceChildren(h('div', { class: 'keys-bar' }, rows.map((k) => h('span', { class: 'kh' },
        Format.list(k.keys).filter((key) => typeof key === 'string').map((key) => h('span', { class: 'kc', text: key })), h('span', { text: k.label })))));
      byId('keys').hidden = rows.length === 0;
    },
    hide() { byId('keys').hidden = true; },
  };

  return { h, append, icon, round, tag, image, journalLine, Toast, Confirm, Picker, Banner, Keys };
})();
