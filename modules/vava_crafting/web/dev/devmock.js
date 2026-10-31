'use strict';
/*
 * web/dev/devmock.js
 * Rôle : données simulées quand la page est ouverte dans un navigateur (hors FiveM), pour travailler le rendu sans
 *        lancer le jeu. Inactif en jeu. Paramètres d'URL : ?view=prompt (invite), ?view=menu (menu de la forge ;
 *        &tab=reparation ou &tab=poincon ouvre l'onglet), ?view=name (boîte de baptême).
 *        Jamais livré (absent des `files`), jamais chargé en jeu : la ligne hors jeu de index.html ne l'insère
 *        que hors FiveM.
 */

const DevMock = (() => {
  const inGame = typeof GetParentResourceName === 'function';
  const post = (action, payload) => window.postMessage({ action, payload }, '*');

  const rules = {
    weights: { materials: 0.5, skill: 0.4, station: 0.1 },
    materialQuality: [10, 30, 50, 72, 92],
    thresholds: [20, 40, 60, 85],
    tierLabels: ['Grossier', 'Commun', 'Soigné', 'Excellent', 'Chef-d\'œuvre'],
    jitter: 5, capByLevel: true, masterpieceTier: 5, repair: { share: 0.25, loss: 5 },
  };
  const menu = {
    station: { id: 'forge_bourg', label: 'Forge du bourg', type: 'forge', typeLabel: 'Forge', quality: 50, busy: false,
      fuel: { item: 'charbon', label: 'Charbon de bois', stock: 3, capacity: 20, perCraft: 1 }, owner: null },
    skills: [{ id: 'forge', label: 'Forge', level: 22 }],
    recipes: [
      { id: 'lingot_fer', label: 'Lingot de fer', skill: 'forge', skillLabel: 'Forge', level: 0, playerLevel: 22, levelOk: true, toolKind: null, toolLabel: null, toolOk: true,
        durationMs: 6000, difficulty: 5, xp: 8, signed: false, transmission: false,
        ingredients: [{ item: 'minerai_fer', label: 'Minerai de fer', quantity: 2, minTier: 1, available: [{ tier: 1, count: 9 }, { tier: 3, count: 4 }] }],
        output: { item: 'lingot_fer', label: 'Lingot de fer', quantity: 1 } },
      { id: 'lingot_cuivre', label: 'Lingot de cuivre', skill: 'forge', skillLabel: 'Forge', level: 0, playerLevel: 22, levelOk: true, toolKind: null, toolLabel: null, toolOk: true,
        durationMs: 5000, difficulty: 0, xp: 6, signed: false, transmission: false,
        ingredients: [{ item: 'minerai_cuivre', label: 'Minerai de cuivre', quantity: 2, minTier: 1, available: [] }],
        output: { item: 'lingot_cuivre', label: 'Lingot de cuivre', quantity: 1 } },
      // recette d'un module qui ne l'a pas déclarée aux compétences (T-147) : verrouillée, avec sa raison
      { id: 'clou_fer', label: 'Clous de fer', skill: 'forge', skillLabel: 'Forge', level: 0, playerLevel: 22, levelOk: true, toolKind: null, toolLabel: null, toolOk: true,
        durationMs: 4000, difficulty: 0, xp: 4, signed: false, transmission: false, unregistered: true,
        ingredients: [{ item: 'lingot_fer', label: 'Lingot de fer', quantity: 1, minTier: 1, available: [{ tier: 2, count: 3 }] }],
        output: { item: 'clou_fer', label: 'Clous de fer', quantity: 10 } },
      { id: 'faucille_fer', label: 'Faucille', skill: 'forge', skillLabel: 'Forge', level: 5, playerLevel: 22, levelOk: true, toolKind: 'marteau', toolLabel: 'un marteau de forge', toolOk: true,
        durationMs: 7000, difficulty: 10, xp: 12, signed: true, transmission: false,
        ingredients: [
          { item: 'lingot_fer', label: 'Lingot de fer', quantity: 1, minTier: 1, available: [{ tier: 2, count: 3 }, { tier: 4, count: 1 }] },
          { item: 'bois_pin', label: 'Bûche de pin', quantity: 1, minTier: 1, available: [{ tier: 2, count: 6 }] },
        ],
        output: { item: 'faucille_fer', label: 'Faucille', quantity: 1 } },
      { id: 'hache_fer', label: 'Hache de bûcheron', skill: 'forge', skillLabel: 'Forge', level: 10, playerLevel: 22, levelOk: true, toolKind: 'marteau', toolLabel: 'un marteau de forge', toolOk: false,
        durationMs: 9000, difficulty: 15, xp: 16, signed: true, transmission: false,
        ingredients: [
          { item: 'lingot_fer', label: 'Lingot de fer', quantity: 2, minTier: 1, available: [{ tier: 2, count: 3 }, { tier: 4, count: 1 }] },
          { item: 'bois_chene', label: 'Bûche de chêne', quantity: 1, minTier: 1, available: [{ tier: 3, count: 2 }] },
        ],
        output: { item: 'hache_fer', label: 'Hache de bûcheron', quantity: 1 } },
      { id: 'epee_courte', label: 'Épée courte', skill: 'forge', skillLabel: 'Forge', level: 30, playerLevel: 22, levelOk: false, toolKind: 'marteau', toolLabel: 'un marteau de forge', toolOk: true,
        durationMs: 15000, difficulty: 35, xp: 30, signed: true, transmission: true,
        ingredients: [
          { item: 'lingot_fer', label: 'Lingot de fer', quantity: 3, minTier: 2, available: [{ tier: 2, count: 3 }, { tier: 4, count: 1 }] },
          { item: 'bois_chene', label: 'Bûche de chêne', quantity: 1, minTier: 1, available: [{ tier: 3, count: 2 }] },
        ],
        output: { item: 'epee_courte', label: 'Épée courte', quantity: 1 } },
    ],
    repairables: [
      { instanceId: 502, item: 'hache_fer', label: 'Hache de bûcheron', name: null, durability: 23, maxDurability: 100, broken: false, recipe: 'hache_fer', recipeLabel: 'Hache de bûcheron',
        levelOk: true, affordable: true, cost: [{ item: 'lingot_fer', label: 'Lingot de fer', quantity: 1, available: 4 }, { item: 'bois_chene', label: 'Bûche de chêne', quantity: 1, available: 2 }] },
      { instanceId: 509, item: 'pioche_fer', label: 'Pioche', name: 'Mord-la-Roche', durability: 0, maxDurability: 80, broken: true, recipe: 'pioche_fer', recipeLabel: 'Pioche',
        levelOk: true, affordable: false, cost: [{ item: 'lingot_fer', label: 'Lingot de fer', quantity: 1, available: 4 }, { item: 'bois_chene', label: 'Bûche de chêne', quantity: 1, available: 0 }] },
    ],
    mark: { current: '⚒', glyphs: ['✦', '✧', '❖', '☽', '☀', '⚒', '⚔', '⚜', '✠', '☘', '❦', '⚓', '♜', '⚚', '✶', '♆', '⚑', '❂'], allowed: true },
    rules,
    key: 'E',
  };

  async function handle(name, data) {
    await new Promise((resolve) => setTimeout(resolve, 60));
    if (name === 'fuel') {
      menu.station.fuel.stock = Math.min(menu.station.fuel.capacity, menu.station.fuel.stock + (data.quantity || 0));
      return { ok: true, stock: menu.station.fuel.stock, capacity: menu.station.fuel.capacity };
    }
    if (name === 'craft') {
      post('menuClose', {});
      const recipe = menu.recipes.find((candidate) => candidate.id === data.recipeId);
      setTimeout(() => post('crafted', {
        kind: 'craft', item: recipe ? recipe.output.item : 'lingot_fer', label: recipe ? recipe.output.label : 'Lingot de fer',
        quantity: 1, quality: recipe && recipe.signed ? 88 : 31, tier: recipe && recipe.signed ? 5 : 2, signed: Boolean(recipe && recipe.signed),
        nameable: Boolean(recipe && recipe.signed), instanceId: 777, nameWindowMs: 300000, nameMin: 2, nameMax: 32,
      }), 1200);
      return { ok: true };
    }
    if (name === 'repair') {
      post('menuClose', {});
      setTimeout(() => post('crafted', { kind: 'repair', item: 'hache_fer', label: 'Hache de bûcheron', quantity: 1, signed: true, nameable: false }), 1200);
      return { ok: true };
    }
    if (name === 'setMark') {
      menu.mark.current = data.glyph;
      return { ok: true };
    }
    if (name === 'name') {
      post('notify', { message: `Baptisé « ${data.name} ».`, kind: 'info' });
      return { ok: true };
    }
    if (name === 'refresh') return { ok: true, menu };
    if (name === 'close') {
      post('menuClose', {});
      return { ok: true };
    }
    return { ok: true };
  }

  if (!inGame) {
    window.addEventListener('DOMContentLoaded', () => {
      document.body.classList.add('dev');
      const params = new URLSearchParams(window.location.search);
      const view = params.get('view') || 'menu';
      if (view === 'prompt') {
        post('prompt', { key: 'E', label: 'Forge du bourg', typeLabel: 'Forge', busy: false, fuel: { stock: 3, capacity: 20 } });
        setTimeout(() => post('prompt', { key: 'E', label: 'Fourneau de l\'auberge', typeLabel: 'Fourneau', busy: true, fuel: { stock: 0, capacity: 20 } }), 3500);
        setTimeout(() => post('prompt', { key: 'E', label: 'Établi du bourg', typeLabel: 'Établi', busy: false, fuel: null }), 7000);
      } else if (view === 'name') {
        post('crafted', { kind: 'craft', item: 'epee_courte', label: 'Épée courte', quantity: 1, quality: 91, tier: 5, signed: true, nameable: true, instanceId: 777, nameWindowMs: 90000, nameMin: 2, nameMax: 32 });
      } else {
        post('menu', menu);
        const tab = params.get('tab');
        if (tab === 'reparation') setTimeout(() => MenuView.setTab('repair'), 0);
        else if (tab === 'poincon') setTimeout(() => MenuView.setTab('mark'), 0);
      }
    });
  }

  return { handle, inGame };
})();
