'use strict';
/*
 * web/js/quality.js
 * Rôle : les règles pures de la qualité d'une pièce, portées de shared/quality.lua pour l'aperçu du menu : qualité
 *        d'un palier de matière, moyenne pondérée des matériaux, score pondéré plafonné par le niveau, qualité finale,
 *        palier. Les règles (`rules`) viennent du serveur avec le menu : l'aperçu suit la config sans être recopié.
 *        Le serveur seul ajoute l'aléa et décide.
 */

const Quality = (() => {
  const clamp = (value, low, high) => Math.max(low, Math.min(high, value));

  /** Qualité (0–100) correspondant à un palier de matière. */
  function materialQuality(tier, rules) {
    const table = UI.list(rules.materialQuality);
    if (table.length === 0) return 0;
    const index = clamp(Math.round(Number(tier) || 1), 1, table.length);
    return Number(table[index - 1]) || 0;
  }

  /** Qualité moyenne des matériaux : paliers choisis (par index d'ingrédient) pondérés par les quantités. */
  function materials(ingredients, choices, rules) {
    let total = 0;
    let weight = 0;
    ingredients.forEach((ingredient, index) => {
      const quantity = Number(ingredient.quantity) || 0;
      total += materialQuality(choices[index] || 1, rules) * quantity;
      weight += quantity;
    });
    return weight === 0 ? 0 : total / weight;
  }

  /** Score sans aléa, plafonné par le niveau si la config le demande. */
  function score(materialsValue, level, station, rules) {
    const w = rules.weights || {};
    let value = materialsValue * (w.materials || 0) + level * (w.skill || 0) + station * (w.station || 0);
    if (rules.capByLevel) value = Math.min(value, level);
    return clamp(value, 0, 100);
  }

  /** Qualité finale pour un aléa donné (0 pour la valeur attendue, ± jitter pour les bornes). */
  function finalize(scoreValue, jitter, level, rules) {
    let value = scoreValue + jitter;
    if (rules.capByLevel) value = Math.min(value, level);
    return Math.floor(clamp(value, 0, 100) + 0.5);
  }

  /** Palier (1 à 5) d'une qualité. */
  function tierOf(value, rules) {
    let tier = 1;
    UI.list(rules.thresholds).forEach((threshold, index) => {
      if (value >= Number(threshold)) tier = index + 2;
    });
    return tier;
  }

  /** Aperçu complet d'une recette : { expected, low, high, tier }. */
  function preview(recipe, choices, level, station, rules) {
    const m = materials(UI.list(recipe.ingredients), choices, rules);
    const s = score(m, level, station, rules);
    const jitter = Number(rules.jitter) || 0;
    const expected = finalize(s, 0, level, rules);
    return { expected, low: finalize(s, -jitter, level, rules), high: finalize(s, jitter, level, rules), tier: tierOf(expected, rules) };
  }

  return { materialQuality, materials, score, finalize, tierOf, preview };
})();
