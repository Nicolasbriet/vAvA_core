'use strict';
/*
 * web/dev/devmock.js
 * Rôle : données simulées quand la page est ouverte dans un navigateur (hors FiveM), pour travailler le rendu sans
 *        lancer le jeu. Inactif en jeu. Paramètres d'URL : ?view=prompt (invites qui se succèdent), ?view=menu&state=…
 *        (empty, growing, ripe, wilted, dead : menu d'emplacement dans cet état ; wilted : culture qui ne craint pas le
 *        gel), &covered=1 (plante couverte contre le gel), &frost=1 (nuit de gel annoncée), &season=ete (printemps ou
 *        été : « Couvrir » n'est pas proposé), &besace=compost (pas assez de déchets végétaux : compost en secours) ou
 *        &besace=vide (rien pour couvrir).
 *        Jamais livré (absent des `files`), jamais chargé en jeu : la ligne hors jeu de index.html ne l'insère
 *        que hors FiveM.
 */

const DevMock = (() => {
  const inGame = typeof GetParentResourceName === 'function';
  const post = (action, payload) => window.postMessage({ action, payload }, '*');
  const now = Math.floor(Date.now() / 1000);

  const slots = {
    empty: { index: 3, crop: null, cropLabel: null, state: null, stage: 0, stages: 0, progress: 0, moisture: 35, fertility: 78, waterings: 0, dryHours: 0, plantedAt: 0 },
    growing: { index: 3, crop: 'ble', cropLabel: 'Blé', state: 'growing', stage: 2, stages: 3, progress: 0.45, moisture: 62, fertility: 71, waterings: 2, dryHours: 0.4, plantedAt: now - 2500 },
    ripe: { index: 5, crop: 'carotte', cropLabel: 'Carotte', state: 'ripe', stage: 2, stages: 2, progress: 1, moisture: 28, fertility: 64, waterings: 3, dryHours: 1.2, plantedAt: now - 2200 },
    wilted: { index: 7, crop: 'chou', cropLabel: 'Chou', state: 'wilted', stage: 1, stages: 2, progress: 0.3, moisture: 0, fertility: 60, waterings: 1, dryHours: 7.5, plantedAt: now - 40000, frostHardy: true },
    dead: { index: 9, crop: 'lin', cropLabel: 'Lin', state: 'dead', stage: 2, stages: 3, progress: 0.6, moisture: 0, fertility: 55, waterings: 1, dryHours: 20.1, plantedAt: now - 90000 },
  };

  // besace simulée : objets qui couvrent, dans l'ordre de config.frost.cover
  const besaces = {
    dechets: { dechets_vegetaux: 5, compost: 2 },
    compost: { dechets_vegetaux: 1, compost: 2 },
    vide: { dechets_vegetaux: 1, compost: 0 },
  };
  const coverRules = [
    { item: 'dechets_vegetaux', label: 'Déchets végétaux', quantity: 2 },
    { item: 'compost', label: 'Compost', quantity: 1 },
  ];

  function menuFor(state, covered, options = {}) {
    const slot = { ...(slots[state] || slots.growing), covered };
    const planted = Boolean(slot.crop);
    const season = options.season !== 'printemps' && options.season !== 'ete';
    const besace = besaces[options.besace] || besaces.dechets;
    const coverOptions = season ? coverRules.map((rule) => ({ ...rule, count: besace[rule.item] || 0 })) : [];
    const use = coverOptions.find((option) => option.count >= option.quantity) || null;
    const canCover = season && use !== null && planted && slot.state !== 'dead' && !slot.covered && !slot.frostHardy;
    return {
      parcel: { id: 'champ_communal', label: 'Champ communal', communal: true },
      slot,
      seeds: [
        { crop: 'ble', label: 'Blé', item: 'graine_ble', available: [{ tier: 2, count: 6 }, { tier: 4, count: 2 }] },
        { crop: 'carotte', label: 'Carotte', item: 'graine_carotte', available: [{ tier: 1, count: 12 }] },
        { crop: 'lin', label: 'Lin', item: 'graine_lin', available: [] },
      ],
      bucket: { held: true, charges: 3 },
      compost: besace.compost,
      cover: { season, options: coverOptions, use: use ? use.item : null },
      frost: { tonight: planted && options.frost === true },
      sickle: false,
      actions: { plant: !planted, water: planted && slot.state !== 'dead', fertilize: besace.compost > 0, harvest: slot.state === 'ripe', clear: planted, cover: canCover },
      rules: { moistureThreshold: 20, tierLabels: ['Grossier', 'Commun', 'Soigné', 'Excellent', 'Chef-d\'œuvre'], frostTonight: 'gel annoncé cette nuit' },
      now,
      key: 'E',
    };
  }

  let current = 'growing';
  let covered = false;
  let mockOptions = {};

  async function handle(name, data) {
    await new Promise((resolve) => setTimeout(resolve, 60));
    if (name === 'begin') {
      post('menuClose', {});
      const action = data.action;
      setTimeout(() => {
        if (action === 'plant') post('result', { action, slot: { ...slots.growing, index: data.slot, crop: data.crop, cropLabel: data.crop === 'ble' ? 'Blé' : 'Carotte', progress: 0, stage: 1 }, label: data.crop === 'ble' ? 'Blé' : 'Carotte' });
        else if (action === 'harvest') post('result', { action, slot: { ...slots.empty, index: data.slot }, item: 'carotte', label: 'Carotte', quantity: 4, tier: 3, seeds: 1 });
        else if (action === 'clear') post('result', { action, slot: { ...slots.empty, index: data.slot }, item: 'dechets_vegetaux', label: 'Déchets végétaux', quantity: 2 });
        else if (action === 'cover') post('result', { action, slot: { ...slots.growing, index: data.slot, covered: true } });
        else post('result', { action, slot: { ...slots.growing, index: data.slot, moisture: action === 'water' ? 100 : 62 } });
      }, 900);
      return { ok: true };
    }
    if (name === 'refresh') return { ok: true, menu: menuFor(current, covered, mockOptions) };
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
        post('prompt', { kind: 'slot', key: 'E', parcelLabel: 'Champ communal', index: 3, crop: 'ble', cropLabel: 'Blé', state: 'growing', stage: 2, stages: 3 });
        setTimeout(() => post('prompt', { kind: 'slot', key: 'E', parcelLabel: 'Champ communal', index: 5, crop: 'carotte', cropLabel: 'Carotte', state: 'ripe', stage: 2, stages: 2 }), 3000);
        setTimeout(() => post('prompt', { kind: 'slot', key: 'E', parcelLabel: 'Jardin privé', index: 1, crop: null, cropLabel: null, state: null, stage: 0, stages: 0 }), 6000);
        setTimeout(() => post('prompt', { kind: 'well', key: 'E', label: 'Puits du bourg' }), 9000);
        setTimeout(() => post('prompt', { kind: 'granary', key: 'E', label: 'Grenier commun' }), 12000);
      } else {
        current = params.get('state') || 'growing';
        covered = params.get('covered') === '1';
        mockOptions = { frost: params.get('frost') === '1', season: params.get('season') || 'hiver', besace: params.get('besace') || 'dechets' };
        post('menu', menuFor(current, covered, mockOptions));
      }
    });
  }

  return { handle, inGame, menuFor };
})();
