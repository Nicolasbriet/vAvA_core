'use strict';
/*
 * web/js/grimoire.js
 * Rôle : grimoire, livre de cuir à deux pages : sorts connus à gauche ; à droite, le sort choisi (niveau en chiffres
 *        romains sur un sceau, barre d'XP dorée, ce que l'on sait, ce que débloque le niveau suivant, mana, recharge,
 *        touche, sigils mémorisables, couleur de la lumière quand le niveau le permet). Pour un non-mage, pages
 *        illisibles. Échap ou le ruban de fermeture le referment.
 */

(() => {
  let selected = null;

  function header(texts) {
    return UI.el('header', 'book-header', null, [
      UI.el('h1', 'book-title', texts.title),
      UI.button('', 'book-close', () => Modal.dismiss()),
    ]);
  }

  function detail(spell, texts) {
    const page = UI.el('div', 'page page-right');
    const atMax = spell.to === null || spell.to === undefined;
    const share = atMax ? 1 : Math.max(0, Math.min(1, (spell.xp - spell.from) / Math.max(1, spell.to - spell.from)));
    const fill = UI.el('div', 'xp-fill');
    fill.style.transform = `scaleX(${share})`;
    const facts = [UI.format(texts.cost, spell.cost), UI.format(texts.cooldown, spell.cooldown),
      UI.format(texts.key, spell.key || texts.noKey)];
    if (spell.lock) facts.push(UI.format(texts.lock, spell.lock));
    if (spell.sigils) facts.push(UI.format(texts.sigils, spell.sigils));

    UI.append(page,
      UI.el('div', 'spell-head', null, [
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
    );
    if (Array.isArray(spell.colors) && spell.colors.length) {
      const swatches = UI.el('div', 'swatches');
      for (const color of spell.colors) {
        const swatch = UI.button('', `swatch${color.name === spell.color ? ' is-selected' : ''}`, () => {
          for (const other of swatches.children) other.classList.remove('is-selected');
          swatch.classList.add('is-selected');
          spell.color = color.name;
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
    if (!spells.some((s) => s.name === selected)) selected = spells[0].name;
    const list = UI.el('div', 'page page-left');
    const pages = UI.el('div', 'pages');
    const show = () => {
      for (const entry of list.children) entry.classList.toggle('is-selected', entry.dataset.name === selected);
      const spell = spells.find((s) => s.name === selected);
      const right = pages.querySelector('.page-right');
      const next = detail(spell, texts);
      if (right) right.replaceWith(next); else pages.append(next);
    };
    for (const spell of spells) {
      const entry = UI.button('', 'entry', () => {
        selected = spell.name;
        show();
      });
      entry.dataset.name = spell.name;
      entry.append(
        UI.el('span', 'entry-seal', UI.roman(spell.level)),
        UI.el('span', 'entry-main', null, [UI.el('span', 'entry-name', spell.label), UI.el('span', 'entry-sub', UI.format(texts.level, spell.level))]),
      );
      list.append(entry);
    }
    pages.append(list);
    root.append(pages);
    show();
  }

  Modal.register('grimoire', render);
})();
