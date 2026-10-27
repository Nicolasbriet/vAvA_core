'use strict';
/*
 * web/js/grid.js
 * Rôle : géométrie des grilles côté interface, identique à shared/grid.lua : elle sert à montrer avant la réponse du
 *        serveur si un geste est possible. Le serveur reste seul juge.
 */

const Grid = (() => {
  const ORIENTATIONS = [false, true];

  /** [largeur, hauteur] occupées selon l'orientation. */
  const footprint = (def, rotated) => (rotated ? [def.height, def.width] : [def.width, def.height]);

  /** Carte d'occupation (index de case → id d'objet), sans l'objet `ignoreId`. */
  function occupancy(container, definitions, ignoreId) {
    const cells = new Map();
    for (const item of container.items.values()) {
      const def = definitions[item.item];
      if (item.id === ignoreId || !def) continue;
      const [w, h] = footprint(def, item.rotated);
      for (let dy = 0; dy < h; dy += 1) {
        for (let dx = 0; dx < w; dx += 1) cells.set((item.y + dy) * container.width + item.x + dx, item.id);
      }
    }
    return cells;
  }

  function fits(container, cells, w, h, x, y) {
    if (x < 0 || y < 0 || x + w > container.width || y + h > container.height) return false;
    for (let dy = 0; dy < h; dy += 1) {
      for (let dx = 0; dx < w; dx += 1) {
        if (cells.has((y + dy) * container.width + x + dx)) return false;
      }
    }
    return true;
  }

  /** Premier emplacement libre : { x, y, rotated } ou null. */
  function findSpace(container, cells, def) {
    for (const rotated of ORIENTATIONS) {
      const [w, h] = footprint(def, rotated);
      for (let y = 0; y <= container.height - h; y += 1) {
        for (let x = 0; x <= container.width - w; x += 1) {
          if (fits(container, cells, w, h, x, y)) return { x, y, rotated };
        }
      }
      if (def.width === def.height) break;
    }
    return null;
  }

  return { footprint, occupancy, fits, findSpace };
})();
