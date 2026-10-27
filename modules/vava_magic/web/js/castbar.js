'use strict';
/*
 * web/js/castbar.js
 * Rôle : barre d'incantation (bas de l'écran) : nom du sort, remplissage sur la durée de l'incantation ; brisée en
 *        rouge si elle est interrompue. Seuls l'opacité et les transformations sont animées.
 */

const Castbar = (() => {
  const root = document.getElementById('castbar');
  const label = document.getElementById('cast-label');
  const fill = document.getElementById('cast-fill');
  // temps laissé à la barre achevée ou brisée avant de disparaître
  const LINGER_MS = 700;
  let hideTimer = null;

  function reset() {
    clearTimeout(hideTimer);
    root.classList.remove('is-broken', 'is-done', 'is-leaving');
    fill.style.transition = 'none';
    fill.style.transform = 'scaleX(0)';
  }

  function start({ label: text, ms }) {
    reset();
    label.textContent = text || '';
    root.hidden = false;
    // la largeur part de zéro au rendu suivant, puis suit la durée exacte de l'incantation
    void fill.offsetWidth;
    fill.style.transition = `transform ${Math.max(0, Number(ms) || 0)}ms linear`;
    fill.style.transform = 'scaleX(1)';
  }

  function leave() {
    root.classList.add('is-leaving');
    hideTimer = setTimeout(() => { root.hidden = true; reset(); }, LINGER_MS);
  }

  function done() {
    if (root.hidden) return;
    clearTimeout(hideTimer);
    root.classList.add('is-done');
    fill.style.transition = 'none';
    fill.style.transform = 'scaleX(1)';
    leave();
  }

  function broken() {
    if (root.hidden) return;
    clearTimeout(hideTimer);
    const current = getComputedStyle(fill).transform;
    fill.style.transition = 'none';
    fill.style.transform = current === 'none' ? 'scaleX(0)' : current;
    label.textContent = UI.t('cast').interrupted || '';
    root.classList.add('is-broken');
    leave();
  }

  return { start, done, broken };
})();
