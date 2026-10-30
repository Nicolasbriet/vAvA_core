'use strict';
/*
 * vava_atelier/web/js/view-list.js
 * Rôle : liste d'un atelier : onglets par genre, filtre (300 ms), lignes, création, pages de 50.
 * Dépendances : strings.js, format.js, components.js
 */

const ListView = (() => {
  const { h, icon, round } = UI;
  const str = Format.str;
  const FILTER_DELAY = 300;

  const capital = (text) => (text ? text.charAt(0).toUpperCase() + text.slice(1) : '');

  function render(model, actions) {
    const descriptor = model.descriptor;
    const kinds = Format.list(descriptor.kinds);
    const kind = model.kind;

    const filter = h('input', { type: 'search', class: 'inp filter', placeholder: STRINGS.list.filter(str(kind.nounPlural)), 'aria-label': STRINGS.list.filterLabel,
      autocomplete: 'off', spellcheck: 'false', maxlength: '48', value: model.query || '' });
    let timer = 0;
    filter.addEventListener('input', () => {
      clearTimeout(timer);
      timer = setTimeout(() => actions.filter(Format.query(filter.value)), FILTER_DELAY);
    });
    filter.addEventListener('keydown', (event) => {
      if (event.key !== 'Enter') return;
      event.preventDefault();
      clearTimeout(timer);
      actions.filter(Format.query(filter.value));
    });

    const count = h('span', { class: 'hp count-line' });
    const rows = h('div', { class: 'rows', role: 'list' });
    const pager = h('div', { class: 'pager', hidden: true });

    const tabs = kinds.length > 1 ? h('nav', { class: 'tabs', 'aria-label': STRINGS.list.tabs }, kinds.map((k) => h('button', {
      type: 'button', class: `tab${k.id === kind.id ? ' on' : ''}`, 'aria-current': k.id === kind.id ? 'page' : null,
      text: capital(str(k.nounPlural)), onclick: () => { if (k.id !== kind.id) actions.selectKind(k.id); } }))) : null;

    const create = kind.creatable !== false ? h('button', { type: 'button', class: 'btn dark', text: STRINGS.list.create(str(kind.noun), str(kind.newLabel)), onclick: () => actions.create() }) : null;

    const el = h('div', { class: 'list-screen' },
      h('header', { class: 'page-head' },
        round('back', STRINGS.back, () => actions.back()),
        h('span', { class: 'ico big' }, icon(descriptor.icon, 24)),
        h('div', { class: 'page-titles' }, h('h1', { text: str(descriptor.label) }), h('p', { class: 'hp', text: str(descriptor.description) }))),
      tabs,
      h('div', { class: 'list-body' },
        h('div', { class: 'toolbar' }, filter, count, create),
        rows, pager));

    function setData(data) {
      const entries = Format.list(data.entries).filter((e) => e && typeof e.id === 'string');
      const total = Number.isInteger(data.total) ? data.total : entries.length;
      count.textContent = STRINGS.list.count(total, str(kind.noun), str(kind.nounPlural));
      if (entries.length === 0) {
        rows.replaceChildren(h('p', { class: 'hp empty', text: model.query ? STRINGS.list.noMatch : STRINGS.list.empty }));
      } else {
        rows.replaceChildren(...entries.map((entry) => h('div', { class: 'row', role: 'listitem' },
          h('button', { type: 'button', class: 'row-main', onclick: () => actions.openEntry(entry.id) },
            h('span', { class: 'row-title', text: str(entry.title) || entry.id }),
            str(entry.hint) ? h('span', { class: 'hp', text: entry.hint }) : null),
          h('button', { type: 'button', class: 'btn small', text: STRINGS.list.open, onclick: () => actions.openEntry(entry.id) }))));
      }
      const page = Number.isInteger(data.page) ? data.page : 1;
      const pages = Number.isInteger(data.pages) ? data.pages : 1;
      pager.hidden = pages <= 1;
      pager.replaceChildren(
        h('button', { type: 'button', class: 'link', text: STRINGS.list.previous, disabled: page <= 1, onclick: () => actions.page(page - 1) }),
        h('span', { class: 'hp', text: STRINGS.list.page(page, pages) }),
        h('button', { type: 'button', class: 'link', text: STRINGS.list.next, disabled: page >= pages, onclick: () => actions.page(page + 1) }));
    }

    function setError(code) {
      rows.replaceChildren(h('p', { class: 'hp empty err', text: errorText(code) }));
    }

    return { el, setData, setError, focus: () => filter.focus() };
  }

  return { render };
})();
