'use strict';
/*
 * web/js/view-menu.js
 * Rôle : le menu d'une station : bandeau (nom, type, qualité, propriétaire, occupation, combustible et alimentation),
 *        onglet Recettes (filtre par compétence, liste, détail : matières et palier choisi par ingrédient, outil,
 *        niveau, durée, aperçu de qualité calculé avec les règles du serveur, bouton Façonner et sa raison de refus),
 *        onglet Réparation (objets signés usés, coût, bouton Réparer), onglet Poinçon (grille de glyphes). Construit à
 *        chaque message du jeu ; rien n'est animé en continu.
 */

const MenuView = (() => {
  const root = document.getElementById('menu');
  const refs = {
    name: root.querySelector('.station-name'),
    meta: root.querySelector('.station-meta'),
    fuel: root.querySelector('.station-fuel'),
    tabs: root.querySelector('.menu-tabs'),
    pane: root.querySelector('.menu-pane'),
    refresh: root.querySelector('.menu-refresh'),
    close: root.querySelector('.menu-close'),
  };
  const M = STRINGS.menu;
  const TABS = ['recipes', 'repair', 'mark'];

  let menu = null;          // données du serveur, listes normalisées
  let tab = 'recipes';
  let selected = null;      // id de la recette affichée
  let skillFilter = null;   // compétence filtrée, ou null
  const choices = {};       // recette → { [index d'ingrédient] = palier }

  const tierLabels = () => (menu && menu.rules && UI.list(menu.rules.tierLabels).length ? UI.list(menu.rules.tierLabels) : STRINGS.tiers);

  // Normalisation ------------------------------------------------------------------------------------------------

  function normalize(data) {
    const copy = { ...data };
    copy.skills = UI.list(data.skills);
    copy.recipes = UI.list(data.recipes).map((recipe) => ({
      ...recipe,
      ingredients: UI.list(recipe.ingredients).map((ingredient) => ({ ...ingredient, available: UI.list(ingredient.available) })),
    }));
    copy.repairables = UI.list(data.repairables).map((entry) => ({ ...entry, cost: UI.list(entry.cost) }));
    copy.mark = { ...(data.mark || {}), glyphs: UI.list(data.mark && data.mark.glyphs) };
    copy.rules = data.rules || {};
    copy.station = data.station || {};
    return copy;
  }

  // Bandeau ----------------------------------------------------------------------------------------------------------

  function renderStation() {
    const S = M.station;
    const station = menu.station;
    refs.name.textContent = station.label || station.id || '';
    const tags = [
      UI.el('span', 'station-type', station.typeLabel || station.type || ''),
      UI.el('span', 'station-quality', S.quality(Math.round(Number(station.quality) || 0))),
      UI.el('span', 'station-owner', station.owner && station.owner.name ? S.owner(station.owner.name) : S.publicStation),
      station.busy ? UI.el('span', 'station-busy', S.busy) : null,
    ];
    refs.meta.replaceChildren(...tags.filter(Boolean));
    if (!station.fuel) {
      refs.fuel.hidden = true;
      return;
    }
    const fuel = station.fuel;
    const stock = Number(fuel.stock) || 0;
    const capacity = Math.max(1, Number(fuel.capacity) || 1);
    const fill = UI.el('span', `fuel-fill${stock <= 0 ? ' is-empty' : ''}`);
    fill.style.transform = `scaleX(${(stock / capacity).toFixed(3)})`;
    const input = UI.el('input', 'fuel-input');
    input.type = 'number';
    input.min = '1';
    input.max = String(Math.max(1, capacity - stock));
    input.value = String(Math.min(5, Math.max(1, capacity - stock)));
    input.disabled = stock >= capacity;
    const feed = UI.button(S.feed, 'button button-ghost fuel-feed', async () => {
      const quantity = Math.floor(Number(input.value));
      if (!(quantity >= 1)) return;
      feed.disabled = true;
      const result = await Bridge.post('fuel', { stationId: station.id, quantity });
      feed.disabled = false;
      if (!result.ok) {
        App.toast(errorMessage(result.error), 'warning');
        return;
      }
      if (typeof result.stock === 'number') updateStation({ fuel: result.stock, busy: station.busy });
    });
    feed.disabled = stock >= capacity;
    refs.fuel.replaceChildren(
      UI.el('span', 'fuel-label', S.fuel),
      UI.el('span', 'fuel-track', null, [fill]),
      UI.el('span', 'fuel-value', S.fuelValue(stock, capacity)),
      UI.el('span', 'fuel-with', stock >= capacity ? S.full : S.feedWith(fuel.label || fuel.item || '', Number(fuel.perCraft) || 1)),
      input, feed,
    );
    refs.fuel.hidden = false;
  }

  function renderTabs() {
    refs.tabs.replaceChildren(...TABS.map((name) => {
      const count = name === 'recipes' ? menu.recipes.length : name === 'repair' ? menu.repairables.length : null;
      const button = UI.button(count === null ? M.tabs[name] : `${M.tabs[name]} (${count})`, `menu-tab${tab === name ? ' is-active' : ''}`, () => setTab(name));
      button.dataset.tab = name;
      return button;
    }));
  }

  // Recettes -----------------------------------------------------------------------------------------------------------

  const fuelOk = () => !menu.station.fuel || (Number(menu.station.fuel.stock) || 0) >= (Number(menu.station.fuel.perCraft) || 1);

  /** Paliers choisis d'une recette (par index), le plus bas possédé par défaut. */
  function choicesOf(recipe) {
    const current = choices[recipe.id] || {};
    recipe.ingredients.forEach((ingredient, index) => {
      const owned = ingredient.available.map((entry) => Number(entry.tier));
      if (!owned.includes(current[index])) current[index] = owned.length ? Math.min(...owned) : Number(ingredient.minTier) || 1;
    });
    choices[recipe.id] = current;
    return current;
  }

  function ownedAtTier(ingredient, tier) {
    const entry = ingredient.available.find((candidate) => Number(candidate.tier) === tier);
    return entry ? Number(entry.count) || 0 : 0;
  }

  /** Ce qui empêche de façonner, ou null. */
  function blocker(recipe, chosen) {
    const R = M.recipes.reasons;
    if (menu.station.busy) return R.busy;
    if (!recipe.levelOk) return R.level;
    if (recipe.toolKind && !recipe.toolOk) return R.tool;
    if (!fuelOk()) return R.fuel;
    const short = recipe.ingredients.some((ingredient, index) => ownedAtTier(ingredient, chosen[index]) < (Number(ingredient.quantity) || 0));
    if (short) return R.materials;
    return null;
  }

  function recipeRow(recipe) {
    const flags = [];
    if (!recipe.levelOk) flags.push(UI.el('span', 'flag is-lock', M.recipes.level(recipe.level, recipe.playerLevel)));
    if (recipe.toolKind && !recipe.toolOk) flags.push(UI.el('span', 'flag is-tool', M.recipes.toolMissing));
    if (recipe.signed) flags.push(UI.el('span', 'flag is-signed', M.recipes.signed));
    if (recipe.transmission) flags.push(UI.el('span', 'flag is-lesson', M.recipes.transmission));
    const row = UI.button(null, `recipe-row${selected === recipe.id ? ' is-selected' : ''}${recipe.levelOk ? '' : ' is-locked'}`, () => {
      selected = recipe.id;
      renderPane();
    });
    row.append(
      UI.el('span', 'recipe-row-name', recipe.label || recipe.id),
      UI.el('span', 'recipe-row-sub', null, [UI.el('span', 'recipe-skill', recipe.skillLabel || recipe.skill || ''), ...flags]),
    );
    row.dataset.recipe = recipe.id;
    return row;
  }

  function ingredientRow(recipe, ingredient, index, chosen) {
    const R = M.recipes;
    const labels = tierLabels();
    const need = Number(ingredient.quantity) || 0;
    const have = ownedAtTier(ingredient, chosen[index]);
    const picker = UI.el('div', 'tier-picker', null, [UI.el('span', 'tier-picker-label', R.tierChoice)]);
    if (ingredient.available.length === 0) {
      picker.append(UI.el('span', 'tier-none', R.noneOwned));
    } else {
      ingredient.available.forEach((entry) => {
        const value = Number(entry.tier);
        const chip = UI.button(null, `tier-choice${chosen[index] === value ? ' is-active' : ''}`, () => {
          chosen[index] = value;
          renderPane();
        });
        chip.append(UI.tier(value, labels), UI.el('span', 'tier-count', `× ${Number(entry.count) || 0}`));
        picker.append(chip);
      });
    }
    const minTier = Number(ingredient.minTier) || 1;
    return UI.el('div', `ingredient${have < need ? ' is-short' : ''}`, null, [
      UI.el('div', 'ingredient-head', null, [
        UI.el('span', 'ingredient-name', ingredient.label || ingredient.item),
        UI.el('span', 'ingredient-owned', R.owned(have, need)),
        minTier > 1 ? UI.el('span', 'ingredient-min', R.minTier(minTier)) : null,
      ]),
      picker,
    ]);
  }

  function recipeDetail(recipe) {
    const R = M.recipes;
    const labels = tierLabels();
    const chosen = choicesOf(recipe);
    const station = menu.station;
    const preview = Quality.preview(recipe, chosen, Number(recipe.playerLevel) || 0, Number(station.quality) || 0, menu.rules);
    const reason = blocker(recipe, chosen);
    const flags = [];
    if (recipe.signed) flags.push(UI.el('span', 'flag is-signed', R.signed));
    if (recipe.transmission) flags.push(UI.el('span', 'flag is-lesson', R.transmission));
    const facts = [
      UI.el('span', `fact${recipe.levelOk ? '' : ' is-bad'}`, R.level(recipe.level, recipe.playerLevel)),
      UI.el('span', `fact${recipe.toolKind && !recipe.toolOk ? ' is-bad' : ''}`, recipe.toolKind
        ? `${R.tool(recipe.toolLabel || recipe.toolKind)} — ${recipe.toolOk ? R.toolOk : R.toolMissing}`
        : R.noTool),
      UI.el('span', 'fact', R.duration(Number(recipe.durationMs) || 0)),
      UI.el('span', 'fact', `${R.xp(Number(recipe.xp) || 0)} · ${R.difficulty(Number(recipe.difficulty) || 0)}`),
    ];
    const craft = UI.button(R.craft, 'button button-primary recipe-craft', async () => {
      craft.disabled = true;
      const payload = {};
      recipe.ingredients.forEach((ingredient, index) => { payload[ingredient.item] = chosen[index]; });
      const result = await Bridge.post('craft', { stationId: station.id, recipeId: recipe.id, choices: payload });
      craft.disabled = false;
      if (!result.ok) App.toast(errorMessage(result.error), 'warning');
    });
    craft.disabled = reason !== null;
    const previewBlock = recipe.signed
      ? UI.el('div', 'preview', null, [
        UI.el('span', 'preview-label', R.preview),
        UI.el('span', 'preview-value', String(preview.expected)),
        UI.tier(preview.tier, labels, 'preview-tier'),
        UI.el('span', 'preview-range', R.previewValue(preview.expected, preview.low, preview.high)),
      ])
      : UI.el('div', 'preview', null, [
        UI.el('span', 'preview-label', R.previewSimple),
        UI.tier(preview.tier, labels, 'preview-tier'),
        UI.el('span', 'preview-range', R.previewValue(preview.expected, preview.low, preview.high)),
      ]);
    return UI.el('div', 'recipe-detail', null, [
      UI.el('header', 'detail-head', null, [UI.el('h3', 'detail-title', recipe.label || recipe.id), ...flags]),
      UI.el('div', 'detail-facts', null, facts),
      UI.el('h4', 'section-title', R.ingredients),
      UI.el('div', 'ingredients', null, recipe.ingredients.map((ingredient, index) => ingredientRow(recipe, ingredient, index, chosen))),
      UI.el('h4', 'section-title', R.output),
      UI.el('div', 'output', null, [
        UI.el('span', 'output-name', (recipe.output && (recipe.output.label || recipe.output.item)) || ''),
        UI.el('span', 'output-quantity', R.quantity(Number(recipe.output && recipe.output.quantity) || 1)),
      ]),
      previewBlock,
      UI.el('div', 'detail-actions', null, [craft, reason ? UI.el('span', 'reason', reason) : null]),
    ]);
  }

  function renderRecipes() {
    const R = M.recipes;
    const filters = UI.el('div', 'skill-filters', null, [
      UI.button(R.all, `skill-filter${skillFilter === null ? ' is-active' : ''}`, () => { skillFilter = null; renderPane(); }),
      ...menu.skills.map((skill) => UI.button(`${skill.label || skill.id} · ${skill.level}`, `skill-filter${skillFilter === skill.id ? ' is-active' : ''}`, () => {
        skillFilter = skill.id;
        renderPane();
      })),
    ]);
    const recipes = menu.recipes.filter((recipe) => skillFilter === null || recipe.skill === skillFilter);
    if (!recipes.some((recipe) => recipe.id === selected)) selected = recipes.length ? recipes[0].id : null;
    const current = recipes.find((recipe) => recipe.id === selected) || null;
    const list = UI.el('div', 'recipe-list', null, recipes.length ? recipes.map(recipeRow) : [UI.el('p', 'empty', R.empty)]);
    const detail = current ? recipeDetail(current) : UI.el('p', 'empty', recipes.length ? R.select : '');
    refs.pane.replaceChildren(UI.el('div', 'recipes', null, [UI.el('aside', 'recipes-side', null, [filters, list]), UI.el('div', 'recipes-main', null, [detail])]));
  }

  // Réparation ---------------------------------------------------------------------------------------------------------

  function repairRow(entry) {
    const R = M.repair;
    const max = Math.max(1, Number(entry.maxDurability) || 1);
    const durability = UI.clamp(Number(entry.durability) || 0, 0, max);
    const fill = UI.el('span', `durability-fill${entry.broken ? ' is-broken' : durability / max <= 0.2 ? ' is-low' : ''}`);
    fill.style.transform = `scaleX(${(durability / max).toFixed(3)})`;
    const reason = menu.station.busy ? R.reasons.busy : !entry.levelOk ? R.reasons.level : !entry.affordable ? R.reasons.afford : null;
    const repair = UI.button(R.repair, 'button button-primary repair-go', async () => {
      repair.disabled = true;
      const result = await Bridge.post('repair', { stationId: menu.station.id, instanceId: entry.instanceId });
      repair.disabled = false;
      if (!result.ok) App.toast(errorMessage(result.error), 'warning');
    });
    repair.disabled = reason !== null;
    return UI.el('div', `repair-row${entry.broken ? ' is-broken' : ''}`, null, [
      UI.el('div', 'repair-main', null, [
        UI.el('div', 'repair-head', null, [
          UI.el('span', 'repair-name', entry.name || entry.label || entry.item),
          entry.name ? UI.el('span', 'repair-sub', entry.label || entry.item) : null,
          entry.broken ? UI.el('span', 'flag is-broken', R.broken) : null,
          UI.el('span', 'repair-recipe', R.recipe(entry.recipeLabel || entry.recipe || '')),
        ]),
        UI.el('div', 'repair-bar', null, [UI.el('span', 'durability-track', null, [fill]), UI.el('span', 'repair-durability', R.durability(durability, max))]),
        UI.el('div', 'repair-cost', null, [
          UI.el('span', 'repair-cost-label', R.cost),
          ...entry.cost.map((cost) => UI.el('span', `cost${(Number(cost.available) || 0) < (Number(cost.quantity) || 0) ? ' is-short' : ''}`,
            `${cost.label || cost.item} ${M.recipes.owned(Number(cost.available) || 0, Number(cost.quantity) || 0)}`)),
        ]),
        UI.el('p', 'repair-loss', R.loss(Number(menu.rules.repair && menu.rules.repair.loss) || 0)),
      ]),
      UI.el('div', 'repair-actions', null, [repair, reason ? UI.el('span', 'reason', reason) : null]),
    ]);
  }

  function renderRepair() {
    const rows = menu.repairables.length ? menu.repairables.map(repairRow) : [UI.el('p', 'empty', M.repair.empty)];
    refs.pane.replaceChildren(UI.el('div', 'repairs', null, rows));
  }

  // Poinçon -----------------------------------------------------------------------------------------------------------

  function renderMark() {
    const K = M.mark;
    const mark = menu.mark;
    const grid = UI.el('div', `glyphs${mark.allowed ? '' : ' is-locked'}`, null, mark.glyphs.map((glyph) => {
      const chip = UI.button(glyph, `glyph${mark.current === glyph ? ' is-active' : ''}`, async () => {
        if (!mark.allowed) return;
        const result = await Bridge.post('setMark', { glyph });
        if (!result.ok) {
          App.toast(errorMessage(result.error), 'warning');
          return;
        }
        mark.current = glyph;
        renderPane();
      });
      chip.disabled = !mark.allowed;
      return chip;
    }));
    refs.pane.replaceChildren(UI.el('div', 'marks', null, [
      UI.el('h3', 'detail-title', K.title),
      UI.el('p', 'marks-text', K.text),
      UI.el('p', `marks-current${mark.current ? '' : ' is-none'}`, mark.current ? K.current(mark.current) : K.none),
      mark.allowed ? null : UI.el('p', 'marks-locked', K.locked),
      grid,
    ]));
  }

  // Assemblage --------------------------------------------------------------------------------------------------------

  function renderPane() {
    if (!menu) return;
    renderTabs();
    if (tab === 'repair') renderRepair();
    else if (tab === 'mark') renderMark();
    else renderRecipes();
  }

  function setTab(name) {
    if (!TABS.includes(name)) return;
    tab = name;
    renderPane();
  }

  /** Ouvre (ou met à jour) le menu avec les données du serveur. */
  function show(data) {
    menu = normalize(data);
    renderStation();
    renderPane();
    root.hidden = false;
  }

  function hide() {
    root.hidden = true;
  }

  /** La station ouverte a changé : { id, fuel, busy }. */
  function updateStation(payload) {
    if (!menu) return;
    if (menu.station.fuel && typeof payload.fuel === 'number') menu.station.fuel.stock = payload.fuel;
    if (typeof payload.busy === 'boolean') menu.station.busy = payload.busy;
    renderStation();
    renderPane();
  }

  async function refresh() {
    refs.refresh.disabled = true;
    const result = await Bridge.post('refresh', {});
    refs.refresh.disabled = false;
    if (result.ok && result.menu) show(result.menu);
    else if (!result.ok) App.toast(errorMessage(result.error), 'warning');
  }

  refs.refresh.textContent = M.refresh;
  refs.close.title = M.close;
  refs.refresh.addEventListener('click', refresh);
  refs.close.addEventListener('click', () => App.closeMenu());

  return { show, hide, setTab, updateStation, isOpen: () => !root.hidden, current: () => menu };
})();
