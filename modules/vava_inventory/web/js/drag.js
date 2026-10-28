'use strict';
/*
 * web/js/drag.js
 * Rôle : glisser-déposer. Pendant le geste : copie de l'objet sous le pointeur (transform seulement), aperçu de
 *        l'emplacement (valide, impossible, fusion, raccourci, mains, jeter), R pour pivoter, Maj pour diviser en
 *        deux. Les cartes d'occupation sont calculées une fois au début du geste ; les mises à jour suivent les
 *        images affichées (requestAnimationFrame), jamais plus.
 */

const Drag = (() => {
  let handlers = null;
  let drag = null;
  let frameRequested = false;

  const clamp = (value, low, high) => Math.max(low, Math.min(high, value));
  const sameMetadata = (a, b) => Model.sameMetadata(a, b);

  function weightAllows(container, from, def, quantity) {
    return container === from || container.maxWeight === 0 || container.weight + def.weight * quantity <= container.maxWeight;
  }

  /** Ce que donnerait un relâchement maintenant. */
  function evaluate() {
    const { x: px, y: py, shift } = drag.pointer;
    const slot = View.slotAt(px, py);
    if (slot !== null) return { kind: 'hotbar', slot };
    // mains : seulement un objet de sa besace qui se tient en main
    if (View.handsAt(px, py)) return { kind: 'hands', valid: Boolean(drag.def.holdable) && drag.from.id === Model.state.own };
    const hit = View.gridAt(px, py);
    if (!hit) return View.isOverInterface(px, py) ? null : { kind: 'drop' };

    const container = Model.state.containers.get(hit.containerId);
    const cellX = Math.floor((px - hit.rect.left) / drag.cell);
    const cellY = Math.floor((py - hit.rect.top) / drag.cell);
    const cells = drag.occupancies.get(container.id);
    const underId = cells.get(cellY * container.width + cellX);
    if (underId !== undefined) {
      const under = container.items.get(underId);
      if (under && under.item === drag.item.item && drag.def.stack > 1 && sameMetadata(under.metadata, drag.item.metadata)) {
        const room = drag.def.stack - under.quantity;
        return { kind: 'merge', container, target: under, valid: room > 0 && weightAllows(container, drag.from, drag.def, Math.min(room, drag.item.quantity)) };
      }
    }

    const [w, h] = Grid.footprint(drag.def, drag.rotated);
    const x = cellX - drag.grabX;
    const y = cellY - drag.grabY;
    const split = shift && drag.item.quantity > 1 && drag.def.stack > 1;
    const quantity = split ? Math.floor(drag.item.quantity / 2) : drag.item.quantity;
    // une division laisse l'original en place : ses cases comptent
    const occupancy = split && container === drag.from ? drag.fullOccupancy : cells;
    const valid = Grid.fits(container, occupancy, w, h, x, y) && weightAllows(container, drag.from, drag.def, quantity);
    return { kind: split ? 'split' : 'move', container, x, y, w, h, quantity, valid };
  }

  function paint() {
    frameRequested = false;
    if (!drag) return;
    const { x, y } = drag.pointer;
    drag.ghost.style.transform = `translate(${x - (drag.grabX + 0.5) * drag.cell}px, ${y - (drag.grabY + 0.5) * drag.cell}px)`;
    const target = evaluate();
    drag.target = target;
    // la copie recouvre l'aperçu : elle porte aussi le refus
    drag.ghost.classList.toggle('is-invalid', Boolean(target && target.valid === false));
    if (!target) View.clearPreview();
    else if (target.kind === 'hotbar') View.highlightSlot(target.slot);
    else if (target.kind === 'hands') View.highlightHands(target.valid);
    else if (target.kind === 'drop') View.showDropZone();
    else if (target.kind === 'merge') {
      const def = drag.def;
      const [w, h] = Grid.footprint(def, target.target.rotated);
      View.setPreview(target.container.id, target.target.x, target.target.y, w, h, target.valid ? 'merge' : 'invalid');
    } else View.setPreview(target.container.id, target.x, target.y, target.w, target.h, target.valid ? 'valid' : 'invalid');
  }

  function schedule() {
    if (!frameRequested) {
      frameRequested = true;
      requestAnimationFrame(paint);
    }
  }

  function applyGhostSize() {
    const [w, h] = Grid.footprint(drag.def, drag.rotated);
    // hors de sa grille, la copie ne reçoit plus la taille de case : elle la porte elle-même
    drag.ghost.style.setProperty('--cell', `${drag.cell}px`);
    drag.ghost.style.width = `${w * drag.cell}px`;
    drag.ghost.style.height = `${h * drag.cell}px`;
    drag.ghost.style.setProperty('--w', w);
    drag.ghost.style.setProperty('--h', h);
    drag.ghost.classList.toggle('is-rotated', drag.rotated);
  }

  function onMove(event) {
    drag.pointer = { x: event.clientX, y: event.clientY, shift: event.shiftKey };
    schedule();
  }

  function rotate() {
    if (drag.def.width === drag.def.height) return;
    drag.rotated = !drag.rotated;
    const [w, h] = Grid.footprint(drag.def, drag.rotated);
    [drag.grabX, drag.grabY] = [clamp(drag.grabY, 0, w - 1), clamp(drag.grabX, 0, h - 1)];
    applyGhostSize();
    schedule();
  }

  function stop() {
    window.removeEventListener('pointermove', onMove);
    window.removeEventListener('pointerup', onUp);
    window.removeEventListener('keydown', onKey, true);
    drag.ghost.remove();
    drag.node.classList.remove('is-dragging');
    View.clearPreview();
  }

  function onKey(event) {
    if (event.key === 'r' || event.key === 'R') {
      event.preventDefault();
      event.stopPropagation();
      rotate();
    } else if (event.key === 'Escape') {
      event.preventDefault();
      event.stopPropagation();
      stop();
      drag = null;
    } else if (event.key === 'Shift') {
      drag.pointer.shift = true;
      schedule();
    }
  }

  function onUp(event) {
    drag.pointer = { x: event.clientX, y: event.clientY, shift: event.shiftKey };
    const target = evaluate();
    const current = drag;
    stop();
    drag = null;
    if (!target) return;
    const { item, from } = current;
    if (target.kind === 'hotbar') {
      if (from.id === Model.state.own) handlers.hotbarSet(target.slot, item.id);
    } else if (target.kind === 'hands') {
      if (target.valid) handlers.hold(item.id);
    } else if (target.kind === 'drop') {
      if (from.kind !== 'drop') handlers.drop(item);
    } else if (!target.valid) {
      return;
    } else if (target.kind === 'merge') {
      handlers.merge(item, target.target);
    } else if (target.kind === 'split') {
      handlers.split(item, target.quantity, target.container, target.x, target.y, current.rotated);
    } else if (target.container !== from || target.x !== item.x || target.y !== item.y || current.rotated !== Boolean(item.rotated)) {
      handlers.move(item, target.container, target.x, target.y, current.rotated);
    }
  }

  function begin(event) {
    if (event.button !== 0 || drag) return;
    const node = event.target.closest('.panels .item');
    if (!node) return;
    const found = Model.find(Number(node.dataset.id));
    const def = found && Model.definition(found.item.item);
    if (!def) return;
    event.preventDefault();
    View.hideTooltip();
    const { container: from, item } = found;
    const cell = View.cellSize(from.id);
    const rect = node.getBoundingClientRect();
    const [w, h] = Grid.footprint(def, item.rotated);
    const occupancies = new Map();
    for (const container of Model.state.containers.values()) {
      occupancies.set(container.id, Grid.occupancy(container, Model.state.definitions, container === from ? item.id : undefined));
    }
    drag = {
      item, def, from, node, cell, occupancies,
      fullOccupancy: Grid.occupancy(from, Model.state.definitions),
      rotated: Boolean(item.rotated),
      grabX: clamp(Math.floor((event.clientX - rect.left) / cell), 0, w - 1),
      grabY: clamp(Math.floor((event.clientY - rect.top) / cell), 0, h - 1),
      ghost: View.ghost(item, rect),
      pointer: { x: event.clientX, y: event.clientY, shift: event.shiftKey },
      target: null,
    };
    applyGhostSize();
    node.classList.add('is-dragging');
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    window.addEventListener('keydown', onKey, true);
    schedule();
  }

  function init(root, callbacks) {
    handlers = callbacks;
    root.addEventListener('pointerdown', begin);
  }

  return { init, isDragging: () => drag !== null };
})();
