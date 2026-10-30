'use strict';
/*
 * web/js/view-menu.js
 * Rôle : le menu d'un emplacement : bandeau (parcelle, numéro, communale ou privée), carte de l'emplacement (culture et
 *        état, croissance, humidité avec le seuil, fertilité, arrosages, sécheresse, date de semis, couverture contre le
 *        gel, nuit de gel annoncée), gestes (semer avec choix de la graine et de son palier, arroser, fertiliser,
 *        récolter, couvrir — proposé en automne et en hiver seulement —, arracher) avec la raison d'un refus.
 *        Construit à chaque message du jeu ; rien n'est animé en continu.
 */

const MenuView = (() => {
  const root = document.getElementById('menu');
  const refs = {
    title: root.querySelector('.menu-title'),
    meta: root.querySelector('.menu-meta'),
    pane: root.querySelector('.menu-pane'),
    refresh: root.querySelector('.menu-refresh'),
    close: root.querySelector('.menu-close'),
  };
  const M = STRINGS.menu;
  const A = M.actions;

  let menu = null;          // données du serveur, listes normalisées
  let seedCrop = null;      // culture choisie pour semer
  const seedTiers = {};     // culture → palier choisi

  const tierLabels = () => (menu && menu.rules && UI.list(menu.rules.tierLabels).length ? UI.list(menu.rules.tierLabels) : STRINGS.tiers);

  // Normalisation ------------------------------------------------------------------------------------------------

  function normalize(data) {
    const copy = { ...data };
    copy.parcel = data.parcel || {};
    copy.slot = data.slot || {};
    copy.seeds = UI.list(data.seeds).map((seed) => ({ ...seed, available: UI.list(seed.available) }));
    copy.bucket = data.bucket || { held: false, charges: 0 };
    copy.compost = Number(data.compost) || 0;
    const cover = data.cover || {};
    copy.cover = { season: cover.season === true, options: UI.list(cover.options), use: typeof cover.use === 'string' ? cover.use : null };
    copy.frost = { tonight: Boolean(data.frost && data.frost.tonight === true) };
    copy.sickle = data.sickle === true;
    copy.actions = data.actions || {};
    copy.rules = data.rules || {};
    copy.now = Number(data.now) || Math.floor(Date.now() / 1000);
    return copy;
  }

  // Bandeau ----------------------------------------------------------------------------------------------------------

  function renderHeader() {
    const parcel = menu.parcel;
    const slot = menu.slot;
    refs.title.textContent = `${parcel.label || parcel.id || ''} — ${M.slot(Number(slot.index) || 1)}`;
    refs.meta.replaceChildren(UI.el('span', `parcel-kind${parcel.communal ? ' is-communal' : ''}`, parcel.communal ? M.communal : M.privateParcel));
  }

  // Carte de l'emplacement ----------------------------------------------------------------------------------------------

  /** Nuit de gel annoncée (serveur) sur une plante vivante ; marquée si la plante y est exposée. */
  function frostFact() {
    const slot = menu.slot;
    if (!menu.frost.tonight || !slot.crop || slot.state === 'dead') return null;
    const text = typeof menu.rules.frostTonight === 'string' && menu.rules.frostTonight !== '' ? menu.rules.frostTonight : M.facts.frostTonight;
    const exposed = slot.covered !== true && slot.frostHardy !== true;
    return UI.el('span', `fact${exposed ? ' is-bad' : ''}`, text);
  }

  function slotCard() {
    const slot = menu.slot;
    const threshold = Number(menu.rules.moistureThreshold) || 0;
    const moisture = UI.clamp(Number(slot.moisture) || 0, 0, 100);
    const fertility = UI.clamp(Number(slot.fertility) || 0, 0, 100);
    const head = UI.el('header', 'slot-head');
    if (slot.crop) {
      const state = slot.state && STRINGS.states[slot.state];
      head.append(UI.el('h3', 'detail-title', slot.cropLabel || slot.crop));
      if (state) {
        const flag = UI.el('span', `flag is-${slot.state}`, state);
        head.append(flag);
      }
    } else {
      head.append(UI.el('h3', 'detail-title', M.free));
    }
    const children = [head];
    if (!slot.crop) {
      children.push(UI.el('p', 'slot-text', M.freeText));
    } else {
      const progress = UI.clamp(Number(slot.progress) || 0, 0, 1);
      const kind = slot.state === 'dead' ? 'dead' : slot.state === 'wilted' ? 'wilted' : slot.state === 'ripe' ? 'ripe' : 'growth';
      children.push(UI.gauge(M.progress, progress, M.percent(progress * 100), kind));
      const facts = [
        UI.el('span', 'fact', M.facts.waterings(Number(slot.waterings) || 0)),
        UI.el('span', `fact${(Number(slot.dryHours) || 0) > 0 ? ' is-bad' : ''}`, M.facts.dryHours(Number(slot.dryHours) || 0)),
        Number(slot.plantedAt) > 0 ? UI.el('span', 'fact', M.facts.planted(M.since(Math.max(0, menu.now - Number(slot.plantedAt))))) : null,
        slot.covered === true ? UI.el('span', 'fact', M.facts.covered) : null,
        slot.frostHardy === true ? UI.el('span', 'fact', M.facts.frostHardy) : null,
        frostFact(),
      ];
      children.push(UI.el('div', 'detail-facts', null, facts));
    }
    const moistureKind = moisture <= threshold ? 'dry' : 'water';
    children.push(UI.gauge(M.moisture, moisture / 100, `${M.percent(moisture)} · ${M.threshold(threshold)}`, moistureKind, threshold / 100));
    if (slot.crop && slot.state !== 'dead' && moisture <= threshold) children.push(UI.el('p', 'slot-warning', M.dry));
    children.push(UI.gauge(M.fertility, fertility / 100, M.percent(fertility), fertility < 30 ? 'low' : 'fertility'));
    return UI.el('section', 'slot-card', null, children);
  }

  // Gestes --------------------------------------------------------------------------------------------------------------

  /** Envoie un geste ; en cas d'acceptation, le jeu ferme le menu et joue le geste. */
  async function begin(action, crop, tier, button) {
    button.disabled = true;
    const result = await Bridge.post('begin', { parcelId: menu.parcel.id, slot: Number(menu.slot.index) || 1, action, crop: crop || '', tier: tier || 0 });
    button.disabled = false;
    if (!result.ok) App.toast(errorMessage(result.error), 'warning');
  }

  function actionBlock(name, labelText, enabled, reason, detail, onClick) {
    const button = UI.button(labelText, `button button-primary action-go`, onClick);
    button.disabled = !enabled;
    button.dataset.action = name;
    return UI.el('div', `action${enabled ? '' : ' is-disabled'}`, null, [
      UI.el('div', 'action-main', null, [
        UI.el('span', 'action-name', labelText),
        detail ? UI.el('span', 'action-detail', detail) : null,
        !enabled && reason ? UI.el('span', 'reason', reason) : null,
      ]),
      button,
    ]);
  }

  /** Semer : culture choisie parmi les graines possédées, puis palier. */
  function plantBlock() {
    const slot = menu.slot;
    const seeds = menu.seeds.filter((seed) => seed.available.length > 0);
    const labels = tierLabels();
    if (!seeds.some((seed) => seed.crop === seedCrop)) seedCrop = seeds.length ? seeds[0].crop : null;
    const current = seeds.find((seed) => seed.crop === seedCrop) || null;
    let chosenTier = null;
    if (current) {
      const owned = current.available.map((entry) => Number(entry.tier));
      if (!owned.includes(seedTiers[current.crop])) seedTiers[current.crop] = Math.min(...owned);
      chosenTier = seedTiers[current.crop];
    }
    const enabled = Boolean(menu.actions.plant) && !slot.crop && current !== null;
    const reason = slot.crop ? A.reasons.occupied : seeds.length === 0 ? A.reasons.noSeeds : !menu.actions.plant ? A.reasons.refused : null;
    const picker = UI.el('div', 'seed-picker');
    if (seeds.length === 0) {
      picker.append(UI.el('span', 'tier-none', A.noSeeds));
    } else {
      picker.append(UI.el('span', 'tier-picker-label', A.seedChoice));
      seeds.forEach((seed) => {
        const chip = UI.button(seed.label || seed.crop, `seed-choice${seed.crop === seedCrop ? ' is-active' : ''}`, () => {
          seedCrop = seed.crop;
          renderPane();
        });
        chip.dataset.crop = seed.crop;
        picker.append(chip);
      });
    }
    const tiers = UI.el('div', 'tier-picker');
    if (current) {
      tiers.append(UI.el('span', 'tier-picker-label', A.tierChoice));
      current.available.forEach((entry) => {
        const value = Number(entry.tier);
        const chip = UI.button(null, `tier-choice${chosenTier === value ? ' is-active' : ''}`, () => {
          seedTiers[current.crop] = value;
          renderPane();
        });
        chip.append(UI.tier(value, labels), UI.el('span', 'tier-count', A.count(Number(entry.count) || 0)));
        tiers.append(chip);
      });
    }
    const button = UI.button(A.plant, 'button button-primary action-go', () => begin('plant', current ? current.crop : '', chosenTier || 0, button));
    button.disabled = !enabled;
    button.dataset.action = 'plant';
    return UI.el('div', `action action-plant${enabled ? '' : ' is-disabled'}`, null, [
      UI.el('div', 'action-main', null, [
        UI.el('span', 'action-name', A.plant),
        slot.crop ? null : picker,
        slot.crop || !current ? null : tiers,
        !enabled && reason ? UI.el('span', 'reason', reason) : null,
      ]),
      button,
    ]);
  }

  function renderActions() {
    const slot = menu.slot;
    const bucket = menu.bucket;
    const charges = Number(bucket.charges) || 0;
    const bucketText = !bucket.held ? A.bucketNone : charges <= 0 ? A.bucketEmpty : A.bucketHeld(charges);
    const waterEnabled = Boolean(menu.actions.water) && Boolean(slot.crop) && slot.state !== 'dead' && bucket.held && charges > 0;
    const waterReason = !slot.crop ? A.reasons.empty : slot.state === 'dead' ? A.reasons.dead : !bucket.held ? A.reasons.noBucket : charges <= 0 ? A.reasons.bucketEmpty : A.reasons.refused;
    const fertilizeEnabled = Boolean(menu.actions.fertilize) && menu.compost > 0;
    const fertilizeReason = menu.compost <= 0 ? A.reasons.noCompost : A.reasons.refused;
    const harvestEnabled = Boolean(menu.actions.harvest) && slot.state === 'ripe';
    const harvestReason = !slot.crop ? A.reasons.empty : slot.state === 'dead' ? A.reasons.dead : slot.state !== 'ripe' ? A.reasons.notRipe(Number(slot.progress) || 0) : A.reasons.refused;
    const clearEnabled = Boolean(menu.actions.clear) && Boolean(slot.crop);
    const clearReason = !slot.crop ? A.reasons.empty : A.reasons.refused;
    const cover = menu.cover;
    const coverWith = cover.options.find((option) => option.item === cover.use) || null;
    const coverEnabled = Boolean(menu.actions.cover) && Boolean(slot.crop) && coverWith !== null;
    const coverReason = !slot.crop ? A.reasons.empty
      : slot.state === 'dead' ? A.reasons.dead
        : slot.covered === true ? A.reasons.covered
          : slot.frostHardy === true ? A.reasons.frostHardy
            : coverWith === null ? A.reasons.noCover(cover.options.map((option) => A.reasons.coverItem(Number(option.quantity) || 1, option.label || option.item)).join(A.reasons.coverOr))
              : A.reasons.refused;
    const coverDetail = coverEnabled ? A.coverWith(Number(coverWith.quantity) || 1, coverWith.label || coverWith.item, Number(coverWith.count) || 0) : null;
    const blocks = [
      plantBlock(),
      actionBlock('water', A.water, waterEnabled, waterReason, bucketText, (event) => begin('water', '', 0, event.currentTarget)),
      actionBlock('fertilize', A.fertilize, fertilizeEnabled, fertilizeReason, A.compost(menu.compost), (event) => begin('fertilize', '', 0, event.currentTarget)),
      actionBlock('harvest', A.harvest, harvestEnabled, harvestReason, menu.sickle ? A.sickle : A.noSickle, (event) => begin('harvest', '', 0, event.currentTarget)),
      // hors de l'automne et de l'hiver (saison décidée par le serveur), « Couvrir » n'est pas proposé
      cover.season ? actionBlock('cover', A.cover, coverEnabled, coverReason, coverDetail, (event) => begin('cover', '', 0, event.currentTarget)) : null,
      actionBlock('clear', A.clear, clearEnabled, clearReason, slot.crop && (slot.state === 'wilted' || slot.state === 'dead') ? A.waste : null, (event) => begin('clear', '', 0, event.currentTarget)),
    ];
    return UI.el('section', 'actions', null, [UI.el('h4', 'section-title', A.title), ...blocks]);
  }

  // Assemblage --------------------------------------------------------------------------------------------------------

  function renderPane() {
    if (!menu) return;
    refs.pane.replaceChildren(slotCard(), renderActions());
  }

  /** Ouvre (ou met à jour) le menu avec les données du serveur. */
  function show(data) {
    menu = normalize(data);
    renderHeader();
    renderPane();
    root.hidden = false;
  }

  function hide() {
    root.hidden = true;
  }

  /** L'emplacement ouvert a changé : vue d'emplacement { parcel, index, … }. */
  function updateSlot(payload) {
    if (!menu || !payload) return;
    if (payload.parcel && payload.parcel !== menu.parcel.id) return;
    if (payload.index !== undefined && Number(payload.index) !== Number(menu.slot.index)) return;
    menu.slot = { ...menu.slot, ...payload };
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

  return { show, hide, updateSlot, isOpen: () => !root.hidden, current: () => menu };
})();
