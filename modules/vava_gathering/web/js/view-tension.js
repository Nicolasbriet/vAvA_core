'use strict';
/*
 * web/js/view-tension.js
 * Rôle : la barre de tension de la pêche. Une aiguille (0 à 1) monte quand la touche est tenue (`pull`/s) et descend
 *        relâchée (`gravity`/s) ; une zone [zoneMin, zoneMax] dérive au hasard (±`drift`/s, bornée) ; pendant
 *        `durationMs`, la part du temps passée dans la zone est mesurée, puis déclarée au jeu (tensionDone). Seule
 *        animation par image du module, et seulement tant que la barre est visible. Les appuis viennent du jeu
 *        (messages tensionHold) : la touche reste celle que le joueur a choisie.
 */

const TensionView = (() => {
  const RESULT_MS = 1100;
  const DRIFT_RETARGET_MS = 600;
  const START_NEEDLE = 0.2;
  const ZONE_LOW = 0.05;
  const ZONE_HIGH = 0.95;
  const root = document.getElementById('tension');
  const refs = {
    title: root.querySelector('.tension-title'),
    timer: root.querySelector('.tension-timer'),
    zone: root.querySelector('.tension-zone'),
    needle: root.querySelector('.tension-needle'),
    timeFill: root.querySelector('.tension-time-fill'),
    hint: root.querySelector('.tension-hint'),
    result: root.querySelector('.tension-result'),
  };
  let game = null;
  let frame = 0;
  let resultTimer = null;

  function paint() {
    const { needle, zoneMin, zoneMax, elapsed, duration } = game;
    refs.needle.style.transform = `translateX(${(needle * 100).toFixed(2)}%)`;
    refs.zone.style.left = `${(zoneMin * 100).toFixed(2)}%`;
    refs.zone.style.width = `${((zoneMax - zoneMin) * 100).toFixed(2)}%`;
    const inZone = needle >= zoneMin && needle <= zoneMax;
    root.classList.toggle('is-in-zone', inZone);
    const left = Math.max(0, duration - elapsed);
    refs.timeFill.style.transform = `scaleX(${(left / duration).toFixed(4)})`;
    refs.timer.textContent = STRINGS.tension.seconds(Math.ceil(left / 1000));
  }

  function tick(now) {
    if (!game) return;
    const dt = Math.min(0.1, (now - game.last) / 1000);
    game.last = now;
    game.elapsed = now - game.startedAt;
    const T = game.tension;
    // aiguille : tenue → monte, relâchée → descend
    game.needle = UI.clamp(game.needle + (game.held ? T.pull : -T.gravity) * dt, 0, 1);
    // zone : dérive vers une cible retirée au hasard toutes les DRIFT_RETARGET_MS
    if (now >= game.retargetAt) {
      game.velocity = (Math.random() * 2 - 1) * T.drift;
      game.retargetAt = now + DRIFT_RETARGET_MS;
    }
    const width = game.zoneMax - game.zoneMin;
    let zoneMin = game.zoneMin + game.velocity * dt;
    if (zoneMin < ZONE_LOW) { zoneMin = ZONE_LOW; game.velocity = Math.abs(game.velocity); }
    if (zoneMin + width > ZONE_HIGH) { zoneMin = ZONE_HIGH - width; game.velocity = -Math.abs(game.velocity); }
    game.zoneMin = zoneMin;
    game.zoneMax = zoneMin + width;
    if (game.needle >= game.zoneMin && game.needle <= game.zoneMax) game.inZoneMs += dt * 1000;
    paint();
    if (game.elapsed >= game.duration) {
      finish();
      return;
    }
    frame = requestAnimationFrame(tick);
  }

  function finish() {
    const done = game;
    game = null;
    cancelAnimationFrame(frame);
    const ratio = Math.min(1, done.inZoneMs / done.duration);
    const success = ratio >= done.tension.holdRatio;
    refs.result.textContent = success ? STRINGS.tension.success : STRINGS.tension.failure;
    refs.result.hidden = false;
    root.classList.toggle('is-success', success);
    root.classList.toggle('is-failure', !success);
    Bridge.post('tensionDone', { token: done.token, ratio });
    clearTimeout(resultTimer);
    resultTimer = setTimeout(hide, RESULT_MS);
  }

  /** Démarre la barre : { token, tension = { durationMs, zoneMin, zoneMax, drift, pull, gravity, holdRatio }, key }. */
  function start(payload) {
    const T = payload.tension || {};
    const tension = {
      durationMs: Number(T.durationMs) || 6000, zoneMin: Number(T.zoneMin) || 0.35, zoneMax: Number(T.zoneMax) || 0.65,
      drift: Number(T.drift) || 0.12, pull: Number(T.pull) || 0.9, gravity: Number(T.gravity) || 0.7, holdRatio: Number(T.holdRatio) || 0.6,
    };
    clearTimeout(resultTimer);
    cancelAnimationFrame(frame);
    const now = performance.now();
    game = {
      token: payload.token, tension, duration: tension.durationMs, startedAt: now, last: now, elapsed: 0,
      needle: START_NEEDLE, zoneMin: tension.zoneMin, zoneMax: tension.zoneMax, velocity: 0, retargetAt: now,
      held: false, inZoneMs: 0,
    };
    refs.title.textContent = STRINGS.tension.title;
    refs.hint.textContent = STRINGS.tension.hint(payload.key || 'E');
    refs.result.hidden = true;
    root.classList.remove('is-success', 'is-failure');
    root.hidden = false;
    paint();
    frame = requestAnimationFrame(tick);
  }

  /** Appui ou relâchement de la touche (envoyé par le jeu). */
  function hold(held) {
    if (game) game.held = Boolean(held);
  }

  function hide() {
    clearTimeout(resultTimer);
    cancelAnimationFrame(frame);
    game = null;
    root.hidden = true;
  }

  return { start, hold, hide, isActive: () => game !== null };
})();
