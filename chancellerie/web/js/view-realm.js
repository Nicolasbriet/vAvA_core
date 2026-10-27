'use strict';
/*
 * web/js/view-realm.js
 * Rôle : les pages courtes du royaume : signalements (en direct, prise en charge, clôture), sanctions (bans en cours,
 *        levée), journal du Conseil (par pages), membres du Conseil (nommer, changer de rang, révoquer),
 *        proclamation à tout le royaume. Chaque page vérifie d'abord que le serveur de jeu répond et n'affiche que ce
 *        que le rang permet ; le Registre revérifie tout.
 */

const RealmViews = (() => {
  const empty = (text) => UI.el('p', 'empty', text);
  const cell = (className, text) => UI.el('td', className, text);

  function table(columns, rows) {
    return UI.el('table', 'ledger', null, [
      UI.el('thead', null, null, [UI.el('tr', null, null, columns.map((c) => UI.el('th', null, c)))]),
      UI.el('tbody', null, null, rows),
    ]);
  }

  /** Page du royaume : titre, puis contenu une fois le serveur de jeu joint. */
  function page(title, render) {
    let sheet = null;
    const view = {
      async show(target) {
        sheet = target;
        sheet.replaceChildren(UI.heading(title), empty('…'));
        const ready = await GAME.ensure();
        if (!sheet) return;
        if (!ready.ok) {
          sheet.replaceChildren(UI.heading(title), empty(STRINGS.error(ready.error)));
          return;
        }
        await view.refresh();
      },
      async refresh() {
        if (!sheet) return;
        const content = await render(view);
        if (sheet) sheet.replaceChildren(UI.heading(title), ...content.filter(Boolean));
      },
      hide() {
        sheet = null;
      },
    };
    return view;
  }

  // Signalements ---------------------------------------------------------------------------------------------------

  const R = STRINGS.reports;
  const reports = page(R.title, async (view) => {
    const result = await GAME.call('reports');
    if (!result.ok) return [empty(STRINGS.error(result.error))];
    const list = UI.list(result.result);
    if (!list.length) return [empty(R.empty)];
    const handle = async (name, id) => {
      if (UI.report(await GAME.call(name, id), STRINGS.done)) view.refresh();
    };
    return [table(R.columns, list.map((report) => UI.el('tr', null, null, [
      cell('cell-number', String(report.id)),
      cell('cell-strong', report.author),
      cell('cell-reason', report.message),
      cell('cell-date', R.ago(report.ageMs || 0)),
      cell('cell-sub', report.claimedBy ? R.claimedBy(report.claimedBy) : R.open),
      UI.el('td', 'cell-end', null, GAME.can('reports') ? [
        report.claimedBy ? null : UI.button(R.claim, () => handle('reportClaim', report.id)),
        UI.button(R.close, () => handle('reportClose', report.id), 'plain'),
      ] : []),
    ])))];
  });

  // Sanctions ------------------------------------------------------------------------------------------------------

  const B = STRINGS.bans;
  let bansPage = 0;
  const bans = page(B.title, async (view) => {
    const result = await GAME.call('bans', bansPage);
    if (!result.ok) return [empty(STRINGS.error(result.error))];
    const list = UI.list(result.result);
    const lift = async (ban) => {
      if (!(await UI.confirm({ title: B.liftTitle, text: B.liftText(ban.target_label), confirm: B.lift }))) return;
      if (UI.report(await GAME.call('unban', ban.account_id), STRINGS.done)) view.refresh();
    };
    return [
      list.length ? table(B.columns, list.map((ban) => UI.el('tr', null, null, [
        cell('cell-number', String(ban.id)),
        UI.el('td', null, null, [UI.el('span', 'cell-strong', ban.target_label), UI.el('span', 'cell-sub', ` · ${STRINGS.players.account(ban.account_id)}`)]),
        cell('cell-reason', ban.reason),
        cell('cell-date', ban.created),
        cell('cell-date', ban.until || B.forever),
        cell(null, ban.actor_label),
        UI.el('td', 'cell-end', null, [GAME.can('unban') ? UI.button(B.lift, () => lift(ban)) : null]),
      ]))) : empty(B.empty),
      UI.pager(bansPage, list.length, GAME.pageSize(), (next) => { bansPage = next; view.refresh(); }),
    ];
  });

  // Journal du Conseil ------------------------------------------------------------------------------------------------

  const L = STRINGS.logs;
  let logsPage = 0;
  const logs = page(L.title, async (view) => {
    const result = await GAME.call('logs', logsPage);
    if (!result.ok) return [empty(STRINGS.error(result.error))];
    const list = UI.list(result.result);
    return [
      list.length ? table(L.columns, list.map((entry) => UI.el('tr', null, null, [
        cell('cell-date', entry.created),
        cell('cell-strong', entry.actor_label),
        cell('cell-action', L.labels[entry.action] || entry.action),
        cell(null, entry.target_label || '—'),
        cell('cell-reason', entry.details || ''),
      ]))) : empty(L.empty),
      UI.pager(logsPage, list.length, GAME.pageSize(), (next) => { logsPage = next; view.refresh(); }),
    ];
  });

  // Conseil ----------------------------------------------------------------------------------------------------------

  const C = STRINGS.council;
  const council = page(C.title, async (view) => {
    const result = await GAME.call('staff');
    if (!result.ok) return [empty(STRINGS.error(result.error))];
    const members = UI.list(result.result);
    const mine = GAME.session().rank;
    const ranks = UI.list(GAME.session().ranks).filter((r) => r.level < mine.level);
    const set = async (accountId, rank) => {
      if (UI.report(await GAME.call('staffSet', accountId, rank), STRINGS.done)) view.refresh();
    };
    const appoint = async () => {
      const values = await UI.form({
        title: C.appointTitle, confirm: C.confirm,
        fields: [
          { name: 'account', label: C.accountField, type: 'number', min: 1, max: 4294967295, integer: true, help: C.accountHelp },
          { name: 'rank', label: C.rankField, type: 'select', options: ranks.map((r) => ({ value: r.name, label: r.label })) },
        ],
      });
      if (values) set(values.account, values.rank);
    };
    const rows = members.map((member) => {
      const label = member.character || STRINGS.players.account(member.accountId);
      const lower = member.level < mine.level && GAME.can('staff');
      let control = null;
      if (lower) {
        const picker = UI.el('select', 'field-input field-inline');
        for (const rank of ranks) {
          const option = UI.el('option', null, rank.label);
          option.value = rank.name;
          if (rank.name === member.rank) option.selected = true;
          picker.append(option);
        }
        picker.addEventListener('change', () => set(member.accountId, picker.value));
        control = UI.el('span', 'row-actions', null, [picker, UI.button(C.revoke, async () => {
          if (await UI.confirm({ title: C.revokeTitle, text: C.revokeText(label), confirm: C.revoke })) set(member.accountId, '');
        }, 'plain')]);
      }
      return UI.el('tr', null, null, [
        UI.el('td', null, null, [UI.el('span', 'cell-strong', label), UI.el('span', 'cell-sub', ` · ${STRINGS.players.account(member.accountId)}`)]),
        UI.el('td', null, null, [UI.el('span', 'tag tag-rank', member.rankLabel)]),
        cell('cell-sub', member.source ? C.online(member.source) : C.offline),
        UI.el('td', 'cell-end', null, [control]),
      ]);
    });
    return [
      members.length ? table(C.columns, rows) : empty(C.empty),
      GAME.can('staff') && ranks.length ? UI.el('div', 'page-actions', null, [UI.button(C.appoint, appoint, 'seal')]) : null,
    ];
  });

  // Proclamation -----------------------------------------------------------------------------------------------------

  const N = STRINGS.announce;
  const TEXT_MAX = 500;
  const announce = page(N.title, async () => {
    const made = UI.field({ name: 'proclamation', label: N.label, type: 'textarea', max: TEXT_MAX, help: N.hint, wide: true });
    const send = UI.button(N.send, async () => {
      const text = made.input.value.trim();
      if (!text) {
        made.input.classList.add('is-invalid');
        return;
      }
      if (!(await UI.confirm({ title: N.confirmTitle, text, confirm: N.send }))) return;
      if (UI.report(await GAME.call('announce', text), N.sent)) made.input.value = '';
    }, 'seal');
    send.disabled = !GAME.can('announce');
    return [UI.el('div', 'form-grid', null, [made.node]), UI.el('div', 'page-actions', null, [send])];
  });

  return { reports, bans, logs, council, announce };
})();
