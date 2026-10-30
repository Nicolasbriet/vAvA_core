'use strict';
/*
 * web/js/wall.js
 * Rôle : le mur des caméras en jeu. Grille des joueurs connectés (1 × 1 à 4 × 4, par pages), une case par joueur avec
 *        son image réduite ; un clic l'ouvre en grand (flèches : joueur précédent ou suivant). Seules les cases de la
 *        page affichée ont une caméra ouverte, une à la fois et en léger décalé ; en vue en grand, les cases se
 *        ferment et seule la caméra en grand reste. Une caméra perdue est retentée après un délai. Mur fermé : plus
 *        aucune connexion ni minuterie.
 */

const Wall = (() => {
  const root = document.getElementById('wall');
  const grid = root.querySelector('.grid');
  const layoutsBox = root.querySelector('.layouts');
  const pagerLabel = root.querySelector('.pager-label');
  const pagerButtons = root.querySelectorAll('[data-page]');
  const countLabel = root.querySelector('.frame-count');
  const hint = root.querySelector('.frame-hint');
  const focusBox = root.querySelector('.focus');
  const focusVideo = focusBox.querySelector('.focus-video');
  const focusStatus = focusBox.querySelector('.screen-status');
  const focusName = focusBox.querySelector('.plate-name');
  const focusNumber = focusBox.querySelector('.plate-number');
  const RETRY_MS = 10000;
  const EARLY_OFFER_MS = 15000;
  // fins sans nouvel essai : le résultat ne changerait pas
  const FINAL = new Set(['unsupported', 'forbidden', 'self', 'wall_closed']);
  const WAITING = new Set(['queued', 'opening', 'waiting', 'connecting']);

  let open = false;
  let players = [];
  let layouts = [1, 2, 3, 4];
  let layout = 3;
  let page = 0;
  let iceServers = [];
  let staggerMs = 150;
  let focused = null;

  /** Caméras ouvertes ou demandées : joueur → { source, quality, state, session, peer, code, retryAt }. */
  const cams = new Map();
  const bySession = new Map();
  // offres arrivées avant la réponse du serveur à la demande de caméra
  const earlyOffers = new Map();
  /** Cases affichées : joueur → élément. */
  const tiles = new Map();
  let queue = [];
  let queueTimer = null;
  // le serveur a fermé ce mur (droit retiré puis rendu, mur trop ancien) : plus aucune case demandée avant réouverture
  let closedByServer = false;

  // Texte et cadre ---------------------------------------------------------------------------------------------

  function element(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function label(button, text) {
    button.title = text;
    button.setAttribute('aria-label', text);
  }

  function setupFrame() {
    root.querySelector('.frame-title').textContent = STRINGS.title;
    label(root.querySelector('[data-action="exit"]'), STRINGS.close);
    label(pagerButtons[0], STRINGS.previousPage);
    label(pagerButtons[1], STRINGS.nextPage);
    label(focusBox.querySelector('[data-step="-1"]'), STRINGS.previousPlayer);
    label(focusBox.querySelector('[data-step="1"]'), STRINGS.nextPlayer);
    focusBox.querySelector('[data-action="back"]').textContent = STRINGS.back;
  }

  function renderLayouts() {
    layoutsBox.replaceChildren(...layouts.map((n) => {
      const button = element('button', 'layout-button');
      button.type = 'button';
      button.dataset.layout = String(n);
      button.style.setProperty('--n', String(n));
      button.setAttribute('aria-pressed', String(n === layout));
      label(button, STRINGS.layout(n));
      for (let i = 0; i < n * n; i += 1) button.append(element('span', 'layout-cell'));
      return button;
    }));
  }

  // Pages ------------------------------------------------------------------------------------------------------

  const perPage = () => layout * layout;
  const pageCount = () => Math.max(1, Math.ceil(players.length / perPage()));
  const visible = () => players.slice(page * perPage(), (page + 1) * perPage());
  const playerOf = (source) => players.find((player) => player.source === source);

  function statusOf(player, cam) {
    if (!player) return STRINGS.statusOf('dropped');
    if (!player.active) return STRINGS.statusOf('not_playing');
    if (!cam || WAITING.has(cam.state)) return STRINGS.connecting;
    if (cam.state === 'ended') return STRINGS.statusOf(cam.code);
    return '';
  }

  function tileOf(player) {
    let tile = tiles.get(player.source);
    if (!tile) {
      tile = element('button', 'screen');
      tile.type = 'button';
      tile.dataset.source = String(player.source);
      const video = element('video', 'screen-video');
      video.muted = true;
      video.autoplay = true;
      video.playsInline = true;
      const plate = element('span', 'plate');
      plate.append(element('span', 'plate-name'), element('span', 'plate-number'));
      tile.append(video, element('span', 'screen-status'), plate);
      tiles.set(player.source, tile);
    }
    tile.querySelector('.plate-name').textContent = player.label;
    tile.querySelector('.plate-number').textContent = STRINGS.number(player.source);
    return tile;
  }

  function paintStatus(box, text) {
    box.textContent = text;
    box.hidden = text === '';
  }

  /** États affichés (cases et vue en grand), sans rien reconstruire. */
  function paint() {
    for (const [source, tile] of tiles) {
      const cam = cams.get(source);
      const status = statusOf(playerOf(source), cam && cam.quality === 'tile' ? cam : null);
      paintStatus(tile.querySelector('.screen-status'), status);
      tile.classList.toggle('is-live', status === '');
    }
    if (focused !== null) {
      const player = playerOf(focused);
      focusName.textContent = player ? player.label : '';
      focusNumber.textContent = STRINGS.number(focused);
      paintStatus(focusStatus, statusOf(player, cams.get(focused)));
    }
  }

  function render() {
    const total = pageCount();
    if (page >= total) page = total - 1;
    countLabel.textContent = STRINGS.count(players.length);
    pagerLabel.textContent = STRINGS.page(page + 1, total);
    pagerButtons[0].disabled = page === 0;
    pagerButtons[1].disabled = page >= total - 1;
    grid.style.setProperty('--n', String(layout));
    grid.dataset.layout = String(layout);
    const shown = visible();
    const keep = new Set(shown.map((player) => player.source));
    for (const source of tiles.keys()) {
      if (!keep.has(source)) tiles.delete(source);
    }
    if (shown.length === 0) grid.replaceChildren(element('p', 'grid-empty', STRINGS.empty));
    else grid.replaceChildren(...shown.map(tileOf));
    for (const button of layoutsBox.children) button.setAttribute('aria-pressed', String(Number(button.dataset.layout) === layout));
    focusBox.hidden = focused === null;
    grid.hidden = focused !== null;
    hint.textContent = focused === null ? STRINGS.hint : STRINGS.focusHint;
    paint();
  }

  // Caméras -----------------------------------------------------------------------------------------------------

  function videoOf(cam) {
    if (cam.quality === 'full') return focusVideo;
    const tile = tiles.get(cam.source);
    return tile ? tile.querySelector('.screen-video') : null;
  }

  /** Image reçue : la case passe en direct à sa première image, pas avant. */
  function attach(cam, stream) {
    const video = videoOf(cam);
    if (!video) return;
    video.onloadeddata = () => {
      if (cams.get(cam.source) !== cam || cam.state !== 'connecting') return;
      cam.state = 'live';
      paint();
    };
    video.srcObject = stream;
    video.play().catch(() => {});
  }

  function detach(cam) {
    const video = videoOf(cam);
    if (!video) return;
    video.onloadeddata = null;
    if (video.srcObject) video.srcObject = null;
  }

  /** Ferme une caméra ; `tell` : prévenir le serveur (inutile quand c'est lui qui l'a fermée). */
  function drop(cam, tell) {
    if (cams.get(cam.source) === cam) cams.delete(cam.source);
    if (cam.session) bySession.delete(cam.session);
    if (cam.peer) cam.peer.close();
    detach(cam);
    if (tell && cam.session && cam.state !== 'ended') Bridge.post('wall:close', { session: cam.session });
    cam.state = 'dropped';
  }

  function fail(cam, code, tell) {
    if (cam.peer) cam.peer.close();
    cam.peer = null;
    detach(cam);
    if (tell && cam.session) Bridge.post('wall:close', { session: cam.session });
    if (cam.session) bySession.delete(cam.session);
    cam.session = null;
    cam.state = 'ended';
    cam.code = code;
    cam.retryAt = FINAL.has(code) ? Infinity : Date.now() + RETRY_MS;
    paint();
  }

  async function accept(cam, sdp) {
    cam.state = 'connecting';
    try {
      const { peer, sdp: answer } = await Viewer.accept(sdp, iceServers, {
        onStream: (stream) => {
          if (cams.get(cam.source) === cam) attach(cam, stream);
        },
        onFailed: () => {
          if (cams.get(cam.source) === cam) fail(cam, 'connection_failed', true);
        },
      });
      if (cams.get(cam.source) !== cam) {
        peer.close();
        return;
      }
      cam.peer = peer;
      Bridge.post('wall:answer', { session: cam.session, sdp: answer });
    } catch (error) {
      if (cams.get(cam.source) === cam) fail(cam, 'connection_failed', true);
    }
  }

  async function request(cam) {
    cam.state = 'opening';
    const response = await Bridge.post('wall:watch', { target: cam.source, quality: cam.quality });
    if (cams.get(cam.source) !== cam || !open) {
      if (response.ok) Bridge.post('wall:close', { session: response.result.session });
      return;
    }
    if (!response.ok) {
      fail(cam, response.error, false);
      if (response.error === 'wall_closed') shutByServer();
      return;
    }
    cam.session = response.result.session;
    cam.state = 'waiting';
    bySession.set(cam.session, cam);
    const early = earlyOffers.get(cam.session);
    if (early) {
      earlyOffers.delete(cam.session);
      accept(cam, early.sdp);
    }
    paint();
  }

  /** Ouvre les caméras en attente une à une, en léger décalé. */
  function pump() {
    queueTimer = null;
    while (queue.length) {
      const cam = queue.shift();
      if (cams.get(cam.source) !== cam || cam.state !== 'queued') continue;
      request(cam);
      if (queue.length) queueTimer = setTimeout(pump, staggerMs);
      return;
    }
  }

  /**
   * Premier refus `wall_closed` : la file est vidée et chaque case en attente affiche « Mur à rouvrir », au lieu
   * d'envoyer jusqu'à seize demandes vouées au même refus. Les caméras déjà ouvertes restent jusqu'à leur fin.
   */
  function shutByServer() {
    closedByServer = true;
    clearTimeout(queueTimer);
    queueTimer = null;
    const waiting = queue;
    queue = [];
    for (const cam of waiting) {
      if (cams.get(cam.source) === cam && cam.state === 'queued') fail(cam, 'wall_closed', false);
    }
    paint();
  }

  function want(source, quality) {
    const existing = cams.get(source);
    if (existing && existing.quality === quality && (existing.state !== 'ended' || Date.now() < existing.retryAt)) return;
    if (existing) drop(existing, true);
    const cam = { source, quality, state: 'queued', session: null, peer: null, code: null, retryAt: 0 };
    cams.set(source, cam);
    // mur fermé par le serveur : la case le dit sans rien demander (la vue en grand n'en dépend pas)
    if (closedByServer && quality === 'tile') {
      fail(cam, 'wall_closed', false);
      return;
    }
    queue.push(cam);
    // départ au tour suivant : toutes les cases voulues sont en file avant la première demande, qui seule part tout
    // de suite ; les suivantes attendent staggerMs chacune (et un refus wall_closed vide la file à temps)
    if (!queueTimer) queueTimer = setTimeout(pump, 0);
  }

  /** Caméras alignées sur ce qui est affiché : la page (cases) ou le joueur en grand. */
  function sync() {
    const desired = new Map();
    if (focused !== null) {
      const player = playerOf(focused);
      if (player && player.active) desired.set(focused, 'full');
    } else {
      for (const player of visible()) {
        if (player.active) desired.set(player.source, 'tile');
      }
    }
    for (const cam of [...cams.values()]) {
      if (desired.get(cam.source) !== cam.quality) drop(cam, true);
    }
    for (const [source, quality] of desired) want(source, quality);
    paint();
  }

  function closeAll() {
    clearTimeout(queueTimer);
    queueTimer = null;
    queue = [];
    for (const cam of [...cams.values()]) drop(cam, false);
    earlyOffers.clear();
  }

  // Actions -----------------------------------------------------------------------------------------------------

  function setLayout(n) {
    if (!layouts.includes(n) || n === layout) return;
    const first = page * perPage();
    layout = n;
    // la page affichée garde le premier joueur qu'elle montrait
    page = Math.floor(first / perPage());
    render();
    sync();
  }

  function turnPage(step) {
    const next = Math.min(Math.max(page + step, 0), pageCount() - 1);
    if (next === page) return;
    page = next;
    render();
    sync();
  }

  function focus(source) {
    focused = source;
    render();
    sync();
  }

  function stepFocus(step) {
    if (focused === null || players.length < 2) return;
    const index = players.findIndex((player) => player.source === focused);
    const next = players[(index + step + players.length) % players.length];
    // la page suit le joueur regardé : au retour, le mur le montre
    page = Math.floor(players.indexOf(next) / perPage());
    focus(next.source);
  }

  function back() {
    focused = null;
    render();
    sync();
  }

  function exit() {
    if (!open) return;
    hide();
    Bridge.post('wall:exit', {});
  }

  function hide() {
    open = false;
    focused = null;
    closeAll();
    tiles.clear();
    grid.replaceChildren();
    root.hidden = true;
  }

  // Messages du jeu ---------------------------------------------------------------------------------------------

  Bridge.on('wall:', {
    open(payload) {
      if (open) return;
      open = true;
      closedByServer = false;
      players = Array.isArray(payload.players) ? payload.players : [];
      layouts = Array.isArray(payload.layouts) && payload.layouts.length ? payload.layouts : layouts;
      layout = layouts.includes(payload.defaultLayout) ? payload.defaultLayout : layouts[layouts.length - 1];
      iceServers = Array.isArray(payload.iceServers) ? payload.iceServers : [];
      staggerMs = Number.isFinite(payload.staggerMs) ? payload.staggerMs : staggerMs;
      page = 0;
      focused = null;
      renderLayouts();
      root.hidden = false;
      render();
      sync();
    },
    players(payload) {
      if (!open || !Array.isArray(payload.players)) return;
      players = payload.players;
      if (focused !== null && !playerOf(focused)) focused = null;
      render();
      sync();
    },
    offer({ session, sdp }) {
      if (!open) return;
      const cam = bySession.get(session);
      if (cam) {
        if (cam.state === 'waiting') accept(cam, sdp);
        return;
      }
      const now = Date.now();
      for (const [id, early] of earlyOffers) {
        if (now - early.at > EARLY_OFFER_MS) earlyOffers.delete(id);
      }
      earlyOffers.set(session, { sdp, at: now });
    },
    ended({ session, reason }) {
      const cam = bySession.get(session);
      if (cam) fail(cam, reason, false);
    },
    close() {
      if (open) hide();
    },
  });

  // Commandes ---------------------------------------------------------------------------------------------------

  root.addEventListener('click', (event) => {
    const target = event.target.closest('button');
    if (!target || target.disabled) return;
    if (target.dataset.action === 'exit') exit();
    else if (target.dataset.action === 'back') back();
    else if (target.dataset.layout) setLayout(Number(target.dataset.layout));
    else if (target.dataset.page) turnPage(Number(target.dataset.page));
    else if (target.dataset.step) stepFocus(Number(target.dataset.step));
    else if (target.dataset.source) focus(Number(target.dataset.source));
  });

  document.addEventListener('keydown', (event) => {
    if (!open) return;
    if (event.key === 'Escape') {
      if (focused !== null) back();
      else exit();
    } else if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      const step = event.key === 'ArrowLeft' ? -1 : 1;
      if (focused !== null) stepFocus(step);
      else turnPage(step);
    } else if (/^[1-9]$/.test(event.key) && focused === null) {
      setLayout(Number(event.key));
    } else {
      return;
    }
    event.preventDefault();
  });

  setupFrame();
  Bridge.post('ready', {});

  return { isOpen: () => open };
})();
