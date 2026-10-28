'use strict';
/*
 * web/js/model.js
 * Rôle : état de l'inventaire côté interface (conteneurs ouverts, définitions, raccourcis, objet en main), mis à jour
 *        par les différences du serveur. Sauvegarde et restauration pour annuler un geste prévu que le serveur refuse.
 *        Lecture des métadonnées d'une pile (contrat standard : palier, qualité, solidité, signature…).
 */

const Model = (() => {
  const state = { own: null, order: [], containers: new Map(), definitions: {}, hotbar: [], hands: 0, closeKey: 'I' };

  /** msgpack transmet une liste vide comme un objet vide : toujours une vraie liste. */
  const list = (value) => (Array.isArray(value) ? value : Object.values(value || {}));

  /** Métadonnées d'une pile : toujours un objet (une table Lua vide arrive parfois en liste vide). */
  const metadataOf = (item) => (item && item.metadata && typeof item.metadata === 'object' && !Array.isArray(item.metadata) ? item.metadata : {});

  /** Égalité profonde, indépendante de l'ordre des clés (le JSON du serveur ne le garantit pas). */
  function sameMetadata(a, b) {
    const left = a && typeof a === 'object' ? a : {};
    const right = b && typeof b === 'object' ? b : {};
    const keys = Object.keys(left);
    if (keys.length !== Object.keys(right).length) return false;
    return keys.every((key) => {
      const x = left[key];
      const y = right[key];
      if (x !== null && y !== null && typeof x === 'object' && typeof y === 'object') return sameMetadata(x, y);
      return x === y;
    });
  }

  const isNumber = (value) => typeof value === 'number' && Number.isFinite(value);

  /** Vue typée des métadonnées standard d'une pile ; les clés absentes ou mal typées sont ignorées. */
  function describe(item) {
    const meta = metadataOf(item);
    const view = {};
    if (Number.isInteger(meta.tier) && meta.tier >= 1) view.tier = meta.tier;
    if (isNumber(meta.quality)) view.quality = meta.quality;
    if (isNumber(meta.durability) && isNumber(meta.max_durability) && meta.max_durability > 0) {
      view.durability = meta.durability;
      view.maxDurability = meta.max_durability;
      view.durabilityRatio = Math.max(0, Math.min(1, meta.durability / meta.max_durability));
    }
    view.broken = meta.broken === true;
    if (typeof meta.name === 'string' && meta.name.length > 0) view.name = meta.name;
    if (typeof meta.crafter_name === 'string' && meta.crafter_name.length > 0) view.crafter = meta.crafter_name;
    if (typeof meta.mark === 'string' && meta.mark.length > 0) view.mark = meta.mark;
    if (isNumber(meta.crafted_at) && meta.crafted_at > 0) view.craftedAt = meta.crafted_at;
    if (typeof meta.origin === 'string' && meta.origin.length > 0) view.origin = meta.origin;
    view.history = list(meta.history).filter((entry) => entry && typeof entry === 'object');
    view.lines = list(meta.lines).filter((line) => line && typeof line === 'object' && typeof line.label === 'string');
    return view;
  }

  /** État du catalogue de développement porté par son conteneur (bandeau : catégorie, page, recherche), ou null. */
  function toCatalog(raw) {
    if (!raw || typeof raw !== 'object') return null;
    return {
      category: typeof raw.category === 'string' ? raw.category : '',
      page: Number(raw.page) || 1,
      pages: Number(raw.pages) || 1,
      query: typeof raw.query === 'string' ? raw.query : '',
      total: Number(raw.total) || 0,
      categories: list(raw.categories).filter((entry) => entry && typeof entry.id === 'string'),
    };
  }

  function toContainer(raw) {
    return {
      id: raw.id, kind: raw.kind, label: raw.label, width: raw.width, height: raw.height,
      maxWeight: raw.maxWeight, weight: raw.weight, items: new Map(list(raw.items).map((item) => [item.id, item])),
      catalog: toCatalog(raw.catalog),
    };
  }

  function load(snapshot) {
    state.own = snapshot.own;
    state.order = [];
    state.containers.clear();
    for (const raw of list(snapshot.containers)) {
      state.containers.set(raw.id, toContainer(raw));
      state.order.push(raw.id);
    }
    state.definitions = { ...snapshot.definitions };
    state.hotbar = list(snapshot.hotbar);
    state.hands = Number(snapshot.hands) || 0;
    if (snapshot.closeKey) state.closeKey = snapshot.closeKey;
  }

  /** Applique une différence ; renvoie le conteneur concerné (ou null s'il n'est pas ouvert). */
  function applyDelta(delta) {
    const container = state.containers.get(delta.container);
    if (!container) return null;
    Object.assign(state.definitions, delta.definitions || {});
    for (const id of list(delta.removed)) container.items.delete(id);
    for (const item of list(delta.set)) {
      // l'objet a pu changer de conteneur : un seul exemplaire affiché
      for (const other of state.containers.values()) if (other !== container) other.items.delete(item.id);
      container.items.set(item.id, item);
    }
    container.weight = delta.weight;
    return container;
  }

  function removeContainer(id) {
    state.containers.delete(id);
    state.order = state.order.filter((value) => value !== id);
  }

  /** { container, item } d'un objet affiché. */
  function find(id) {
    for (const container of state.containers.values()) {
      const item = container.items.get(id);
      if (item) return { container, item };
    }
    return null;
  }

  const definition = (name) => state.definitions[name];

  /** Copie des conteneurs touchés par un geste prévu. */
  function save(containers) {
    return containers.map((container) => ({
      container, weight: container.weight,
      items: new Map([...container.items].map(([id, item]) => [id, { ...item }])),
    }));
  }

  function restore(saved) {
    for (const entry of saved) {
      entry.container.items = entry.items;
      entry.container.weight = entry.weight;
    }
  }

  function setHotbar(value) {
    state.hotbar = list(value);
  }

  function setHands(id) {
    state.hands = Number(id) || 0;
  }

  /** Pile tenue en main, si elle est dans l'inventaire du joueur. */
  function heldItem() {
    const own = state.containers.get(state.own);
    return own && state.hands ? own.items.get(state.hands) || null : null;
  }

  return {
    state, list, load, applyDelta, removeContainer, find, definition, save, restore, setHotbar, setHands, heldItem,
    metadataOf, sameMetadata, describe,
  };
})();
