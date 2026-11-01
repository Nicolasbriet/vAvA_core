'use strict';
/*
 * web/js/hud.js
 * Rôle : jauges du HUD (création, mise à jour de la valeur, du palier et de la lueur, ordre, visibilité), notifications
 *        (empilées, retirées après leur durée ou quand elles sont trop nombreuses) et barre de progression d'une action
 *        longue (une seule : avance par une transition CSS sur la durée restante, aucune boucle par image ; fin ou
 *        interruption annoncée par le jeu). Chaque jauge garde son élément ; une mise à jour ne touche que la jauge
 *        concernée. Réglages de la bannière (vava_pause, 1.6.0) : message `settings` { scale, durationMs } (aussi dans
 *        `init.settings`) : échelle du HUD par transform (--hud-scale), durée des notifications ; valeurs bornées ici.
 *        Chiffres des coups (T-155) : `number`, `numbersMove`, `numbersClear`, rythme dans `init.numbers` ; montée
 *        par animation CSS, suivi par transition de transform, retrait à la fin de l'animation ; rien ne tourne sans
 *        chiffre à l'écran. Remontée d'une jauge (T-114) : `value` (ou `define`) avec `refill` { perSecond, delayMs } :
 *        la baisse se peint, puis une seule transition linéaire jusqu'au plein ; un seul minuteur vivant par jauge
 *        (départ, paliers franchis, plein), annulé au message suivant.
 * Dépendances : js/numbers.js (HudNumbers), js/refill.js (HudRefill), chargés avant
 */

(() => {
  const SVG = 'http://www.w3.org/2000/svg';
  const RADIUS = 21;
  const LEAVE_MS = 260;
  const PROGRESS_LEAVE_MS = 340;
  const root = document.getElementById('hud');
  const toasts = document.getElementById('toasts');
  const bar = document.getElementById('progress');
  const barLabel = bar.querySelector('.progress-label');
  const barFill = bar.querySelector('.progress-fill');
  const barHint = bar.querySelector('.progress-hint');
  const entries = new Map();
  const N = HudNumbers;
  const R = HudRefill;
  const layer = document.getElementById('numbers');
  // chiffres à l'écran, du plus ancien au plus récent : id → { node, dx, dy, timer }
  const alive = new Map();
  let numberRules = N.rules(null);
  // réglages des notifications, reçus à l'initialisation
  let toastRules = { durationMs: 4500, maxVisible: 4 };
  let barTimer = null;

  function progressReset() {
    clearTimeout(barTimer);
    barTimer = null;
    bar.classList.remove('is-shown', 'is-leaving', 'is-done', 'is-cancelled');
    bar.setAttribute('aria-hidden', 'true');
    barFill.style.transition = 'none';
    barFill.style.transform = 'scaleX(0)';
    delete bar.dataset.id;
  }

  // la barre part de l'avancée déjà faite (page rechargée en cours d'action) et file jusqu'au bout par une seule
  // transition sur la durée restante
  function progressStart({ id, label, durationMs, elapsedMs = 0, cancelable, hint }) {
    clearTimeout(barTimer);
    barTimer = null;
    const fraction = durationMs > 0 ? Math.min(1, Math.max(0, elapsedMs / durationMs)) : 1;
    bar.dataset.id = id;
    barLabel.textContent = label;
    barHint.textContent = cancelable ? hint || '' : '';
    bar.classList.remove('is-leaving', 'is-done', 'is-cancelled');
    barFill.style.transition = 'none';
    barFill.style.transform = `scaleX(${fraction})`;
    // l'état de départ doit être appliqué avant que la transition ne parte
    void barFill.offsetWidth;
    barFill.style.transition = `transform ${Math.max(0, durationMs - elapsedMs)}ms linear`;
    barFill.style.transform = 'scaleX(1)';
    bar.setAttribute('aria-valuenow', String(Math.round(fraction * 100)));
    bar.setAttribute('aria-label', label);
    bar.setAttribute('aria-hidden', 'false');
    bar.classList.add('is-shown');
  }

  function progressEnd({ id, done }) {
    if (bar.dataset.id !== id || !bar.classList.contains('is-shown')) return;
    barFill.style.transition = 'none';
    if (done) barFill.style.transform = 'scaleX(1)';
    bar.classList.add(done ? 'is-done' : 'is-cancelled', 'is-leaving');
    barTimer = setTimeout(progressReset, PROGRESS_LEAVE_MS);
  }

  function dismiss(node) {
    if (node.classList.contains('is-leaving')) return;
    node.classList.add('is-leaving');
    setTimeout(() => node.remove(), LEAVE_MS);
  }

  function notify({ message, kind }) {
    const node = document.createElement('div');
    node.className = 'toast';
    node.dataset.kind = kind || 'info';
    node.textContent = message;
    toasts.append(node);
    const shown = [...toasts.children].filter((child) => !child.classList.contains('is-leaving'));
    for (const old of shown.slice(0, Math.max(0, shown.length - toastRules.maxVisible))) dismiss(old);
    setTimeout(() => dismiss(node), toastRules.durationMs);
  }

  const level = (entry) => R.level(entry.value, entry.low, entry.critical);

  function circle(className) {
    const node = document.createElementNS(SVG, 'circle');
    node.setAttribute('class', className);
    node.setAttribute('cx', '24');
    node.setAttribute('cy', '24');
    node.setAttribute('r', String(RADIUS));
    // longueur ramenée à 100 : la valeur en pourcentage devient directement le tracé
    node.setAttribute('pathLength', '100');
    return node;
  }

  function paint(entry) {
    const percent = Math.round(entry.value * 1000) / 10;
    entry.fill.setAttribute('stroke-dasharray', `${percent} 100`);
    entry.node.dataset.level = level(entry);
    entry.node.setAttribute('aria-valuenow', String(Math.round(percent)));
  }

  function build(def) {
    const node = document.createElement('div');
    node.className = 'gauge';
    node.dataset.id = def.id;
    node.setAttribute('role', 'meter');
    node.setAttribute('aria-valuemin', '0');
    node.setAttribute('aria-valuemax', '100');
    const ring = document.createElementNS(SVG, 'svg');
    ring.setAttribute('class', 'gauge-ring');
    ring.setAttribute('viewBox', '0 0 48 48');
    ring.setAttribute('aria-hidden', 'true');
    const fill = circle('gauge-fill');
    ring.append(circle('gauge-track'), fill);
    const icon = document.createElement('img');
    icon.className = 'gauge-icon';
    icon.alt = '';
    icon.draggable = false;
    node.append(ring, icon);
    return { node, fill, icon };
  }

  function order() {
    const sorted = [...entries.values()].sort((a, b) => a.order - b.order || (a.id < b.id ? -1 : 1)).map((entry) => entry.node);
    // la plus longue suite déjà en ordre reste en place, seuls les autres sont réinsérés : sortir un nœud du document
    // couperait sa remontée (T-114)
    const placed = [...root.children];
    const keep = new Set(R.steady(sorted.map((node) => placed.indexOf(node))).map((i) => sorted[i]));
    let next = null;
    for (let i = sorted.length - 1; i >= 0; i -= 1) {
      if (!keep.has(sorted[i])) root.insertBefore(sorted[i], next);
      next = sorted[i];
    }
  }

  // Remontée (T-114) ---------------------------------------------------------------------------------------

  function refillStop(entry) {
    clearTimeout(entry.timer);
    entry.timer = null;
    if (!entry.plan) return;
    entry.plan = null;
    entry.fill.classList.remove('is-refilling');
    entry.fill.style.transition = '';
  }

  function refillNext(entry, index) {
    const plan = entry.plan;
    const step = plan.steps[index];
    entry.timer = setTimeout(() => {
      entry.value = step.value;
      entry.node.dataset.level = step.level;
      entry.node.setAttribute('aria-valuenow', String(Math.round(step.value * 100)));
      if (index + 1 < plan.steps.length) refillNext(entry, index + 1);
      else refillStop(entry);
    }, Math.max(0, step.at - (performance.now() - plan.t0)));
  }

  function refillStart(entry, raw) {
    const plan = R.plan(entry.value, raw, entry.low, entry.critical);
    if (!plan) return;
    entry.plan = { ...plan, t0: performance.now() };
    entry.timer = setTimeout(() => {
      entry.fill.classList.add('is-refilling');
      entry.fill.style.transition = `stroke-dasharray ${plan.durationMs}ms linear`;
      entry.fill.setAttribute('stroke-dasharray', '100 100');
      refillNext(entry, 0);
    }, plan.startMs);
  }

  function define(def) {
    let entry = entries.get(def.id);
    if (!entry) {
      entry = { id: def.id, ...build(def), timer: null, plan: null };
      entries.set(def.id, entry);
    }
    refillStop(entry);
    Object.assign(entry, { label: def.label, order: def.order, low: def.low, critical: def.critical, value: def.value });
    entry.node.classList.toggle('is-active', Boolean(def.active));
    entry.node.setAttribute('aria-label', def.label);
    if (entry.icon.getAttribute('src') !== def.icon) entry.icon.src = def.icon;
    paint(entry);
    order();
    if (def.refill) refillStart(entry, def.refill);
  }

  // réglages de la bannière : échelle de 0,5 à 2, durée d'une notification de 0,5 à 60 s ; une valeur hors bornes est
  // ignorée (la précédente reste)
  const finite = (value) => typeof value === 'number' && Number.isFinite(value);
  function settings({ scale, durationMs } = {}) {
    if (finite(scale) && scale >= 0.5 && scale <= 2) document.documentElement.style.setProperty('--hud-scale', String(scale));
    if (finite(durationMs) && durationMs >= 500 && durationMs <= 60000) toastRules.durationMs = Math.round(durationMs);
  }

  // Chiffres des coups --------------------------------------------------------------------------------------

  function numberDrop(id) {
    const entry = alive.get(id);
    if (!entry) return;
    clearTimeout(entry.timer);
    entry.node.remove();
    alive.delete(id);
  }

  function numbersClear() {
    for (const entry of alive.values()) clearTimeout(entry.timer);
    alive.clear();
    layer.replaceChildren();
  }

  function numberRhythm(raw) {
    numberRules = N.rules(raw);
    layer.style.setProperty('--number-ms', `${numberRules.durationMs}ms`);
    layer.style.setProperty('--number-rise', `${numberRules.riseVh}vh`);
    layer.style.setProperty('--number-follow', `${numberRules.followMs}ms`);
  }

  // ancre (suivie) > corps (monte, s'efface) > chiffre, mot
  function number(raw) {
    const n = N.read(raw);
    if (!n) return;
    numberDrop(n.id);
    for (const old of N.evict([...alive.keys()], numberRules.maxAlive)) numberDrop(old);
    const node = document.createElement('div');
    node.className = 'number';
    node.style.transform = N.place(n.x, n.y, n.dx, n.dy);
    const body = document.createElement('div');
    body.className = `number-body ${n.cls.join(' ')}`;
    for (const [cls, text] of [['number-text', n.text], ['number-sub', n.sub]]) {
      if (!text) continue;
      const span = document.createElement('span');
      span.className = cls;
      span.textContent = text;
      body.append(span);
    }
    node.append(body);
    body.addEventListener('animationend', () => numberDrop(n.id), { once: true });
    // secours : animations coupées (mouvement réduit)
    const timer = setTimeout(() => numberDrop(n.id), numberRules.durationMs + 250);
    alive.set(n.id, { node, dx: n.dx, dy: n.dy, timer });
    layer.append(node);
  }

  function numbersMove(raw) {
    for (const move of N.moves(raw)) {
      const entry = alive.get(move.id);
      if (!entry) continue;
      if (move.x !== null && move.y !== null) entry.node.style.transform = N.place(move.x, move.y, entry.dx, entry.dy);
      entry.node.classList.toggle('is-hidden', move.hidden);
    }
  }

  const handlers = {
    init({ position = {}, gauges = [], visible = false, notifications, progress = null, settings: tuned = null, numbers = null }) {
      if (notifications) toastRules = { durationMs: notifications.durationMs, maxVisible: notifications.maxVisible };
      numberRhythm(numbers);
      numbersClear();
      if (tuned && typeof tuned === 'object') settings(tuned);
      if (position.left) root.style.setProperty('--left', position.left);
      if (position.bottom) root.style.setProperty('--bottom', position.bottom);
      for (const entry of entries.values()) refillStop(entry);
      entries.clear();
      root.replaceChildren();
      for (const def of gauges) define(def);
      root.classList.toggle('is-visible', Boolean(visible));
      bar.classList.toggle('is-visible', Boolean(visible));
      progressReset();
      if (progress) progressStart(progress);
    },
    define,
    value({ id, value, refill }) {
      const entry = entries.get(id);
      if (!entry) return;
      refillStop(entry);
      entry.value = value;
      paint(entry);
      if (refill) refillStart(entry, refill);
    },
    active({ id, active }) {
      const entry = entries.get(id);
      if (entry) entry.node.classList.toggle('is-active', Boolean(active));
    },
    remove({ id }) {
      const entry = entries.get(id);
      if (!entry) return;
      refillStop(entry);
      entry.node.remove();
      entries.delete(id);
    },
    visible({ visible }) {
      root.classList.toggle('is-visible', Boolean(visible));
      if (!visible) numbersClear();
      // la progression continue derrière le menu pause ou un fondu : seule son opacité suit le HUD
      bar.classList.toggle('is-visible', Boolean(visible));
    },
    notify,
    progress: progressStart,
    progressEnd,
    settings,
    number,
    numbersMove,
    numbersClear,
  };

  window.addEventListener('message', (event) => {
    const data = event.data || {};
    const handler = handlers[data.action];
    if (handler) handler(data.payload || {});
  });

  // page prête : le jeu envoie l'état complet (hors jeu, l'aperçu simulé s'en charge)
  if (typeof GetParentResourceName === 'function') {
    fetch(`https://${GetParentResourceName()}/ready`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' })
      .catch(() => {});
  }
})();
