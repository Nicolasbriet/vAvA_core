'use strict';
/*
 * web/js/view-logs.js
 * Rôle : onglet Journal : actions du Conseil, des plus récentes aux plus anciennes, par pages.
 */

const LogsView = (() => {
  const L = STRINGS.logs;
  const list = (value) => (Array.isArray(value) ? value : Object.values(value || {}));
  let page = 0;

  function table(rows) {
    const head = UI.el('tr', null, null, L.columns.map((c) => UI.el('th', null, c)));
    const body = rows.map((entry) => UI.el('tr', null, null, [
      UI.el('td', 'cell-date', entry.created),
      UI.el('td', 'cell-strong', entry.actor_label),
      UI.el('td', 'cell-action', L.labels[entry.action] || entry.action),
      UI.el('td', null, entry.target_label || '—'),
      UI.el('td', 'cell-reason', entry.details || ''),
    ]));
    return UI.el('table', 'ledger', null, [UI.el('thead', null, null, [head]), UI.el('tbody', null, null, body)]);
  }

  async function show(ctx, options = {}) {
    if (options.page !== undefined) page = options.page;
    const result = await Bridge.request('logs', page);
    const rows = result.ok ? list(result.result) : [];
    if (!result.ok) UI.report(result);
    ctx.single.replaceChildren(
      UI.heading(L.heading),
      rows.length ? table(rows) : UI.el('p', 'empty', L.empty),
      ctx.pager(page, rows.length, (next) => show(ctx, { page: next })),
    );
  }

  return { id: 'logs', permission: 'logs', single: true, show };
})();
