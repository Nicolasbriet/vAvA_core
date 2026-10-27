'use strict';
/*
 * web/js/controls.js
 * Rôle : construction du DOM et contrôles réutilisables (curseur, sélecteur à flèches, couleur de palette,
 *        choix segmenté, champ texte).
 *        Chaque contrôle se met à jour localement et immédiatement ; l'envoi au jeu est planifié par l'appelant.
 */

const UI = (() => {
  /** Crée un élément. `props` : class, text, html (contenu de confiance uniquement), on<event>, attributs. */
  function el(tag, props = {}, children = []) {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(props)) {
      if (value === undefined || value === null || value === false) continue;
      if (key === 'class') node.className = value;
      else if (key === 'text') node.textContent = value;
      else if (key === 'html') node.innerHTML = value;
      else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
      else node.setAttribute(key, value === true ? '' : value);
    }
    for (const child of [].concat(children)) if (child) node.append(child);
    return node;
  }

  function icon(name) {
    return el('span', { class: 'icon', 'aria-hidden': 'true', html: ICONS[name] });
  }

  function iconButton(name, label, onclick, extraClass = '') {
    return el('button', { type: 'button', class: `icon-button ${extraClass}`, title: label, 'aria-label': label, onclick }, [icon(name)]);
  }

  function group(title, children, actions) {
    return el('section', { class: 'group' }, [
      title ? el('header', { class: 'group-head' }, [el('h3', { class: 'group-title', text: title }), actions || null]) : null,
      ...children,
    ]);
  }

  /** Curseur continu. `format` affiche la valeur ; les légendes optionnelles encadrent la piste. */
  function slider({ label, min, max, step, value, format, legends, onInput }) {
    const output = el('output', { class: 'control-value' });
    const input = el('input', { type: 'range', class: 'slider', min, max, step, value, 'aria-label': label });
    const update = () => {
      const current = Number(input.value);
      output.textContent = format ? format(current) : String(current);
      input.style.setProperty('--fill', `${((current - min) / (max - min)) * 100}%`);
    };
    input.addEventListener('input', () => {
      update();
      onInput(Number(input.value));
    });
    update();
    const node = el('div', { class: 'control' }, [
      el('div', { class: 'control-head' }, [el('span', { class: 'control-label', text: label }), output]),
      input,
      legends ? el('div', { class: 'slider-legends' }, [el('span', { text: legends[0] }), el('span', { text: legends[1] })]) : null,
    ]);
    return {
      node,
      set(next) {
        input.value = next;
        update();
      },
    };
  }

  /**
   * Sélecteur d'index à flèches pour les listes longues (coupes, vêtements) : boutons, flèches du clavier,
   * molette (Maj : par 10). Circulaire : après le dernier vient le premier.
   */
  function stepper({ label, min, max, value, format, onChange }) {
    let low = min;
    let high = max;
    let current = value;
    let enabled = true;
    const display = el('span', { class: 'stepper-display' });
    const count = el('span', { class: 'stepper-count' });
    const render = () => {
      display.textContent = format ? format(current) : String(current - low + 1);
      count.textContent = high >= low ? `/ ${high - low + 1}` : '';
    };
    const move = (delta) => {
      if (!enabled || high < low) return;
      const span = high - low + 1;
      current = low + ((((current - low + delta) % span) + span) % span);
      render();
      onChange(current);
    };
    const field = el('div', {
      class: 'stepper-field', tabindex: '0', role: 'spinbutton', 'aria-label': label,
      onkeydown: (event) => {
        if (event.key === 'ArrowLeft' || event.key === 'ArrowDown') { event.preventDefault(); move(-1); }
        if (event.key === 'ArrowRight' || event.key === 'ArrowUp') { event.preventDefault(); move(1); }
      },
      onwheel: (event) => {
        event.preventDefault();
        move((event.deltaY > 0 ? 1 : -1) * (event.shiftKey ? 10 : 1));
      },
    }, [display, count]);
    render();
    const node = el('div', { class: 'control' }, [
      el('div', { class: 'control-head' }, [el('span', { class: 'control-label', text: label })]),
      el('div', { class: 'stepper' }, [
        iconButton('left', `${label} : précédent`, () => move(-1)),
        field,
        iconButton('right', `${label} : suivant`, () => move(1)),
      ]),
    ]);
    return {
      node,
      set(next) {
        current = next;
        render();
      },
      /** Nouvelle borne haute (nombre de variantes connu après un changement) ; renvoie la valeur, recadrée. */
      setMax(next) {
        high = next;
        if (current > high) current = Math.max(low, high);
        render();
        return current;
      },
      /** Désactive le contrôle quand il n'a pas d'objet (variante d'un accessoire absent). */
      setEnabled(next) {
        enabled = next;
        node.classList.toggle('is-disabled', !next);
        for (const button of node.querySelectorAll('button')) button.disabled = !next;
        field.tabIndex = next ? 0 : -1;
      },
    };
  }

  const rgb = ([r, g, b]) => `rgb(${r}, ${g}, ${b})`;

  /** Grille de pastilles fidèles aux palettes du jeu. */
  function swatchGrid({ label, colors, value, onPick }) {
    let current = value;
    const buttons = colors.map((color, index) => el('button', {
      type: 'button', class: 'swatch', style: `--swatch: ${rgb(color)}`, 'aria-label': `${label} ${index + 1}`,
      onclick: () => onPick(index),
    }));
    const set = (index) => {
      if (buttons[current]) buttons[current].classList.remove('is-selected');
      current = index;
      if (buttons[current]) buttons[current].classList.add('is-selected');
    };
    set(value);
    return { node: el('div', { class: 'swatches', role: 'group', 'aria-label': label }, buttons), set };
  }

  /**
   * Couleur d'une palette, compacte : flèches et molette pour parcourir, pastille de la couleur choisie,
   * palette complète dépliée au clic.
   */
  function colorPicker({ label, colors, value, onPick }) {
    let current = Math.min(value, colors.length - 1);
    const chip = el('span', { class: 'color-chip' });
    const count = el('span', { class: 'stepper-count' });
    const render = () => {
      chip.style.setProperty('--swatch', rgb(colors[current] || [0, 0, 0]));
      count.textContent = `${current + 1} / ${colors.length}`;
    };
    const pick = (next) => {
      current = next;
      render();
      grid.set(next);
      onPick(next);
    };
    const move = (delta) => pick((((current + delta) % colors.length) + colors.length) % colors.length);
    const grid = swatchGrid({ label, colors, value: current, onPick: pick });
    grid.node.hidden = true;
    const field = el('button', {
      type: 'button', class: 'stepper-field color-field', 'aria-label': label, 'aria-expanded': 'false',
      onclick: () => {
        grid.node.hidden = !grid.node.hidden;
        field.setAttribute('aria-expanded', grid.node.hidden ? 'false' : 'true');
      },
      onkeydown: (event) => {
        if (event.key === 'ArrowLeft' || event.key === 'ArrowDown') { event.preventDefault(); move(-1); }
        if (event.key === 'ArrowRight' || event.key === 'ArrowUp') { event.preventDefault(); move(1); }
      },
      onwheel: (event) => {
        event.preventDefault();
        move(event.deltaY > 0 ? 1 : -1);
      },
    }, [chip, count]);
    render();
    const node = el('div', { class: 'control' }, [
      el('div', { class: 'control-head' }, [el('span', { class: 'control-label', text: label })]),
      el('div', { class: 'stepper' }, [
        iconButton('left', `${label} : précédente`, () => move(-1)),
        field,
        iconButton('right', `${label} : suivante`, () => move(1)),
      ]),
      grid.node,
    ]);
    return { node };
  }

  /** Choix exclusif en boutons accolés. */
  function segmented({ label, options, value, onChange }) {
    const buttons = new Map();
    const select = (next) => {
      for (const [key, button] of buttons) {
        button.classList.toggle('is-selected', key === next);
        button.setAttribute('aria-pressed', key === next ? 'true' : 'false');
      }
    };
    for (const option of options) {
      buttons.set(option.value, el('button', {
        type: 'button', class: 'segment', onclick: () => {
          if (!buttons.get(option.value).classList.contains('is-selected')) onChange(option.value);
        },
      }, [option.label]));
    }
    select(value);
    const node = el('div', { class: 'control' }, [
      el('div', { class: 'control-head' }, [el('span', { class: 'control-label', text: label })]),
      el('div', { class: 'segmented', role: 'group', 'aria-label': label }, [...buttons.values()]),
    ]);
    return { node, set: select };
  }

  /** Champ texte avec message d'aide ou d'erreur. */
  function textField({ label, value, maxLength, hint, onInput }) {
    const id = `field-${Math.random().toString(36).slice(2, 9)}`;
    const input = el('input', { id, type: 'text', class: 'text-input', value, maxlength: maxLength, autocomplete: 'off', spellcheck: 'false' });
    const message = el('p', { class: 'field-hint', text: hint || '' });
    input.addEventListener('input', () => onInput(input.value));
    const node = el('div', { class: 'control' }, [el('label', { class: 'control-label', for: id, text: label }), input, message]);
    return {
      node,
      input,
      setError(error) {
        node.classList.toggle('has-error', Boolean(error));
        message.textContent = error || hint || '';
      },
    };
  }

  return { el, icon, iconButton, group, slider, stepper, colorPicker, segmented, textField };
})();
