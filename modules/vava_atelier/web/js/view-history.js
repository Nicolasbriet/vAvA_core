'use strict';
/*
 * vava_atelier/web/js/view-history.js
 * Rôle : historique d'une fiche (versions figées, les plus récentes d'abord, « Plus anciennes ») dans le cadre de la
 *        fiche (page ou volet) ; « Voir » ouvre une version en lecture, « Revenir à cette version » la rétablit.
 * Dépendances : strings.js, format.js, lifecycle.js, components.js
 */

const HistoryView = (() => {
  const { h, icon, round, tag } = UI;
  const H = STRINGS.history;

  function row(r, actions) {
    return h('div', { class: 'jr hrow' },
      h('div', { class: 'hrow-top' }, tag(r.tag, r.tone), h('strong', { text: r.title }), r.from ? h('span', { class: 'hp', text: r.from }) : null),
      r.summary ? h('span', { class: 'jl', text: r.summary }) : null,
      h('div', { class: 'jw' }, h('span', { text: r.who }),
        h('span', { class: 'hrow-acts' },
          h('button', { type: 'button', class: 'link', text: H.view, onclick: () => actions.view(r.version) }),
          r.canRestore ? h('button', { type: 'button', class: 'link', text: H.restore, onclick: () => actions.restore(r.version) }) : null)));
  }

  function render(model, actions) {
    const side = model.layout === 'side';
    const lines = h('div', { class: 'journal-lines' });
    const older = h('button', { type: 'button', class: 'btn', text: H.older, hidden: true, onclick: () => actions.older() });
    const back = round('back', H.back, () => actions.back());
    const titles = h('div', { class: 'page-titles' }, h('h1', { text: H.title }), h('p', { class: 'hp', text: model.title }));
    const el = h('div', { class: `history ${side ? 'layout-side' : 'layout-page'}` },
      h('header', { class: side ? 'side-head history-head' : 'page-head' }, back, side ? null : h('span', { class: 'ico big' }, icon(model.descriptor.icon, 24)), titles),
      h('div', { class: 'journal-body' }, lines, h('div', { class: 'pager' }, older)));
    let last = 0;

    return {
      el,
      add(data, reset) {
        const rows = Lifecycle.history(data.versions);
        if (reset) lines.replaceChildren();
        for (const r of rows) lines.append(row(r, actions));
        if (rows.length > 0) last = rows[rows.length - 1].version;
        if (lines.childElementCount === 0) lines.append(h('p', { class: 'hp empty', text: H.none }));
        older.hidden = data.more !== true;
      },
      setError(code) {
        lines.replaceChildren(h('p', { class: 'hp empty err', text: errorText(code) }));
        older.hidden = true;
      },
      setLoading(on) { older.disabled = on; },
      oldest: () => last,
      focus: () => back.focus(),
    };
  }

  return { render };
})();
