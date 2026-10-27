'use strict';
/*
 * web/js/view-announce.js
 * Rôle : onglet Proclamation : texte lu par tout le royaume, avec son aperçu tel qu'il apparaîtra.
 */

const AnnounceView = (() => {
  const N = STRINGS.announce;

  function show(ctx) {
    const area = UI.el('textarea', 'field-input field-lines');
    area.rows = 4;
    area.maxLength = 500;
    area.id = 'announce-text';
    const label = UI.el('label', 'field-label', N.label);
    label.htmlFor = area.id;
    const previewText = UI.el('p', 'proclamation-text', '');
    const preview = UI.el('div', 'proclamation is-preview', null, [
      UI.el('p', 'proclamation-title', N.title), previewText, UI.el('p', 'proclamation-author', ctx.session.rank.label),
    ]);
    area.addEventListener('input', () => { previewText.textContent = area.value; });
    const send = UI.button(N.confirm, async () => {
      const text = area.value.trim();
      if (!text) return;
      if (UI.report(await Bridge.request('announce', text), N.sent)) {
        area.value = '';
        previewText.textContent = '';
      }
    }, 'seal');
    ctx.single.replaceChildren(
      UI.heading(N.heading),
      UI.el('div', 'field', null, [label, area]),
      UI.el('p', 'hint', N.hint),
      UI.el('h3', 'group-title', N.preview),
      preview,
      UI.el('div', 'group-buttons', null, [send]),
    );
  }

  return { id: 'announce', permission: 'announce', single: true, show };
})();
