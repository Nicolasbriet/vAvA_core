'use strict';
/*
 * web/js/model.js
 * Rôle : état de l'inventaire côté interface (conteneurs ouverts, définitions, raccourcis), mis à jour par les
 *        différences du serveur. Sauvegarde et restauration pour annuler un geste prévu que le serveur refuse.
 */

const Model = (() => {
  const state = { own: null, order: [], containers: new Map(), definitions: {}, hotbar: [], closeKey: 'I' };

  /** msgpack transmet une liste vide comme un objet vide : toujours une vraie liste. */
  const list = (value) => (Array.isArray(value) ? value : Object.values(value || {}));

  function toContainer(raw) {
    return {
      id: raw.id, kind: raw.kind, label: raw.label, width: raw.width, height: raw.height,
      maxWeight: raw.maxWeight, weight: raw.weight, items: new Map(list(raw.items).map((item) => [item.id, item])),
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

  return { state, list, load, applyDelta, removeContainer, find, definition, save, restore, setHotbar };
})();
