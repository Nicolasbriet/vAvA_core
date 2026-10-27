'use strict';
/*
 * web/js/view.js
 * Rôle : rendu : un panneau par conteneur ouvert, objets positionnés en cases et teintés par catégorie, poids,
 *        raccourcis, fiche d'objet au survol, aperçu d'emplacement pendant un glisser, zone pour jeter, légende des
 *        commandes. Les éléments sont réutilisés d'une mise à jour à l'autre : seuls les objets modifiés sont touchés.
 *        Les cases sont un fond CSS (aucun élément par case).
 */

const View = (() => {
  const TOOLTIP_DELAY_MS = 250;
  const TOOLTIP_GAP_PX = 10;
  const VIEWPORT_MARGIN_PX = 12;
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

  /** Élément d'un objet, créé ou mis à jour. */
  function itemNode(item) {
    const def = Model.definition(item.item) || fallbackDefinition(item.item);
    let node = itemNodes.get(item.id);
    if (!node) {
      node = el('div', 'item');
      node.dataset.id = String(item.id);
      node.append(el('span', 'item-art'), el('span', 'item-quantity'));
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
    section.append(header, bar, grid);
    panels.set(container.id, { section, grid, preview, weightCurrent, weightMax, weightFill });
    return section;
  }

  function renderHotbar() {
    const own = Model.state.containers.get(Model.state.own);
    const slots = Model.state.hotbar.map((id, index) => {
      const slot = el('div', 'hotbar-slot');
      slot.dataset.slot = String(index + 1);
      slot.append(el('span', 'hotbar-key', String(index + 1)));
      const item = own && id ? own.items.get(id) : null;
      const def = item && Model.definition(item.item);
      if (def) {
        slot.classList.add('is-filled');
        slot.dataset.id = String(item.id);
        slot.dataset.category = def.category || '';
        slot.append(art(def));
        if (item.quantity > 1) slot.append(el('span', 'item-quantity', String(item.quantity)));
      }
      return slot;
    });
    refs.hotbar.replaceChildren(...slots);
  }

  /** Rendu complet (ouverture, conteneur ajouté ou retiré). */
  function render() {
    hideTooltip();
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
  }

  // Glisser-déposer ------------------------------------------------------------------------------------------

  function cellSize(containerId) {
    const panel = panels.get(containerId);
    const container = Model.state.containers.get(containerId);
    if (!panel || !container) return 0;
    return panel.grid.getBoundingClientRect().width / container.width;
  }

  /** Grille sous le pointeur : { containerId, rect } ou null. */
  function gridAt(x, y) {
    for (const [containerId, panel] of panels) {
      const rect = panel.grid.getBoundingClientRect();
      if (x >= rect.left && x < rect.right && y >= rect.top && y < rect.bottom) return { containerId, rect };
    }
    return null;
  }

  function slotAt(x, y) {
    for (const slot of refs.hotbar.children) {
      const rect = slot.getBoundingClientRect();
      if (x >= rect.left && x < rect.right && y >= rect.top && y < rect.bottom) return Number(slot.dataset.slot);
    }
    return null;
  }

  /** Vrai si le pointeur est sur un élément de l'interface (le reste de l'écran sert à jeter). */
  function isOverInterface(x, y) {
    for (const node of [...refs.panels.children, refs.hotbarPanel]) {
      const rect = node.getBoundingClientRect();
      if (x >= rect.left && x < rect.right && y >= rect.top && y < rect.bottom) return true;
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
    refs.dropZone.hidden = true;
  }

  function highlightSlot(slot) {
    clearPreview();
    const node = refs.hotbar.children[slot - 1];
    if (node) node.classList.add('is-target');
  }

  function showDropZone() {
    clearPreview();
    refs.dropZone.hidden = false;
  }

  // Infobulle -------------------------------------------------------------------------------------------------

  /** Fiche de l'objet : nom, catégorie, description, poids, taille, pile, geste d'utilisation. */
  function tooltipContent(item, def) {
    const T = STRINGS.tooltip;
    const header = el('header', 'tooltip-header');
    header.append(el('h3', 'tooltip-title', def.label));
    if (def.category) header.append(el('p', 'tooltip-category', categoryLabel(def.category)));
    const facts = el('dl', 'tooltip-facts');
    const fact = (label, value, note) => {
      const row = el('div', 'tooltip-fact');
      const dd = el('dd', null, value);
      if (note) dd.append(el('small', null, note));
      row.append(el('dt', null, label), dd);
      facts.append(row);
    };
    fact(T.weight, T.kilos(def.weight * item.quantity), item.quantity > 1 ? T.unit(def.weight) : null);
    fact(T.size, T.cells(def.width, def.height));
    if (def.stack > 1) fact(T.quantity, STRINGS.quantity(item.quantity, def.stack));
    const parts = [header];
    if (def.description) parts.push(el('p', 'tooltip-text', def.description));
    parts.push(facts);
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
    const found = Model.find(item.id);
    if (def.usable && found && found.container.id === Model.state.own) {
      const use = el('p', 'tooltip-use');
      use.append(hint(T.use));
      parts.push(use);
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
      tooltip: root.querySelector('.tooltip'),
      dropZone: root.querySelector('.drop-zone'),
    };
    root.querySelector('.hotbar-title').textContent = STRINGS.hotbar;
    root.querySelector('.hotbar-hint').textContent = STRINGS.hotbarHint;
    root.querySelector('.hints').replaceChildren(...STRINGS.hints.map(hint));
    refs.dropZone.textContent = STRINGS.dropZone;
  }

  return {
    init, render, renderContainer, renderHotbar, cellSize, gridAt, slotAt, isOverInterface, ghost,
    setPreview, clearPreview, highlightSlot, showDropZone, showTooltip, hideTooltip,
    element: (id) => itemNodes.get(id),
  };
})();
