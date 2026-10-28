'use strict';
/*
 * web/js/ui.js
 * Rôle : outils communs aux vues : création d'éléments (texte brut uniquement, jamais de HTML venu du jeu), boutons,
 *        légendes de touches, durées et dates en français, chiffres romains.
 */

const UI = (() => {
  function el(tag, className, text, children) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    if (children) node.append(...children.filter(Boolean));
    return node;
  }

  function button(label, className, onClick) {
    const node = el('button', className, label);
    node.type = 'button';
    if (onClick) node.addEventListener('click', onClick);
    return node;
  }

  /** Touche et action : « [Échap] fermer ». */
  function hint([key, label]) {
    const node = el('span', 'hint');
    node.append(el('kbd', null, key), label);
    return node;
  }

  const ROMAN = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];
  const roman = (value) => ROMAN[value - 1] || String(value);

  /** Durée en secondes → « 3 jours », « 2 h 10 », « 42 min », « moins d'une minute ». */
  function duration(seconds) {
    const T = STRINGS.time;
    const total = Math.max(0, Math.floor(Number(seconds) || 0));
    if (total < 60) return T.lessThanMinute;
    if (total < 3600) return T.minutes(Math.floor(total / 60));
    if (total < 86400) return T.hours(Math.floor(total / 3600), Math.floor((total % 3600) / 60));
    return T.days(Math.floor(total / 86400));
  }

  /** Compte à rebours court en millisecondes → « 42 s », « 1 min 05 ». */
  function countdown(ms) {
    const T = STRINGS.time;
    const total = Math.max(0, Math.ceil((Number(ms) || 0) / 1000));
    if (total < 60) return T.seconds(total);
    return `${Math.floor(total / 60)} min ${String(total % 60).padStart(2, '0')}`;
  }

  /** « il y a 2 h », « à l'instant », à partir d'un instant serveur (secondes). */
  function ago(seconds, now) {
    const delta = now - seconds;
    if (delta < 60) return STRINGS.time.now;
    return STRINGS.time.ago(duration(delta));
  }

  /** Date en français à partir de secondes (horloge du serveur). */
  function date(seconds) {
    return new Date((Number(seconds) || 0) * 1000).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' });
  }

  /** Titre de section orné (filet et losange). */
  function section(text) {
    return el('h3', 'section-title', text);
  }

  return { el, button, hint, roman, duration, countdown, ago, date, section };
})();
