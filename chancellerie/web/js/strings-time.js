'use strict';
/*
 * web/js/strings-time.js
 * Rôle : textes de la page Ciel et heure (vava_time) et de ses erreurs, ajoutés à STRINGS (strings.js, chargé avant).
 *        Les libellés des ciels et des saisons, et l'an du royaume, viennent du serveur de jeu.
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
  hint: 'L\'heure du royaume suit celle de Paris ; les saisons se succèdent plus vite que l\'année réelle, et le ciel suit son cours au fil de la saison. Chaque décision part aussitôt à tous les joueurs et s\'inscrit au journal du Conseil.',
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
  length: 'Durée',
  lengthText: (days) => `chaque saison dure ${days} jours`,
  frostLabel: 'Nuit',
  frostNone: 'pas de gel annoncé',
  frostTonight: (hour) => `nuit de gel : le froid tombera à ${hour} h`,
  frostStruck: 'le gel est tombé cette nuit',
  weatherTitle: 'Ciel',
  weatherNow: 'Ciel',
  weatherState: 'État',
  cycle: 'suit son cours',
  forced: 'imposé par le Conseil',
  frozenWeather: 'figé',
  next: 'Prochain changement',
  fading: (from) => `le ciel quitte « ${from} »`,
  never: 'aucun (figé)',
  soon: 'sous peu',
  inMinutes: (minutes) => `dans ${minutes} min environ`,
  seasonFit: 'Saison',
  inSeason: 'de saison',
  outOfSeason: 'hors saison',
  impose: 'Imposer un ciel…',
  imposeTitle: 'Imposer un ciel',
  imposeText: 'Le ciel change en une vingtaine de secondes. Imposé, il tient le temps d\'un ciel puis reprend son cours, sauf s\'il est figé.',
  imposeConfirm: 'Imposer',
  weatherField: 'Ciel',
  holdLabel: 'Durée',
  hold: 'Le figer',
  holdHelp: 'Il reste jusqu\'à ce que le Conseil rende le ciel à son cours.',
  freezeWeather: 'Figer le ciel',
  release: 'Rendre à son cours',
  reload: 'Relire',
  done: {
    clock: 'L\'heure du royaume est réglée.',
    freeze: 'L\'heure est figée.',
    resume: 'Le temps reprend son cours.',
    real: 'Le royaume retrouve l\'heure réelle.',
    impose: 'Le ciel obéit.',
    weatherFreeze: 'Le ciel est figé.',
    release: 'Le ciel reprend son cours.',
  },
};
