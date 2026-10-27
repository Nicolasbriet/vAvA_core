'use strict';
/*
 * web/js/ansi.js
 * Rôle : les couleurs de la console de FXServer (séquences ANSI) rendues en fragments de texte colorés. Seules
 *        les séquences de style sont comprises ; toute autre séquence est retirée. Aucun HTML n'est interprété.
 *        Les couleurs trop sombres pour l'ardoise sont éclaircies.
 */

const ANSI = (() => {
  const SEQUENCE = /\x1b\[([0-9;]*)([A-Za-z])/g;
  const BASE = [
    [40, 34, 28], [205, 96, 80], [137, 172, 96], [214, 170, 92], [104, 140, 180], [178, 120, 170], [96, 172, 170], [214, 204, 182],
    [110, 98, 86], [232, 128, 108], [168, 204, 120], [240, 204, 120], [140, 176, 214], [208, 150, 200], [130, 204, 200], [244, 236, 220],
  ];
  const CUBE = [0, 95, 135, 175, 215, 255];
  const MIN_LIGHT = 105;

  /** Couleur de la palette 256 → [r, g, b]. */
  function palette(index) {
    if (index < 16) return BASE[index];
    if (index < 232) {
      const value = index - 16;
      return [CUBE[Math.floor(value / 36)], CUBE[Math.floor(value / 6) % 6], CUBE[value % 6]];
    }
    const grey = 8 + (index - 232) * 10;
    return [grey, grey, grey];
  }

  /** Éclaircit une couleur illisible sur l'ardoise, en gardant sa teinte. */
  function readable([r, g, b]) {
    const light = 0.299 * r + 0.587 * g + 0.114 * b;
    if (light >= MIN_LIGHT) return `rgb(${r}, ${g}, ${b})`;
    const lift = (MIN_LIGHT - light) / (255 - light);
    const up = (value) => Math.round(value + (255 - value) * lift);
    return `rgb(${up(r)}, ${up(g)}, ${up(b)})`;
  }

  function applyCodes(style, codes) {
    for (let i = 0; i < codes.length; i += 1) {
      const code = codes[i];
      if (code === 0) Object.assign(style, { color: null, bold: false, dim: false, italic: false, underline: false });
      else if (code === 1) style.bold = true;
      else if (code === 2) style.dim = true;
      else if (code === 3) style.italic = true;
      else if (code === 4) style.underline = true;
      else if (code === 22) { style.bold = false; style.dim = false; }
      else if (code === 23) style.italic = false;
      else if (code === 24) style.underline = false;
      else if (code >= 30 && code <= 37) style.color = palette(code - 30);
      else if (code >= 90 && code <= 97) style.color = palette(code - 90 + 8);
      else if (code === 39) style.color = null;
      else if (code === 38 && codes[i + 1] === 5 && codes[i + 2] !== undefined) {
        style.color = palette(codes[i + 2] & 255);
        i += 2;
      } else if (code === 38 && codes[i + 1] === 2 && codes[i + 4] !== undefined) {
        style.color = [codes[i + 2] & 255, codes[i + 3] & 255, codes[i + 4] & 255];
        i += 4;
      } else if (code === 48 && (codes[i + 1] === 5 || codes[i + 1] === 2)) {
        // fonds ignorés : l'ardoise garde sa couleur
        i += codes[i + 1] === 5 ? 2 : 4;
      }
    }
  }

  function span(text, style) {
    if (!style.color && !style.bold && !style.dim && !style.italic && !style.underline) return document.createTextNode(text);
    const node = document.createElement('span');
    const classes = [];
    if (style.bold) classes.push('ansi-bold');
    if (style.dim) classes.push('ansi-dim');
    if (style.italic) classes.push('ansi-italic');
    if (style.underline) classes.push('ansi-underline');
    if (classes.length) node.className = classes.join(' ');
    if (style.color) node.style.color = readable(style.color);
    node.textContent = text;
    return node;
  }

  /** Texte d'une ligne → nœuds à ajouter. */
  function render(text) {
    const nodes = [];
    const style = { color: null, bold: false, dim: false, italic: false, underline: false };
    let last = 0;
    SEQUENCE.lastIndex = 0;
    let match;
    while ((match = SEQUENCE.exec(text))) {
      if (match.index > last) nodes.push(span(text.slice(last, match.index), style));
      if (match[2] === 'm') applyCodes(style, match[1] === '' ? [0] : match[1].split(';').map(Number));
      last = SEQUENCE.lastIndex;
    }
    if (last < text.length) nodes.push(span(text.slice(last), style));
    return nodes;
  }

  /** Texte sans aucune séquence (recherche, copie). */
  function strip(text) {
    return text.replace(SEQUENCE, '');
  }

  return { render, strip };
})();
