'use strict';
/*
 * web/js/devmock.js
 * Rôle : aperçu de l'outil dans un navigateur, sans le jeu : fond de ciel, état d'exemple, décisions simulées (même
 *        sens que le serveur : mettre l'heure, décaler, figer, reprendre, heure réelle ; imposer, figer, rendre le ciel).
 *        Inactif en jeu. Paramètres d'URL : ?frozen=1 (heure figée), ?forced=1 (ciel imposé et figé), ?struck=1 (gel tombé),
 *        ?refused=1 (chaque décision refusée).
 */

const DevMock = (() => {
  const DAY = 86400;
  const params = new URLSearchParams(location.search);
  // ciels de l'hiver (saison de l'exemple)
  const WEATHERS = [
    ['clair', 'Ciel clair', true], ['soleil', 'Grand soleil', false], ['nuages', 'Nuages épars', true],
    ['couvert', 'Ciel couvert', true], ['eclaircies', 'Éclaircies', false], ['pluie', 'Pluie', true], ['orage', 'Orage', false],
    ['brume', 'Brume', false], ['brouillard', 'Brouillard', true], ['neige_legere', 'Neige légère', true],
    ['neige', 'Neige', true], ['tempete', 'Tempête de neige', true], ['neige_au_sol', 'Neige au sol', false],
  ].map(([id, label, inSeason]) => ({ id, label, inSeason }));
  const labelOf = (id) => (WEATHERS.find((w) => w.id === id) || { label: id }).label;

  // heure de Paris simulée : celle du navigateur
  const realNow = () => {
    const d = new Date();
    return d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds();
  };
  const normalize = (shift) => {
    const value = ((shift % DAY) + DAY) % DAY;
    return value >= DAY / 2 ? value - DAY : value;
  };

  const state = {
    shift: 3 * 3600,
    frozen: params.get('frozen') ? 22 * 3600 + 15 * 60 : false,
    weather: params.get('forced') ? 'orage' : 'pluie',
    from: 'couvert',
    forced: Boolean(params.get('forced')),
    weatherFrozen: Boolean(params.get('forced')),
    endsAt: Date.now() + 23 * 60000,
  };

  function view() {
    const real = realNow();
    const seconds = state.frozen !== false ? state.frozen : ((real + state.shift) % DAY + DAY) % DAY;
    const current = WEATHERS.find((w) => w.id === state.weather);
    return {
      clock: { seconds, real, shift: state.shift, frozen: state.frozen !== false },
      calendar: {
        season: 'hiver', label: 'hiver', name: 'saison des frimas', day: 4, year: 1, yearText: 'an 1 du royaume',
        text: '4e jour de la saison des frimas (hiver), an 1 du royaume', length: 14,
      },
      frost: { tonight: true, warned: true, struck: Boolean(params.get('struck')), warnHour: 17, hour: 21 },
      weather: {
        id: state.weather, label: current.label, from: state.from, fromLabel: labelOf(state.from), fading: false,
        forced: state.forced, frozen: state.weatherFrozen,
        endsIn: state.weatherFrozen ? -1 : Math.max(0, Math.round((state.endsAt - Date.now()) / 1000)),
        inSeason: current.inSeason,
      },
      weathers: WEATHERS,
      limits: { maxShiftMinutes: 720 },
    };
  }

  function send(action, payload) {
    window.postMessage({ action, payload }, '*');
  }

  function clock(action, value) {
    const now = view().clock.seconds;
    if (action === 'set') {
      if (state.frozen !== false) state.frozen = value * 60;
      else state.shift = normalize(value * 60 - realNow());
    } else if (action === 'shift') {
      if (state.frozen !== false) state.frozen = ((state.frozen + value * 60) % DAY + DAY) % DAY;
      else state.shift = normalize(state.shift + value * 60);
    } else if (action === 'freeze') {
      state.frozen = now;
    } else if (action === 'resume') {
      if (state.frozen !== false) state.shift = normalize(state.frozen - realNow());
      state.frozen = false;
    } else if (action === 'real') {
      state.shift = 0;
      state.frozen = false;
    }
  }

  function weather(action, id, hold) {
    if (action === 'impose') {
      state.from = state.weather;
      state.weather = id;
      state.forced = true;
      state.weatherFrozen = hold;
    } else if (action === 'freeze') {
      state.weatherFrozen = true;
    } else {
      state.from = state.weather;
      state.weather = 'nuages';
      state.forced = false;
      state.weatherFrozen = false;
    }
    state.endsAt = Date.now() + 31 * 60000;
  }

  async function handle(name, data) {
    if (name === 'close') {
      setTimeout(() => send('close', {}), 10);
      return { ok: true };
    }
    if (params.get('refused') && (name === 'clock' || name === 'weather')) return { ok: false, error: 'forbidden' };
    if (name === 'clock') clock(data.action, data.value);
    else if (name === 'weather') weather(data.action, data.weather, data.hold);
    return { ok: true, result: view() };
  }

  function start() {
    document.body.classList.add('dev');
    send('open', { view: view() });
  }

  return { handle, start };
})();
