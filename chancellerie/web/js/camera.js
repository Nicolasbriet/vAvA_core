'use strict';
/*
 * web/js/camera.js
 * Rôle : les caméras sur l'écran des joueurs, côté navigateur. `watch` ouvre une caméra (droit vérifié par le
 *        Registre), reçoit l'offre WebRTC du jeu du joueur par le flux d'évènements, répond une fois ses candidats
 *        réseau réunis, puis remet l'image (sans son) ; le mur des caméras en ouvre plusieurs à la fois. Par-dessus :
 *        la visionneuse de la fiche d'un joueur (« Regarder l'écran »), une vue en grand dans une fenêtre. Une offre
 *        arrivée avant la réponse du serveur attend sa caméra un moment.
 */

const CAMERA = (() => {
  const C = STRINGS.camera;
  const ICE_WAIT_MS = 4000;
  const EARLY_OFFER_MS = 15000;
  /** Caméras demandées ou ouvertes ; celles qui ont leur session, par session. */
  const entries = new Set();
  const watches = new Map();
  const earlyOffers = new Map();
  let refs = null;
  let viewer = null;

  function gathered(peer) {
    if (peer.iceGatheringState === 'complete') return Promise.resolve();
    return new Promise((resolve) => {
      const timer = setTimeout(resolve, ICE_WAIT_MS);
      peer.addEventListener('icegatheringstatechange', () => {
        if (peer.iceGatheringState !== 'complete') return;
        clearTimeout(timer);
        resolve();
      });
    });
  }

  /** Fin d'une caméra ; `code` nul : fermée par celui qui regarde (rien à lui expliquer). */
  function finish(watch, code, tell) {
    if (watch.closed) return;
    watch.closed = true;
    entries.delete(watch);
    if (watch.session) watches.delete(watch.session);
    if (watch.peer) watch.peer.close();
    if (tell && watch.session) API.post('/api/game/camera/stop', { session: watch.session });
    if (code !== null) watch.handlers.onEnded(code);
  }

  async function accept(watch, sdp) {
    const peer = new RTCPeerConnection({ iceServers: watch.iceServers.map((url) => ({ urls: url })) });
    watch.peer = peer;
    peer.addEventListener('track', (event) => {
      if (!watch.closed) watch.handlers.onStream(event.streams[0] || new MediaStream([event.track]));
    });
    peer.addEventListener('connectionstatechange', () => {
      if (!watch.closed && peer.connectionState === 'failed') finish(watch, 'connection_failed', true);
    });
    try {
      await peer.setRemoteDescription({ type: 'offer', sdp });
      await peer.setLocalDescription(await peer.createAnswer());
      await gathered(peer);
    } catch (error) {
      finish(watch, 'connection_failed', true);
      return;
    }
    if (watch.closed) return;
    const result = await API.post('/api/game/camera/answer', { session: watch.session, sdp: peer.localDescription.sdp });
    if (!result.ok) finish(watch, result.error, true);
  }

  /**
   * Ouvre une caméra : `quality` = tile (case d'un mur) ou full (vue en grand). `handlers` : onStream(stream),
   * onEnded(code), et facultatif onWaiting() (accordée, le jeu du joueur prépare l'image). Renvoie { close }.
   */
  function watch(target, quality, handlers) {
    const entry = { target, quality, session: null, peer: null, closed: false, iceServers: [], handlers };
    entries.add(entry);
    (async () => {
      if (typeof RTCPeerConnection !== 'function') {
        finish(entry, 'unsupported', false);
        return;
      }
      const result = await API.post('/api/game/camera/start', { target, quality });
      if (entry.closed) {
        if (result.ok) API.post('/api/game/camera/stop', { session: result.session });
        return;
      }
      if (!result.ok) {
        finish(entry, result.error, false);
        return;
      }
      entry.session = result.session;
      entry.iceServers = UI.list(result.iceServers);
      watches.set(entry.session, entry);
      if (handlers.onWaiting) handlers.onWaiting();
      const early = earlyOffers.get(entry.session);
      if (early) {
        earlyOffers.delete(entry.session);
        accept(entry, early.sdp);
      }
    })();
    return { close: () => finish(entry, null, true) };
  }

  /** Texte de la fin d'une caméra (raison du serveur, ou erreur). */
  const endedText = (code) => C.ended[code] || STRINGS.error(code);

  // Visionneuse de la fiche d'un joueur ---------------------------------------------------------------------------

  function status(text, live) {
    refs.status.textContent = text;
    refs.root.classList.toggle('is-live', Boolean(live));
  }

  function closeViewer() {
    if (viewer) viewer.close();
    viewer = null;
    refs.video.srcObject = null;
    refs.root.hidden = true;
  }

  return {
    watch,
    endedText,

    init() {
      const root = document.querySelector('.viewer');
      refs = {
        root, title: root.querySelector('.viewer-title'), status: root.querySelector('.viewer-status'),
        video: root.querySelector('.viewer-video'), note: root.querySelector('.viewer-note'), close: root.querySelector('[data-action="viewer-close"]'),
      };
      refs.note.textContent = C.privacy;
      refs.close.textContent = C.stop;
      refs.close.addEventListener('click', closeViewer);
      refs.video.addEventListener('loadeddata', () => {
        if (viewer) status(C.live, true);
      });
      document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && !refs.root.hidden) closeViewer();
      });
    },

    /** Ouvre la visionneuse sur l'écran d'un joueur (vue en grand). */
    open(target, label) {
      closeViewer();
      refs.title.textContent = C.title(label);
      refs.root.hidden = false;
      status(C.connecting, false);
      const handle = watch(target, 'full', {
        onWaiting: () => { if (viewer === handle) status(C.waiting, false); },
        onStream: (stream) => {
          if (viewer !== handle) return;
          refs.video.srcObject = stream;
          refs.video.play().catch(() => {});
        },
        onEnded: (code) => {
          if (viewer !== handle) return;
          viewer = null;
          refs.video.srcObject = null;
          status(endedText(code), false);
        },
      });
      viewer = handle;
    },

    /** La visionneuse est-elle ouverte ? (le mur lui laisse alors le clavier) */
    viewerOpen: () => Boolean(refs && !refs.root.hidden),

    /** Évènement du flux : offre du jeu du joueur, ou fin d'une caméra. */
    event(data) {
      const entry = watches.get(data.session);
      if (!entry) {
        if (typeof data.offer !== 'string') return;
        const now = Date.now();
        for (const [id, early] of earlyOffers) {
          if (now - early.at > EARLY_OFFER_MS) earlyOffers.delete(id);
        }
        earlyOffers.set(data.session, { sdp: data.offer, at: now });
        return;
      }
      if (data.ended) finish(entry, String(data.ended), false);
      else if (typeof data.offer === 'string' && !entry.peer) accept(entry, data.offer);
    },

    /** Déconnexion : toutes les caméras s'éteignent (le serveur les ferme avec le flux). */
    reset() {
      for (const entry of [...entries]) finish(entry, null, false);
      earlyOffers.clear();
      if (refs && !refs.root.hidden) closeViewer();
    },
  };
})();
