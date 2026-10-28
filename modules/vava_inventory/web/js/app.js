'use strict';
/*
 * web/js/app.js
 * Rôle : assemblage : messages du jeu, gestes (déplacer et fusionner sont prévus localement puis confirmés ou
 *        annulés par le serveur), prendre en main ou reposer, menu contextuel, double-clic, raccourcis clavier.
 */

(() => {
  const app = document.getElementById('app');
  const A = STRINGS.actions;

  const uniq = (list) => [...new Set(list)];
  const own = () => Model.state.containers.get(Model.state.own);

  function refresh(containers) {
    for (const container of uniq(containers)) View.renderContainer(container);
    View.renderHotbar();
    View.renderHands();
  }

  /** Prévision locale : appliquée tout de suite, annulée si le serveur refuse. */
  async function predicted(containers, apply, request) {
    const saved = Model.save(uniq(containers));
    apply();
    refresh(containers);
    const result = await request();
    if (!result.ok) {
      Model.restore(saved);
      refresh(containers);
      Menu.toast(errorMessage(result.error));
    }
    return result;
  }

  async function plain(name, data) {
    const result = await Bridge.post(name, data);
    if (!result.ok) Menu.toast(errorMessage(result.error));
    return result;
  }

  const actions = {
    move(item, container, x, y, rotated) {
      const found = Model.find(item.id);
      if (!found) return;
      const from = found.container;
      const def = Model.definition(item.item);
      return predicted([from, container], () => {
        from.items.delete(item.id);
        container.items.set(item.id, { ...item, x, y, rotated });
        if (from !== container) {
          from.weight -= def.weight * item.quantity;
          container.weight += def.weight * item.quantity;
        }
      }, () => Bridge.post('move', { id: item.id, container: container.id, x, y, rotated }));
    },
    merge(item, target) {
      const source = Model.find(item.id);
      const destination = Model.find(target.id);
      if (!source || !destination) return;
      const def = Model.definition(item.item);
      const amount = Math.min(item.quantity, def.stack - target.quantity);
      return predicted([source.container, destination.container], () => {
        destination.container.items.set(target.id, { ...target, quantity: target.quantity + amount });
        if (amount >= item.quantity) source.container.items.delete(item.id);
        else source.container.items.set(item.id, { ...item, quantity: item.quantity - amount });
        if (source.container !== destination.container) {
          source.container.weight -= def.weight * amount;
          destination.container.weight += def.weight * amount;
        }
      }, () => Bridge.post('merge', { id: item.id, target: target.id }));
    },
    split(item, quantity, container, x, y, rotated) {
      return plain('split', { id: item.id, quantity, container: container.id, x, y, rotated });
    },
    drop(item, quantity) {
      return plain('drop', { id: item.id, quantity });
    },
    hotbarSet(slot, id) {
      return plain('hotbarSet', { slot, id });
    },
    hold(id) {
      return plain('hold', { id });
    },
  };

  function use(item) {
    return plain('use', { id: item.id });
  }

  /** Prend l'objet en main, ou le repose s'il y est déjà. */
  function toggleHold(item) {
    return actions.hold(Model.state.hands === item.id ? 0 : item.id);
  }

  /** Geste principal d'un objet de sa besace : utiliser, sinon tenir ou reposer. */
  function primary(item, def) {
    if (def.usable) return use(item);
    if (def.holdable) return toggleHold(item);
    return null;
  }

  /** Ramasser : premier emplacement libre de son inventaire. */
  function pickup(item) {
    const container = own();
    const def = Model.definition(item.item);
    if (!container || !def) return;
    const space = Grid.findSpace(container, Grid.occupancy(container, Model.state.definitions), def);
    if (!space) {
      Menu.toast(errorMessage('no_space'));
      return;
    }
    actions.move(item, container, space.x, space.y, space.rotated);
  }

  async function splitDialog(item, container) {
    const def = Model.definition(item.item);
    const quantity = await Menu.quantity({ title: `${STRINGS.split.title} : ${def.label}`, max: item.quantity - 1, value: Math.floor(item.quantity / 2) });
    if (!quantity) return;
    const space = Grid.findSpace(container, Grid.occupancy(container, Model.state.definitions), def);
    if (!space) {
      Menu.toast(errorMessage('no_space'));
      return;
    }
    actions.split(item, quantity, container, space.x, space.y, space.rotated);
  }

  function itemFromEvent(event) {
    const node = event.target.closest('.panels .item');
    return node ? Model.find(Number(node.dataset.id)) : null;
  }

  function openContextMenu(event) {
    const slotNode = event.target.closest('.hotbar-slot');
    if (slotNode) {
      event.preventDefault();
      if (slotNode.classList.contains('is-filled')) {
        Menu.context(event.clientX, event.clientY, [{ label: A.clearSlot, run: () => actions.hotbarSet(Number(slotNode.dataset.slot), 0) }]);
      }
      return;
    }
    const handsNode = event.target.closest('.hands-slot');
    if (handsNode) {
      event.preventDefault();
      if (handsNode.classList.contains('is-filled')) {
        Menu.context(event.clientX, event.clientY, [{ label: A.release, run: () => actions.hold(0) }]);
      }
      return;
    }
    const found = itemFromEvent(event);
    if (!found) return;
    event.preventDefault();
    View.hideTooltip();
    const { item, container } = found;
    const def = Model.definition(item.item);
    const inOwn = container.id === Model.state.own;
    const entries = [];
    if (def && def.usable && inOwn) entries.push({ label: A.use, run: () => use(item) });
    if (def && def.holdable && inOwn) {
      const held = Model.state.hands === item.id;
      entries.push({ label: held ? A.release : A.hold, run: () => toggleHold(item) });
    }
    if (def && def.stack > 1 && item.quantity > 1) entries.push({ label: A.split, run: () => splitDialog(item, container) });
    if (container.kind === 'drop') entries.push({ label: A.pickup, run: () => pickup(item) });
    else if (container.kind === 'catalog') entries.push({ label: A.take, run: () => pickup(item) });
    else entries.push({ label: A.drop, danger: true, run: () => actions.drop(item) });
    Menu.context(event.clientX, event.clientY, entries);
  }

  function onDoubleClick(event) {
    const found = itemFromEvent(event);
    if (!found) return;
    const def = Model.definition(found.item.item);
    if (found.container.kind === 'drop' || found.container.kind === 'catalog') pickup(found.item);
    else if (def && found.container.id === Model.state.own) primary(found.item, def);
  }

  // Catalogue de développement : le bandeau demande une page au serveur, qui renvoie le panneau garni ------------

  const SEARCH_DEBOUNCE_MS = 250;
  let searchTimer = null;

  /** Conteneur du catalogue désigné par un élément du bandeau. */
  function catalogOf(node) {
    const container = Model.state.containers.get(Number(node.dataset.container));
    return container && container.catalog ? container : null;
  }

  function catalogRequest(container, changes) {
    const state = container.catalog;
    return plain('catalog', { category: state.category, page: state.page, query: state.query, ...changes });
  }

  function onCatalogClick(event) {
    const tab = event.target.closest('.catalog-tab');
    if (tab) {
      const container = catalogOf(tab);
      if (container) catalogRequest(container, { category: tab.dataset.category, page: 1 });
      return;
    }
    const button = event.target.closest('.catalog-prev, .catalog-next');
    if (!button || button.disabled) return;
    const container = catalogOf(button);
    if (container) catalogRequest(container, { page: container.catalog.page + (button.classList.contains('catalog-next') ? 1 : -1) });
  }

  /** Recherche envoyée après une courte pause de frappe (ou tout de suite : Entrée). */
  function searchNow(input) {
    clearTimeout(searchTimer);
    const container = catalogOf(input);
    const query = input.value.trim();
    if (container && query !== container.catalog.query) catalogRequest(container, { query, page: 1 });
  }

  function onCatalogInput(event) {
    const input = event.target.closest('.catalog-search');
    if (!input) return;
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => searchNow(input), SEARCH_DEBOUNCE_MS);
  }

  function onHotbarClick(event) {
    const slotNode = event.target.closest('.hotbar-slot.is-filled');
    if (!slotNode || event.button !== 0) return;
    const found = Model.find(Number(slotNode.dataset.id));
    const def = found && Model.definition(found.item.item);
    if (def) primary(found.item, def);
  }

  function close() {
    app.hidden = true;
    Menu.dismiss();
    View.hideTooltip();
    Bridge.post('close');
  }

  View.init(app);
  Menu.init(app);
  Drag.init(app, actions);
  app.addEventListener('contextmenu', openContextMenu);
  app.addEventListener('dblclick', onDoubleClick);
  app.addEventListener('click', onHotbarClick);
  app.addEventListener('click', onCatalogClick);
  app.addEventListener('input', onCatalogInput);
  app.addEventListener('pointerover', (event) => {
    if (Drag.isDragging()) return;
    const found = itemFromEvent(event);
    if (found) View.showTooltip(found.item, event.target.closest('.item'));
  });
  app.addEventListener('pointerout', (event) => {
    if (event.target.closest('.item')) View.hideTooltip();
  });

  Bridge.onMessage((action, payload) => {
    if (action === 'open') {
      Model.load(payload);
      View.render();
      app.hidden = false;
    } else if (action === 'delta') {
      const container = Model.applyDelta(payload);
      if (container) refresh([...Model.state.containers.values()]);
    } else if (action === 'containerClosed') {
      Model.removeContainer(payload.id);
      View.render();
    } else if (action === 'hotbar') {
      Model.setHotbar(payload.hotbar);
      View.renderHotbar();
    } else if (action === 'hands') {
      Model.setHands(payload.id);
      // la marque « en main » vit sur l'objet et sur ses emplacements
      const ownContainer = own();
      if (ownContainer) View.renderContainer(ownContainer);
      View.renderHotbar();
      View.renderHands();
    } else if (action === 'notify') {
      Menu.toast(payload.message);
    } else if (action === 'close') {
      app.hidden = true;
      Menu.dismiss();
      View.hideTooltip();
    }
  });

  document.addEventListener('keydown', (event) => {
    if (app.hidden || Drag.isDragging()) return;
    const typing = event.target instanceof HTMLInputElement;
    const searching = typing && event.target.classList.contains('catalog-search');
    if (event.key === 'Escape') {
      event.preventDefault();
      // dans la recherche du catalogue : quitter le champ d'abord, fermer l'inventaire au second Échap
      if (searching) event.target.blur();
      else if (!Menu.dismiss()) close();
      return;
    }
    if (event.key === 'Enter' && searching) {
      event.preventDefault();
      searchNow(event.target);
      return;
    }
    if (!typing && !Menu.isOpen() && event.key.toLowerCase() === String(Model.state.closeKey).toLowerCase()) close();
  });
})();
