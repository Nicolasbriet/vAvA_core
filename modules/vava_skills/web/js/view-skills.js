'use strict';
/*
 * web/js/view-skills.js
 * Rôle : onglet Compétences : budget de points en tête (utilisés / total au-delà du savoir commun), compétences
 *        groupées par catégorie ; pour chacune : signe de rouille cliquable (↑ → = → ↓), nom, rang, sceau du niveau,
 *        barre d'XP, badges (pénurie, savoir de maître, Renommée), maître et apprentis en résumé, dernière pratique.
 *        Un changement de signe part au serveur ; la page est redessinée à sa réponse ou à un évènement du serveur.
 */

const SkillsView = (() => {
  const S = STRINGS.skill;
  const M = STRINGS.modes;
  const ORDER = ['up', 'keep', 'down'];

  const nextMode = (mode) => ORDER[(Math.max(0, ORDER.indexOf(mode)) + 1) % ORDER.length];

  async function cycle(skill) {
    const result = await Bridge.post('setMode', { skill: skill.id, mode: nextMode(skill.mode) });
    if (!result.ok) {
      App.toast(errorMessage(result.error), 'warning');
      return;
    }
    Model.updateSkill(result.skill, result.budget);
    App.render();
  }

  function budgetBlock(sheet) {
    const B = STRINGS.budget;
    const { used, total } = sheet.budget;
    const ratio = total > 0 ? Math.min(1, used / total) : 0;
    const fill = UI.el('div', `budget-fill${ratio >= 1 ? ' is-full' : ''}`);
    fill.style.transform = `scaleX(${ratio})`;
    const remaining = Math.max(0, total - used);
    return UI.el('section', 'budget', null, [
      UI.el('div', 'budget-head', null, [
        UI.el('h2', 'budget-title', B.title),
        UI.el('span', 'budget-count', B.used(used, total)),
      ]),
      UI.el('div', 'budget-track', null, [fill]),
      UI.el('p', `budget-note${remaining === 0 ? ' is-full' : ''}`, remaining === 0 ? B.full : B.remaining(remaining)),
      UI.el('p', 'budget-common', B.common(sheet.rules.commonKnowledge || 0)),
    ]);
  }

  function legend() {
    const node = UI.el('p', 'mode-legend', null, [document.createTextNode(`${M.legend} `)]);
    for (const mode of ORDER) {
      node.append(UI.el('span', `mode-glyph is-${mode}`, M[mode].glyph), ` ${M[mode].label}`, mode !== 'down' ? ', ' : '.');
    }
    return node;
  }

  function badges(skill) {
    const list = [];
    if (skill.shortage) list.push(UI.el('span', 'badge is-shortage', S.shortage(skill.shortage)));
    if (skill.mentoredOnly) list.push(UI.el('span', 'badge is-mentored', S.mentoredOnly));
    if (skill.renown > 0) list.push(UI.el('span', 'badge is-renown', S.renown(skill.renown)));
    return list;
  }

  function notes(skill) {
    const parts = [];
    if (skill.mentor) parts.push(skill.mentor.online ? S.mentor(skill.mentor.name) : S.mentorAway(skill.mentor.name));
    if (skill.apprentices.length > 0) parts.push(S.apprentices(skill.apprentices.length));
    parts.push(skill.practicedAt > 0 ? S.practiced(UI.ago(skill.practicedAt, Model.now())) : S.never);
    return parts.join(' · ');
  }

  function row(skill, maxLevel) {
    const atMax = skill.level >= maxLevel;
    const share = atMax ? 1 : Math.max(0, Math.min(1, skill.xp / Math.max(1, skill.xpToNext)));
    const fill = UI.el('div', 'xp-fill');
    fill.style.transform = `scaleX(${share})`;
    const mode = UI.button(M[skill.mode] ? M[skill.mode].glyph : '?', `mode-button is-${skill.mode}`, () => cycle(skill));
    mode.title = M[skill.mode] ? M[skill.mode].hint : '';
    mode.setAttribute('aria-label', mode.title);
    const node = UI.el('div', 'skill-row', null, [
      mode,
      UI.el('div', 'skill-main', null, [
        UI.el('div', 'skill-head', null, [
          UI.el('span', 'skill-name', skill.label),
          UI.el('span', 'skill-rank', skill.rank.label),
          ...badges(skill),
        ]),
        UI.el('div', 'xp', null, [
          UI.el('div', 'xp-track', null, [fill]),
          UI.el('span', 'xp-caption', atMax ? S.max : S.xp(skill.xp, skill.xpToNext)),
        ]),
        UI.el('p', 'skill-notes', notes(skill)),
      ]),
      UI.el('span', 'level-seal', String(skill.level)),
    ]);
    node.dataset.skill = skill.id;
    return node;
  }

  function render(pages) {
    const sheet = Model.state.sheet;
    const page = UI.el('div', 'page');
    page.append(budgetBlock(sheet), legend());
    const maxLevel = sheet.rules.maxLevel || 100;
    for (const group of Model.groups()) {
      page.append(UI.section(group.category.label));
      for (const skill of group.skills) page.append(row(skill, maxLevel));
    }
    pages.classList.add('is-single');
    pages.append(page);
  }

  return { render };
})();
