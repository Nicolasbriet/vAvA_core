'use strict';
/*
 * web/js/threat.js
 * Rôle : frisson d'une cible verrouillée par un sort d'attaque : le bord de l'écran rougit un instant, avec un texte
 *        discret (config). Sans prendre la main du joueur ; un nouveau frisson relance l'effet.
 */

const Threat = (() => {
  const root = document.getElementById('threat');
  const text = document.getElementById('threat-text');
  let timer = null;

  function show({ ms }) {
    clearTimeout(timer);
    text.textContent = UI.t('threat').text || '';
    root.hidden = true;
    // relance de l'animation au rendu suivant
    void root.offsetWidth;
    root.style.setProperty('--threat-ms', `${Math.max(500, Number(ms) || 0)}ms`);
    root.hidden = false;
    timer = setTimeout(() => { root.hidden = true; }, Math.max(500, Number(ms) || 0));
  }

  return { show };
})();
