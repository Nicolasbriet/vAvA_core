'use strict';
/*
 * web/js/view-performance.js
 * Rôle : la page Performances : chiffres du dernier relevé (processeur et mémoire de FXServer et de la machine, débit
 *        réseau reçu et envoyé, joueurs, tick principal), puis une courbe par mesure — processeur, mémoire de
 *        FXServer, bande passante, joueurs, durée des ticks — sur la dernière heure (chaque relevé, en direct) ou sur
 *        24 heures (moyennes par minute, relues chaque minute). Les mêmes relevés se lisent aussi en tableau.
 */

const PerformanceView = (() => {
  const P = STRINGS.performance;
  const SPANS = { hour: 3600 * 1000, day: 24 * 3600 * 1000 };
  const DAY_REFRESH_MS = 60000;
  const TABLE_ROWS = 120;
  const MB = 1024 * 1024;
  const count = (value) => String(Math.round(value));

  // une courbe par mesure, un seul axe chacune ; séries dans un ordre fixe (couleurs .series-1, -2, -3)
  const CHARTS = [
    { id: 'cpu', keys: ['fxCpu', 'cpu'], format: STRINGS.percent, floor: 10 },
    { id: 'memory', keys: ['fxMem'], format: STRINGS.bytes, floor: 256 * MB },
    { id: 'network', keys: ['rx', 'tx'], format: STRINGS.bitrate, floor: 12500 },
    { id: 'players', keys: ['players'], format: count, floor: 4, integer: true },
    { id: 'ticks', keys: ['tickMain', 'tickNetwork', 'tickSync'], format: STRINGS.ms, floor: 10 },
  ];

  let sheet = null;
  let context = null;
  let refs = null;
  let charts = [];
  let range = 'hour';
  let samples = [];
  let stepMs = 5000;
  let cores = 1;
  let latest = null;
  let timer = null;
  let table = false;

  const now = () => Date.now() - ((context && context.status().skew) || 0);

  function fact(label, value, small) {
    return UI.el('div', 'fact', null, [UI.el('dt', null, label), UI.el('dd', null, value, small ? [document.createTextNode(' '), UI.el('small', null, small)] : null)]);
  }

  function renderFacts() {
    const s = latest || {};
    const F = P.facts;
    refs.facts.replaceChildren(
      fact(F.fxCpu, STRINGS.percent(s.fxCpu), P.cpuHelp(cores)),
      fact(F.fxMem, STRINGS.bytes(s.fxMem)),
      fact(F.hostCpu, STRINGS.percent(s.cpu)),
      fact(F.hostMem, STRINGS.bytes(s.memUsed), s.memTotal ? P.memOf(STRINGS.bytes(s.memTotal)) : null),
      fact(F.rx, STRINGS.bitrate(s.rx)),
      fact(F.tx, STRINGS.bitrate(s.tx)),
      fact(F.players, s.players === null || s.players === undefined ? '—' : String(s.players)),
      fact(F.tick, STRINGS.ms(s.tickMain)),
    );
    const notes = [];
    if (!latest) notes.push(P.collecting);
    else if (latest.fxMem === null) notes.push(P.stopped);
    else if (latest.state === 'running' && samples.slice(-3).every((x) => x.tickMain === null)) notes.push(P.perfMissing);
    refs.notes.replaceChildren(...notes.map((text) => UI.el('p', 'hint', text)));
  }

  function period() {
    const to = now();
    return { from: to - SPANS[range], to };
  }

  function renderCharts() {
    const { from, to } = period();
    for (const chart of charts) chart.update({ samples, from, to, stepMs, clock: range === 'hour' });
  }

  function renderTable() {
    const rows = samples.slice(-TABLE_ROWS).reverse().map((s) => UI.el('tr', null, null, [
      UI.el('td', 'cell-date', range === 'hour' ? STRINGS.clock(s.at) : STRINGS.date(s.at)),
      UI.el('td', 'cell-end', STRINGS.percent(s.fxCpu)), UI.el('td', 'cell-end', STRINGS.percent(s.cpu)),
      UI.el('td', 'cell-end', STRINGS.bytes(s.fxMem)), UI.el('td', 'cell-end', STRINGS.bitrate(s.rx)),
      UI.el('td', 'cell-end', STRINGS.bitrate(s.tx)), UI.el('td', 'cell-end', s.players === null ? '—' : String(s.players)),
      UI.el('td', 'cell-end', STRINGS.ms(s.tickMain)),
    ]));
    refs.table.replaceChildren(rows.length ? UI.el('table', 'ledger', null, [
      UI.el('thead', null, null, [UI.el('tr', null, null, P.tableColumns.map((c, i) => UI.el('th', i ? 'cell-end' : null, c)))]),
      UI.el('tbody', null, null, rows),
    ]) : UI.el('p', 'empty', P.noData));
  }

  function render() {
    renderFacts();
    refs.charts.hidden = table;
    refs.table.hidden = !table;
    refs.toggle.textContent = table ? P.hideTable : P.showTable;
    if (table) renderTable();
    else renderCharts();
  }

  async function load() {
    const result = await API.get(`/api/metrics?range=${range}`);
    if (!sheet) return;
    if (!result.ok) {
      UI.report(result);
      return;
    }
    samples = UI.list(result.samples);
    stepMs = result.stepMs;
    cores = result.cores;
    if (result.latest) latest = result.latest;
    render();
  }

  function setRange(next) {
    range = next;
    for (const button of refs.ranges.children) button.classList.toggle('is-selected', button.dataset.range === range);
    clearInterval(timer);
    timer = range === 'day' ? setInterval(load, DAY_REFRESH_MS) : null;
    load();
  }

  function build() {
    refs = {
      facts: UI.el('dl', 'facts facts-wide'),
      notes: UI.el('div'),
      ranges: UI.el('div', 'stamps'),
      charts: UI.el('div', 'chart-board'),
      table: UI.el('div', 'perf-table'),
      toggle: UI.button(P.showTable, () => {
        table = !table;
        render();
      }),
    };
    for (const id of ['hour', 'day']) {
      const button = UI.button(P.ranges[id], () => setRange(id));
      button.className = `stamp${id === range ? ' is-selected' : ''}`;
      button.dataset.range = id;
      refs.ranges.append(button);
    }
    charts = CHARTS.map((def) => {
      const text = P.charts[def.id];
      const chart = CHART.create({
        title: text.title, format: def.format, floor: def.floor, integer: def.integer,
        series: def.keys.map((key) => ({ key, label: P.series[key] })),
      });
      refs.charts.append(UI.el('section', `chart-card${def.id === 'ticks' ? ' is-wide' : ''}`, null, [
        UI.el('h3', 'section-title', text.title), UI.el('p', 'chart-help', text.help), chart.node,
      ]));
      return chart;
    });
  }

  return {
    show(target, appContext) {
      sheet = target;
      context = appContext;
      build();
      sheet.replaceChildren(
        UI.heading(P.title),
        UI.el('div', 'perf-bar', null, [refs.ranges, UI.el('span', 'spacer'), refs.toggle]),
        refs.facts,
        refs.notes,
        refs.charts,
        refs.table,
      );
      latest = null;
      samples = [];
      renderFacts();
      setRange(range);
    },

    hide() {
      clearInterval(timer);
      timer = null;
      for (const chart of charts) chart.destroy();
      charts = [];
      sheet = null;
      refs = null;
    },

    /** Nouveau relevé (toutes les quelques secondes). */
    metrics(sample) {
      if (!sheet) return;
      latest = sample;
      if (range === 'hour') {
        samples.push(sample);
        const oldest = now() - SPANS.hour;
        while (samples.length && samples[0].at < oldest) samples.shift();
        if (table) {
          renderFacts();
          renderTable();
        } else {
          render();
        }
      } else {
        renderFacts();
      }
    },
  };
})();
