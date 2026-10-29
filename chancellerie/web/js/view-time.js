'use strict';
/*
 * web/js/view-time.js
 * Rôle : la page Ciel et heure (vava_time) : heure du royaume (qui avance dans la page), heure de Paris, décalage,
 *        date et saison, ciel courant et prochain changement. Avec le droit des outils du Registre : mettre l'heure,
 *        décaler d'une heure, figer, reprendre, rendre l'heure réelle ; imposer un ciel (et le figer), figer le ciel,
 *        le rendre au cycle. Chaque décision passe par le pont du serveur de jeu : le Registre vérifie le droit du rang
 *        et l'inscrit à son journal, vava_time revalide les valeurs. Relue après chaque décision et au prochain
 *        changement de ciel prévu ; aucune relecture en boucle.
 */

const TimeView = (() => {
  const T = STRINGS.time;
  const DAY = 86400;
  const TICK_MS = 1000;
  // relecture au changement de ciel prévu : un peu après, et jamais au-delà de deux heures
  const REFRESH_MARGIN_S = 3;
  const REFRESH_MAX_S = 7200;

  let sheet = null;
  let view = null;
  let receivedAt = 0;
  let tick = null;
  let planned = null;
  let refs = {};

  const empty = (text) => UI.el('p', 'empty', text);
  const pad = (n) => String(n).padStart(2, '0');

  /** « 22:05 » d'une seconde du jour. */
  function hhmm(seconds) {
    const s = ((Math.floor(seconds) % DAY) + DAY) % DAY;
    return `${pad(Math.floor(s / 3600))}:${pad(Math.floor((s % 3600) / 60))}`;
  }

  const elapsed = () => (Date.now() - receivedAt) / 1000;
  const kingdom = () => (view.clock.frozen ? view.clock.seconds : view.clock.seconds + elapsed());
  const real = () => view.clock.real + elapsed();
  const fact = (label, value) => UI.el('div', 'fact', null, [UI.el('dt', null, label), value]);

  function nextChange() {
    const w = view.weather;
    if (w.fading) return T.fading(w.fromLabel);
    if (w.endsIn < 0) return T.never;
    const minutes = Math.floor(Math.max(0, w.endsIn - elapsed()) / 60);
    return minutes < 1 ? T.soon : T.inMinutes(minutes);
  }

  function update() {
    if (!view || !refs.kingdom) return;
    refs.kingdom.textContent = hhmm(kingdom());
    refs.real.textContent = hhmm(real());
    refs.next.textContent = nextChange();
  }

  function stop() {
    clearInterval(tick);
    clearTimeout(planned);
    tick = null;
    planned = null;
  }

  async function refresh() {
    if (!sheet) return;
    const result = await GAME.call('time');
    if (!sheet) return;
    if (!result.ok) {
      stop();
      sheet.replaceChildren(UI.heading(T.title), empty(STRINGS.error(result.error)));
      return;
    }
    setView(result.result);
  }

  async function decide(name, args, done) {
    const result = await GAME.call(name, ...args);
    if (UI.report(result, done) && sheet) setView(result.result);
  }

  async function setTime() {
    const now = kingdom();
    const values = await UI.form({
      title: T.setTitle, text: T.setText, confirm: T.setConfirm,
      fields: [
        { name: 'hour', label: T.hours, type: 'number', min: 0, max: 23, integer: true, value: Math.floor(now / 3600) % 24 },
        { name: 'minute', label: T.minutes, type: 'number', min: 0, max: 59, integer: true, value: Math.floor((now % 3600) / 60) },
      ],
    });
    if (values) decide('timeClock', ['set', values.hour * 60 + values.minute], T.done.clock);
  }

  async function impose() {
    const values = await UI.form({
      title: T.imposeTitle, text: T.imposeText, confirm: T.imposeConfirm,
      fields: [
        {
          name: 'weather', label: T.weatherField, type: 'stamps', value: view.weather.id,
          options: UI.list(view.weathers).map((w) => ({ value: w.id, label: w.inSeason ? w.label : `${w.label} (${T.outOfSeason})` })),
        },
        { name: 'hold', label: T.holdLabel, type: 'checks', options: [{ value: 'hold', label: T.hold, help: T.holdHelp }] },
      ],
    });
    if (values) decide('timeWeather', ['impose', values.weather, values.hold.includes('hold')], T.done.impose);
  }

  function render() {
    const c = view.clock;
    const w = view.weather;
    const cal = view.calendar;
    const can = GAME.can('tools');
    refs = {
      kingdom: UI.el('dd', null, hhmm(kingdom())),
      real: UI.el('dd', null, hhmm(real())),
      next: UI.el('dd', 'fact-text', nextChange()),
    };
    const conduct = w.frozen ? T.frozenWeather : (w.forced ? T.forced : T.cycle);
    sheet.replaceChildren(...[
      UI.heading(T.title),
      UI.el('p', 'prose', T.hint),
      can ? null : UI.el('p', 'prose', T.readOnly),
      UI.el('h4', 'section-title', T.clockTitle),
      UI.el('dl', 'facts', null, [
        fact(T.kingdom, refs.kingdom),
        fact(T.real, refs.real),
        fact(T.shift, UI.el('dd', null, c.frozen ? '—' : T.shiftText(c.shift))),
        fact(T.state, UI.el('dd', 'fact-text', c.frozen ? T.frozen : T.running)),
      ]),
      can ? UI.el('div', 'page-actions', null, [
        UI.button(T.set, setTime),
        UI.button(T.back, () => decide('timeClock', ['shift', -60], T.done.clock)),
        UI.button(T.forward, () => decide('timeClock', ['shift', 60], T.done.clock)),
        c.frozen
          ? UI.button(T.resume, () => decide('timeClock', ['resume', 0], T.done.resume))
          : UI.button(T.freeze, () => decide('timeClock', ['freeze', 0], T.done.freeze)),
        UI.button(T.realTime, () => decide('timeClock', ['real', 0], T.done.real)),
      ]) : null,
      UI.el('h4', 'section-title', T.calendarTitle),
      UI.el('dl', 'facts', null, [
        fact(T.day, UI.el('dd', 'fact-text', T.dayText(cal.day))),
        fact(T.season, UI.el('dd', 'fact-text', `${cal.name} (${cal.label})`)),
        fact(T.year, UI.el('dd', 'fact-text', T.yearText(cal.year))),
      ]),
      UI.el('h4', 'section-title', T.weatherTitle),
      UI.el('dl', 'facts', null, [
        fact(T.weatherNow, UI.el('dd', 'fact-text', w.label)),
        fact(T.weatherState, UI.el('dd', 'fact-text', conduct)),
        fact(T.next, refs.next),
        fact(T.seasonFit, UI.el('dd', 'fact-text', w.inSeason ? T.inSeason : T.outOfSeason)),
      ]),
      can ? UI.el('div', 'page-actions', null, [
        UI.button(T.impose, impose, 'seal'),
        w.frozen ? null : UI.button(T.freezeWeather, () => decide('timeWeather', ['freeze'], T.done.weatherFreeze)),
        w.forced || w.frozen ? UI.button(T.release, () => decide('timeWeather', ['release'], T.done.release)) : null,
      ]) : null,
      UI.el('div', 'page-actions', null, [UI.button(T.reload, refresh, 'plain')]),
    ].filter(Boolean));
  }

  function setView(next) {
    if (!sheet || !next || typeof next !== 'object' || !next.clock || !next.weather || !next.calendar) return;
    view = next;
    receivedAt = Date.now();
    render();
    clearInterval(tick);
    tick = setInterval(update, TICK_MS);
    clearTimeout(planned);
    planned = null;
    const endsIn = Number(view.weather.endsIn);
    if (Number.isFinite(endsIn) && endsIn >= 0 && endsIn <= REFRESH_MAX_S) planned = setTimeout(refresh, (endsIn + REFRESH_MARGIN_S) * 1000);
  }

  return {
    async show(target) {
      sheet = target;
      view = null;
      sheet.replaceChildren(UI.heading(T.title), empty('…'));
      const ready = await GAME.ensure();
      if (!sheet) return;
      if (!ready.ok) {
        sheet.replaceChildren(UI.heading(T.title), empty(STRINGS.error(ready.error)));
        return;
      }
      refresh();
    },
    hide() {
      sheet = null;
      view = null;
      stop();
    },
  };
})();
