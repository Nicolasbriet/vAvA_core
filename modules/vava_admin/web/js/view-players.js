'use strict';
/*
 * web/js/view-players.js
 * Rôle : onglet Joueurs : liste des âmes présentes (recherche locale) et fiche d'un joueur avec les actions que le
 *        rang permet. Le serveur revérifie chaque action ; la fiche est relue après une action qui la change.
 */

const PlayersView = (() => {
  const P = STRINGS.players;
  const A = STRINGS.actions;
  const D = STRINGS.dialogs;
  const list = (value) => (Array.isArray(value) ? value : Object.values(value || {}));
  let players = [];
  let selected = null;
  let filter = '';
  let ctx = null;

  const matches = (player) => {
    if (!filter) return true;
    const text = `${player.source} ${player.character || ''} ${player.name || ''} ${player.accountId}`.toLowerCase();
    return text.includes(filter);
  };

  function tag(text, kind) {
    return UI.el('span', `tag${kind ? ` tag-${kind}` : ''}`, text);
  }

  function row(player) {
    const node = UI.el('button', `entry${player.source === selected ? ' is-selected' : ''}`, null, [
      UI.el('span', 'entry-number', `n° ${player.source}`),
      UI.el('span', 'entry-main', null, [
        UI.el('span', 'entry-name', player.character || P.noCharacter),
        UI.el('span', 'entry-sub', `${player.name || ''} · ${P.account(player.accountId)}`),
      ]),
      UI.el('span', 'entry-tags', null, [
        player.source === ctx.session.self ? tag(P.tags.self) : null,
        player.rank ? tag(player.rank, 'rank') : null,
        player.downed ? tag(P.tags.downed, 'danger') : null,
        player.frozen ? tag(P.tags.frozen, 'cold') : null,
      ]),
    ]);
    node.type = 'button';
    node.addEventListener('click', () => select(player.source));
    return node;
  }

  function renderList() {
    const search = UI.el('input', 'search');
    search.type = 'search';
    search.placeholder = P.search;
    search.value = filter;
    search.addEventListener('input', () => {
      filter = search.value.trim().toLowerCase();
      ctx.left.querySelector('.entries').replaceChildren(...entries());
    });
    const entries = () => {
      const shown = players.filter(matches);
      return shown.length ? shown.map(row) : [UI.el('p', 'empty', P.empty)];
    };
    ctx.left.replaceChildren(
      UI.heading(P.heading, UI.el('span', 'page-count', P.count(players.length))),
      search,
      UI.el('div', 'entries', null, entries()),
    );
  }

  const fact = (label, value) => UI.el('div', 'fact', null, [UI.el('dt', null, label), UI.el('dd', null, value)]);

  function vital(label, value, kind) {
    const ratio = Math.max(0, Math.min(1, value));
    const fill = UI.el('span', 'gauge-fill');
    fill.style.transform = `scaleX(${ratio})`;
    return UI.el('div', `vital vital-${kind}`, null, [
      UI.el('span', 'vital-label', label),
      UI.el('span', 'gauge', null, [fill]),
      UI.el('span', 'vital-value', `${Math.round(ratio * 100)} %`),
    ]);
  }

  async function act(name, args = [], success = STRINGS.done) {
    const result = await Bridge.request(name, selected, ...args);
    if (UI.report(result, success)) await select(selected, true);
  }

  async function withDialog(name, spec, toArgs) {
    const values = await UI.dialog(spec);
    if (values) await act(name, toArgs(values));
  }

  function actionGroups(data) {
    const can = ctx.can;
    const self = data.source === ctx.session.self;
    const who = data.character || P.session(data.source);
    const groups = [];
    const group = (title, buttons) => {
      const shown = buttons.filter(Boolean);
      if (shown.length) groups.push(UI.el('div', 'action-group', null, [UI.el('h3', 'group-title', title), UI.el('div', 'group-buttons', null, shown)]));
    };
    group(P.groups.move, [
      can('teleport') && !self && UI.button(A.reach, () => act('reach')),
      can('teleport') && !self && UI.button(A.bring, () => act('bring')),
      can('teleport') && UI.button(A.sendBack, () => act('sendBack')),
      can('spectate') && !self && UI.button(A.spectate, () => act('spectate', [], null)),
      can('freeze') && !self && UI.button(data.frozen ? A.unfreeze : A.freeze, () => act('freeze', [!data.frozen])),
    ]);
    group(P.groups.care, [
      can('heal') && UI.button(A.heal, () => act('heal')),
      can('heal') && UI.button(A.feed, () => act('feed')),
    ]);
    group(P.groups.words, [
      can('message') && !self && UI.button(A.message, () => withDialog('message',
        { title: `${D.message.title} ${who}`, confirm: D.message.confirm, fields: [{ name: 'text', type: 'textarea', label: D.message.label }] },
        (v) => [v.text])),
      can('warn') && !self && UI.button(A.warn, () => withDialog('warn',
        { title: `${D.warn.title} ${who}`, confirm: D.warn.confirm, fields: [{ name: 'text', type: 'textarea', label: D.warn.label }] },
        (v) => [v.text])),
    ]);
    group(P.groups.goods, [
      can('inventory') && !self && UI.button(A.inventory, () => act('inventory', [], null)),
      can('give') && UI.button(A.give, () => withDialog('give',
        { title: `${D.give.title} ${who}`, confirm: D.give.confirm, fields: [
          { name: 'item', type: 'text', label: D.give.item, max: 64 },
          { name: 'quantity', type: 'number', label: D.give.quantity, value: 1, min: 1, max: 1000 },
        ] },
        (v) => [v.item, v.quantity])),
    ]);
    const durations = list(ctx.session.banDurations);
    group(P.groups.justice, [
      can('kick') && !self && UI.button(A.kick, () => withDialog('kick',
        { title: `${D.kick.title} ${who}`, confirm: D.kick.confirm, fields: [{ name: 'text', type: 'textarea', label: D.kick.label }] },
        (v) => [v.text]), 'seal'),
      can('ban') && !self && durations.length > 0 && UI.button(A.ban, () => withDialog('ban',
        { title: `${D.ban.title} ${who}`, confirm: D.ban.confirm, fields: [
          { name: 'hours', type: 'durations', label: D.ban.duration, options: durations },
          { name: 'text', type: 'textarea', label: D.ban.label },
        ] },
        (v) => [v.hours, v.text]), 'seal'),
    ]);
    if (can('staff') && !self) groups.push(council(data));
    return groups;
  }

  /** Nomination : rangs inférieurs au sien seulement (le serveur le revérifie). */
  function council(data) {
    const picker = UI.el('select', 'field-input');
    const none = UI.el('option', null, P.noRank);
    none.value = '';
    picker.append(none);
    for (const rank of list(ctx.session.ranks)) {
      if (rank.level >= ctx.session.rank.level) continue;
      const option = UI.el('option', null, rank.label);
      option.value = rank.name;
      option.selected = rank.name === data.rank;
      picker.append(option);
    }
    const apply = UI.button(A.appoint, async () => {
      const result = await Bridge.request('staffSet', data.accountId, picker.value);
      if (UI.report(result, STRINGS.done)) await select(data.source, true);
    });
    return UI.el('div', 'action-group', null, [
      UI.el('h3', 'group-title', P.groups.council),
      UI.el('div', 'group-buttons', null, [UI.el('label', 'field-label', P.appoint), picker, apply]),
    ]);
  }

  function renderDetail(data) {
    const facts = UI.el('dl', 'facts', null, [
      fact(P.labels.name, data.name || '—'),
      fact(P.labels.account, `n° ${data.accountId}`),
      fact(P.labels.session, `n° ${data.source} · ${P.ping(data.ping)}`),
      data.position ? fact(P.labels.position, `${data.position.x}, ${data.position.y}, ${data.position.z}`) : null,
    ]);
    const vitals = UI.el('div', 'vitals', null, [
      data.health ? vital(P.vitals.health, data.health.downed ? 0 : data.health.health, 'health') : null,
      data.needs ? vital(P.vitals.hunger, data.needs.hunger / 100, 'hunger') : null,
      data.needs ? vital(P.vitals.thirst, data.needs.thirst / 100, 'thirst') : null,
    ]);
    const warnings = list(data.warnings);
    const warningList = warnings.length
      ? UI.el('ol', 'warnings', null, warnings.map((w) => UI.el('li', null, null, [
        UI.el('span', 'warning-date', w.created), UI.el('span', 'warning-text', w.reason), UI.el('span', 'warning-author', w.actor_label),
      ])))
      : UI.el('p', 'empty', P.noWarnings);
    const tags = UI.el('div', 'entry-tags', null, [
      data.rankLabel ? tag(data.rankLabel, 'rank') : null,
      data.health && data.health.downed ? tag(P.tags.downed, 'danger') : null,
      data.frozen ? tag(P.tags.frozen, 'cold') : null,
    ]);
    ctx.right.replaceChildren(
      UI.heading(data.character || P.noCharacter, tags),
      facts,
      vitals,
      UI.el('div', 'actions', null, actionGroups(data)),
      UI.el('h3', 'group-title', P.warnings),
      warningList,
    );
  }

  async function select(source, keep) {
    selected = source;
    if (!keep) renderList();
    else for (const node of ctx.left.querySelectorAll('.entry')) node.classList.toggle('is-selected', node.querySelector('.entry-number').textContent === `n° ${source}`);
    const result = await Bridge.request('player', source);
    if (!result.ok) {
      UI.report(result);
      ctx.right.replaceChildren(UI.el('p', 'empty', P.none));
      return;
    }
    renderDetail(result.result);
  }

  async function show(context, options = {}) {
    ctx = context;
    const result = await Bridge.request('players');
    players = result.ok ? list(result.result) : [];
    if (!result.ok) UI.report(result);
    if (options.source) selected = options.source;
    renderList();
    if (selected && players.some((p) => p.source === selected)) await select(selected, true);
    else ctx.right.replaceChildren(UI.el('p', 'empty', P.none));
  }

  return { id: 'players', permission: 'view', show };
})();
