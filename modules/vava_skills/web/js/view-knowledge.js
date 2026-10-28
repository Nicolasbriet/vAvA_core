'use strict';
/*
 * web/js/view-knowledge.js
 * Rôle : onglet Savoirs, sur deux pages : à gauche les savoirs transmis connus (nom, compétence) et les apprentissages
 *        en cours (leçons reçues, prochaine leçon possible) ; à droite le savoir choisi (source, professeur, date) et
 *        sa lignée, lue au serveur à la demande (de soi jusqu'au fondateur) puis gardée tant que le livre est ouvert.
 */

const KnowledgeView = (() => {
  const T = STRINGS.knowledge;

  function recipeEntry(recipe, selected, rerender) {
    const entry = UI.button('', `entry${recipe.id === selected ? ' is-selected' : ''}`, () => {
      Model.state.selectedRecipe = recipe.id;
      rerender();
    });
    entry.append(
      UI.el('span', 'entry-main', null, [
        UI.el('span', 'entry-name', recipe.label),
        UI.el('span', 'entry-sub', Model.skillLabel(recipe.skill)),
      ]),
      UI.el('span', 'entry-seal', '✦'),
    );
    return entry;
  }

  function lessonEntry(lesson) {
    const now = Model.now();
    const wait = lesson.nextAllowedAt > now ? T.nextLesson(UI.duration(lesson.nextAllowedAt - now)) : T.nextLessonNow;
    const share = Math.max(0, Math.min(1, lesson.count / Math.max(1, lesson.required)));
    const fill = UI.el('div', 'xp-fill is-lesson');
    fill.style.transform = `scaleX(${share})`;
    return UI.el('div', 'lesson', null, [
      UI.el('div', 'entry-main', null, [
        UI.el('span', 'entry-name', lesson.label),
        UI.el('span', 'entry-sub', `${Model.skillLabel(lesson.skill)} · ${T.lessons(lesson.count, lesson.required)}`),
      ]),
      UI.el('div', 'xp', null, [UI.el('div', 'xp-track', null, [fill]), UI.el('span', 'xp-caption', wait)]),
    ]);
  }

  function chain(lineage) {
    const list = UI.el('ol', 'lineage');
    const links = Model.list(lineage.chain);
    links.forEach((link, index) => {
      const last = index === links.length - 1;
      const who = index === 0 ? T.you : (last ? T.founder : '');
      const source = T.source[link.source] || link.source || '';
      list.append(UI.el('li', `lineage-link${index === 0 ? ' is-you' : ''}${last ? ' is-founder' : ''}`, null, [
        UI.el('span', 'lineage-name', link.name),
        who ? UI.el('span', 'lineage-tag', who) : null,
        UI.el('span', 'lineage-sub', [link.learnedAt ? UI.date(link.learnedAt) : '', source].filter(Boolean).join(' · ')),
      ]));
    });
    return list;
  }

  async function loadLineage(recipeId, holder) {
    holder.replaceChildren(UI.el('p', 'prose is-muted', T.loading));
    const result = await Bridge.post('lineage', { recipe: recipeId });
    if (!result.ok || !result.lineage) {
      holder.replaceChildren(UI.el('p', 'prose is-muted', result.ok ? T.lineageUnavailable : errorMessage(result.error)));
      return;
    }
    Model.state.lineages.set(recipeId, result.lineage);
    if (Model.state.selectedRecipe === recipeId) holder.replaceChildren(UI.el('p', 'prose', T.lineageIntro), chain(result.lineage));
  }

  function detail(recipe) {
    const page = UI.el('div', 'page page-right');
    const facts = [T.source[recipe.source] || recipe.source || ''];
    if (recipe.taughtBy) facts.push(T.taughtBy(recipe.taughtBy.name));
    if (recipe.learnedAt) facts.push(T.learnedOn(UI.date(recipe.learnedAt)));
    page.append(
      UI.el('div', 'recipe-head', null, [
        UI.el('h2', 'page-title', recipe.label),
        UI.el('span', 'entry-seal is-large', '✦'),
      ]),
      UI.el('p', 'summary', Model.skillLabel(recipe.skill)),
      UI.el('ul', 'facts', null, facts.filter(Boolean).map((fact) => UI.el('li', null, fact))),
      UI.section(T.lineage),
    );
    const holder = UI.el('div', 'lineage-holder');
    const known = Model.state.lineages.get(recipe.id);
    if (known) holder.append(UI.el('p', 'prose', T.lineageIntro), chain(known));
    else holder.append(UI.button(T.showLineage, 'button button-primary', () => loadLineage(recipe.id, holder)));
    page.append(holder);
    return page;
  }

  function render(pages) {
    const sheet = Model.state.sheet;
    const rerender = () => App.render();
    const left = UI.el('div', 'page page-left');
    left.append(UI.section(T.known));
    if (sheet.recipes.length === 0) left.append(UI.el('p', 'prose is-muted', T.none));
    for (const recipe of sheet.recipes) left.append(recipeEntry(recipe, Model.state.selectedRecipe, rerender));
    left.append(UI.section(T.learning));
    if (sheet.lessons.length === 0) left.append(UI.el('p', 'prose is-muted', T.noLearning));
    for (const lesson of sheet.lessons) left.append(lessonEntry(lesson));

    const selected = sheet.recipes.find((recipe) => recipe.id === Model.state.selectedRecipe);
    const right = selected ? detail(selected) : UI.el('div', 'page page-right', null, [UI.el('p', 'empty', T.select)]);
    pages.classList.remove('is-single');
    pages.append(left, right);
  }

  return { render };
})();
