'use strict';
/*
 * web/js/view-cameras.js
 * Rôle : la page Caméras, le mur de l'écran des joueurs connectés : grille 1 × 1 à 4 × 4, par pages, chaque écran
 *        sous sa plaque (nom et numéro) ; un clic l'ouvre en grand (flèches : joueur précédent ou suivant). Seuls les
 *        écrans de la page affichée ont une caméra ouverte, une à la fois et en léger décalé ; en grand, les cases se
 *        ferment et seule la vue en grand reste. Une caméra perdue est retentée après un délai ; la liste des joueurs
 *        est relue à intervalle tant que la page est ouverte. L'ouverture du mur et chaque vue en grand sont
 *        inscrites au journal du Conseil (par le Registre).
 */

const CamerasView = (() => {
  const W = STRINGS.cameras;
  const LAYOUTS = [1, 2, 3, 4];
  const DEFAULT_LAYOUT = 3;
  const LAYOUT_KEY = 'chancellerie.cameras.layout';
  const STAGGER_MS = 150;
  const RETRY_MS = 10000;
  const REFRESH_MS = 5000;
  // fins sans nouvel essai : le résultat ne changerait pas
  const FINAL = new Set(['unsupported', 'forbidden', 'no_rank', 'invalid_actor']);

  let sheet = null;
  let refs = null;
  let players = [];
  let layout = DEFAULT_LAYOUT;
  let page = 0;
  let focused = null;
  let refreshTimer = null;
  let queueTimer = null;
  let queue = [];
  /** Caméras : joueur → { source, quality, state, handle, code, retryAt }. */
  const cams = new Map();
  /** Écrans affichés : joueur → élément. */
  const tiles = new Map();

  // Disposition retenue (confort de ce navigateur seulement) ----------------------------------------------------

  function savedLayout() {
    try {
      const value = Number(window.localStorage.getItem(LAYOUT_KEY));
      return LAYOUTS.includes(value) ? value : DEFAULT_LAYOUT;
    } catch (error) {
      return DEFAULT_LAYOUT;
    }
  }

  function saveLayout() {
    try {
      window.localStorage.setItem(LAYOUT_KEY, String(layout));
    } catch (error) {
      // stockage refusé : la disposition revient à celle par défaut au prochain passage
    }
  }

  // Pages --------------------------------------------------------------------------------------------------------

  const perPage = () => layout * layout;
  const pageCount = () => Math.max(1, Math.ceil(players.length / perPage()));
  const visible = () => players.slice(page * perPage(), (page + 1) * perPage());
  const playerOf = (source) => players.find((player) => player.source === source);
  const statusText = (code) => W.status[code] || STRINGS.error(code);

  function statusOf(player, cam) {
    if (!player) return W.status.dropped;
    if (!player.active) return W.status.not_playing;
    if (!cam || (cam.state !== 'live' && cam.state !== 'ended')) return W.connecting;
    if (cam.state === 'ended') return statusText(cam.code);
    return '';
  }

  function label(button, text) {
    button.title = text;
    button.setAttribute('aria-label', text);
    return button;
  }

  function tileOf(player) {
    let tile = tiles.get(player.source);
    if (!tile) {
      tile = UI.el('button', 'screen', null, [
        UI.el('video', 'screen-video'),
        UI.el('span', 'screen-status'),
        UI.el('span', 'plate', null, [UI.el('span', 'plate-name'), UI.el('span', 'plate-number')]),
      ]);
      tile.type = 'button';
      tile.dataset.source = String(player.source);
      const video = tile.querySelector('video');
      video.muted = true;
      video.autoplay = true;
      video.playsInline = true;
      tile.addEventListener('click', () => focus(player.source));
      tiles.set(player.source, tile);
    }
    tile.querySelector('.plate-name').textContent = player.label;
    tile.querySelector('.plate-number').textContent = W.number(player.source);
    return tile;
  }

  function paintStatus(box, text) {
    box.textContent = text;
    box.hidden = text === '';
  }

  /** États affichés, sans rien reconstruire. */
  function paint() {
    if (!refs) return;
    for (const [source, tile] of tiles) {
      const cam = cams.get(source);
      const status = statusOf(playerOf(source), cam && cam.quality === 'tile' ? cam : null);
      paintStatus(tile.querySelector('.screen-status'), status);
      tile.classList.toggle('is-live', status === '');
    }
    if (focused !== null) {
      const player = playerOf(focused);
      refs.focusName.textContent = player ? player.label : '';
      refs.focusNumber.textContent = W.number(focused);
      paintStatus(refs.focusStatus, statusOf(player, cams.get(focused)));
    }
  }

  function render() {
    if (!refs) return;
    const total = pageCount();
    if (page >= total) page = total - 1;
    refs.count.textContent = W.count(players.length);
    refs.pageLabel.textContent = W.page(page + 1, total);
    refs.previous.disabled = page === 0;
    refs.next.disabled = page >= total - 1;
    refs.grid.style.setProperty('--n', String(layout));
    refs.grid.dataset.layout = String(layout);
    for (const button of refs.layouts) button.setAttribute('aria-pressed', String(Number(button.dataset.layout) === layout));
    const shown = visible();
    const keep = new Set(shown.map((player) => player.source));
    for (const source of tiles.keys()) {
      if (!keep.has(source)) tiles.delete(source);
    }
    if (shown.length === 0) refs.grid.replaceChildren(UI.el('p', 'wall-empty', W.empty));
    else refs.grid.replaceChildren(...shown.map(tileOf));
    refs.grid.hidden = focused !== null;
    refs.focus.hidden = focused === null;
    refs.hint.textContent = focused === null ? W.hint : W.focusHint;
    paint();
  }

  // Caméras ------------------------------------------------------------------------------------------------------

  function videoOf(cam) {
    if (!refs) return null;
    if (cam.quality === 'full') return refs.focusVideo;
    const tile = tiles.get(cam.source);
    return tile ? tile.querySelector('video') : null;
  }

  function detach(cam) {
    const video = videoOf(cam);
    if (!video) return;
    video.onloadeddata = null;
    if (video.srcObject) video.srcObject = null;
  }

  /** Image reçue : l'écran passe en direct à sa première image, pas avant. */
  function attach(cam, stream) {
    const video = videoOf(cam);
    if (!video) return;
    video.onloadeddata = () => {
      if (cams.get(cam.source) !== cam) return;
      cam.state = 'live';
      paint();
    };
    video.srcObject = stream;
    video.play().catch(() => {});
  }

  function drop(cam) {
    if (cams.get(cam.source) === cam) cams.delete(cam.source);
    detach(cam);
    if (cam.handle) cam.handle.close();
    cam.state = 'dropped';
  }

  function open(cam) {
    cam.state = 'opening';
    cam.handle = CAMERA.watch(cam.source, cam.quality, {
      onStream: (stream) => {
        if (cams.get(cam.source) === cam) attach(cam, stream);
      },
      onEnded: (code) => {
        if (cams.get(cam.source) !== cam) return;
        detach(cam);
        cam.state = 'ended';
        cam.code = code;
        cam.retryAt = FINAL.has(code) ? Infinity : Date.now() + RETRY_MS;
        paint();
      },
    });
  }

  /** Ouvre les caméras en attente une à une, en léger décalé. */
  function pump() {
    queueTimer = null;
    while (queue.length) {
      const cam = queue.shift();
      if (cams.get(cam.source) !== cam || cam.state !== 'queued') continue;
      open(cam);
      if (queue.length) queueTimer = setTimeout(pump, STAGGER_MS);
      return;
    }
  }

  function want(source, quality) {
    const existing = cams.get(source);
    if (existing && existing.quality === quality && (existing.state !== 'ended' || Date.now() < existing.retryAt)) return;
    if (existing) drop(existing);
    const cam = { source, quality, state: 'queued', handle: null, code: null, retryAt: 0 };
    cams.set(source, cam);
    queue.push(cam);
    if (!queueTimer) pump();
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
      if (desired.get(cam.source) !== cam.quality) drop(cam);
    }
    for (const [source, quality] of desired) want(source, quality);
    paint();
  }

  function closeAll() {
    clearTimeout(queueTimer);
    queueTimer = null;
    queue = [];
    for (const cam of [...cams.values()]) drop(cam);
  }

  // Actions -------------------------------------------------------------------------------------------------------

  function setLayout(n) {
    if (!LAYOUTS.includes(n) || n === layout) return;
    const first = page * perPage();
    layout = n;
    saveLayout();
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

  async function refresh() {
    const result = await API.post('/api/game/cameras/players');
    if (!sheet || !refs) return;
    if (!result.ok) return;
    players = UI.list(result.players);
    if (focused !== null && !playerOf(focused)) focused = null;
    render();
    sync();
  }

  function onKey(event) {
    if (!refs || CAMERA.viewerOpen() || !document.querySelector('.dialog').hidden) return;
    if (event.target instanceof HTMLElement && event.target.closest('input, textarea, select')) return;
    if (event.key === 'Escape' && focused !== null) back();
    else if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      const step = event.key === 'ArrowLeft' ? -1 : 1;
      if (focused !== null) stepFocus(step);
      else turnPage(step);
    } else if (/^[1-4]$/.test(event.key) && focused === null) setLayout(Number(event.key));
    else return;
    event.preventDefault();
  }

  // Page ---------------------------------------------------------------------------------------------------------

  function build() {
    const layouts = LAYOUTS.map((n) => {
      const button = label(UI.el('button', 'layout-button', null, Array.from({ length: n * n }, () => UI.el('span', 'layout-cell'))), W.layout(n));
      button.type = 'button';
      button.dataset.layout = String(n);
      button.style.setProperty('--n', String(n));
      button.addEventListener('click', () => setLayout(n));
      return button;
    });
    const arrow = (className, text, onClick) => {
      const button = label(UI.el('button', className), text);
      button.type = 'button';
      button.addEventListener('click', onClick);
      return button;
    };
    const previous = arrow('wall-arrow', W.previousPage, () => turnPage(-1));
    const next = arrow('wall-arrow is-next', W.nextPage, () => turnPage(1));
    const focusVideo = UI.el('video', 'focus-video');
    focusVideo.muted = true;
    focusVideo.autoplay = true;
    focusVideo.playsInline = true;
    const focusStatus = UI.el('span', 'screen-status');
    const focusName = UI.el('span', 'plate-name');
    const focusNumber = UI.el('span', 'plate-number');
    const grid = UI.el('div', 'wall-grid');
    const focusBox = UI.el('div', 'wall-focus', null, [
      arrow('wall-arrow is-large', W.previousPlayer, () => stepFocus(-1)),
      UI.el('figure', 'focus-screen', null, [focusVideo, focusStatus, UI.el('figcaption', 'plate is-large', null, [focusName, focusNumber])]),
      arrow('wall-arrow is-large is-next', W.nextPlayer, () => stepFocus(1)),
      UI.button(W.back, back),
    ]);
    const count = UI.el('span', 'wall-count');
    const pageLabel = UI.el('span', 'wall-page');
    const hint = UI.el('p', 'wall-hint');
    refs = { grid, focus: focusBox, focusVideo, focusStatus, focusName, focusNumber, count, pageLabel, previous, next, hint, layouts };
    sheet.replaceChildren(
      UI.heading(W.title),
      UI.el('p', 'prose', W.privacy),
      UI.el('div', 'wall-bar', null, [count, UI.el('div', 'wall-layouts', null, layouts), UI.el('div', 'wall-pager', null, [previous, pageLabel, next])]),
      UI.el('div', 'wall-panel', null, [grid, focusBox]),
      hint,
    );
  }

  return {
    async show(target) {
      sheet = target;
      sheet.classList.add('is-wall');
      sheet.replaceChildren(UI.heading(W.title), UI.el('p', 'empty', '…'));
      const ready = await GAME.ensure();
      if (!sheet) return;
      if (!ready.ok) {
        sheet.replaceChildren(UI.heading(W.title), UI.el('p', 'empty', STRINGS.error(ready.error)));
        return;
      }
      const opened = await API.post('/api/game/cameras/wall');
      if (!sheet) return;
      if (!opened.ok) {
        sheet.replaceChildren(UI.heading(W.title), UI.el('p', 'empty', STRINGS.error(opened.error)));
        return;
      }
      players = UI.list(opened.players);
      layout = savedLayout();
      page = 0;
      focused = null;
      build();
      render();
      sync();
      document.addEventListener('keydown', onKey);
      refreshTimer = setInterval(refresh, REFRESH_MS);
    },

    hide() {
      clearInterval(refreshTimer);
      refreshTimer = null;
      document.removeEventListener('keydown', onKey);
      closeAll();
      tiles.clear();
      if (sheet) sheet.classList.remove('is-wall');
      sheet = null;
      refs = null;
    },

    /** Un joueur est arrivé ou parti : la liste est relue. */
    players() {
      if (refs) refresh();
    },
  };
})();
