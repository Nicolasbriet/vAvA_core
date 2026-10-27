'use strict';
/*
 * web/js/view-players.js
 * Rôle : la page Joueurs : joueurs connectés en direct (relus à intervalle et à chaque arrivée ou départ), fiche du
 *        joueur choisi (vie, faim, soif, position, avertissements) et ses actions selon les droits du rang : paroles,
 *        déplacements (vers un joueur, vers un lieu, retour), soins, justice (immobiliser, expulser, bannir), biens
 *        (inventaire, don), surveillance (son écran). Chaque action est décidée et inscrite par le Registre du Conseil.
 */

const PlayersView = (() => {
  const P = STRINGS.players;
  const D = P.dialogs;
  const A = P.actions;
  const REFRESH_MS = 5000;
  const COORD_MAX = 20000;
  const TEXT_MAX = 500;

  let sheet = null;
  let refs = null;
  let timer = null;
  let players = [];
  let selected = null;
  let detail = null;
  // compte de jeu → compte du panneau qui y est relié
  let panelOf = new Map();

  const labelOf = (player) => player.character || player.name || P.account(player.accountId);
  const panelTag = (player) => (panelOf.has(player.accountId) ? UI.el('span', 'tag tag-rank', P.panelAccount(panelOf.get(player.accountId))) : null);

  /** Profil public d'un identifiant, quand il en a un (Steam : identifiant hexadécimal → SteamID64). */
  function profileOf(identifier) {
    const [kind, value] = [identifier.type, String(identifier.value).split(':').slice(1).join(':')];
    if (kind === 'steam' && /^[0-9a-f]{1,16}$/i.test(value)) return `https://steamcommunity.com/profiles/${BigInt(`0x${value}`).toString()}`;
    if (kind === 'discord' && /^\d{5,20}$/.test(value)) return `https://discord.com/users/${value}`;
    return null;
  }

  async function copy(text) {
    try {
      await navigator.clipboard.writeText(text);
    } catch (error) {
      // presse-papiers refusé (adresse non sécurisée) : par une zone de texte, à l'ancienne
      const area = UI.el('textarea', 'offscreen');
      area.value = text;
      document.body.append(area);
      area.select();
      document.execCommand('copy');
      area.remove();
    }
    UI.slip(P.copied);
  }

  /** Identifiants du joueur (lus à l'instant par le serveur de jeu, jamais l'adresse IP). */
  function identifiersList(identifiers) {
    if (!identifiers.length) return message(P.noIdentifiers);
    return UI.el('ul', 'identifiers', null, identifiers.map((identifier) => {
      const profile = profileOf(identifier);
      const link = profile ? UI.el('a', 'plain-button', P.profile) : null;
      if (link) {
        link.href = profile;
        link.target = '_blank';
        link.rel = 'noopener noreferrer';
      }
      return UI.el('li', null, null, [
        UI.el('span', 'identifier-type', P.identifierLabels[identifier.type] || identifier.type),
        UI.el('span', 'identifier-value mono', identifier.value),
        UI.el('span', 'identifier-actions', null, [UI.button(P.copy, () => copy(identifier.value), 'plain'), link]),
      ]);
    }));
  }

  async function refreshLinks() {
    const result = await API.get('/api/links');
    if (result.ok) panelOf = new Map(UI.list(result.links).map((link) => [link.accountId, link.name]));
  }
  const percent = (value) => P.percent(value);

  function message(text) {
    return UI.el('p', 'empty', text);
  }

  // Liste ---------------------------------------------------------------------------------------------------------

  function renderList() {
    if (!players.length) {
      refs.list.replaceChildren(message(P.empty));
      return;
    }
    const rows = players.map((player) => {
      const tags = [
        player.downed ? UI.el('span', 'tag tag-danger', P.tags.downed) : null,
        player.frozen ? UI.el('span', 'tag tag-cold', P.tags.frozen) : null,
      ];
      const row = UI.el('tr', `ledger-row${player.source === selected ? ' is-selected' : ''}`, null, [
        UI.el('td', 'cell-number', String(player.source)),
        UI.el('td', null, null, [UI.el('span', 'cell-strong', player.name), panelTag(player)]),
        UI.el('td', null, null, [document.createTextNode(player.character || P.noCharacter), ...tags]),
        UI.el('td', 'cell-sub', player.rank || '—'),
        UI.el('td', 'cell-end', P.ms(player.ping)),
      ]);
      row.addEventListener('click', () => select(player.source));
      return row;
    });
    refs.list.replaceChildren(UI.el('table', 'ledger is-clickable', null, [
      UI.el('thead', null, null, [UI.el('tr', null, null, P.columns.map((c, i) => UI.el('th', i === 4 ? 'cell-end' : null, c)))]),
      UI.el('tbody', null, null, rows),
    ]));
  }

  async function refreshList() {
    const result = await GAME.call('players');
    if (!sheet) return;
    if (!result.ok) {
      refs.count.textContent = '';
      refs.list.replaceChildren(message(STRINGS.error(result.error)));
      return;
    }
    players = UI.list(result.result);
    refs.count.textContent = P.count(players.length);
    renderList();
    if (selected && !players.some((p) => p.source === selected)) {
      selected = null;
      detail = null;
      refs.detail.replaceChildren(message(P.gone));
    }
  }

  // Fiche ---------------------------------------------------------------------------------------------------------

  function fact(label, value) {
    return UI.el('div', 'fact', null, [UI.el('dt', null, label), UI.el('dd', null, value)]);
  }

  async function act(name, args, success) {
    const result = await GAME.call(name, ...args);
    if (UI.report(result, success)) {
      await refreshDetail();
      refreshList();
    }
    return result;
  }

  /** Action à un texte (message, motif) : dialogue, puis demande au Registre. */
  async function dialogText(name, dialog, success) {
    const values = await UI.form({
      title: `${dialog.title} ${labelOf(detail)}`, confirm: dialog.confirm,
      fields: [{ name: 'text', label: dialog.label, type: 'textarea', max: TEXT_MAX }],
    });
    if (values) act(name, [detail.source, values.text], success);
  }

  async function moveToPlayer() {
    const others = players.filter((p) => p.source !== detail.source);
    if (!others.length) {
      UI.slip(P.empty);
      return;
    }
    const values = await UI.form({
      title: `${D.moveToPlayer.title}…`, text: labelOf(detail), confirm: D.moveToPlayer.confirm,
      fields: [{ name: 'to', label: D.moveToPlayer.label, type: 'select', options: others.map((p) => ({ value: p.source, label: `${p.source} · ${labelOf(p)}` })) }],
    });
    if (values) act('moveToPlayer', [detail.source, Number(values.to)], P.done.move);
  }

  async function moveToCoords() {
    const here = detail.position || { x: 0, y: 0, z: 0 };
    const coord = (name, value) => ({ name, label: name.toUpperCase(), type: 'number', min: -COORD_MAX, max: COORD_MAX, value });
    const values = await UI.form({
      title: D.moveToCoords.title, text: labelOf(detail), confirm: D.moveToCoords.confirm,
      fields: [coord('x', here.x), coord('y', here.y), coord('z', here.z)],
    });
    if (values) act('moveToCoords', [detail.source, values.x, values.y, values.z], P.done.move);
  }

  async function ban() {
    const durations = GAME.banDurations();
    if (!durations.length) return;
    const values = await UI.form({
      title: `${D.ban.title} ${labelOf(detail)}`, confirm: D.ban.confirm,
      fields: [
        { name: 'hours', label: D.ban.duration, type: 'stamps', options: durations.map((h) => ({ value: h, label: STRINGS.banDuration(h) })) },
        { name: 'reason', label: D.ban.label, type: 'textarea', max: TEXT_MAX },
      ],
    });
    if (values) act('ban', [detail.source, values.hours, values.reason], P.done.ban);
  }

  async function give() {
    const values = await UI.form({
      title: `${D.give.title} ${labelOf(detail)}`, confirm: D.give.confirm,
      fields: [
        { name: 'item', label: D.give.item, max: 64 },
        { name: 'quantity', label: D.give.quantity, type: 'number', min: 1, max: 1000, value: 1, integer: true },
      ],
    });
    if (values) act('give', [detail.source, values.item, values.quantity], P.done.give);
  }

  async function inventory() {
    const result = await GAME.call('inventoryView', detail.source);
    if (!UI.report(result)) return;
    const items = UI.list(result.result);
    await UI.confirm({
      title: D.inventory.title(labelOf(detail)),
      text: items.length ? items.map((item) => `${item.quantity} × ${item.label}`).join(' · ') : D.inventory.empty,
      confirm: D.inventory.close,
    });
  }

  /** Groupe d'actions : n'apparaît que s'il garde au moins un bouton permis. */
  function group(title, buttons) {
    const allowed = buttons.filter(Boolean);
    if (!allowed.length) return null;
    return UI.el('div', 'action-group', null, [UI.el('h4', 'group-title', title), UI.el('div', 'group-buttons', null, allowed)]);
  }

  const when = (permission, label, onClick, kind) => (GAME.can(permission) ? UI.button(label, onClick, kind) : null);

  function renderDetail(error) {
    if (error) {
      refs.detail.replaceChildren(message(STRINGS.error(error)));
      return;
    }
    if (!detail) {
      refs.detail.replaceChildren(message(P.none));
      return;
    }
    const F = P.facts;
    const health = detail.health ? (detail.health.downed ? P.tags.downed : percent(detail.health.health * 100)) : '—';
    const needs = detail.needs || {};
    const position = detail.position ? `${detail.position.x}, ${detail.position.y}, ${detail.position.z}` : '—';
    const warnings = UI.list(detail.warnings);
    refs.detail.replaceChildren(
      UI.el('h3', 'fiche-title', labelOf(detail)),
      UI.el('dl', 'facts facts-compact', null, [
        fact(F.account, P.account(detail.accountId)), fact(F.name, detail.name), fact(F.health, health),
        fact(F.hunger, needs.hunger !== undefined ? percent(needs.hunger) : '—'),
        fact(F.thirst, needs.thirst !== undefined ? percent(needs.thirst) : '—'),
        fact(F.ping, P.ms(detail.ping)), fact(F.position, position),
        panelOf.has(detail.accountId) ? fact(F.panel, panelOf.get(detail.accountId)) : null,
      ]),
      UI.el('h4', 'section-title', P.identifiersTitle),
      identifiersList(UI.list(detail.identifiers)),
      UI.el('h4', 'section-title', P.adminTitle),
      UI.el('div', 'actions', null, [
        group(P.groups.words, [
          when('message', A.message, () => dialogText('message', D.message, P.done.message)),
          when('warn', A.warn, () => dialogText('warn', D.warn, P.done.warn)),
        ]),
        group(P.groups.move, [
          when('teleport', A.moveToPlayer, moveToPlayer),
          when('teleport', A.moveToCoords, moveToCoords),
          when('teleport', A.sendBack, () => act('sendBack', [detail.source], P.done.move)),
        ]),
        group(P.groups.care, [
          when('heal', A.heal, () => act('heal', [detail.source], P.done.heal)),
          when('heal', A.feed, () => act('feed', [detail.source], P.done.feed)),
        ]),
        group(P.groups.justice, [
          when('freeze', detail.frozen ? A.unfreeze : A.freeze, () => act('freeze', [detail.source, !detail.frozen], detail.frozen ? P.done.unfreeze : P.done.freeze)),
          when('kick', A.kick, () => dialogText('kick', D.kick, P.done.kick), 'seal'),
          when('ban', A.ban, ban, 'seal'),
        ]),
        group(P.groups.goods, [
          when('inventory', A.inventory, inventory),
          when('give', A.give, give),
        ]),
        group(P.groups.watch, [
          when('watch', A.watch, () => CAMERA.open(detail.source, labelOf(detail))),
        ]),
      ]),
      UI.el('h4', 'section-title', P.warnings),
      warnings.length
        ? UI.el('ul', 'warnings', null, warnings.map((w) => UI.el('li', null, null, [
          UI.el('span', 'cell-date', w.created), UI.el('span', null, w.reason), UI.el('span', 'cell-sub', w.actor_label),
        ])))
        : message(P.noWarnings),
    );
  }

  async function refreshDetail() {
    if (!selected) return;
    const result = await GAME.call('player', selected);
    if (!sheet) return;
    detail = result.ok ? result.result : null;
    if (!result.ok && result.error === 'not_found') selected = null;
    renderDetail(result.ok ? null : result.error);
  }

  function select(source) {
    selected = source;
    renderList();
    refs.detail.replaceChildren(message('…'));
    refreshDetail();
  }

  return {
    async show(target) {
      sheet = target;
      refs = { count: UI.el('span', 'page-aside'), list: UI.el('div', 'realm-list'), detail: UI.el('div', 'fiche') };
      const heading = UI.heading(P.title);
      heading.append(refs.count);
      sheet.replaceChildren(heading, UI.el('div', 'realm-columns', null, [refs.list, refs.detail]));
      refs.detail.replaceChildren(message(P.none));
      const ready = await GAME.ensure();
      if (!sheet) return;
      if (!ready.ok) {
        refs.list.replaceChildren(message(STRINGS.error(ready.error)));
        return;
      }
      await refreshLinks();
      await refreshList();
      if (selected) refreshDetail();
      timer = setInterval(() => {
        refreshList();
        refreshDetail();
      }, REFRESH_MS);
    },
    hide() {
      clearInterval(timer);
      timer = null;
      sheet = null;
    },
    /** Arrivée ou départ annoncé par le serveur de jeu. */
    players() {
      if (sheet) refreshList();
    },
    /** Joueur à ouvrir à l'arrivée sur la page (clic depuis le tableau de bord). */
    focus(source) {
      selected = source;
      detail = null;
    },
    /** Un compte du panneau vient d'être relié à son joueur. */
    async linked() {
      if (!sheet) return;
      await refreshLinks();
      renderList();
      if (detail) renderDetail(null);
    },
  };
})();
