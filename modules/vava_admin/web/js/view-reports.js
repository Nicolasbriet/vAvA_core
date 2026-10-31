'use strict';
/*
 * web/js/view-reports.js
 * Rôle : onglet Signalements : doléances en attente, prise en charge, clôture, accès à la fiche du joueur.
 */

const ReportsView = (() => {
  const R = STRINGS.reports;
  const list = (value) => (Array.isArray(value) ? value : Object.values(value || {}));
  let reports = [];
  let selected = null;
  let ctx = null;

  // nature d'une demande (1.9.0) : libellé connu seulement, sinon rien (jamais une valeur reçue telle quelle)
  const kindLabel = (report) => (Object.prototype.hasOwnProperty.call(R.kinds, report.kind) ? R.kinds[report.kind] : null);
  const isCoord = (v) => typeof v === 'number' && Number.isFinite(v);

  function row(report) {
    const kind = kindLabel(report);
    const node = UI.el('button', `entry${report.id === selected ? ' is-selected' : ''}`, null, [
      UI.el('span', 'entry-number', `n° ${report.id}`),
      UI.el('span', 'entry-main', null, [
        UI.el('span', 'entry-name', report.author),
        UI.el('span', 'entry-sub', R.age(ageText(report.ageMs))),
      ]),
      UI.el('span', 'entry-tags', null, [
        kind ? UI.el('span', 'tag', kind) : null,
        UI.el('span', `tag${report.claimedBy ? ' tag-rank' : ' tag-danger'}`, report.claimedBy ? '✓' : R.open),
      ].filter(Boolean)),
    ]);
    node.type = 'button';
    node.addEventListener('click', () => {
      selected = report.id;
      render();
    });
    return node;
  }

  async function run(name, id) {
    const result = await Bridge.request(name, id);
    if (UI.report(result, STRINGS.done)) await show(ctx);
  }

  function renderDetail() {
    const report = reports.find((r) => r.id === selected);
    if (!report) {
      ctx.right.replaceChildren(UI.el('p', 'empty', R.none));
      return;
    }
    const present = typeof report.source === 'number';
    const kind = kindLabel(report);
    const p = report.position;
    const position = p && isCoord(p.x) && isCoord(p.y) && isCoord(p.z) ? R.position(p) : null;
    const witnesses = list(report.witnesses).map((w) => (w && typeof w.name === 'string' ? w.name : null)).filter(Boolean);
    // un élément absent (null) deviendrait le texte « null »
    ctx.right.replaceChildren(...[
      UI.heading(R.from(report.author), UI.el('span', 'page-count', R.age(ageText(report.ageMs)))),
      kind ? UI.el('p', 'report-status', kind) : null,
      UI.el('blockquote', 'report-text', report.message),
      position ? UI.el('p', 'report-status', position) : null,
      report.kind === 'player' ? UI.el('p', 'report-status', witnesses.length ? R.witnesses(witnesses) : R.noWitnesses) : null,
      UI.el('p', 'report-status', report.claimedBy ? R.claimedBy(report.claimedBy) : R.open),
      present ? null : UI.el('p', 'empty', R.gone),
      UI.el('div', 'group-buttons', null, [
        !report.claimedBy ? UI.button(R.claim, () => run('reportClaim', report.id)) : null,
        present && ctx.can('teleport') ? UI.button(R.reach, async () => {
          UI.report(await Bridge.request('reach', report.source));
        }) : null,
        present && ctx.can('view') ? UI.button(R.player, () => ctx.goTo('players', { source: report.source })) : null,
        UI.button(R.close, () => run('reportClose', report.id), 'seal'),
      ]),
    ].filter(Boolean));
  }

  function render() {
    ctx.left.replaceChildren(
      UI.heading(R.heading, UI.el('span', 'page-count', String(reports.length))),
      UI.el('div', 'entries', null, reports.length ? reports.map(row) : [UI.el('p', 'empty', R.empty)]),
    );
    renderDetail();
  }

  async function show(context) {
    ctx = context;
    const result = await Bridge.request('reports');
    reports = result.ok ? list(result.result) : [];
    if (!result.ok) UI.report(result);
    if (!reports.some((r) => r.id === selected)) selected = reports.length ? reports[0].id : null;
    render();
  }

  return { id: 'reports', permission: 'reports', show };
})();
