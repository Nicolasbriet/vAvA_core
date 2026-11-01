'use strict';
/*
 * web/dev/devmock.js
 * Rôle : jauges, notifications et progression simulées quand la page est ouverte dans un navigateur (hors FiveM), pour
 *        travailler le rendu sans lancer le jeu. Jamais livré (absent des `files`), jamais chargé en jeu : la ligne
 *        hors jeu de index.html ne l'insère que hors FiveM. Paramètres d'URL : ?values=0.8,0.62,0.08,0.5 (santé,
 *        faim, soif, voix), ?talking=1 (lueur du médaillon de la voix), ?progress=1 (barre de progression de 8 s menée
 *        à son terme) ou ?progress=cancel (interrompue à 60 %). Réglages de la bannière (1.6.0) : ?scale=90|100|115
 *        (taille de l'interface), ?notify=courte|normale|longue (durée des notifications : 0,6, 1 ou 1,6 × 4,5 s ; sans
 *        ce paramètre, les notifications simulées restent à l'écran). Chiffres des coups (T-155) : ?numbers=1|mots|plafond,
 *        &mode=tous|infliges|aucun, &cache=1 (détail au second bloc, plus bas).
 */

(() => {
  if (typeof GetParentResourceName === 'function') return;
  const icon = (resource, name) => `../../${resource}/web/icons/${name}.svg`;
  window.addEventListener('DOMContentLoaded', () => {
    document.body.classList.add('dev');
    const params = new URLSearchParams(window.location.search);
    const values = (params.get('values') || '0.8,0.62,0.24,0.5').split(',').map(Number);
    const gauge = (id, label, order, value) => {
      const [resource, name] = id.split(':');
      return { id, label, icon: icon(resource, name), order, low: 0.3, critical: 0.1, value };
    };
    window.postMessage({ action: 'init', payload: {
      position: { left: '1.5vw', bottom: '3vh' },
      gauges: [
        gauge('vava_health:health', 'Santé', 5, values[0]),
        gauge('vava_needs:hunger', 'Faim', 10, values[1]),
        gauge('vava_needs:thirst', 'Soif', 20, values[2]),
        { ...gauge('vava_voice:voice', 'Voix', 40, values[3] ?? 0.5), low: 0, critical: 0 },
      ],
      visible: true,
      notifications: { durationMs: 600000, maxVisible: 4 },
      // rythme des chiffres des coups (T-155), comme le joint client/main.lua à l'état complet (config numbers)
      numbers: { durationMs: 900, riseVh: 5, followMs: 100, maxAlive: 10, maxPerSecond: 16 },
    } }, '*');
    // réglages de la bannière, envoyés comme le ferait client/main.lua (échelle et durée déjà calculées)
    const factors = { courte: 0.6, normale: 1, longue: 1.6 };
    if (params.get('scale') || factors[params.get('notify')]) {
      window.postMessage({ action: 'settings', payload: {
        scale: (Number(params.get('scale')) || 100) / 100,
        durationMs: factors[params.get('notify')] ? 4500 * factors[params.get('notify')] : undefined,
      } }, '*');
    }
    if (params.get('talking') === '1') {
      window.postMessage({ action: 'active', payload: { id: 'vava_voice:voice', active: true } }, '*');
    }
    const progressMode = params.get('progress');
    if (progressMode) {
      const durationMs = 8000;
      window.postMessage({ action: 'progress', payload: {
        id: 'vava_gathering:chop', label: 'Vous abattez un chêne', durationMs, elapsedMs: 0,
        cancelable: true, hint: 'Peut être interrompue',
      } }, '*');
      const cancelled = progressMode === 'cancel';
      setTimeout(() => window.postMessage({ action: 'progressEnd', payload: { id: 'vava_gathering:chop', done: !cancelled } }, '*'),
        cancelled ? durationMs * 0.6 : durationMs);
    }
    const samples = [
      ['Vous avez la gorge sèche.', 'info'],
      ['La faim vous affaiblit : vous ne tenez plus la course.', 'warning'],
      ['Personne n\'est à terre près de vous.', 'danger'],
    ];
    samples.forEach(([message, kind], i) => window.postMessage({ action: 'notify', payload: { id: i + 1, message, kind } }, '*'));
  });
})();

/*
 * Chiffres des coups (T-155), simulés comme les enverrait client/numbers.lua (texte et mot déjà composés, cascade déjà
 * calculée) : ?numbers=1 une rafale (12, 7 « Bloqué », « Paré », 22 « Chancelle », 18 « À terre », un coup reçu, trois
 * petits 3 de brûlure) ; ?numbers=mots les autres issues (« Esquivé », « Absorbé », « Garde brisée », « Bloqué » seul,
 * « Sans effet », un reçu « À terre ») ; ?numbers=plafond vingt coups en 0,4 s (la page en garde 10 à l'écran ; le
 * débit de 16 par seconde est celui du Lua, non imité). &mode=tous|infliges|aucun : réglage « Chiffres des coups »
 * de la bannière (le filtre est en Lua ; il est imité ici). &cache=1 : la cible passe un instant hors de l'écran (chiffres masqués, puis revenus). La cible
 * (point de laiton) glisse : un `numbersMove` part toutes les 100 ms tant qu'un chiffre vit, comme la boucle de suivi
 * du Lua, et s'arrête ensuite. Un clic ou la touche N rejoue la rafale. &figer=300 : chiffres arrêtés à 300 ms de leur
 * vie (captures d'écran).
 */
(() => {
  if (typeof GetParentResourceName === 'function') return;
  const params = new URLSearchParams(window.location.search);
  const kind = params.get('numbers');
  if (!kind) return;
  const mode = ['tous', 'infliges', 'aucun'].includes(params.get('mode')) ? params.get('mode') : 'tous';
  const post = (action, payload) => window.postMessage({ action, payload }, '*');
  // valeurs de config_client.lua (numbers) : rythme (envoyé dans `init.numbers` par le premier bloc), cascade
  const cfg = { durationMs: 900, followMs: 100,
    stackMs: 350, stackMax: 4, stackStepVh: 2.6, stackStepVw: 1.2, jitterVw: 0.6 };
  const self = { x: 0.5, y: 0.47 };
  const bursts = {
    1: [['dealt', '12', null, 'dealt'], ['dealt', '7', 'Bloqué', 'dealt'], ['dealt', 'Paré', null, 'dealt word'],
      ['dealt', '22', 'Chancelle', 'dealt big'], ['dealt', '18', 'À terre', 'dealt huge'], ['taken', '9', null, 'taken'],
      ['dealt', '3', null, 'dealt small'], ['dealt', '3', null, 'dealt small'], ['dealt', '3', null, 'dealt small']],
    mots: [['dealt', 'Esquivé', null, 'dealt word'], ['dealt', 'Absorbé', null, 'dealt word'],
      ['dealt', '4', 'Garde brisée', 'dealt'], ['dealt', 'Bloqué', null, 'dealt word'], ['dealt', 'Sans effet', null, 'dealt word'],
      ['taken', 'Paré', null, 'taken word'], ['taken', '14', 'À terre', 'taken huge']],
    plafond: Array.from({ length: 20 }, (_, i) => ['dealt', String(8 + (i % 5)), null, 'dealt']),
  };
  const list = bursts[kind] || bursts[1];
  const spacing = kind === 'plafond' ? 20 : 260;

  let marker = null;
  let target = { x: 0.5, y: 0.38 };
  let started = 0;
  const alive = new Map();   // id → { side, endsAt }
  let loop = null;
  let nextId = 0;
  const lastBySide = {};

  function markerAt(pos) {
    if (!marker) {
      marker = document.createElement('div');
      Object.assign(marker.style, { position: 'fixed', left: '0', top: '0', width: '14px', height: '14px', margin: '-7px 0 0 -7px',
        borderRadius: '50%', background: '#dcc08a', boxShadow: '0 0 0 2px #070504', transition: 'transform 100ms linear', zIndex: '0' });
      document.body.append(marker);
    }
    marker.style.transform = `translate3d(${pos.x * 100}vw, ${pos.y * 100}vh, 0)`;
  }

  function targetAt(now) {
    const t = (now - started) / 1000;
    return { x: 0.5 + 0.12 * Math.sin(t * 1.6), y: 0.38 + 0.02 * Math.cos(t * 2.1) };
  }

  // cascade comme numbers.stack du Lua : un coup qui suit le précédent de moins de stackMs monte d'un cran, côté alterné
  function stack(side, now) {
    const last = lastBySide[side];
    const step = last && now - last.at < cfg.stackMs ? (last.step + 1) % cfg.stackMax : 0;
    lastBySide[side] = { at: now, step };
    const sign = step % 2 === 1 ? -1 : 1;
    return { dx: step === 0 ? 0 : sign * cfg.stackStepVw * Math.ceil(step / 2) + (Math.random() * 2 - 1) * cfg.jitterVw,
      dy: -step * cfg.stackStepVh };
  }

  function follow() {
    const now = performance.now();
    for (const [id, entry] of alive) if (entry.endsAt <= now) alive.delete(id);
    if (alive.size === 0) {
      clearInterval(loop);
      loop = null;
      return;
    }
    target = targetAt(now);
    markerAt(target);
    const hidden = params.get('cache') === '1' && (now - started) % 1600 > 900 && (now - started) % 1600 < 1200;
    const moves = [];
    for (const [id, entry] of alive) {
      if (entry.side === 'taken') continue;   // sa propre tête : immobile ici
      moves.push(hidden ? { id, hidden: true } : { id, x: target.x, y: target.y });
    }
    if (moves.length > 0) post('numbersMove', { list: moves });
  }

  function hit([side, text, sub, cls]) {
    if (mode === 'aucun' || (mode === 'infliges' && side === 'taken')) {
      console.info('[devmock] chiffre filtré par le réglage', mode, side, text);
      return;
    }
    const now = performance.now();
    const pos = side === 'taken' ? self : target;
    const id = ++nextId;
    post('number', { id, x: pos.x, y: pos.y, ...stack(side, now), text, ...(sub ? { sub } : {}), cls });
    alive.set(id, { side, endsAt: now + cfg.durationMs });
    if (!loop) loop = setInterval(follow, cfg.followMs);
  }

  function burst() {
    if (!started) started = performance.now();
    list.forEach((entry, i) => setTimeout(() => hit(entry), i * spacing));
  }

  window.addEventListener('DOMContentLoaded', () => {
    // &figer=300 : chaque chiffre arrêté à 300 ms de sa vie (captures d'écran ; il part quand même à la fin de sa vie)
    const frozen = Number(params.get('figer'));
    if (Number.isFinite(frozen) && frozen > 0) {
      const style = document.createElement('style');
      style.textContent = `.number-body { animation-delay: -${Math.round(frozen)}ms !important; animation-play-state: paused !important; }`;
      document.head.append(style);
    }
    // l'`init` du premier bloc porte déjà le rythme des chiffres (init.numbers)
    started = performance.now();
    markerAt(targetAt(started));
    setTimeout(burst, 300);
    document.addEventListener('click', burst);
    document.addEventListener('keydown', (event) => { if (event.key === 'n' || event.key === 'N') burst(); });
  });
})();
