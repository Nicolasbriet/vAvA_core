'use strict';
/*
 * web/js/screen.js
 * Rôle : écran à terre (délais avant de rendre l'âme et d'être porté au lieu de soins, maintien de la touche, geste
 *        de la personne qui vous relève) et bandeau du geste pour relever quelqu'un. Les délais sont recalés à chaque
 *        mise à jour du jeu ; l'affichage n'est rafraîchi qu'une fois par seconde, et seulement à l'écran.
 */

(() => {
  const TICK_MS = 1000;
  const downed = document.getElementById('downed');
  const assist = document.getElementById('assist');
  const refs = {
    title: downed.querySelector('.downed-title'),
    subtitle: downed.querySelector('.downed-subtitle'),
    bar: downed.querySelector('.downed-bar'),
    timer: downed.querySelector('.downed-timer'),
    giveUp: downed.querySelector('.downed-giveup'),
    giveUpKey: downed.querySelector('.hold-key'),
    giveUpLabel: downed.querySelector('.downed-giveup-label'),
    hold: downed.querySelector('.hold'),
    auto: downed.querySelector('.downed-auto'),
    assistLabel: assist.querySelector('.assist-label'),
    assistBar: assist.querySelector('.bar'),
  };
  refs.title.textContent = STRINGS.title;
  refs.subtitle.textContent = STRINGS.waiting;
  refs.giveUpLabel.textContent = STRINGS.giveUp;
  refs.assistLabel.textContent = STRINGS.assisting;
  refs.giveUpKey.textContent = 'E';

  // échéances en temps de la page (performance.now)
  let giveUpAt = 0;
  let autoAt = 0;
  let timer = null;

  function paint() {
    const now = performance.now();
    const giveUpLeft = giveUpAt - now;
    refs.timer.hidden = giveUpLeft <= 0;
    refs.giveUp.hidden = giveUpLeft > 0;
    if (giveUpLeft > 0) refs.timer.textContent = STRINGS.giveUpIn(clock(giveUpLeft));
    refs.auto.textContent = STRINGS.autoIn(clock(autoAt - now));
  }

  /** Barre qui se remplit en `durationMs` (une seule transition : le compositeur s'en charge). */
  function run(bar, durationMs) {
    const fill = bar.querySelector('.bar-fill');
    fill.style.transition = 'none';
    fill.style.transform = 'scaleX(0)';
    // relecture forcée : la transition repart de zéro
    void fill.offsetWidth;
    fill.style.transition = `transform ${durationMs}ms linear`;
    fill.style.transform = 'scaleX(1)';
    bar.hidden = false;
  }

  function stop(bar) {
    bar.hidden = true;
    const fill = bar.querySelector('.bar-fill');
    fill.style.transition = 'none';
    fill.style.transform = 'scaleX(0)';
  }

  const handlers = {
    init({ giveUpKey }) {
      if (giveUpKey) refs.giveUpKey.textContent = giveUpKey;
    },
    downed({ giveUpInMs, autoInMs, giveUpKey }) {
      // touche choisie par le joueur dans ses raccourcis, relue par le jeu à chaque affichage
      if (giveUpKey) refs.giveUpKey.textContent = giveUpKey;
      const now = performance.now();
      giveUpAt = now + giveUpInMs;
      autoAt = now + autoInMs;
      downed.hidden = false;
      paint();
      if (!timer) timer = setInterval(paint, TICK_MS);
    },
    up() {
      downed.hidden = true;
      clearInterval(timer);
      timer = null;
      refs.subtitle.textContent = STRINGS.waiting;
      stop(refs.bar);
      refs.hold.classList.remove('is-holding');
    },
    channel({ role, state, durationMs }) {
      if (role === 'helper') {
        if (state === 'start') {
          assist.hidden = false;
          run(refs.assistBar, durationMs);
        } else {
          assist.hidden = true;
          stop(refs.assistBar);
        }
      } else if (role === 'patient') {
        if (state === 'start') {
          refs.subtitle.textContent = STRINGS.helped;
          run(refs.bar, durationMs);
        } else {
          refs.subtitle.textContent = STRINGS.waiting;
          stop(refs.bar);
        }
      }
    },
    hold({ active, durationMs }) {
      refs.hold.style.setProperty('--hold-ms', `${durationMs}ms`);
      refs.hold.classList.toggle('is-holding', Boolean(active));
    },
  };

  window.addEventListener('message', (event) => {
    const data = event.data || {};
    const handler = handlers[data.action];
    if (handler) handler(data.payload || {});
  });

  if (typeof GetParentResourceName === 'function') {
    fetch(`https://${GetParentResourceName()}/ready`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' })
      .catch(() => {});
  }
})();
