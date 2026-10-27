'use strict';
/*
 * web/js/wheel.js
 * Rôle : roue des sorts, au centre de l'écran, tant que la touche est maintenue. Anneau intérieur : les éléments dont
 *        un sort est connu (et « Ranger la magie » quand un sort est prêt) ; anneau extérieur : les sorts de l'élément
 *        survolé, avec icône, niveau en chiffres romains, coût en mana, et temps de recharge (sort grisé). Le moyeu de
 *        parchemin nomme ce que la souris désigne ; au centre, rien n'est choisi. Au relâchement (signalé par le jeu,
 *        ou vu ici sur la touche), le choix part au jeu. Rien n'est dessiné en continu : seul le compte à rebours des
 *        recharges se met à jour, roue ouverte.
 */

const Wheel = (() => {
  const root = document.getElementById('wheel');
  const NS = 'http://www.w3.org/2000/svg';
  const SIZE = 600;
  const C = SIZE / 2;
  const R = { hub: 68, innerIn: 76, innerOut: 152, outerIn: 162, outerOut: 262 };
  // part d'un cercle prise par chaque sort de l'anneau extérieur, et marge entre deux secteurs (radians)
  const SPELL_SPAN = Math.PI / 5;
  const GAP = 0.022;
  const TICK_MS = 200;
  const TAU = Math.PI * 2;

  let data = null;
  let open = false;
  let openedAt = 0;
  let hover = { kind: 'center' };
  let groupIndex = -1;
  let ticker = null;
  let nodes = null;

  function point(r, a) {
    return [C + r * Math.sin(a), C - r * Math.cos(a)];
  }

  function sectorPath(r0, r1, a0, a1) {
    const large = a1 - a0 > Math.PI ? 1 : 0;
    const [x0, y0] = point(r1, a0);
    const [x1, y1] = point(r1, a1);
    const [x2, y2] = point(r0, a1);
    const [x3, y3] = point(r0, a0);
    return `M${x0} ${y0}A${r1} ${r1} 0 ${large} 1 ${x1} ${y1}L${x2} ${y2}A${r0} ${r0} 0 ${large} 0 ${x3} ${y3}Z`;
  }

  function svgEl(tag, attrs) {
    const node = document.createElementNS(NS, tag);
    for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value);
    return node;
  }

  /** Nœud HTML posé sur la roue à un point de l'image (coordonnées de la roue). */
  function place(node, r, a) {
    const [x, y] = point(r, a);
    node.style.left = `${(x / SIZE) * 100}%`;
    node.style.top = `${(y / SIZE) * 100}%`;
    return node;
  }

  function colorOf(color) {
    const c = color || { r: 220, g: 192, b: 138 };
    return { css: `rgb(${c.r}, ${c.g}, ${c.b})`, rgb: `${c.r}, ${c.g}, ${c.b}` };
  }

  /** Entrées de l'anneau intérieur : les groupes, puis « ranger » si un sort est prêt. */
  function innerItems() {
    const items = data.groups.map((group) => ({ kind: 'group', group }));
    if (data.selected) items.push({ kind: 'deselect' });
    return items;
  }

  function groupColor(group) {
    const spell = group.spells[0];
    return colorOf(spell && spell.color);
  }

  function cooldownLeft(spell) {
    return Math.max(0, (Number(spell.cooldown) || 0) - (performance.now() - openedAt));
  }

  function renderOuter() {
    nodes.outer.replaceChildren();
    nodes.outerIcons.replaceChildren();
    nodes.spells = [];
    const items = innerItems();
    const item = items[groupIndex];
    if (!item || item.kind !== 'group') return;
    const step = TAU / items.length;
    const center = groupIndex * step;
    const spells = item.group.spells;
    const start = center - ((spells.length - 1) / 2) * SPELL_SPAN;
    spells.forEach((spell, index) => {
      const a = start + index * SPELL_SPAN;
      const color = colorOf(spell.color);
      const path = svgEl('path', { d: sectorPath(R.outerIn, R.outerOut, a - SPELL_SPAN / 2 + GAP, a + SPELL_SPAN / 2 - GAP), class: 'wheel-sector is-outer' });
      path.style.setProperty('--element', color.css);
      path.style.setProperty('--element-rgb', color.rgb);
      if (spell.name === data.selected) path.classList.add('is-selected');
      nodes.outer.append(path);
      const cost = UI.el('span', 'wheel-cost', UI.format(UI.t('wheel').cost, spell.cost));
      const cooldown = UI.el('span', 'wheel-cooldown');
      const iconNode = UI.el('span', 'wheel-icon');
      iconNode.style.setProperty('--icon', UI.image(`img/spells/${spell.icon}.svg`));
      const badge = place(UI.el('div', 'wheel-spell', null, [
        iconNode,
        UI.el('span', 'wheel-level', UI.roman(spell.level)),
        cost,
        cooldown,
      ]), (R.outerIn + R.outerOut) / 2, a);
      badge.style.setProperty('--element', color.css);
      badge.style.setProperty('--element-rgb', color.rgb);
      nodes.outerIcons.append(badge);
      nodes.spells.push({ spell, angle: a, path, badge, cooldown });
    });
    tick();
  }

  function render() {
    root.replaceChildren();
    const svg = svgEl('svg', { viewBox: `0 0 ${SIZE} ${SIZE}`, class: 'wheel-svg', 'aria-hidden': 'true' });
    const middle = (R.outerIn + R.outerOut) / 2;
    svg.append(
      svgEl('circle', { cx: C, cy: C, r: R.outerOut + 10, class: 'wheel-rim' }),
      // anneau extérieur gravé : bande, filets et graduations, même vide
      svgEl('circle', { cx: C, cy: C, r: middle, class: 'wheel-track' }),
      svgEl('circle', { cx: C, cy: C, r: R.outerIn - 2, class: 'wheel-engraving' }),
      svgEl('circle', { cx: C, cy: C, r: R.outerOut + 3, class: 'wheel-engraving' }),
      svgEl('circle', { cx: C, cy: C, r: R.outerOut - 4, class: 'wheel-ticks' }),
      svgEl('circle', { cx: C, cy: C, r: R.innerOut + 5, class: 'wheel-divider' }),
    );
    const inner = svgEl('g', {});
    const outer = svgEl('g', {});
    svg.append(inner, outer);
    const innerIcons = UI.el('div', 'wheel-layer');
    const outerIcons = UI.el('div', 'wheel-layer');
    const hubTitle = UI.el('span', 'wheel-hub-title');
    const hubSub = UI.el('span', 'wheel-hub-sub');
    const hub = UI.el('div', 'wheel-hub', null, [hubTitle, hubSub]);
    nodes = { inner, outer, innerIcons, outerIcons, hubTitle, hubSub, groups: [], spells: [] };

    const items = innerItems();
    const step = TAU / items.length;
    items.forEach((item, index) => {
      const a = index * step;
      const path = svgEl('path', { d: sectorPath(R.innerIn, R.innerOut, a - step / 2 + GAP, a + step / 2 - GAP), class: 'wheel-sector is-inner' });
      const iconNode = UI.el('span', 'wheel-icon');
      const badge = place(UI.el('div', 'wheel-group', null, [iconNode]), (R.innerIn + R.innerOut) / 2, a);
      if (item.kind === 'group') {
        const color = groupColor(item.group);
        for (const target of [path, badge]) {
          target.style.setProperty('--element', color.css);
          target.style.setProperty('--element-rgb', color.rgb);
        }
        iconNode.style.setProperty('--icon', UI.image(`img/elements/${item.group.icon}.svg`));
      } else {
        path.classList.add('is-deselect');
        badge.classList.add('is-deselect');
        iconNode.style.setProperty('--icon', UI.image('img/elements/ranger.svg'));
      }
      inner.append(path);
      innerIcons.append(badge);
      nodes.groups.push({ item, path, badge });
    });
    root.append(svg, innerIcons, outerIcons, hub);
    // le groupe du sort prêt est ouvert d'emblée
    groupIndex = items.findIndex((item) => item.kind === 'group' && item.group.spells.some((s) => s.name === data.selected));
    if (groupIndex === -1) groupIndex = items.findIndex((item) => item.kind === 'group');
    renderOuter();
    highlight();
  }

  function highlight() {
    if (!nodes) return;
    const texts = UI.t('wheel');
    nodes.groups.forEach((entry, index) => {
      const active = index === groupIndex && entry.item.kind === 'group';
      const hovered = (hover.kind === 'group' && hover.index === index) || (hover.kind === 'deselect' && entry.item.kind === 'deselect');
      entry.path.classList.toggle('is-active', active);
      entry.path.classList.toggle('is-hover', hovered);
      entry.badge.classList.toggle('is-hover', hovered || active);
    });
    for (const entry of nodes.spells) {
      const hovered = hover.kind === 'spell' && hover.spell === entry.spell;
      entry.path.classList.toggle('is-hover', hovered);
      entry.badge.classList.toggle('is-hover', hovered);
    }
    let title = texts.cancel;
    let sub = '';
    if (hover.kind === 'spell') {
      title = hover.spell.label;
      sub = `${UI.format(texts.level, hover.spell.level)} · ${UI.format(UI.t('grimoire').cost || 'Mana : %d', hover.spell.cost)}`;
    } else if (hover.kind === 'group') {
      title = nodes.groups[hover.index].item.group.label;
    } else if (hover.kind === 'deselect') {
      title = texts.deselect;
    }
    nodes.hubTitle.textContent = title;
    nodes.hubSub.textContent = sub;
  }

  function tick() {
    if (!nodes) return;
    const texts = UI.t('wheel');
    for (const entry of nodes.spells) {
      const left = cooldownLeft(entry.spell);
      entry.path.classList.toggle('is-cooling', left > 0);
      entry.badge.classList.toggle('is-cooling', left > 0);
      entry.cooldown.textContent = left > 0 ? UI.format(texts.cooldown, Math.ceil(left / 1000)) : '';
    }
  }

  /** La souris a bougé : ce qu'elle désigne. */
  function track(event) {
    if (!open || !nodes) return;
    const rect = root.getBoundingClientRect();
    if (!rect.width) return;
    const scale = rect.width / SIZE;
    const dx = (event.clientX - rect.left) / scale - C;
    const dy = (event.clientY - rect.top) / scale - C;
    const r = Math.hypot(dx, dy);
    let a = Math.atan2(dx, -dy);
    if (a < 0) a += TAU;
    const items = innerItems();
    const step = TAU / items.length;
    let next = { kind: 'center' };
    if (r >= R.hub && r < R.outerIn) {
      const index = Math.round(a / step) % items.length;
      const item = items[index];
      if (item.kind === 'group') {
        next = { kind: 'group', index };
        if (index !== groupIndex) {
          groupIndex = index;
          renderOuter();
        }
      } else {
        next = { kind: 'deselect' };
      }
    } else if (r >= R.outerIn) {
      let best = null;
      for (const entry of nodes.spells) {
        let diff = Math.abs(a - ((entry.angle % TAU) + TAU) % TAU);
        if (diff > Math.PI) diff = TAU - diff;
        if (diff <= SPELL_SPAN / 2 && (!best || diff < best.diff)) best = { entry, diff };
      }
      next = best ? { kind: 'spell', spell: best.entry.spell } : (groupIndex >= 0 ? { kind: 'group', index: groupIndex } : next);
    }
    hover = next;
    highlight();
  }

  function show(payload) {
    data = {
      groups: Array.isArray(payload.groups) ? payload.groups : [],
      selected: payload.selected || '',
      releaseKey: String(payload.releaseKey || 'TAB').toUpperCase(),
    };
    open = true;
    openedAt = performance.now();
    hover = { kind: 'center' };
    render();
    root.hidden = false;
    clearInterval(ticker);
    ticker = setInterval(tick, TICK_MS);
  }

  function close() {
    open = false;
    clearInterval(ticker);
    ticker = null;
    root.hidden = true;
    root.replaceChildren();
    nodes = null;
  }

  /** Relâchement : le choix part au jeu, puis la roue se ferme. */
  function choose() {
    if (!open) return;
    let body = {};
    if (hover.kind === 'spell') body = { spell: hover.spell.name };
    else if (hover.kind === 'deselect') body = { deselect: true };
    close();
    Bridge.post('wheel:choose', body);
  }

  /** Échap : rien n'est choisi. */
  function cancel() {
    if (!open) return;
    close();
    Bridge.post('wheel:choose', {});
  }

  function matchesRelease(event) {
    if (!data) return false;
    const key = String(event.key || '').toUpperCase();
    const code = String(event.code || '').toUpperCase().replace(/^KEY/, '');
    return key === data.releaseKey || code === data.releaseKey;
  }

  window.addEventListener('mousemove', track);
  window.addEventListener('keydown', (event) => {
    if (!open) return;
    if (event.key === 'Tab' || matchesRelease(event)) event.preventDefault();
    if (event.key === 'Escape') {
      event.preventDefault();
      cancel();
    }
  });
  window.addEventListener('keyup', (event) => {
    if (open && matchesRelease(event)) choose();
  });
  window.addEventListener('mouseup', (event) => {
    if (open && event.button === 0) choose();
  });

  return { show, close, choose, isOpen: () => open };
})();
