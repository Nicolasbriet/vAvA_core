'use strict';
/*
 * web/js/hud.js
 * Rôle : barre de mana (bas de l'écran) avec le sort prêt dans les mains (sceau à l'icône de l'élément, nom, niveau
 *        en chiffres romains) ; réticule de visée au centre de l'écran, aux couleurs de l'élément, grisé hors de
 *        portée. La barre anime seule la remontée de la mana d'après le rythme reçu du jeu (aucun envoi périodique)
 *        et ne se montre que si la mana n'est pas pleine, en mode magie éveillé, ou juste après un sort. Mot bref
 *        d'une combinaison réussie (« Vapeur ! ») au-dessus de la barre, qui monte, luit et s'efface.
 */

const Hud = (() => {
  const root = document.getElementById('hud');
  const seal = document.getElementById('hud-seal');
  const icon = document.getElementById('hud-icon');
  const label = document.getElementById('hud-label');
  const level = document.getElementById('hud-level');
  const fill = document.getElementById('hud-fill');
  const reticleRoot = document.getElementById('reticle');
  const comboNode = document.getElementById('hud-combo');
  // rafraîchissement de la barre tant qu'elle remonte, et délai de son effacement
  const TICK_MS = 250;
  const FADE_MS = 600;
  // durée du mot d'une combinaison
  const COMBO_MS = 1800;

  let pool = null;
  let awake = false;
  let lingerUntil = 0;
  let enabled = false;
  let ticker = null;
  let hideTimer = null;
  let comboTimer = null;

  /** Mana prédite maintenant, d'après le dernier envoi du jeu. */
  function current() {
    if (!pool) return { value: 0, max: 1 };
    if (pool.value >= pool.max) return { value: pool.max, max: pool.max };
    const periods = Math.floor((performance.now() - pool.base) / pool.period);
    return { value: Math.min(pool.max, pool.value + periods * pool.points), max: pool.max };
  }

  function wanted() {
    if (!enabled || !pool) return false;
    const { value, max } = current();
    return value < max || awake || performance.now() < lingerUntil;
  }

  function show() {
    clearTimeout(hideTimer);
    root.classList.remove('is-leaving');
    root.hidden = false;
  }

  function hide() {
    if (root.hidden || root.classList.contains('is-leaving')) return;
    root.classList.add('is-leaving');
    hideTimer = setTimeout(() => {
      root.hidden = true;
      root.classList.remove('is-leaving');
    }, FADE_MS);
  }

  function draw() {
    const { value, max } = current();
    fill.style.transform = `scaleX(${max > 0 ? Math.max(0, Math.min(1, value / max)) : 0})`;
    root.classList.toggle('is-low', value / max < 0.25);
    if (wanted()) show(); else hide();
    // la boucle ne tourne que tant qu'il y a quelque chose à animer ou à effacer
    if (!wanted() && ticker) {
      clearInterval(ticker);
      ticker = null;
    }
  }

  function wake() {
    draw();
    if (!ticker && wanted()) ticker = setInterval(draw, TICK_MS);
  }

  function setMana({ value, max, points, period, elapsed }) {
    enabled = true;
    pool = { value, max, points, period: Math.max(1, period), base: performance.now() - (elapsed || 0) };
    wake();
  }

  function setSpell(spell) {
    if (!spell || !spell.name) {
      root.classList.add('is-empty');
      label.textContent = '';
      level.textContent = '';
      icon.style.removeProperty('--icon');
      return;
    }
    root.classList.remove('is-empty');
    label.textContent = spell.label;
    level.textContent = UI.roman(spell.level);
    icon.style.setProperty('--icon', UI.image(`img/spells/${spell.icon}.svg`));
    const color = spell.color || { r: 220, g: 192, b: 138 };
    root.style.setProperty('--element', `rgb(${color.r}, ${color.g}, ${color.b})`);
    root.style.setProperty('--element-rgb', `${color.r}, ${color.g}, ${color.b}`);
  }

  function setMode({ awake: value }) {
    awake = value === true;
    seal.classList.toggle('is-awake', awake);
    wake();
  }

  function flash({ ms }) {
    lingerUntil = performance.now() + (Number(ms) || 0);
    wake();
    setTimeout(wake, (Number(ms) || 0) + TICK_MS);
  }

  /** Combinaison réussie : { label } ; la barre se montre le temps du mot. */
  function combo({ label }) {
    comboNode.textContent = String(label || '');
    clearTimeout(comboTimer);
    comboNode.hidden = false;
    // la même animation repart à chaque combinaison
    comboNode.classList.remove('is-on');
    void comboNode.offsetWidth;
    comboNode.classList.add('is-on');
    flash({ ms: COMBO_MS + FADE_MS });
    comboTimer = setTimeout(() => { comboNode.hidden = true; }, COMBO_MS);
  }

  function casting({ active }) {
    root.classList.toggle('is-casting', active === true);
  }

  function disable() {
    enabled = false;
    pool = null;
    awake = false;
    if (ticker) clearInterval(ticker);
    ticker = null;
    root.hidden = true;
  }

  /** Réticule : { visible, color, out }. */
  function reticle({ visible, color, out }) {
    if (!visible) {
      reticleRoot.hidden = true;
      return;
    }
    const c = color || { r: 220, g: 192, b: 138 };
    reticleRoot.style.setProperty('--element', `rgb(${c.r}, ${c.g}, ${c.b})`);
    reticleRoot.classList.toggle('is-out', out === true);
    reticleRoot.hidden = false;
  }

  return { setMana, setSpell, setMode, flash, combo, casting, disable, reticle, current };
})();
