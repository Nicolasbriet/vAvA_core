'use strict';
/*
 * web/js/model.js
 * Rôle : état du livre côté interface : la fiche reçue du serveur (compétences, budget, mentorats, savoirs, leçons,
 *        propositions, pénurie), l'onglet ouvert, l'horloge du serveur (pour les délais), le savoir choisi et les
 *        lignées déjà lues. Mis à jour par les messages du serveur ; aucune règle de jeu n'est décidée ici.
 */

const Model = (() => {
  const state = { sheet: null, tab: 'competences', clockOffset: 0, closeKey: 'K', selectedRecipe: null, lineages: new Map() };

  /** msgpack transmet une liste vide comme un objet vide : toujours une vraie liste. */
  const list = (value) => (Array.isArray(value) ? value : Object.values(value || {}));

  function normalizeSkill(skill) {
    skill.apprentices = list(skill.apprentices);
    if (!skill.mentor || typeof skill.mentor !== 'object') skill.mentor = null;
    if (!skill.rank || typeof skill.rank !== 'object') skill.rank = { name: '', label: '' };
    return skill;
  }

  /** Une proposition garde son échéance en horloge locale : le compte à rebours ne dépend pas du serveur. */
  function normalizeProposal(proposal) {
    if (proposal.expiresAtMs === undefined) proposal.expiresAtMs = Date.now() + Math.max(0, Number(proposal.expiresInMs) || 0);
    return proposal;
  }

  function load(sheet) {
    sheet.categories = list(sheet.categories);
    sheet.skills = list(sheet.skills).map(normalizeSkill);
    sheet.recipes = list(sheet.recipes);
    sheet.lessons = list(sheet.lessons);
    sheet.proposals = list(sheet.proposals).map(normalizeProposal);
    sheet.shortages = list(sheet.shortages);
    sheet.rules = sheet.rules || {};
    sheet.rules.ranks = list(sheet.rules.ranks);
    sheet.rules.mentoring = sheet.rules.mentoring || {};
    sheet.budget = sheet.budget || { used: 0, total: 0 };
    sheet.character = sheet.character || {};
    state.sheet = sheet;
    state.clockOffset = typeof sheet.now === 'number' ? Date.now() / 1000 - sheet.now : 0;
    if (sheet.closeKey) state.closeKey = sheet.closeKey;
    if (state.selectedRecipe && !sheet.recipes.some((recipe) => recipe.id === state.selectedRecipe)) state.selectedRecipe = null;
  }

  /** Instant présent en horloge du serveur (secondes). */
  const now = () => Date.now() / 1000 - state.clockOffset;

  const skill = (id) => (state.sheet ? state.sheet.skills.find((entry) => entry.id === id) || null : null);

  function skillLabel(id) {
    const found = skill(id);
    return found ? found.label : id;
  }

  /** Compétences groupées par catégorie, dans l'ordre de la config ; les catégories vides sont omises. */
  function groups() {
    if (!state.sheet) return [];
    return state.sheet.categories
      .map((category) => ({ category, skills: state.sheet.skills.filter((entry) => entry.category === category.id) }))
      .filter((group) => group.skills.length > 0);
  }

  /** Remplace une compétence (même place) et le budget si le serveur l'envoie. */
  function updateSkill(view, budget) {
    if (!state.sheet || !view || typeof view !== 'object') return;
    normalizeSkill(view);
    const index = state.sheet.skills.findIndex((entry) => entry.id === view.id);
    if (index >= 0) state.sheet.skills[index] = view;
    else state.sheet.skills.push(view);
    if (budget && typeof budget === 'object') state.sheet.budget = budget;
  }

  function addProposal(proposal) {
    if (!state.sheet || !proposal || typeof proposal !== 'object') return;
    normalizeProposal(proposal);
    state.sheet.proposals = state.sheet.proposals.filter((entry) => entry.id !== proposal.id);
    state.sheet.proposals.push(proposal);
  }

  function removeProposal(id) {
    if (!state.sheet) return;
    state.sheet.proposals = state.sheet.proposals.filter((entry) => entry.id !== id);
  }

  /** Retire les propositions échues ; vrai si la liste a changé. */
  function pruneProposals() {
    if (!state.sheet) return false;
    const before = state.sheet.proposals.length;
    state.sheet.proposals = state.sheet.proposals.filter((entry) => entry.expiresAtMs > Date.now());
    return state.sheet.proposals.length !== before;
  }

  const teachable = () => (state.sheet ? state.sheet.skills.filter((entry) => entry.canMentor) : []);

  return { state, list, load, now, skill, skillLabel, groups, updateSkill, addProposal, removeProposal, pruneProposals, teachable };
})();
