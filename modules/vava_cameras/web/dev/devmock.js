'use strict';
/*
 * web/dev/devmock.js
 * Rôle : jeu et serveur simulés quand la page est ouverte dans un navigateur (hors FiveM), pour travailler le rendu
 *        sans lancer le jeu. Chaque caméra demandée est une vraie connexion WebRTC locale, filmant une scène dessinée
 *        (le mur est éprouvé de bout en bout). Inactif en jeu. Paramètres d'URL : ?players=N (joueurs simulés,
 *        11 par défaut), &layout=1..4, &focus=<numéro>, &closed=1 (mur fermé), &budget=<numéro> (vue en grand de
 *        ce joueur refusée : déjà regardé en grand ailleurs).
 *        Jamais livré (absent des `files`), jamais chargé en jeu : la ligne hors jeu de index.html ne l'insère
 *        que hors FiveM.
 */

const DevMock = (() => {
  const inGame = typeof GetParentResourceName === 'function';
  const params = new URLSearchParams(window.location.search);
  const NAMES = [
    'Aldric Morvan', 'Éloïse d\'Aubigné', 'Bertrand Dugarry', 'Corwin le Roux', 'Isolde Varenne', 'Gaspard Fol',
    'Mathilde de Brocéliande', 'Thibaut Lancelin', 'Ysolde Kermarec', 'Hugues de Montfort', 'Perrine la Rousse',
    'Anselme Gaudin', 'Bérangère Clairval', 'Enguerrand Lestrange', 'Aliénor Duprat', 'Guérin Malbec',
    'Sibylle d\'Arcis', 'Roland Vaubert', 'Clémence Hautval', 'Évrard Tessier',
  ];
  const count = Math.min(Number(params.get('players')) || 11, NAMES.length);
  const players = NAMES.slice(0, count).map((label, i) => ({ source: i + 2, label, active: i !== 4 }));
  const fakes = new Map();
  let serial = 0;

  /** Scène filmée d'un joueur simulé : ciel, collines, soleil qui tourne. */
  function scene(player) {
    const canvas = document.createElement('canvas');
    canvas.width = 480;
    canvas.height = 270;
    const ctx = canvas.getContext('2d');
    const hue = (player.source * 47) % 360;
    let t = player.source * 10;
    const timer = setInterval(() => {
      t += 1;
      const sky = ctx.createLinearGradient(0, 0, 0, 270);
      sky.addColorStop(0, `hsl(${hue}, 35%, 42%)`);
      sky.addColorStop(1, `hsl(${(hue + 30) % 360}, 45%, 72%)`);
      ctx.fillStyle = sky;
      ctx.fillRect(0, 0, 480, 270);
      ctx.fillStyle = 'rgba(255, 236, 190, 0.85)';
      ctx.beginPath();
      ctx.arc(240 + Math.cos(t / 30) * 160, 90 + Math.sin(t / 30) * 30, 22, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = `hsl(${(hue + 90) % 360}, 25%, 24%)`;
      ctx.beginPath();
      ctx.moveTo(0, 270);
      for (let x = 0; x <= 480; x += 20) ctx.lineTo(x, 190 + Math.sin((x + t) / 45) * 18);
      ctx.lineTo(480, 270);
      ctx.fill();
    }, 100);
    return { stream: canvas.captureStream(10), stop: () => clearInterval(timer) };
  }

  /** Joueur filmé simulé : offre WebRTC envoyée au mur comme si elle venait du serveur. */
  async function film(session, source) {
    const player = players.find((p) => p.source === source);
    const { stream, stop } = scene(player);
    const peer = new RTCPeerConnection();
    fakes.set(session, { peer, stop });
    stream.getTracks().forEach((track) => peer.addTrack(track, stream));
    await peer.setLocalDescription(await peer.createOffer());
    await new Promise((resolve) => {
      if (peer.iceGatheringState === 'complete') resolve();
      peer.addEventListener('icegatheringstatechange', () => peer.iceGatheringState === 'complete' && resolve());
      setTimeout(resolve, 2000);
    });
    window.postMessage({ action: 'wall:offer', payload: { session, sdp: peer.localDescription.sdp } }, '*');
  }

  function forget(session) {
    const fake = fakes.get(session);
    if (!fake) return;
    fakes.delete(session);
    fake.stop();
    fake.peer.close();
  }

  const handlers = {
    'wall:watch': ({ target, quality }) => {
      const player = players.find((p) => p.source === target);
      if (!player) return { ok: false, error: 'not_found' };
      if (!player.active) return { ok: false, error: 'not_playing' };
      // &budget=<numéro> : ce joueur est déjà regardé en grand par un autre membre
      if (quality === 'full' && Number(params.get('budget')) === target) return { ok: false, error: 'budget' };
      serial += 1;
      const session = serial.toString(16).padStart(24, '0');
      setTimeout(() => film(session, target), 80);
      return { ok: true, result: { session, label: player.label, quality } };
    },
    'wall:answer': ({ session, sdp }) => {
      const fake = fakes.get(session);
      if (fake) fake.peer.setRemoteDescription({ type: 'answer', sdp }).catch(() => {});
      return { ok: true };
    },
    'wall:close': ({ session }) => {
      forget(session);
      return { ok: true };
    },
    'wall:exit': () => {
      [...fakes.keys()].forEach(forget);
      return { ok: true };
    },
  };

  async function handle(name, data) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    const handler = handlers[name];
    return handler ? handler(data) : { ok: true };
  }

  if (!inGame) {
    document.body.classList.add('dev');
    window.addEventListener('load', () => {
      if (params.get('closed') === '1') return;
      const layout = Number(params.get('layout')) || 3;
      window.postMessage({
        action: 'wall:open',
        payload: { players, layouts: [1, 2, 3, 4], defaultLayout: layout, iceServers: [], staggerMs: 150 },
      }, '*');
      const focus = Number(params.get('focus'));
      if (focus) setTimeout(() => document.querySelector(`.screen[data-source="${focus}"]`)?.click(), 300);
    });
  }

  return { handle, players, sessions: () => fakes.size };
})();
