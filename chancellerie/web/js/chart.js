'use strict';
/*
 * web/js/chart.js
 * Rôle : courbes dans le temps, dessinées en SVG (aucune bibliothèque) : un seul axe des valeurs par graphique,
 *        grille discrète, traits de 2 px aux couleurs des séries (feuille de style : .series-1 à .series-3, dans un
 *        ordre fixe), légende avec la dernière valeur dès deux séries, trou dans la courbe quand les relevés
 *        manquent. Au survol : réticule, point sur chaque série et étiquette des valeurs. Redessiné quand sa
 *        largeur change.
 */

const CHART = (() => {
  const NS = 'http://www.w3.org/2000/svg';
  const HEIGHT = 190;
  const PAD = { top: 12, right: 14, bottom: 24, left: 64 };
  const Y_INTERVALS = 4;
  // un écart de plus de 2,5 pas entre deux relevés coupe la courbe (serveur arrêté, Chancellerie fermée)
  const GAP_STEPS = 2.5;
  const TOOLTIP_GAP = 14;
  const X_STEPS = [5 * 60000, 10 * 60000, 15 * 60000, 30 * 60000, 3600000, 2 * 3600000, 3 * 3600000, 6 * 3600000];
  const X_TICKS_MAX = 7;

  function svg(tag, attrs, className) {
    const node = document.createElementNS(NS, tag);
    if (className) node.setAttribute('class', className);
    for (const [key, value] of Object.entries(attrs || {})) node.setAttribute(key, String(value));
    return node;
  }

  /** Plus petit maximum « rond » (1, 2, 2,5, 5 × 10ⁿ) au-dessus de la valeur. */
  function niceMax(value) {
    if (!(value > 0)) return 1;
    const power = 10 ** Math.floor(Math.log10(value));
    for (const step of [1, 2, 2.5, 5, 10]) if (value <= step * power) return step * power;
    return 10 * power;
  }

  /** Index du relevé le plus proche d'un instant (relevés triés par date). */
  function nearest(samples, at) {
    let low = 0;
    let high = samples.length - 1;
    while (high - low > 1) {
      const middle = (low + high) >> 1;
      if (samples[middle].at < at) low = middle;
      else high = middle;
    }
    return Math.abs(samples[low].at - at) <= Math.abs(samples[high].at - at) ? low : high;
  }

  /**
   * @param {{ title: string, series: { key: string, label: string }[], format: (v: number) => string, floor?: number,
   *   integer?: boolean }} options
   *        floor : maximum de l'axe au moins égal à cette valeur (une courbe presque nulle ne remplit pas tout) ;
   *        integer : graduations entières
   */
  function create(options) {
    const { series, format, floor = 0 } = options;
    const node = UI.el('figure', 'chart');
    const legendValues = [];
    if (series.length > 1) {
      const legend = UI.el('ul', 'chart-legend');
      series.forEach((item, index) => {
        const value = UI.el('span', 'chart-legend-value', '—');
        legendValues.push(value);
        legend.append(UI.el('li', null, null, [UI.el('span', `chart-swatch series-${index + 1}`), UI.el('span', null, item.label), value]));
      });
      node.append(legend);
    }
    const plot = UI.el('div', 'chart-plot');
    const root = svg('svg', { height: HEIGHT, role: 'img' }, 'chart-svg');
    const tooltip = UI.el('div', 'chart-tooltip');
    tooltip.hidden = true;
    plot.append(root, tooltip);
    node.append(plot);

    let data = { samples: [], from: 0, to: 1, stepMs: 5000, clock: true };
    let geometry = null;
    let hoverLayer = null;

    function render() {
      const width = Math.max(240, plot.clientWidth || 600);
      root.setAttribute('width', width);
      root.setAttribute('viewBox', `0 0 ${width} ${HEIGHT}`);
      root.replaceChildren();
      const { samples, from, to, stepMs } = data;
      const innerW = width - PAD.left - PAD.right;
      const innerH = HEIGHT - PAD.top - PAD.bottom;
      let top = 0;
      for (const sample of samples) {
        for (const item of series) {
          const value = sample[item.key];
          if (value !== null && value !== undefined && value > top) top = value;
        }
      }
      let yMax = niceMax(Math.max(top, floor));
      // valeurs entières (joueurs) : graduations entières
      if (options.integer) yMax = Math.max(Y_INTERVALS, Math.ceil(yMax / Y_INTERVALS) * Y_INTERVALS);
      const x = (at) => PAD.left + ((at - from) / (to - from)) * innerW;
      const y = (value) => PAD.top + innerH - (value / yMax) * innerH;
      geometry = { x, y, width, innerW };

      const grid = svg('g', null, 'chart-grid');
      for (let i = 0; i <= Y_INTERVALS; i += 1) {
        const value = (yMax / Y_INTERVALS) * i;
        const lineY = y(value);
        grid.append(svg('line', { x1: PAD.left, x2: width - PAD.right, y1: lineY, y2: lineY }, i === 0 ? 'chart-baseline' : null));
        const label = svg('text', { x: PAD.left - 8, y: lineY + 4, 'text-anchor': 'end' }, 'chart-label');
        label.textContent = format(value);
        grid.append(label);
      }
      const span = to - from;
      const xStep = X_STEPS.find((candidate) => span / candidate <= X_TICKS_MAX) || X_STEPS[X_STEPS.length - 1];
      // graduations sur des heures rondes (heure locale)
      const offset = new Date().getTimezoneOffset() * 60000;
      for (let at = Math.ceil((from - offset) / xStep) * xStep + offset; at <= to; at += xStep) {
        const label = svg('text', { x: x(at), y: HEIGHT - 6, 'text-anchor': 'middle' }, 'chart-label');
        label.textContent = STRINGS.time(at);
        grid.append(label);
      }
      root.append(grid);

      const visible = samples.filter((s) => s.at >= from && s.at <= to);
      const hasData = visible.some((s) => series.some((item) => s[item.key] !== null && s[item.key] !== undefined));
      if (!hasData) {
        const empty = svg('text', { x: PAD.left + innerW / 2, y: PAD.top + innerH / 2, 'text-anchor': 'middle' }, 'chart-empty');
        empty.textContent = STRINGS.performance.noData;
        root.append(empty);
      }
      series.forEach((item, index) => {
        // segments continus de points [x, y] : coupés par un relevé manquant ou un trou dans le temps
        const segments = [];
        let previous = null;
        for (const sample of visible) {
          const value = sample[item.key];
          if (value === null || value === undefined) {
            previous = null;
            continue;
          }
          if (!previous || sample.at - previous.at > stepMs * GAP_STEPS) segments.push([]);
          segments[segments.length - 1].push([x(sample.at).toFixed(1), y(value).toFixed(1)]);
          previous = sample;
        }
        if (!segments.length) return;
        const line = segments.map((points) => `M${points.map((p) => p.join(',')).join('L')}`).join('');
        if (series.length === 1) {
          // une seule série : l'aire sous la courbe, à peine teintée, donne du corps à la lecture
          const base = y(0).toFixed(1);
          const area = segments.map((points) => `M${points[0][0]},${base}L${points.map((p) => p.join(',')).join('L')}L${points[points.length - 1][0]},${base}Z`).join('');
          root.append(svg('path', { d: area }, `chart-area series-${index + 1}`));
        }
        root.append(svg('path', { d: line }, `chart-line series-${index + 1}`));
      });

      hoverLayer = svg('g', null, 'chart-hover');
      root.append(hoverLayer);
      root.append(svg('rect', { x: PAD.left, y: PAD.top, width: innerW, height: innerH, fill: 'transparent' }, 'chart-hit'));
      const latest = visible[visible.length - 1];
      root.setAttribute('aria-label', `${options.title}${latest ? ` : ${series.map((item) => `${item.label} ${latest[item.key] === null || latest[item.key] === undefined ? '—' : format(latest[item.key])}`).join(', ')}` : ''}`);
    }

    function hideHover() {
      tooltip.hidden = true;
      if (hoverLayer) hoverLayer.replaceChildren();
    }

    function showHover(event) {
      const visible = data.samples.filter((s) => s.at >= data.from && s.at <= data.to);
      if (!geometry || !visible.length) return;
      const box = root.getBoundingClientRect();
      const pointerX = event.clientX - box.left;
      const at = data.from + ((pointerX - PAD.left) / geometry.innerW) * (data.to - data.from);
      const sample = visible[nearest(visible, at)];
      // loin de tout relevé (trou, début de période sans données) : rien à montrer
      if (Math.abs(sample.at - at) > data.stepMs * GAP_STEPS) {
        hideHover();
        return;
      }
      const lineX = geometry.x(sample.at);
      hoverLayer.replaceChildren(svg('line', { x1: lineX, x2: lineX, y1: PAD.top, y2: HEIGHT - PAD.bottom }, 'chart-crosshair'));
      const rows = [UI.el('p', 'chart-tooltip-time', data.clock ? STRINGS.clock(sample.at) : STRINGS.time(sample.at))];
      series.forEach((item, index) => {
        const value = sample[item.key];
        if (value !== null && value !== undefined) {
          hoverLayer.append(svg('circle', { cx: lineX, cy: geometry.y(value), r: 4 }, `chart-dot series-${index + 1}`));
        }
        rows.push(UI.el('p', 'chart-tooltip-row', null, [
          UI.el('span', `chart-swatch series-${index + 1}`), UI.el('span', null, item.label),
          UI.el('strong', null, value === null || value === undefined ? '—' : format(value)),
        ]));
      });
      tooltip.replaceChildren(...rows);
      tooltip.hidden = false;
      const width = tooltip.offsetWidth;
      const left = lineX + TOOLTIP_GAP + width > geometry.width ? lineX - TOOLTIP_GAP - width : lineX + TOOLTIP_GAP;
      tooltip.style.left = `${Math.max(0, left)}px`;
    }

    root.addEventListener('pointermove', showHover);
    root.addEventListener('pointerleave', hideHover);
    const observer = new ResizeObserver(() => render());
    observer.observe(plot);

    return {
      node,
      /** @param {{ samples: object[], from: number, to: number, stepMs: number, clock: boolean }} next */
      update(next) {
        data = next;
        const latest = next.samples[next.samples.length - 1];
        series.forEach((item, index) => {
          if (!legendValues[index]) return;
          const value = latest ? latest[item.key] : null;
          legendValues[index].textContent = value === null || value === undefined ? '—' : format(value);
        });
        render();
        if (!tooltip.hidden) hideHover();
      },
      destroy() {
        observer.disconnect();
      },
    };
  }

  return { create };
})();
