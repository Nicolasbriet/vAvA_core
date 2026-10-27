'use strict';
/*
 * web/js/hud.js
 * Rôle : jauges du HUD (création, mise à jour de la valeur, du palier et de la lueur, ordre, visibilité) et notifications
 *        (empilées, retirées après leur durée ou quand elles sont trop nombreuses). Chaque jauge garde son élément ;
 *        une mise à jour ne touche que la jauge concernée.
 */

(() => {
  const SVG = 'http://www.w3.org/2000/svg';
  const RADIUS = 21;
  const LEAVE_MS = 260;
  const root = document.getElementById('hud');
  const toasts = document.getElementById('toasts');
  const entries = new Map();
  // réglages des notifications, reçus à l'initialisation
  let toastRules = { durationMs: 4500, maxVisible: 4 };

  function dismiss(node) {
    if (node.classList.contains('is-leaving')) return;
    node.classList.add('is-leaving');
    setTimeout(() => node.remove(), LEAVE_MS);
  }

  function notify({ message, kind }) {
    const node = document.createElement('div');
    node.className = 'toast';
    node.dataset.kind = kind || 'info';
    node.textContent = message;
    toasts.append(node);
    const shown = [...toasts.children].filter((child) => !child.classList.contains('is-leaving'));
    for (const old of shown.slice(0, Math.max(0, shown.length - toastRules.maxVisible))) dismiss(old);
    setTimeout(() => dismiss(node), toastRules.durationMs);
  }

  const level = (entry) => {
    if (entry.value <= entry.critical) return 'critical';
    if (entry.value <= entry.low) return 'low';
    return 'ok';
  };

  function circle(className) {
    const node = document.createElementNS(SVG, 'circle');
    node.setAttribute('class', className);
    node.setAttribute('cx', '24');
    node.setAttribute('cy', '24');
    node.setAttribute('r', String(RADIUS));
    // longueur ramenée à 100 : la valeur en pourcentage devient directement le tracé
    node.setAttribute('pathLength', '100');
    return node;
  }

  function paint(entry) {
    const percent = Math.round(entry.value * 1000) / 10;
    entry.fill.setAttribute('stroke-dasharray', `${percent} 100`);
    entry.node.dataset.level = level(entry);
    entry.node.setAttribute('aria-valuenow', String(Math.round(percent)));
  }

  function build(def) {
    const node = document.createElement('div');
    node.className = 'gauge';
    node.dataset.id = def.id;
    node.setAttribute('role', 'meter');
    node.setAttribute('aria-valuemin', '0');
    node.setAttribute('aria-valuemax', '100');
    const ring = document.createElementNS(SVG, 'svg');
    ring.setAttribute('class', 'gauge-ring');
    ring.setAttribute('viewBox', '0 0 48 48');
    ring.setAttribute('aria-hidden', 'true');
    const fill = circle('gauge-fill');
    ring.append(circle('gauge-track'), fill);
    const icon = document.createElement('img');
    icon.className = 'gauge-icon';
    icon.alt = '';
    icon.draggable = false;
    node.append(ring, icon);
    return { node, fill, icon };
  }

  function order() {
    const sorted = [...entries.values()].sort((a, b) => a.order - b.order || (a.id < b.id ? -1 : 1));
    root.replaceChildren(...sorted.map((entry) => entry.node));
  }

  function define(def) {
    let entry = entries.get(def.id);
    if (!entry) {
      entry = { id: def.id, ...build(def) };
      entries.set(def.id, entry);
    }
    Object.assign(entry, { label: def.label, order: def.order, low: def.low, critical: def.critical, value: def.value });
    entry.node.classList.toggle('is-active', Boolean(def.active));
    entry.node.setAttribute('aria-label', def.label);
    if (entry.icon.getAttribute('src') !== def.icon) entry.icon.src = def.icon;
    paint(entry);
    order();
  }

  const handlers = {
    init({ position = {}, gauges = [], visible = false, notifications }) {
      if (notifications) toastRules = { durationMs: notifications.durationMs, maxVisible: notifications.maxVisible };
      if (position.left) root.style.setProperty('--left', position.left);
      if (position.bottom) root.style.setProperty('--bottom', position.bottom);
      entries.clear();
      root.replaceChildren();
      for (const def of gauges) define(def);
      root.classList.toggle('is-visible', Boolean(visible));
    },
    define,
    value({ id, value }) {
      const entry = entries.get(id);
      if (!entry) return;
      entry.value = value;
      paint(entry);
    },
    active({ id, active }) {
      const entry = entries.get(id);
      if (entry) entry.node.classList.toggle('is-active', Boolean(active));
    },
    remove({ id }) {
      const entry = entries.get(id);
      if (!entry) return;
      entry.node.remove();
      entries.delete(id);
    },
    visible({ visible }) {
      root.classList.toggle('is-visible', Boolean(visible));
    },
    notify,
  };

  window.addEventListener('message', (event) => {
    const data = event.data || {};
    const handler = handlers[data.action];
    if (handler) handler(data.payload || {});
  });

  // page prête : le jeu envoie l'état complet (hors jeu, l'aperçu simulé s'en charge)
  if (typeof GetParentResourceName === 'function') {
    fetch(`https://${GetParentResourceName()}/ready`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' })
      .catch(() => {});
  }
})();
