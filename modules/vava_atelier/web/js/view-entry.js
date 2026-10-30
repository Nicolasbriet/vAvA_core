'use strict';
/*
 * vava_atelier/web/js/view-entry.js
 * Rôle : fiche d'une entrée, en « page » (cadre centré) ou en « volet » (448 px) : étiquette d'état, ligne du tenant,
 *        lecture seule, pied rendu d'après le serveur (commandes, liens, phrase), avis d'un changement venu d'ailleurs.
 * Dépendances : strings.js, format.js, lifecycle.js, components.js
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
    const publishHint = str((descriptor.texts || {}).publishHint);
    const title = h('h1', { text: model.title });
    const compare = compareBox(model.compare);
    const ok = h('p', { class: 'okbar', role: 'status', hidden: true }, icon('check', 16, 2.2), h('span', { text: STRINGS.entry.checkOk }));
    const stateTag = h('span');
    const line = h('p', { class: 'hp state-line', hidden: true });
    const staleLine = h('p', { class: 'hp err', text: STRINGS.states.stale, hidden: true });
    const notice = h('div', { class: 'notice', role: 'status', hidden: true });
    const fields = h('fieldset', { class: 'fs' }, form.el);
    const commands = h('div', { class: 'foot-actions' });
    const links = h('div', { class: 'foot-links' });
    const hint = h('p', { class: 'hp foot-hint' });
    let okTimer = 0, buttons = [], tone = '', shown = [];

    function setState(state, text, stale) {
      tone = str(state && state.tone) || 'live';
      stateTag.replaceChildren(tag(str(state && state.label), tone));
      line.textContent = text || '';
      line.hidden = !text;
      staleLine.hidden = stale !== true;
    }

    function setFooter(footer) {
      shown = footer;
      const got = Lifecycle.foot(footer, { tone, publishHint });
      const button = (b, cls) => h('button', { type: 'button', class: cls, text: b.label, data: { id: b.id }, onclick: () => actions.run(b.id) });
      commands.replaceChildren(...got.commands.map((b) => button(b, `btn${b.primary ? ' primary' : ''}`)));
      links.replaceChildren(...got.links.map((b) => button(b, 'link')));
      links.hidden = got.links.length === 0;
      hint.textContent = got.hint;
      hint.hidden = !got.hint;
      buttons = Array.from(commands.children).concat(Array.from(links.children));
    }

    setState(model.state, model.line, model.stale);
    setFooter(model.footer);
    fields.disabled = model.readOnly === true;

    let el;
    if (side) {
      el = h('div', { class: 'entry layout-side' },
        h('div', { class: 'side-head' },
          h('div', { class: 'title-row' }, title, stateTag),
          line, staleLine,
          h('p', { class: 'hp', text: capital(str(kind.noun)) }),
          steps(kind.steps)),
        h('div', { class: 'entry-scroll' }, notice, fields, compare.box),
        h('footer', { class: 'entry-foot' }, ok, commands, hint, links));
    } else {
      el = h('div', { class: 'entry layout-page' },
        h('header', { class: 'page-head' },
          round('back', model.backLabel || STRINGS.backList, () => actions.back()),
          h('span', { class: 'ico big' }, icon(descriptor.icon, 24)),
          h('div', { class: 'page-titles' },
            h('div', { class: 'title-row' }, title, stateTag),
            h('p', { class: 'hp', text: `${str(descriptor.label)} › ${str(kind.noun)}` }),
            line, staleLine),
          steps(kind.steps)),
        h('div', { class: 'entry-body' },
          h('div', { class: 'entry-scroll' }, notice, fields),
          h('aside', { class: 'entry-aside' }, compare.box, h('p', { class: 'hp note', text: STRINGS.entry.note }))),
        h('footer', { class: 'entry-foot' }, h('div', { class: 'foot-left' }, hint, ok, links), commands));
    }

    return {
      el,
      setTitle(text) { title.textContent = text || model.title; },
      setCompare: compare.set,
      setState,
      setFooter,
      setReadOnly(on) { fields.disabled = on; },
      setBusy(on, id) {
        for (const node of buttons) {
          node.disabled = on;
          if (node.dataset.id === id) node.textContent = on ? (id === 'check' ? STRINGS.entry.checking : STRINGS.working) : Lifecycle.label(shown, id);
        }
      },
      setNotice(text, reload) {
        notice.replaceChildren(...(text ? [h('span', { text }), reload ? h('button', { type: 'button', class: 'link', text: STRINGS.changed.reload, onclick: reload }) : null] : []));
        notice.hidden = !text;
      },
      flashOk() {
        clearTimeout(okTimer);
        ok.hidden = false;
        hint.hidden = true;
        okTimer = setTimeout(() => { ok.hidden = true; hint.hidden = !hint.textContent; }, OK_MS);
      },
      hideOk() { clearTimeout(okTimer); ok.hidden = true; hint.hidden = !hint.textContent; },
    };
  }

  return { render };
})();
