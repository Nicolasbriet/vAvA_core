'use strict';
/*
 * web/js/view-network.js
 * Rôle : la page Réseau, en lecture seule : ce que montre /vava_reseau en jeu. Le compteur des envois du core sur la
 *        dernière minute (mesure exacte ou estimée, envois, volume, latents, plus gros message, évènements les plus
 *        lourds), pour tout le royaume, un module, ou ce que reçoit un joueur (totaux ; le détail seulement s'il est
 *        suivi en jeu par /vava_reseau joueur, que la page ne lance jamais). Droit des outils du Registre, vérifié par le
 *        pont. Relue à la demande, ou à intervalle choisi (5 s au moins, compté depuis la dernière demande, réussie ou
 *        non), seulement quand la page est visible, une demande à la fois ; la relecture automatique s'arrête sur un refus
 *        durable (droit, serveur arrêté, compteur absent, joueur parti) et après 15 min sans action sur la page. La
 *        première lecture dit au pont que la page s'ouvre (une ligne au journal du Conseil), les relectures non.
 */

const NetworkView = (() => {
  const T = STRINGS.network;
  const SCOPES = ['all', 'resource', 'player'];
  // relectures permises : à la demande (0), ou toutes les 5, 15 ou 30 s ; jamais plus vite que AUTO_MIN_MS
  const AUTOS = [0, 5000, 15000, 30000];
  const AUTO_MIN_MS = 5000;
  const AUTO_DEFAULT = 15000;
  // quoi qu'il arrive, jamais deux demandes automatiques à moins de GAP_MIN_MS l'une de l'autre
  const GAP_MIN_MS = 1000;
  // délai refusé par le pont (deux lectures trop proches) : un seul nouvel essai avancé (porté à GAP_MIN_MS)
  const RETRY_MS = 600;
  // relecture automatique repassée « à la demande » après ce temps sans action sur la page
  const IDLE_MS = 15 * 60 * 1000;
  // refus qui ne passeront pas tout seuls : la relecture automatique s'arrête, la reprise est manuelle
  const STOPPING = new Set([
    'forbidden', 'net_unavailable', 'server_stopped', 'unknown_player', 'invalid_args', 'unknown_request', 'no_rank',
    'invalid_actor',
  ]);
  const RESOURCE_PATTERN = /^[A-Za-z0-9_.-]{1,48}$/;
  const PLAYER_MAX = 65535;
  const OTHER_RESOURCE = '*';
  const numberFormat = new Intl.NumberFormat('fr-FR');

  let sheet = null;
  let refs = {};
  let scope = 'all';
  let resource = '';
  let player = null;
  let auto = AUTO_DEFAULT;
  let timer = null;
  // dernière lecture réussie (affichage « lu à ») ; dernière demande partie, réussie ou non (rythme des relectures)
  let readAt = 0;
  let attemptAt = 0;
  // dernière action de la personne sur la page (portée, saisie, relecture, rythme)
  let actionAt = 0;
  // demande en route (les relectures attendent sa réponse) ; nouvel essai après un délai refusé déjà fait
  let inFlight = false;
  let retried = false;
  // relecture automatique arrêtée par la page : pourquoi (affiché à côté de l'heure), ou ''
  let autoNote = '';
  // la prochaine lecture est celle de l'ouverture de la page (inscrite au journal par le pont)
  let opening = true;
  // numéro de la dernière lecture demandée : une réponse plus ancienne (portée changée entre-temps) est ignorée
  let sequence = 0;
  // numéro de l'affichage de la page : une ouverture dépassée (page quittée puis rouverte) ne construit rien
  let showing = 0;

  const count = (value) => numberFormat.format(Number(value) || 0);
  const visible = () => document.visibilityState !== 'hidden';

  function fact(label, value, className) {
    return UI.el('div', 'fact', null, [UI.el('dt', null, label), UI.el('dd', className || null, value)]);
  }

  function stop() {
    clearTimeout(timer);
    timer = null;
  }

  function setBusy(busy) {
    inFlight = busy;
    if (refs.reload) refs.reload.disabled = busy;
    if (refs.read) refs.read.disabled = busy;
  }

  /** Rythme choisi, sans rien relancer (tampons à jour). */
  function markAuto(next) {
    auto = AUTOS.includes(next) ? next : 0;
    if (!refs.autos) return;
    for (const node of refs.autos.children) node.classList.toggle('is-selected', Number(node.dataset.auto) === auto);
  }

  /** Arrêt de la relecture automatique par la page (refus durable, inactivité) : affiché, reprise manuelle. */
  function halt(note) {
    markAuto(0);
    autoNote = note;
    stop();
  }

  /**
   * Prochaine relecture : seulement en relecture automatique, page affichée et visible, aucune demande en route.
   * Le délai court depuis la dernière demande partie (réussie ou non) : un refus immédiat ne fait jamais boucler.
   */
  function schedule(delayMs) {
    stop();
    if (!sheet || !auto || !visible() || inFlight) return;
    if (Date.now() - actionAt >= IDLE_MS) {
      halt(T.idleStopped);
      renderAside();
      return;
    }
    const due = delayMs !== undefined ? delayMs : Math.max(AUTO_MIN_MS, auto) - (Date.now() - attemptAt);
    timer = setTimeout(() => load(false), Math.max(GAP_MIN_MS, due));
  }

  function onVisibility() {
    if (!sheet) return;
    if (visible()) schedule();
    else stop();
    renderAside();
  }

  function renderAside() {
    if (!refs.aside) return;
    const parts = [];
    if (readAt) parts.push(T.readAt(STRINGS.clock(readAt)));
    if (autoNote) parts.push(autoNote);
    else if (auto && !visible()) parts.push(T.paused);
    refs.aside.textContent = parts.join(' · ');
  }

  /** Valeur saisie pour la portée choisie, ou undefined si elle est refusée (champ marqué). */
  function readValue() {
    const input = refs.input;
    input.classList.remove('is-invalid');
    if (scope === 'all') return '';
    const text = input.value.trim();
    if (scope === 'resource') {
      if (!RESOURCE_PATTERN.test(text)) {
        input.classList.add('is-invalid');
        return undefined;
      }
      return text;
    }
    const target = Number(text);
    if (!/^\d{1,5}$/.test(text) || !Number.isInteger(target) || target < 1 || target > PLAYER_MAX) {
      input.classList.add('is-invalid');
      return undefined;
    }
    return target;
  }

  /** Action de la personne : l'inactivité repart de zéro. */
  function acted() {
    actionAt = Date.now();
  }

  /**
   * Une lecture. `byUser` : demandée par une action (portée, ligne, Lire, Relire), qui passe même si une relecture est
   * en route (la réponse dépassée est ignorée) ; une relecture automatique, elle, attend toujours la réponse en route.
   */
  async function load(byUser) {
    if (!sheet || (!byUser && inFlight)) return;
    stop();
    const value = scope === 'resource' ? resource : (scope === 'player' ? player : '');
    const ticket = ++sequence;
    attemptAt = Date.now();
    setBusy(true);
    const result = await GAME.call('netStats', scope, value, opening);
    if (!sheet || ticket !== sequence) return;
    setBusy(false);
    if (result.ok) {
      opening = false;
      retried = false;
      readAt = Date.now();
      render(result.result);
      renderAside();
      schedule();
      return;
    }
    // l'ouverture refusée (serveur arrêté, droit…) sera redite à la lecture suivante
    if (result.error === 'rate_limited') {
      // deux lectures trop proches pour le pont : l'affichage reste ; en relecture automatique, un seul nouvel essai
      // un peu plus tôt (jamais sous GAP_MIN_MS), puis le rythme normal ; à la demande, la personne relit elle-même
      UI.slip(STRINGS.error(result.error));
      const again = !retried;
      retried = true;
      schedule(again ? RETRY_MS : undefined);
      renderAside();
      return;
    }
    retried = false;
    const lines = [UI.el('p', 'empty', STRINGS.error(result.error))];
    if (STOPPING.has(result.error) && auto) {
      halt(T.autoStopped);
      lines.push(UI.el('p', 'hint', T.autoStoppedHelp));
    }
    refs.body.replaceChildren(...lines);
    renderAside();
    schedule();
  }

  /** Lire ce que montre la barre (bouton Lire, Entrée). */
  function readBar() {
    if (inFlight) return;
    const value = readValue();
    if (value === undefined) return;
    if (scope === 'resource') resource = value;
    if (scope === 'player') player = value;
    acted();
    load(true);
  }

  /** Relire : ignoré pendant une lecture en route (le bouton est grisé). */
  function reload() {
    if (inFlight) return;
    acted();
    load(true);
  }

  function setScope(next, value) {
    acted();
    scope = next;
    if (next === 'resource' && value !== undefined) resource = value;
    for (const node of refs.scopes.children) node.classList.toggle('is-selected', node.dataset.scope === scope);
    const input = refs.input;
    input.classList.remove('is-invalid');
    input.hidden = scope === 'all';
    refs.read.hidden = scope === 'all';
    if (scope === 'resource') {
      input.inputMode = 'text';
      input.maxLength = 48;
      input.placeholder = T.resourcePlaceholder;
      input.setAttribute('aria-label', T.resourceField);
      input.value = resource;
    } else if (scope === 'player') {
      input.inputMode = 'numeric';
      input.maxLength = 5;
      input.placeholder = T.playerPlaceholder;
      input.setAttribute('aria-label', T.playerField);
      input.value = player ? String(player) : '';
    }
    // valeur déjà connue (ligne cliquée, page rouverte, portée reprise) : lue aussitôt ; sinon on attend la saisie
    if (scope === 'all' || (scope === 'resource' && resource) || (scope === 'player' && player)) {
      load(true);
    } else {
      stop();
      // une lecture encore en route pour l'ancienne portée ne s'affichera pas
      sequence += 1;
      setBusy(false);
      refs.body.replaceChildren();
      input.focus();
    }
  }

  /** Rythme choisi par la personne : la relecture reprend, la note d'arrêt s'efface. */
  function setAuto(next) {
    acted();
    markAuto(next);
    autoNote = '';
    renderAside();
    schedule();
  }

  function stampBar(entries, selected, dataKey, onPick) {
    const node = UI.el('div', 'stamps');
    node.setAttribute('role', 'radiogroup');
    for (const [value, label] of entries) {
      const stamp = UI.button(label, () => onPick(value));
      stamp.className = `stamp${value === selected ? ' is-selected' : ''}`;
      stamp.setAttribute('role', 'radio');
      stamp.dataset[dataKey] = String(value);
      node.append(stamp);
    }
    return node;
  }

  function eventRows(events) {
    const clickable = scope === 'all';
    return events.map((event) => {
      const other = event.resource === OTHER_RESOURCE;
      const row = UI.el('tr', null, null, [
        UI.el('td', 'cell-strong', other ? T.other : String(event.resource)),
        UI.el('td', null, String(event.label)),
        UI.el('td', 'cell-end', count(event.messages)),
        UI.el('td', 'cell-end', STRINGS.bytes(Number(event.bytes) || 0)),
        UI.el('td', 'cell-end', STRINGS.bytes(Number(event.largest) || 0)),
        UI.el('td', 'cell-end', Number(event.latent) > 0 ? count(event.latent) : '—'),
      ]);
      if (clickable && !other && RESOURCE_PATTERN.test(String(event.resource))) {
        row.addEventListener('click', () => setScope('resource', String(event.resource)));
      }
      return row;
    });
  }

  function emptyText(view) {
    if (view.scope === 'player') return T.emptyPlayer;
    if (view.scope === 'resource') return T.emptyResource(String(view.resource));
    return T.empty;
  }

  function render(view) {
    if (!view || typeof view !== 'object' || !view.total) return;
    const total = view.total;
    const events = UI.list(view.events);
    const isPlayer = view.scope === 'player';
    const watched = isPlayer && view.watched === true;
    const facts = [
      isPlayer ? fact(T.facts.player, T.playerText(view.target, watched && typeof view.name === 'string' ? view.name : ''), 'fact-text') : null,
      isPlayer ? fact(T.facts.watched, watched ? T.watchedYes : T.watchedNo, 'fact-text') : null,
      fact(T.facts.mode, T.modes[view.mode] || T.modes.estimate, 'fact-text'),
      fact(T.facts.messages, count(total.messages)),
      fact(T.facts.bytes, STRINGS.bytes(Number(total.bytes) || 0)),
      fact(T.facts.latent, count(total.latent)),
      isPlayer && !watched ? null : fact(T.facts.largest, events.length ? STRINGS.bytes(Number(view.largest) || 0) : '—'),
    ].filter(Boolean);
    const body = [UI.el('dl', 'facts', null, facts)];
    if (view.mode !== 'exact') body.push(UI.el('p', 'hint', T.modeHelp));
    if (isPlayer && !watched) {
      body.push(UI.el('p', 'prose', T.notWatched(view.target)));
    } else if (!events.length) {
      body.push(UI.el('p', 'empty', emptyText(view)));
    } else {
      body.push(UI.el('table', `ledger${scope === 'all' ? ' is-clickable' : ''}`, null, [
        UI.el('thead', null, null, [UI.el('tr', null, null, T.columns.map((c, i) => UI.el('th', i >= 2 ? 'cell-end' : null, c)))]),
        UI.el('tbody', null, null, eventRows(events)),
      ]));
      if (scope === 'all') body.push(UI.el('p', 'hint', T.rowHelp));
    }
    body.push(UI.el('p', 'hint', T.notCounted));
    refs.body.replaceChildren(...body);
  }

  function build() {
    const input = UI.el('input', 'field-input field-inline');
    input.spellcheck = false;
    input.autocomplete = 'off';
    input.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') readBar();
    });
    refs = {
      aside: null,
      body: UI.el('div'),
      input,
      read: UI.button(T.read, readBar),
      reload: UI.button(T.reload, reload, 'plain'),
      scopes: stampBar(SCOPES.map((id) => [id, T.scopes[id]]), scope, 'scope', (id) => setScope(id)),
      autos: stampBar(AUTOS.map((ms) => [ms, T.autos[ms]]), auto, 'auto', setAuto),
    };
    const heading = UI.heading(T.title, ' ');
    refs.aside = heading.querySelector('.page-aside');
    sheet.replaceChildren(
      heading,
      UI.el('p', 'prose', T.hint),
      UI.el('div', 'perf-bar', null, [refs.scopes, input, refs.read]),
      refs.body,
      UI.el('div', 'perf-bar', null, [
        refs.reload, UI.el('span', 'spacer'), UI.el('span', 'field-label', T.autoLabel), refs.autos,
      ]),
    );
    input.hidden = true;
    refs.read.hidden = true;
  }

  return {
    async show(target) {
      sheet = target;
      const shown = ++showing;
      opening = true;
      readAt = 0;
      attemptAt = 0;
      retried = false;
      autoNote = '';
      inFlight = false;
      sheet.replaceChildren(UI.heading(T.title), UI.el('p', 'empty', '…'));
      const ready = await GAME.ensure();
      if (!sheet || shown !== showing) return;
      if (!ready.ok || !GAME.can('tools')) {
        sheet.replaceChildren(UI.heading(T.title), UI.el('p', 'empty', STRINGS.error(ready.ok ? 'forbidden' : ready.error)));
        return;
      }
      build();
      document.addEventListener('visibilitychange', onVisibility);
      setScope(scope);
    },
    hide() {
      sheet = null;
      sequence += 1;
      showing += 1;
      inFlight = false;
      stop();
      document.removeEventListener('visibilitychange', onVisibility);
      refs = {};
    },
  };
})();
