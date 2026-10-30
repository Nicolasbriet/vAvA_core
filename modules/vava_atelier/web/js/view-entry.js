'use strict';
/*
 * vava_atelier/web/js/view-entry.js
 * Rôle : fiche d'une entrée, en « page » (cadre centré) ou en « volet » (448 px) ; « Vérifier », emplacement de T-101.
 * Dépendances : strings.js, format.js, components.js
 */

const EntryView = (() => {
  const { h, icon, round, tag } = UI;
  const str = Format.str;
  const OK_MS = 3000;

  const capital = (text) => (text ? text.charAt(0).toUpperCase() + text.slice(1) : '');

  function steps(list) {
    const items = Format.list(list).filter((s) => typeof s === 'string').slice(0, 4);
    if (items.length === 0) return null;
    return h('ol', { class: 'steps', 'aria-label': STRINGS.entry.steps, style: `--steps:${items.length}` },
      items.map((label, index) => h('li', { class: index === 0 ? 'current' : '', 'aria-current': index === 0 ? 'step' : null },
        h('span', { class: 'num', text: String(index + 1) }), label)));
  }

  function compareBox(compare) {
    const box = h('div', { class: 'compare', hidden: true });
    function set(value) {
      const ok = value && typeof value === 'object' && (str(value.title) || str(value.text));
      box.replaceChildren(...(ok ? [h('span', { class: 'lb', text: str(value.title) }), h('span', { class: 'compare-text', text: str(value.text) })] : []));
      box.hidden = !ok;
    }
    set(compare);
    return { box, set };
  }

  function render(model, actions) {
    const { descriptor, kind, form } = model;
    const side = model.layout === 'side';
    const title = h('h1', { text: model.title });
    const compare = compareBox(model.compare);
    const ok = h('p', { class: 'okbar', role: 'status', hidden: true }, icon('check', 16, 2.2), h('span', { text: STRINGS.entry.checkOk }));
    // T-100 ne connaît que « Vérifier » ; les boutons de T-101 iront dans `slot`
    const declared = Format.list(model.footer).find((b) => b && b.id === 'check') || {};
    const checkLabel = str(declared.label) || STRINGS.entry.check;
    const checkButton = h('button', { type: 'button', class: `btn check${declared.primary === false ? '' : ' primary'}`, text: checkLabel, onclick: () => actions.check() });
    const slot = h('div', { class: 'slot', data: { slot: 'footer' } });
    const hint = h('p', { class: 'hp foot-hint', text: STRINGS.entry.checkHint });
    const stateTag = tag(str(model.state.label), model.state.tone);
    let okTimer = 0;

    let el;
    if (side) {
      el = h('div', { class: 'entry layout-side' },
        h('div', { class: 'side-head' },
          h('div', { class: 'title-row' }, title, stateTag),
          h('p', { class: 'hp', text: capital(str(kind.noun)) }),
          steps(kind.steps)),
        h('div', { class: 'entry-scroll' }, form.el, compare.box),
        h('footer', { class: 'entry-foot' }, ok, h('div', { class: 'foot-actions' }, slot, checkButton), hint));
    } else {
      el = h('div', { class: 'entry layout-page' },
        h('header', { class: 'page-head' },
          round('back', STRINGS.backList, () => actions.back()),
          h('span', { class: 'ico big' }, icon(descriptor.icon, 24)),
          h('div', { class: 'page-titles' },
            h('div', { class: 'title-row' }, title, stateTag),
            h('p', { class: 'hp', text: `${str(descriptor.label)} › ${str(kind.noun)}` })),
          steps(kind.steps)),
        h('div', { class: 'entry-body' },
          h('div', { class: 'entry-scroll' }, form.el),
          h('aside', { class: 'entry-aside' }, compare.box, h('p', { class: 'hp note', text: STRINGS.entry.note }))),
        h('footer', { class: 'entry-foot' }, hint, ok, h('div', { class: 'foot-actions' }, slot, checkButton)));
    }

    return {
      el,
      setTitle(text) { title.textContent = text || model.title; },
      setCompare: compare.set,
      setChecking(on) {
        checkButton.disabled = on;
        checkButton.textContent = on ? STRINGS.entry.checking : checkLabel;
      },
      flashOk() {
        clearTimeout(okTimer);
        ok.hidden = false;
        hint.hidden = true;
        okTimer = setTimeout(() => { ok.hidden = true; hint.hidden = false; }, OK_MS);
      },
      hideOk() { clearTimeout(okTimer); ok.hidden = true; hint.hidden = false; },
    };
  }

  return { render };
})();
