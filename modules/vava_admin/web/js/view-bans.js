'use strict';
/*
 * web/js/view-bans.js
 * Rôle : onglet Sanctions : bans en cours, par pages, et levée d'un ban (selon le rang).
 */

const BansView = (() => {
  const B = STRINGS.bans;
  const list = (value) => (Array.isArray(value) ? value : Object.values(value || {}));
  let page = 0;
  let ctx = null;

  async function lift(ban) {
    const ok = await UI.dialog({ title: STRINGS.dialogs.unban.title, text: STRINGS.dialogs.unban.text(ban.target_label), confirm: STRINGS.dialogs.unban.confirm });
    if (!ok) return;
    const result = await Bridge.request('unban', ban.account_id);
    if (UI.report(result, STRINGS.done)) await show(ctx);
  }

  function table(rows) {
    const head = UI.el('tr', null, null, B.columns.map((c) => UI.el('th', null, c)));
    const body = rows.map((ban) => UI.el('tr', null, null, [
      UI.el('td', 'cell-number', String(ban.id)),
      UI.el('td', null, null, [UI.el('span', 'cell-strong', ban.target_label), UI.el('span', 'cell-sub', ` · ${STRINGS.players.account(ban.account_id)}`)]),
      UI.el('td', 'cell-reason', ban.reason),
      UI.el('td', 'cell-date', ban.created),
      UI.el('td', 'cell-date', ban.until || B.forever),
      UI.el('td', null, ban.actor_label),
      UI.el('td', null, null, [ctx.can('unban') ? UI.button(B.lift, () => lift(ban)) : null]),
    ]));
    return UI.el('table', 'ledger', null, [UI.el('thead', null, null, [head]), UI.el('tbody', null, null, body)]);
  }

  async function show(context, options = {}) {
    ctx = context;
    if (options.page !== undefined) page = options.page;
    const result = await Bridge.request('bans', page);
    const rows = result.ok ? list(result.result) : [];
    if (!result.ok) UI.report(result);
    ctx.single.replaceChildren(
      UI.heading(B.heading),
      rows.length ? table(rows) : UI.el('p', 'empty', B.empty),
      ctx.pager(page, rows.length, (next) => show(ctx, { page: next })),
    );
  }

  return { id: 'bans', permission: 'bans', single: true, show };
})();
