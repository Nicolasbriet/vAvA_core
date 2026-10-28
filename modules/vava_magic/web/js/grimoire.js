'use strict';
/*
 * web/js/grimoire.js
 * Rôle : grimoire, livre de cuir à deux pages : sorts connus à gauche, rangés par élément ; à droite, le sort choisi
 *        (icône aux couleurs de l'élément, niveau en chiffres romains sur un sceau, barre d'XP dorée, ce que l'on
 *        sait, ce que débloque le niveau suivant, mana, recharge, incantation, élément, commandes, sigils
 *        mémorisables, couleur de la lumière quand le niveau le permet). Après les sorts, les combinaisons
 *        découvertes (deux éléments, déclencheur, résultat) et le compte de celles qui restent à trouver. Pour un
 *        non-mage, pages illisibles. Échap ou le ruban de fermeture le referment.
 */

(() => {
  // part de la couleur gardée pour une icône posée sur le parchemin
  const INK_SHADE = 0.62;
  let selected = null;

  function header(texts) {
    return UI.el('header', 'book-header', null, [
      UI.el('h1', 'book-title', texts.title),
      UI.button('', 'book-close', () => Modal.dismiss()),
    ]);
  }

  /** Icône d'un sort aux couleurs de son élément. */
  function spellIcon(spell, className) {
    const icon = UI.el('span', className);
    if (spell.icon) icon.style.setProperty('--icon', UI.image(`img/spells/${spell.icon}.svg`));
    // sur le parchemin, la couleur de l'élément est foncée pour rester lisible
    const c = spell.color || { r: 190, g: 136, b: 64 };
    const ink = (value) => Math.round(value * INK_SHADE);
    icon.style.setProperty('--element', `rgb(${ink(c.r)}, ${ink(c.g)}, ${ink(c.b)})`);
    return icon;
  }

  /** Deux icônes d'éléments en quinconce, aux couleurs (foncées) de chacun. */
  function elementPair(combo, className) {
    const pair = UI.el('span', `icon-pair ${className}`);
    for (const element of Array.isArray(combo.elements) ? combo.elements.slice(0, 2) : []) {
      pair.append(spellIcon({ icon: null, color: element.color }, 'pair-icon'));
      const node = pair.lastElementChild;
      if (element.icon) node.style.setProperty('--icon', UI.image(`img/elements/${element.icon}.svg`));
    }
    return pair;
  }

  function comboDetail(combo, texts) {
    const page = UI.el('div', 'page page-right');
    const names = (Array.isArray(combo.elements) ? combo.elements : []).map((e) => e.label).filter(Boolean).join(' · ');
    UI.append(page,
      UI.el('div', 'spell-head', null, [elementPair(combo, 'is-large'), UI.title(combo.label, 'page-title')]),
      combo.summary ? UI.el('p', 'summary', combo.summary) : null,
      UI.el('h3', 'section-title', texts.comboTrigger),
      UI.el('p', 'prose', combo.trigger || ''),
      UI.el('h3', 'section-title', texts.comboResult),
      UI.el('p', 'prose', combo.result || ''),
      names ? UI.el('ul', 'facts', null, [UI.el('li', null, UI.format(texts.comboElements, names))]) : null,
    );
    return page;
  }

  function detail(spell, texts, controls) {
    const page = UI.el('div', 'page page-right');
    const atMax = spell.to === null || spell.to === undefined;
    const share = atMax ? 1 : Math.max(0, Math.min(1, (spell.xp - spell.from) / Math.max(1, spell.to - spell.from)));
    const fill = UI.el('div', 'xp-fill');
    fill.style.transform = `scaleX(${share})`;
    const facts = [UI.format(texts.cost, spell.cost), UI.format(texts.cooldown, spell.cooldown),
      spell.cast ? UI.format(texts.cast, spell.cast) : texts.instant];
    if (spell.element) facts.push(UI.format(texts.element, spell.element));
    if (spell.lock) facts.push(UI.format(texts.lock, spell.lock));
    if (spell.sigils) facts.push(UI.format(texts.sigils, spell.sigils));

    UI.append(page,
      UI.el('div', 'spell-head', null, [
        spellIcon(spell, 'spell-icon'),
        UI.title(spell.label, 'page-title'),
        UI.el('span', 'level-seal', UI.roman(spell.level)),
      ]),
      spell.summary ? UI.el('p', 'summary', spell.summary) : null,
      UI.el('div', 'xp', null, [
        UI.el('div', 'xp-track', null, [fill]),
        UI.el('span', 'xp-caption', atMax ? `${UI.format(texts.xpMax, spell.xp)} · ${texts.mastered}` : UI.format(texts.xp, spell.xp, spell.to)),
      ]),
      UI.el('h3', 'section-title', `${texts.current} — ${UI.format(texts.level, spell.level)}`),
      UI.el('p', 'prose', spell.description),
      spell.next ? UI.el('h3', 'section-title', texts.next) : null,
      spell.next ? UI.el('p', 'prose is-next', spell.next) : null,
      UI.el('ul', 'facts', null, facts.map((fact) => UI.el('li', null, fact))),
      controls ? UI.el('p', 'controls-line', UI.format(texts.controls, controls.wheel, controls.aim, controls.cast)) : null,
    );
    if (Array.isArray(spell.colors) && spell.colors.length) {
      const swatches = UI.el('div', 'swatches');
      for (const color of spell.colors) {
        const swatch = UI.button('', `swatch${color.name === spell.lightColor ? ' is-selected' : ''}`, () => {
          for (const other of swatches.children) other.classList.remove('is-selected');
          swatch.classList.add('is-selected');
          spell.lightColor = color.name;
          Bridge.post('grimoire:color', { name: color.name });
        });
        swatch.title = color.label;
        swatch.setAttribute('aria-label', color.label);
        swatch.style.setProperty('--swatch', `rgb(${color.r}, ${color.g}, ${color.b})`);
        swatches.append(UI.el('div', 'swatch-cell', null, [swatch, UI.el('span', 'swatch-label', color.label)]));
      }
      page.append(UI.el('h3', 'section-title', texts.colors), swatches);
    }
    return page;
  }

  function render(root, data) {
    const texts = UI.t('grimoire');
    root.append(header(texts));
    if (data.sealed) {
      root.append(UI.el('div', 'pages is-sealed', null, [
        UI.el('div', 'page page-left', null, [UI.el('div', 'illegible')]),
        UI.el('div', 'page page-right', null, [UI.el('p', 'sealed-text', texts.sealed), UI.el('div', 'illegible is-short')]),
      ]));
      return;
    }
    const spells = Array.isArray(data.spells) ? data.spells : [];
    if (!spells.length) {
      root.append(UI.el('div', 'pages is-single', null, [UI.el('div', 'page', null, [UI.el('p', 'empty', texts.empty)])]));
      return;
    }
    const combos = Array.isArray(data.combos) ? data.combos : [];
    const hidden = Number(data.hiddenCombos) || 0;
    const comboKey = (combo) => `combo:${combo.id}`;
    if (!spells.some((s) => s.name === selected) && !combos.some((c) => comboKey(c) === selected)) selected = spells[0].name;
    const list = UI.el('div', 'page page-left');
    const pages = UI.el('div', 'pages');
    const show = () => {
      for (const entry of list.querySelectorAll('.entry')) entry.classList.toggle('is-selected', entry.dataset.name === selected);
      const combo = combos.find((c) => comboKey(c) === selected);
      const spell = spells.find((s) => s.name === selected);
      const right = pages.querySelector('.page-right');
      const next = combo ? comboDetail(combo, texts) : detail(spell, texts, data.controls);
      if (right) right.replaceWith(next); else pages.append(next);
    };
    // un titre par élément (ordre de la roue), puis ses sorts
    const labels = {};
    for (const group of Array.isArray(data.groups) ? data.groups : []) labels[group.id] = group.label;
    let lastGroup = null;
    for (const spell of spells) {
      if (spell.group && spell.group !== lastGroup) {
        lastGroup = spell.group;
        list.append(UI.el('h3', 'entry-group', labels[spell.group] || spell.element || ''));
      }
      const entry = UI.button('', 'entry is-spell', () => {
        selected = spell.name;
        show();
      });
      entry.dataset.name = spell.name;
      entry.append(
        spellIcon(spell, 'entry-icon'),
        UI.el('span', 'entry-main', null, [UI.el('span', 'entry-name', spell.label), UI.el('span', 'entry-sub', UI.format(texts.level, spell.level))]),
        UI.el('span', 'entry-seal', UI.roman(spell.level)),
      );
      list.append(entry);
    }
    // combinaisons découvertes, puis le compte de celles qui restent (sans les nommer)
    list.append(UI.el('h3', 'entry-group', texts.combos));
    for (const combo of combos) {
      const entry = UI.button('', 'entry is-spell is-combo', () => {
        selected = comboKey(combo);
        show();
      });
      entry.dataset.name = comboKey(combo);
      const names = (Array.isArray(combo.elements) ? combo.elements : []).map((e) => e.label).filter(Boolean).join(' · ');
      entry.append(
        elementPair(combo, ''),
        UI.el('span', 'entry-main', null, [UI.el('span', 'entry-name', combo.label), UI.el('span', 'entry-sub', names)]),
        UI.el('span', 'entry-seal is-combo', '✦'),
      );
      list.append(entry);
    }
    if (!combos.length) list.append(UI.el('p', 'entry-note', texts.combosNone));
    else if (hidden > 0) list.append(UI.el('p', 'entry-note', UI.format(texts.combosHidden, hidden)));
    pages.append(list);
    root.append(pages);
    show();
  }

  Modal.register('grimoire', render);
})();
