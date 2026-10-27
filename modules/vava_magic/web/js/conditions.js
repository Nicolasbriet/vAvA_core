'use strict';
/*
 * web/js/conditions.js
 * Rôle : états élémentaires du joueur (bas de l'écran, à droite de la barre de mana) : une icône par état, aux
 *        couleurs de son élément, avec ses secondes restantes ; « Protégé » après un contrôle dur. Effets d'écran :
 *        bord rougi qui palpite tant que l'on brûle, givre sur les bords quand on est gelé, éclat bref à chaque coup.
 *        Seul le compte à rebours se met à jour (deux fois par seconde), et seulement s'il reste un état.
 */

const Conditions = (() => {
  const root = document.getElementById('conditions');
  const burn = document.getElementById('screen-burn');
  const frost = document.getElementById('screen-frost');
  const hit = document.getElementById('screen-hit');
  const TICK_MS = 500;
  const HIT_MS = 320;
  // teinte de chaque état (couleur de son élément)
  const COLORS = {
    burn: '255, 132, 52', wet: '96, 176, 255', slow: '150, 196, 255', stagger: '200, 156, 98',
    knockdown: '200, 156, 98', frozen: '200, 232, 255', immune: '220, 192, 138',
  };

  let entries = [];
  let ticker = null;
  let hitTimer = null;

  function tick() {
    const now = performance.now();
    let left = 0;
    for (const entry of entries) {
      const ms = Math.max(0, entry.until - now);
      entry.time.textContent = ms > 0 ? `${Math.ceil(ms / 1000)}` : '';
      if (ms > 0) left += 1;
    }
    if (!left) {
      clearInterval(ticker);
      ticker = null;
    }
  }

  /** États reçus du jeu : [{ name, ms }]. */
  function set({ list }) {
    const labels = UI.t('states');
    const now = performance.now();
    root.replaceChildren();
    entries = [];
    for (const item of Array.isArray(list) ? list : []) {
      if (!item || typeof item.name !== 'string') continue;
      const icon = UI.el('span', 'condition-icon');
      icon.style.setProperty('--icon', UI.image(`img/states/${item.name}.svg`));
      const time = UI.el('span', 'condition-time');
      const node = UI.el('div', `condition is-${item.name}`, null, [icon, time, UI.el('span', 'condition-label', labels[item.name] || '')]);
      node.style.setProperty('--tint', COLORS[item.name] || COLORS.immune);
      root.append(node);
      entries.push({ until: now + (Number(item.ms) || 0), time });
    }
    root.hidden = entries.length === 0;
    tick();
    if (entries.length && !ticker) ticker = setInterval(tick, TICK_MS);
  }

  /** Effets d'écran durables : { burn, frost }. */
  function screen({ burn: burning, frost: frozen }) {
    burn.hidden = !burning;
    frost.hidden = !frozen;
  }

  /** Éclat bref d'un coup reçu : { kind } (burn…). */
  function flash({ kind }) {
    clearTimeout(hitTimer);
    hit.className = `screen-hit is-${kind || 'burn'}`;
    hit.hidden = false;
    // la même animation repart à chaque coup
    void hit.offsetWidth;
    hit.classList.add('is-on');
    hitTimer = setTimeout(() => { hit.hidden = true; }, HIT_MS);
  }

  return { set, screen, flash };
})();
