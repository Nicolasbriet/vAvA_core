'use strict';
/*
 * web/js/strings.js
 * Rôle : tous les textes de l'outil « Ciel et heure » (les libellés des ciels et des saisons viennent du jeu).
 */

const STRINGS = {
  title: 'Ciel et heure',
  close: 'Fermer',
  clock: {
    title: 'Heure du royaume',
    real: 'Heure réelle',
    shift: 'Décalage',
    noShift: 'aucun',
    frozen: 'figée',
    running: 'au rythme réel',
    setLabel: 'Mettre l\'heure à',
    hours: 'heures',
    minutes: 'minutes',
    set: 'Régler',
    back: '− 1 h',
    forward: '+ 1 h',
    freeze: 'Figer l\'heure',
    resume: 'Laisser le temps reprendre',
    reset: 'Rendre l\'heure réelle',
    hint: 'L\'heure suit celle de Paris. Décalée ou réglée, elle avance ensuite au même rythme, pour tout le royaume.',
  },
  calendar: {
    title: 'Calendrier',
    hint: 'La saison oriente le ciel et pèse sur les cultures et la récolte.',
  },
  weather: {
    title: 'Ciel',
    cycle: 'au gré du cycle',
    forced: 'imposé par le Conseil',
    frozen: 'figé',
    outOfSeason: 'hors saison',
    fading: (from) => `transition depuis « ${from} »`,
    endsIn: (minutes) => (minutes < 1 ? 'change sous peu' : `change dans ${minutes} min environ`),
    endsForced: (minutes) => (minutes < 1 ? 'le cycle reprend sous peu' : `le cycle reprend dans ${minutes} min environ`),
    hold: 'le figer',
    impose: 'Imposer ce ciel',
    freeze: 'Figer le ciel',
    release: 'Rendre au cycle',
    hint: 'Le cycle suit la saison. Un ciel imposé dure le temps d\'un ciel, puis le cycle reprend, sauf s\'il est figé.',
  },
  done: {
    clock: 'L\'heure du royaume est réglée.',
    freeze: 'L\'heure est figée.',
    resume: 'Le temps reprend son cours.',
    real: 'Le royaume retrouve l\'heure réelle.',
    impose: 'Le ciel obéit.',
    weatherFreeze: 'Le ciel est figé.',
    release: 'Le ciel est rendu à son cours.',
  },
  errors: {
    forbidden: 'Ce pouvoir revient au Conseil.',
    invalid_value: 'Valeur refusée.',
    unknown_weather: 'Ce ciel n\'existe pas.',
    not_ready: 'Le ciel du royaume n\'est pas encore prêt.',
    rate_limited: 'Doucement : le ciel ne change pas si vite.',
    closed: 'L\'outil est fermé.',
  },
  error: (code) => STRINGS.errors[code] || `Refusé (${code}).`,
  shift(seconds) {
    if (!seconds) return STRINGS.clock.noShift;
    const minutes = Math.round(Math.abs(seconds) / 60);
    const sign = seconds < 0 ? '−' : '+';
    return `${sign}${Math.floor(minutes / 60)} h ${String(minutes % 60).padStart(2, '0')}`;
  },
};
