'use strict';
/*
 * vava_atelier/web/js/view-journal.js — journal entier : filtre par atelier, lignes par 25
 * Dépendances : strings.js, format.js, components.js
 */

const JournalView = (() => {
  const { h, icon, round, journalLine, Picker } = UI;
  const str = Format.str;

  function render(model, actions) {
    const labels = new Map(model.editors.map((e) => [e.editor, e.label]));
    const items = [{ value: '', label: STRINGS.journal.allEditors }].concat(model.editors.map((e) => ({ value: e.editor, label: e.label })));
    const pickText = h('span', { class: 'pick-text', text: labels.get(model.filter) || STRINGS.journal.allEditors });
    const pick = h('button', { type: 'button', class: 'inp pick', 'aria-haspopup': 'listbox', 'aria-expanded': 'false', 'aria-label': STRINGS.journal.filter },
      pickText, h('span', { class: 'pick-chevron' }, icon('chevron', 16, 2)));
    pick.addEventListener('click', () => {
      if (Picker.isOpen()) { Picker.close(true); return; }
      Picker.open(pick, {
        search: items.length > 12, current: model.filter,
        load: (query) => {
          const q = Format.fold(query);
          return Promise.resolve({ items: q ? items.filter((i) => Format.fold(i.label).includes(q)) : items, more: false });
        },
        onPick: (item) => { if (item.value !== model.filter) actions.filter(item.value); },
      });
    });

    const lines = h('div', { class: 'journal-lines' });
    const older = h('button', { type: 'button', class: 'btn', text: STRINGS.journal.older, hidden: true, onclick: () => actions.older() });

    const el = h('div', { class: 'journal-screen' },
      h('header', { class: 'page-head' },
        round('back', STRINGS.back, () => actions.back()),
        h('div', { class: 'page-titles' }, h('h1', { text: STRINGS.journal.title })),
        h('label', { class: 'journal-filter' }, h('span', { class: 'lb', text: STRINGS.journal.filter }), pick)),
      h('div', { class: 'journal-body' }, lines, h('div', { class: 'pager' }, older)));

    return {
      el,
      add(data, reset) {
        const list = Format.list(data.lines).filter((l) => l && typeof l === 'object');
        if (reset) lines.replaceChildren();
        // filtrée, la ligne n'a pas d'`editor` : c'est celui du filtre
        for (const line of list) lines.append(journalLine(line, model.filter ? '' : labels.get(str(line.editor)) || ''));
        if (lines.childElementCount === 0) lines.append(h('p', { class: 'hp empty', text: STRINGS.journal.none }));
        older.hidden = data.more !== true;
      },
      setError(code, text) {
        lines.replaceChildren(h('p', { class: 'hp empty err', text: errorText(code, text) }));
        older.hidden = true;
      },
      setLoading(on) { older.disabled = on; },
      focus: () => pick.focus(),
    };
  }

  return { render };
})();
