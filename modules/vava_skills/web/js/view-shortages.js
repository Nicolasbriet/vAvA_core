'use strict';
/*
 * web/js/view-shortages.js
 * Rôle : onglet Pénurie : les métiers qui manquent de bras dans le royaume (compteur d'artisans confirmés,
 *        multiplicateur d'expérience), avec le texte qui explique la règle. La liste vient de la fiche et peut être
 *        relue au serveur (panneau d'affichage).
 */

const ShortagesView = (() => {
  const T = STRINGS.shortages;

  function row(entry) {
    return UI.el('div', 'shortage-row', null, [
      UI.el('div', 'entry-main', null, [
        UI.el('span', 'entry-name', entry.label || Model.skillLabel(entry.skill)),
        UI.el('span', 'entry-sub', T.count(entry.count || 0)),
      ]),
      UI.el('span', 'shortage-mult', T.multiplier(entry.multiplier || 1)),
    ]);
  }

  function render(pages) {
    const sheet = Model.state.sheet;
    const page = UI.el('div', 'page');
    page.append(UI.section(T.title), UI.el('p', 'prose', T.intro));
    if (sheet.shortages.length === 0) page.append(UI.el('p', 'prose is-muted', T.none));
    for (const entry of sheet.shortages) page.append(row(entry));
    page.append(UI.el('p', 'prose is-muted is-footnote', T.board));
    pages.classList.add('is-single');
    pages.append(page);
  }

  /** Relit la liste au serveur (le livre affiche alors ce que montrerait un panneau). */
  async function refresh() {
    const result = await Bridge.post('shortages', {});
    if (result.ok && result.shortages && Model.state.sheet) {
      Model.state.sheet.shortages = Model.list(result.shortages);
      if (Model.state.tab === 'penurie') App.render();
    }
  }

  return { render, refresh };
})();
