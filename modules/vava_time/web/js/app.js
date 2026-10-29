'use strict';
/*
 * web/js/app.js
 * Rôle : l'outil « Ciel et heure » : heure du royaume qui avance (calculée ici depuis la vue reçue, sans rien demander
 *        au jeu), heure de Paris et décalage, mettre l'heure, décaler, figer, reprendre, heure réelle ; date et saison ;
 *        ciel courant (imposé, figé, hors saison, prochain changement), tampons des ciels, imposer, figer, rendre au
 *        cycle. Chaque décision part au jeu, qui la fait vérifier par le serveur, et revient avec la nouvelle vue.
 *        Tout texte venu du jeu est posé avec textContent.
 */

const App = (() => {
  const S = STRINGS;
  const DAY = 86400;
  const TICK_MS = 1000;
  const SLIP_MS = 3200;
  const CLOCK_DONE = { set: S.done.clock, shift: S.done.clock, freeze: S.done.freeze, resume: S.done.resume, real: S.done.real };
  const WEATHER_DONE = { impose: S.done.impose, freeze: S.done.weatherFreeze, release: S.done.release };

  const panel = document.getElementById('sky');
  const body = panel.querySelector('.panel-body');
  const slipNode = panel.querySelector('.slip');

  let view = null;
  // instant (performance.now) où la vue est arrivée : l'heure avance à partir de là
  let receivedAt = 0;
  let tick = null;
  let busy = false;
  let slipTimer = null;
  // choix en cours dans l'outil (gardés d'une vue à l'autre)
  let selected = null;
  let hold = false;
  let draft = null;
  let refs = {};

  function el(tag, className, text, children) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    if (children) node.append(...children.filter(Boolean));
    return node;
  }

  function button(label, onClick, kind = 'ink') {
    const node = el('button', kind === 'seal' ? 'seal-button' : 'ink-button', label);
    node.type = 'button';
    node.addEventListener('click', onClick);
    return node;
  }

  function heading(text) {
    const letters = Array.from(text);
    return el('h2', 'section-title', null, [el('span', 'lettrine', letters[0]), document.createTextNode(letters.slice(1).join(''))]);
  }

  const pad = (n) => String(n).padStart(2, '0');

  /** « 22:05 » d'une seconde du jour. */
  function hhmm(seconds) {
    const s = ((Math.floor(seconds) % DAY) + DAY) % DAY;
    return `${pad(Math.floor(s / 3600))}:${pad(Math.floor((s % 3600) / 60))}`;
  }

  const elapsed = () => (performance.now() - receivedAt) / 1000;
  const kingdomSeconds = () => (view.clock.frozen ? view.clock.seconds : view.clock.seconds + elapsed());
  const realSeconds = () => view.clock.real + elapsed();

  function slip(message, isError) {
    slipNode.textContent = message;
    slipNode.classList.toggle('is-error', Boolean(isError));
    slipNode.hidden = false;
    clearTimeout(slipTimer);
    slipTimer = setTimeout(() => { slipNode.hidden = true; }, SLIP_MS);
  }

  function fact(label, value) {
    return el('div', 'fact', null, [el('dt', null, label), value]);
  }

  /** Prochain changement du ciel, d'après la vue et le temps passé depuis. */
  function weatherDetail() {
    const w = view.weather;
    if (w.fading) return S.weather.fading(w.fromLabel);
    if (w.endsIn < 0) return '';
    const minutes = Math.floor(Math.max(0, w.endsIn - elapsed()) / 60);
    return w.forced ? S.weather.endsForced(minutes) : S.weather.endsIn(minutes);
  }

  /** L'heure et le compte à rebours avancent ; rien n'est demandé au jeu. */
  function update() {
    if (!view || !refs.face) return;
    refs.face.textContent = hhmm(kingdomSeconds());
    refs.real.textContent = hhmm(realSeconds());
    refs.weatherDetail.textContent = weatherDetail();
  }

  function setBusy(value) {
    busy = value;
    for (const node of body.querySelectorAll('button')) node.disabled = value || node.dataset.off === '1';
  }

  async function decide(name, data, done) {
    if (busy) return;
    setBusy(true);
    const result = await Bridge.post(name, data);
    setBusy(false);
    if (!result.ok) {
      slip(S.error(result.error), true);
      return;
    }
    setView(result.result);
    slip(done);
  }

  const clock = (action, value) => decide('clock', { action, value }, CLOCK_DONE[action]);
  const weather = (action) => decide('weather', { action, weather: action === 'impose' ? selected : undefined, hold: action === 'impose' ? hold : undefined }, WEATHER_DONE[action]);

  function timeInput(label, value, max) {
    const input = el('input', 'field-input');
    input.type = 'number';
    input.min = '0';
    input.max = String(max);
    input.step = '1';
    input.value = pad(Number(value) || 0);
    input.setAttribute('aria-label', label);
    input.addEventListener('input', () => {
      draft = { hour: refs.hour.value, minute: refs.minute.value };
    });
    input.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') setTime();
    });
    return { node: el('label', 'field', null, [el('span', 'field-label', label), input]), input };
  }

  function setTime() {
    const hour = Number(refs.hour.value);
    const minute = Number(refs.minute.value);
    const empty = refs.hour.value.trim() === '' || refs.minute.value.trim() === '';
    if (empty || !Number.isInteger(hour) || hour < 0 || hour > 23 || !Number.isInteger(minute) || minute < 0 || minute > 59) {
      slip(S.error('invalid_value'), true);
      return;
    }
    draft = null;
    clock('set', hour * 60 + minute);
  }

  function clockSection() {
    const c = view.clock;
    const now = kingdomSeconds();
    refs.face = el('span', 'clock-face', hhmm(now));
    refs.real = el('dd', null, hhmm(realSeconds()));
    const hour = timeInput(S.clock.hours, draft ? draft.hour : Math.floor(now / 3600) % 24, 23);
    const minute = timeInput(S.clock.minutes, draft ? draft.minute : Math.floor((now % 3600) / 60), 59);
    refs.hour = hour.input;
    refs.minute = minute.input;
    return el('section', 'section', null, [
      heading(S.clock.title),
      el('div', 'clock', null, [refs.face, c.frozen ? el('span', 'tag', S.clock.frozen) : el('span', 'clock-moment', S.clock.running)]),
      el('dl', 'facts', null, [fact(S.clock.real, refs.real), fact(S.clock.shift, el('dd', null, c.frozen ? '—' : S.shift(c.shift)))]),
      el('div', 'set-time', null, [
        el('span', 'field-label', S.clock.setLabel), hour.node, el('span', 'colon', ':'), minute.node, button(S.clock.set, setTime),
      ]),
      el('div', 'buttons', null, [
        button(S.clock.back, () => clock('shift', -60)),
        button(S.clock.forward, () => clock('shift', 60)),
        c.frozen ? button(S.clock.resume, () => clock('resume', 0)) : button(S.clock.freeze, () => clock('freeze', 0)),
        button(S.clock.reset, () => clock('real', 0)),
      ]),
      el('p', 'hint', S.clock.hint),
    ]);
  }

  function calendarSection() {
    return el('section', 'section', null, [
      heading(S.calendar.title),
      el('p', 'date', view.calendar.text),
      el('p', 'hint', S.calendar.hint),
    ]);
  }

  function stamp(entry) {
    const node = el('button', `stamp${entry.id === selected ? ' is-selected' : ''}`, null, [
      el('span', 'stamp-label', entry.label),
      entry.inSeason ? null : el('span', 'stamp-note', S.weather.outOfSeason),
    ]);
    node.type = 'button';
    node.setAttribute('aria-pressed', String(entry.id === selected));
    node.addEventListener('click', () => {
      selected = entry.id;
      for (const other of refs.stamps.children) {
        const on = other === node;
        other.classList.toggle('is-selected', on);
        other.setAttribute('aria-pressed', String(on));
      }
    });
    return node;
  }

  function weatherSection() {
    const w = view.weather;
    const status = w.frozen ? S.weather.frozen : (w.forced ? S.weather.forced : S.weather.cycle);
    refs.weatherDetail = el('p', 'weather-detail', weatherDetail());
    refs.stamps = el('div', 'stamps', null, view.weathers.map(stamp));
    const holdBox = el('input');
    holdBox.type = 'checkbox';
    holdBox.checked = hold;
    holdBox.addEventListener('change', () => { hold = holdBox.checked; });
    const freeze = button(S.weather.freeze, () => weather('freeze'));
    if (w.frozen) freeze.dataset.off = '1';
    const release = button(S.weather.release, () => weather('release'));
    if (!w.forced && !w.frozen) release.dataset.off = '1';
    const section = el('section', 'section', null, [
      heading(S.weather.title),
      el('div', 'weather-now', null, [
        el('span', 'weather-name', w.label),
        el('span', w.frozen || w.forced ? 'tag' : 'tag tag-quiet', status),
        w.inSeason ? null : el('span', 'tag tag-quiet', S.weather.outOfSeason),
      ]),
      refs.weatherDetail,
      refs.stamps,
      el('label', 'choice', null, [holdBox, el('span', null, S.weather.hold)]),
      el('div', 'buttons', null, [button(S.weather.impose, () => weather('impose'), 'seal'), freeze, release]),
      el('p', 'hint', S.weather.hint),
    ]);
    return section;
  }

  function render() {
    refs = {};
    body.replaceChildren(clockSection(), calendarSection(), weatherSection());
    setBusy(busy);
  }

  function setView(next) {
    if (!next || typeof next !== 'object' || !next.clock || !next.weather) return;
    view = next;
    receivedAt = performance.now();
    if (!selected || !view.weathers.some((w) => w.id === selected)) selected = view.weather.id;
    render();
  }

  function open(next) {
    selected = null;
    hold = false;
    draft = null;
    setView(next);
    panel.hidden = false;
    clearInterval(tick);
    tick = setInterval(update, TICK_MS);
  }

  function close() {
    panel.hidden = true;
    clearInterval(tick);
    tick = null;
    view = null;
    slipNode.hidden = true;
  }

  function init() {
    panel.querySelector('.panel-title').textContent = S.title;
    const closeButton = panel.querySelector('[data-action="close"]');
    closeButton.setAttribute('aria-label', S.close);
    closeButton.addEventListener('click', () => Bridge.post('close'));
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && !panel.hidden) Bridge.post('close');
    });
    Bridge.onMessage((action, payload) => {
      if (action === 'open') open(payload.view);
      else if (action === 'state' && !panel.hidden) setView(payload.view);
      else if (action === 'close') close();
    });
    if (Bridge.inGame) Bridge.post('ready');
    else DevMock.start();
  }

  init();
  return { open, close };
})();
