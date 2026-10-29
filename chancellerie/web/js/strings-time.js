'use strict';
/*
 * web/js/strings-time.js
 * Rôle : textes de la page Ciel et heure (vava_time) et de ses erreurs, ajoutés à STRINGS (strings.js, chargé avant).
 *        Les libellés des ciels et des saisons viennent du serveur de jeu.
 */

STRINGS.nav.time = 'Ciel et heure';

Object.assign(STRINGS.errors, {
  time_unavailable: 'Le ciel et l\'heure du royaume (vava_time) ne sont pas lancés.',
  invalid_value: 'Valeur refusée par le serveur de jeu.',
  unknown_weather: 'Ce ciel n\'existe pas.',
  not_ready: 'Le serveur de jeu n\'est pas encore prêt : réessayez dans un instant.',
});

STRINGS.time = {
  title: 'Ciel et heure',
  hint: 'L\'heure du royaume suit celle de Paris et la saison suit le calendrier ; le ciel change de lui-même selon la saison. Chaque décision part aussitôt à tous les joueurs et s\'inscrit au journal du Conseil.',
  readOnly: 'Ce rang lit le ciel et l\'heure ; les régler demande le droit des outils du Registre.',
  clockTitle: 'Heure du royaume',
  kingdom: 'Au royaume',
  real: 'À Paris',
  shift: 'Décalage',
  state: 'Cours',
  running: 'au rythme réel',
  frozen: 'figée',
  noShift: 'aucun',
  shiftText(seconds) {
    if (!seconds) return STRINGS.time.noShift;
    const minutes = Math.round(Math.abs(seconds) / 60);
    return `${seconds < 0 ? '−' : '+'}${Math.floor(minutes / 60)} h ${String(minutes % 60).padStart(2, '0')}`;
  },
  set: 'Mettre l\'heure…',
  setTitle: 'Mettre l\'heure du royaume',
  setText: 'Elle repart de là au rythme réel, ou reste figée si elle l\'est.',
  setConfirm: 'Régler',
  hours: 'Heures (0 à 23)',
  minutes: 'Minutes (0 à 59)',
  back: '− 1 h',
  forward: '+ 1 h',
  freeze: 'Figer l\'heure',
  resume: 'Laisser le temps reprendre',
  realTime: 'Rendre l\'heure réelle',
  calendarTitle: 'Calendrier',
  day: 'Jour',
  dayText: (day) => `${day === 1 ? '1er' : `${day}e`} jour de la saison`,
  season: 'Saison',
  year: 'An',
  yearText: (year) => `an ${year} du royaume`,
  weatherTitle: 'Ciel',
  weatherNow: 'Ciel',
  weatherState: 'Conduite',
  cycle: 'au gré du cycle',
  forced: 'imposé par le Conseil',
  frozenWeather: 'figé',
  next: 'Prochain changement',
  fading: (from) => `transition depuis « ${from} »`,
  never: 'aucun (figé)',
  soon: 'sous peu',
  inMinutes: (minutes) => `dans ${minutes} min environ`,
  seasonFit: 'Saison',
  inSeason: 'de saison',
  outOfSeason: 'hors saison',
  impose: 'Imposer un ciel…',
  imposeTitle: 'Imposer un ciel',
  imposeText: 'Le ciel change en une vingtaine de secondes. Imposé, il dure le temps d\'un ciel puis le cycle reprend, sauf s\'il est figé.',
  imposeConfirm: 'Imposer',
  weatherField: 'Ciel',
  holdLabel: 'Durée',
  hold: 'Le figer',
  holdHelp: 'Il reste jusqu\'à ce que le Conseil rende le ciel au cycle.',
  freezeWeather: 'Figer le ciel',
  release: 'Rendre au cycle',
  reload: 'Relire',
  done: {
    clock: 'L\'heure du royaume est réglée.',
    freeze: 'L\'heure est figée.',
    resume: 'Le temps reprend son cours.',
    real: 'Le royaume retrouve l\'heure réelle.',
    impose: 'Le ciel obéit.',
    weatherFreeze: 'Le ciel est figé.',
    release: 'Le ciel est rendu à son cours.',
  },
};
