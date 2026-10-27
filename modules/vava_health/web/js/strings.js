'use strict';
/*
 * web/js/strings.js
 * Rôle : textes de l'écran à terre et du geste pour relever (français).
 */

const STRINGS = Object.freeze({
  title: 'Vous êtes à terre',
  waiting: 'Quelqu\'un peut vous relever.',
  helped: 'Quelqu\'un vous relève…',
  giveUpIn: (time) => `Vous pourrez rendre l'âme dans ${time}`,
  giveUp: 'Maintenir pour rendre l\'âme',
  autoIn: (time) => `Porté au lieu de soins dans ${time}`,
  assisting: 'Vous relevez quelqu\'un…',
});

/** Durée en minutes et secondes : 2:05. */
function clock(ms) {
  const total = Math.max(0, Math.ceil(ms / 1000));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}
