'use strict';
/*
 * web/js/view.js
 * Rôle : rendu : un panneau par conteneur ouvert, objets positionnés en cases et teintés par catégorie, marques des
 *        métadonnées (palier, solidité, brisé, en main), poids, raccourcis, emplacement des mains, fiche d'objet au
 *        survol (nom propre, signature, provenance, histoire), aperçu d'emplacement pendant un glisser, zone pour
 *        jeter, légende des commandes. Les éléments sont réutilisés d'une mise à jour à l'autre : seuls les objets
 *        modifiés sont touchés. Les cases sont un fond CSS (aucun élément par case).
 */

const View = (() => {
  const TOOLTIP_DELAY_MS = 250;
  const TOOLTIP_GAP_PX = 10;
  const VIEWPORT_MARGIN_PX = 12;
  const HISTORY_SHOWN = 5;
  let refs = null;
  const itemNodes = new Map();
  const panels = new Map();
  let tooltipTimer = null;

  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  const initials = (label) => label.split(/\s+/).filter(Boolean).slice(0, 2).map((word) => Array.from(word)[0].toUpperCase()).join('');

  const fallbackDefinition = (name) => ({ label: name, width: 1, height: 1, stack: 1, weight: 0 });

  const numeral = (tier) => STRINGS.metadata.tierNumerals[tier - 1] || String(tier);

  /** Touche et action : « [R] pivoter ». */
  function hint([key, label]) {
    const node = el('span', 'hint');
    node.append(el('kbd', null, key), label);
    return node;
  }

  function art(def) {
    if (def.image) {
      const image = el('img', 'item-art');
      image.src = def.image;
      image.alt = '';
      image.draggable = false;
      return image;
    }
    return el('span', 'item-art item-initials', initials(def.label));
  }

  /** Marques des métadonnées sur une case (objet ou emplacement) : palier, solidité, brisé, en main. */
  function decorate(node, item, meta) {
    node.dataset.tier = meta.tier ? String(meta.tier) : '';
    node.classList.toggle('is-broken', meta.broken);
    node.classList.toggle('is-held', item.id === Model.state.hands);
    const tierNode = node.querySelector('.item-tier');
    if (tierNode) tierNode.textContent = meta.tier ? numeral(meta.tier) : '';
    const bar = node.querySelector('.item-durability');
    if (bar) {
      const shown = meta.durabilityRatio !== undefined && !meta.broken;
      bar.hidden = !shown;
      if (shown) {
        bar.style.setProperty('--ratio', meta.durabilityRatio);
        bar.classList.toggle('is-low', meta.durabilityRatio <= 0.4);
        bar.classList.toggle('is-critical', meta.durabilityRatio <= 0.15);
      }
    }
  }

  /** Élément d'un objet, créé ou mis à jour. */
  function itemNode(item) {
    const def = Model.definition(item.item) || fallbackDefinition(item.item);
    let node = itemNodes.get(item.id);
    if (!node) {
      node = el('div', 'item');
      node.dataset.id = String(item.id);
      const durability = el('span', 'item-durability');
      durability.append(el('span', 'item-durability-fill'));
      node.append(el('span', 'item-art'), el('span', 'item-tier'), durability, el('span', 'item-held'), el('span', 'item-quantity'));
      itemNodes.set(item.id, node);
    }
    // l'image et la teinte ne changent qu'avec l'objet ou sa définition (arrivée après coup)
    const artKey = `${item.item}|${def.image || def.label}|${def.category || ''}`;
    if (node.dataset.art !== artKey) {
      node.dataset.art = artKey;
      node.firstChild.replaceWith(art(def));
      node.dataset.category = def.category || '';
    }
    const [w, h] = Grid.footprint(def, item.rotated);
    const style = node.style;
    style.setProperty('--x', item.x);
    style.setProperty('--y', item.y);
    style.setProperty('--w', w);
    style.setProperty('--h', h);
    style.setProperty('--aw', def.width);
    style.setProperty('--ah', def.height);
    node.classList.toggle('is-rotated', Boolean(item.rotated));
    node.lastChild.textContent = def.stack > 1 && item.quantity > 1 ? String(item.quantity) : '';
    decorate(node, item, Model.describe(item));
    return node;
  }

  function updateWeight(container) {
    const panel = panels.get(container.id);
    if (!panel) return;
    panel.weightCurrent.textContent = kilos(container.weight);
    panel.weightMax.textContent = STRINGS.weightMax(container.maxWeight);
    const ratio = container.maxWeight > 0 ? Math.min(1, container.weight / container.maxWeight) : 0;
    panel.weightFill.style.setProperty('--ratio', ratio);
    panel.weightFill.classList.toggle('is-heavy', ratio > 0.9);
  }

  /** Synchronise les objets d'un conteneur avec le DOM. */
  function renderContainer(container) {
    const panel = panels.get(container.id);
    if (!panel) return;
    const present = new Set();
    for (const item of container.items.values()) {
      const node = itemNode(item);
      present.add(item.id);
      if (node.parentNode !== panel.grid) panel.grid.append(node);
    }
    for (const node of [...panel.grid.querySelectorAll('.item')]) {
      const id = Number(node.dataset.id);
      if (!present.has(id)) {
        node.remove();
        if (!Model.find(id)) itemNodes.delete(id);
      }
    }
    updateWeight(container);
    if (panel.empty) panel.empty.hidden = container.items.size > 0;
  }

  /** Bandeau du catalogue de développement : onglets de catégories, recherche, pages. */
  function buildCatalogBar(container) {
    const C = STRINGS.catalog;
    const state = container.catalog;
    const containerId = String(container.id);
    const bar = el('div', 'catalog-bar');
    const tabs = el('div', 'catalog-tabs');
    const tab = (id, label, count) => {
      const button = el('button', `catalog-tab${id === state.category ? ' is-active' : ''}`);
      button.type = 'button';
      button.dataset.category = id;
      button.dataset.container = containerId;
      button.append(el('span', 'catalog-tab-label', label), el('span', 'catalog-tab-count', String(count)));
      return button;
    };
    tabs.append(tab('', C.all, state.categories.reduce((sum, entry) => sum + (Number(entry.count) || 0), 0)));
    for (const entry of state.categories) tabs.append(tab(entry.id, entry.id ? categoryLabel(entry.id) : C.uncategorized, entry.count));
    const nav = el('div', 'catalog-nav');
    const search = el('input', 'catalog-search');
    search.type = 'search';
    search.placeholder = C.search;
    search.title = C.searchTitle;
    search.autocomplete = 'off';
    search.spellcheck = false;
    search.maxLength = 48;
    search.value = state.query;
    search.dataset.container = containerId;
    const pageButton = (className, text, title, disabled) => {
      const button = el('button', `catalog-page-button ${className}`, text);
      button.type = 'button';
      button.title = title;
      button.disabled = disabled;
      button.dataset.container = containerId;
      return button;
    };
    nav.append(
      search,
      el('span', 'catalog-count', C.count(state.total)),
      pageButton('catalog-prev', '‹', C.prev, state.page <= 1),
      el('span', 'catalog-page', C.page(state.page, state.pages)),
      pageButton('catalog-next', '›', C.next, state.page >= state.pages),
    );
    bar.append(tabs, nav);
    return bar;
  }

  function buildPanel(container) {
    const own = container.id === Model.state.own;
    const section = el('section', `panel${own ? ' panel-own' : ''}`);
    section.dataset.container = String(container.id);
    section.dataset.kind = container.kind;
    const weightCurrent = el('span', 'weight-current');
    const weightMax = el('span', 'weight-max');
    const weightText = el('span', 'panel-weight');
    weightText.append(weightCurrent, weightMax);
    const weightFill = el('span', 'weight-fill');
    const bar = el('span', 'weight-bar');
    bar.append(weightFill);
    const header = el('header', 'panel-header');
    header.append(el('h2', 'panel-title', container.label), weightText);
    const grid = el('div', 'grid');
    grid.dataset.container = String(container.id);
    grid.style.setProperty('--cols', container.width);
    grid.style.setProperty('--rows', container.height);
    const preview = el('div', 'preview');
    preview.hidden = true;
    grid.append(preview);
    let empty = null;
    if (container.catalog) {
      empty = el('p', 'grid-empty', STRINGS.catalog.empty);
      empty.hidden = true;
      grid.append(empty);
      section.append(header, bar, buildCatalogBar(container), grid);
    } else {
      section.append(header, bar, grid);
    }
    panels.set(container.id, { section, grid, preview, empty, weightCurrent, weightMax, weightFill });
    return section;
  }

  /** Recherche du catalogue en cours de frappe : le serveur renvoie tout le panneau, le champ garde texte et focus. */
  function searchState() {
    const active = document.activeElement;
    if (!active || !active.classList || !active.classList.contains('catalog-search')) return null;
    return { container: Number(active.dataset.container), value: active.value, start: active.selectionStart, end: active.selectionEnd };
  }

  function restoreSearch(saved) {
    if (!saved) return;
    const panel = panels.get(saved.container);
    const input = panel && panel.section.querySelector('.catalog-search');
    if (!input) return;
    input.value = saved.value;
    input.focus();
    input.setSelectionRange(saved.start, saved.end);
  }

  /** Emplacement (raccourci ou mains) rempli par un objet : image, quantité, marques. */
  function fillSlot(slot, item, def) {
    slot.classList.add('is-filled');
    slot.dataset.id = String(item.id);
    slot.dataset.category = def.category || '';
    slot.append(art(def), el('span', 'item-tier'));
    if (item.quantity > 1) slot.append(el('span', 'item-quantity', String(item.quantity)));
    decorate(slot, item, Model.describe(item));
  }

  function renderHotbar() {
    const own = Model.state.containers.get(Model.state.own);
    const slots = Model.state.hotbar.map((id, index) => {
      const slot = el('div', 'hotbar-slot');
      slot.dataset.slot = String(index + 1);
      slot.append(el('span', 'hotbar-key', String(index + 1)));
      const item = own && id ? own.items.get(id) : null;
      const def = item && Model.definition(item.item);
      if (def) fillSlot(slot, item, def);
      return slot;
    });
    refs.hotbar.replaceChildren(...slots);
  }

  function renderHands() {
    const slot = el('div', 'hands-slot');
    const item = Model.heldItem();
    const def = item && Model.definition(item.item);
    if (def) fillSlot(slot, item, def);
    refs.hands.replaceWith(slot);
    refs.hands = slot;
  }

  /** Rendu complet (ouverture, conteneur ajouté ou retiré). */
  function render() {
    hideTooltip();
    const searching = searchState();
    panels.clear();
    itemNodes.clear();
    const sections = [];
    for (const id of Model.state.order) {
      const container = Model.state.containers.get(id);
      if (!container) continue;
      sections.push(buildPanel(container));
    }
    refs.panels.replaceChildren(...sections);
    for (const id of Model.state.order) {
      const container = Model.state.containers.get(id);
      if (container) renderContainer(container);
    }
    renderHotbar();
    renderHands();
    restoreSearch(searching);
  }

  // Glisser-déposer ------------------------------------------------------------------------------------------

  function cellSize(containerId) {
    const panel = panels.get(containerId);
    const container = Model.state.containers.get(containerId);
    if (!panel || !container) return 0;
    return panel.grid.getBoundingClientRect().width / container.width;
  }

  const inside = (rect, x, y) => x >= rect.left && x < rect.right && y >= rect.top && y < rect.bottom;

  /** Grille sous le pointeur : { containerId, rect } ou null. */
  function gridAt(x, y) {
    for (const [containerId, panel] of panels) {
      const rect = panel.grid.getBoundingClientRect();
      if (inside(rect, x, y)) return { containerId, rect };
    }
    return null;
  }

  function slotAt(x, y) {
    for (const slot of refs.hotbar.children) {
      if (inside(slot.getBoundingClientRect(), x, y)) return Number(slot.dataset.slot);
    }
    return null;
  }

  const handsAt = (x, y) => inside(refs.hands.getBoundingClientRect(), x, y);

  /** Vrai si le pointeur est sur un élément de l'interface (le reste de l'écran sert à jeter). */
  function isOverInterface(x, y) {
    for (const node of [...refs.panels.children, refs.hotbarPanel]) {
      if (inside(node.getBoundingClientRect(), x, y)) return true;
    }
    return false;
  }

  /** Copie flottante de l'objet suivant le pointeur. */
  function ghost(item, rect) {
    const node = itemNodes.get(item.id).cloneNode(true);
    node.classList.add('ghost');
    node.style.width = `${rect.width}px`;
    node.style.height = `${rect.height}px`;
    document.body.append(node);
    return node;
  }

  function setPreview(containerId, x, y, w, h, kind) {
    clearPreview();
    const panel = panels.get(containerId);
    if (!panel) return;
    const preview = panel.preview;
    preview.style.setProperty('--x', x);
    preview.style.setProperty('--y', y);
    preview.style.setProperty('--w', w);
    preview.style.setProperty('--h', h);
    preview.dataset.kind = kind;
    preview.hidden = false;
  }

  function clearPreview() {
    for (const panel of panels.values()) panel.preview.hidden = true;
    for (const slot of refs.hotbar.children) slot.classList.remove('is-target');
    refs.hands.classList.remove('is-target', 'is-refused');
    refs.dropZone.hidden = true;
  }

  function highlightSlot(slot) {
    clearPreview();
    const node = refs.hotbar.children[slot - 1];
    if (node) node.classList.add('is-target');
  }

  function highlightHands(valid) {
    clearPreview();
    refs.hands.classList.add(valid ? 'is-target' : 'is-refused');
  }

  function showDropZone() {
    clearPreview();
    refs.dropZone.hidden = false;
  }

  // Infobulle -------------------------------------------------------------------------------------------------

  /** Lignes des métadonnées standard : palier, qualité, solidité, provenance, puis les lignes libres d'un module. */
  function metadataFacts(meta, fact) {
    const M = STRINGS.metadata;
    if (meta.tier) fact(M.tier, `${M.tierLabel(meta.tier)} (${numeral(meta.tier)})`, null, 'tier');
    if (meta.quality !== undefined) fact(M.quality, M.qualityValue(meta.quality));
    if (meta.durability !== undefined) fact(M.durability, M.durabilityValue(meta.durability, meta.maxDurability), null, meta.durabilityRatio <= 0.15 ? 'critical' : null);
    if (meta.origin) fact(M.origin, meta.origin);
    for (const line of meta.lines) fact(line.label, line.value === undefined || line.value === null ? '' : String(line.value));
  }

  /** Signature de l'artisan : « Façonné par Aldric · ⚒ · le 12 mars 1247 ». */
  function signature(meta) {
    const M = STRINGS.metadata;
    if (!meta.crafter && !meta.mark && !meta.craftedAt) return null;
    const node = el('p', 'tooltip-signature');
    const parts = [];
    if (meta.crafter) parts.push(M.crafter(meta.crafter));
    if (meta.craftedAt) parts.push(M.craftedAt(M.date(meta.craftedAt)));
    node.append(parts.join(', '));
    if (meta.mark) node.append(el('span', 'tooltip-mark', meta.mark));
    return node;
  }

  /** Dernières entrées de l'histoire d'un objet : « 3 mai 1248 — Réparation par Bertrand : lame redressée ». */
  function history(meta) {
    const M = STRINGS.metadata;
    const entries = meta.history.slice(-HISTORY_SHOWN).reverse();
    if (entries.length === 0) return null;
    const block = el('div', 'tooltip-history');
    block.append(el('h4', 'tooltip-history-title', M.history));
    const list = el('ul', 'tooltip-history-list');
    for (const entry of entries) {
      const kind = typeof entry.kind === 'string' ? (M.historyKinds[entry.kind] || entry.kind) : '';
      const date = typeof entry.at === 'number' && entry.at > 0 ? M.date(entry.at) : '';
      const who = typeof entry.by === 'string' && entry.by.length > 0 ? M.historyBy(entry.by) : '';
      const note = typeof entry.note === 'string' && entry.note.length > 0 ? ` : ${entry.note}` : '';
      const row = el('li', 'tooltip-history-entry');
      if (date) row.append(el('time', null, date), ' — ');
      row.append(`${kind}${who}${note}`);
      list.append(row);
    }
    block.append(list);
    return block;
  }

  /** Fiche de l'objet : nom (propre ou de l'objet), catégorie, description, mesures, métadonnées, histoire, geste. */
  function tooltipContent(item, def) {
    const T = STRINGS.tooltip;
    const M = STRINGS.metadata;
    const meta = Model.describe(item);
    const header = el('header', 'tooltip-header');
    header.append(el('h3', 'tooltip-title', meta.name || def.label));
    if (meta.name) header.append(el('p', 'tooltip-subtitle', def.label));
    if (def.category) header.append(el('p', 'tooltip-category', categoryLabel(def.category)));
    const facts = el('dl', 'tooltip-facts');
    const fact = (label, value, note, kind) => {
      const row = el('div', `tooltip-fact${kind ? ` is-${kind}` : ''}`);
      const dd = el('dd', null, value);
      if (note) dd.append(el('small', null, note));
      row.append(el('dt', null, label), dd);
      facts.append(row);
    };
    const parts = [header];
    if (meta.broken) {
      const state = el('p', 'tooltip-state is-broken');
      state.append(el('strong', null, M.broken), ` — ${M.brokenNote}`);
      parts.push(state);
    } else if (item.id === Model.state.hands) {
      parts.push(el('p', 'tooltip-state is-held', M.held));
    }
    if (def.description) parts.push(el('p', 'tooltip-text', def.description));
    metadataFacts(meta, fact);
    fact(T.weight, T.kilos(def.weight * item.quantity), item.quantity > 1 ? T.unit(def.weight) : null);
    fact(T.size, T.cells(def.width, def.height));
    if (def.stack > 1) fact(T.quantity, STRINGS.quantity(item.quantity, def.stack));
    parts.push(facts);
    const signed = signature(meta);
    if (signed) parts.push(signed);
    const effects = def.effects || {};
    const known = STRINGS.effects.filter(([key]) => typeof effects[key] === 'number' && effects[key] !== 0);
    if (known.length > 0) {
      const list = el('dl', 'tooltip-effects');
      for (const [key, label] of known) {
        const row = el('div', `tooltip-effect${effects[key] < 0 ? ' is-negative' : ''}`);
        row.append(el('dt', null, label), el('dd', null, STRINGS.effectValue(effects[key])));
        list.append(row);
      }
      parts.push(list);
    }
    const past = history(meta);
    if (past) parts.push(past);
    const found = Model.find(item.id);
    if (found && found.container.id === Model.state.own) {
      let gesture = null;
      if (def.usable) gesture = T.use;
      else if (def.holdable) gesture = item.id === Model.state.hands ? T.release : T.hold;
      if (gesture) {
        const use = el('p', 'tooltip-use');
        use.append(hint(gesture));
        parts.push(use);
      }
    }
    return parts;
  }

  function showTooltip(item, anchor) {
    clearTimeout(tooltipTimer);
    tooltipTimer = setTimeout(() => {
      const def = Model.definition(item.item);
      if (!def) return;
      const tooltip = refs.tooltip;
      tooltip.dataset.category = def.category || '';
      tooltip.dataset.tier = Model.describe(item).tier ? String(Model.describe(item).tier) : '';
      tooltip.replaceChildren(...tooltipContent(item, def));
      tooltip.hidden = false;
      // à droite de l'objet, ou à gauche s'il n'y a pas la place ; jamais hors de l'écran
      const rect = anchor.getBoundingClientRect();
      const box = tooltip.getBoundingClientRect();
      let left = rect.right + TOOLTIP_GAP_PX;
      if (left + box.width > window.innerWidth - VIEWPORT_MARGIN_PX) left = rect.left - TOOLTIP_GAP_PX - box.width;
      const top = Math.min(rect.top, window.innerHeight - box.height - VIEWPORT_MARGIN_PX);
      tooltip.style.left = `${Math.round(Math.max(VIEWPORT_MARGIN_PX, left))}px`;
      tooltip.style.top = `${Math.round(Math.max(VIEWPORT_MARGIN_PX, top))}px`;
    }, TOOLTIP_DELAY_MS);
  }

  function hideTooltip() {
    clearTimeout(tooltipTimer);
    if (refs) refs.tooltip.hidden = true;
  }

  function init(root) {
    refs = {
      panels: root.querySelector('.panels'),
      hotbarPanel: root.querySelector('.hotbar'),
      hotbar: root.querySelector('.hotbar-slots'),
      hands: root.querySelector('.hands-slot'),
      tooltip: root.querySelector('.tooltip'),
      dropZone: root.querySelector('.drop-zone'),
    };
    root.querySelector('.hotbar-title').textContent = STRINGS.hotbar;
    root.querySelector('.hotbar-hint').textContent = STRINGS.hotbarHint;
    root.querySelector('.hands-title').textContent = STRINGS.hands;
    root.querySelector('.hands-hint').textContent = STRINGS.handsHint;
    root.querySelector('.hints').replaceChildren(...STRINGS.hints.map(hint));
    refs.dropZone.textContent = STRINGS.dropZone;
  }

  return {
    init, render, renderContainer, renderHotbar, renderHands, cellSize, gridAt, slotAt, handsAt, isOverInterface, ghost,
    setPreview, clearPreview, highlightSlot, highlightHands, showDropZone, showTooltip, hideTooltip,
    element: (id) => itemNodes.get(id),
  };
})();
