'use strict';
/*
 * web/js/register.js
 * Rôle : registre des murmures, livre à deux pages : les murmures consignés à gauche (les plus récents d'abord :
 *        date, envoyé « À … » ou reçu « De … »), le murmure choisi à droite ; « Arracher la page » le retire
 *        (le jeu le demande au serveur, la page tombe s'il l'accepte).
 */

(() => {
  function dateOf(seconds, texts) {
    const date = new Date(Number(seconds) * 1000);
    const months = Array.isArray(texts.months) ? texts.months : [];
    return UI.format(texts.date, date.getDate(), months[date.getMonth()] || '', date.getHours(), String(date.getMinutes()).padStart(2, '0'));
  }

  /** « À … » ou « De … » ; un murmure reçu d'une présence inconnue n'a pas de contact. */
  function whoOf(page, texts) {
    if (page.direction === 1) return UI.format(texts.sent, page.contact);
    return page.contact ? UI.format(texts.received, page.contact) : texts.unknown;
  }

  function render(root, data) {
    const texts = UI.t('register');
    const pages = Array.isArray(data.pages) ? data.pages.slice() : [];
    let count = Number(data.count) || pages.length;
    let selected = pages.length ? pages[0].id : null;

    const counter = UI.el('span', 'page-count');
    const list = UI.el('div', 'page page-left');
    const spread = UI.el('div', 'pages');

    function detail() {
      const page = pages.find((p) => p.id === selected);
      const right = UI.el('div', 'page page-right');
      if (!page) {
        right.append(UI.el('p', 'empty', texts.empty));
        return right;
      }
      const tear = UI.button(texts.tear, 'ink-button tear-button', async () => {
        tear.disabled = true;
        const answer = await Bridge.post('register:tear', { id: data.id, page: page.id });
        if (!answer || !answer.ok) {
          tear.disabled = false;
          return;
        }
        right.classList.add('is-torn');
        const index = pages.indexOf(page);
        pages.splice(index, 1);
        count = Math.max(0, count - 1);
        selected = pages.length ? pages[Math.min(index, pages.length - 1)].id : null;
        setTimeout(draw, 350);
      });
      right.append(
        UI.el('h3', 'letter-who', whoOf(page, texts)),
        UI.el('p', 'letter-date', dateOf(page.at, texts)),
        UI.el('p', 'letter-text', page.text),
        UI.el('div', 'page-actions', null, [tear]),
      );
      return right;
    }

    function draw() {
      counter.textContent = UI.format(texts.count, count, Number(data.max) || 0);
      list.replaceChildren();
      if (!pages.length) list.append(UI.el('p', 'empty', texts.empty));
      for (const page of pages) {
        const entry = UI.button('', `entry${page.id === selected ? ' is-selected' : ''}`, () => {
          selected = page.id;
          draw();
        });
        entry.append(
          UI.el('span', `entry-mark ${page.direction === 1 ? 'is-sent' : 'is-received'}`),
          UI.el('span', 'entry-main', null, [UI.el('span', 'entry-name', whoOf(page, texts)), UI.el('span', 'entry-sub', dateOf(page.at, texts))]),
        );
        list.append(entry);
      }
      spread.replaceChildren(list, detail());
    }

    root.append(
      UI.el('header', 'book-header', null, [
        UI.el('h1', 'book-title', texts.title),
        counter,
        UI.button('', 'book-close', () => Modal.dismiss()),
      ]),
      spread,
    );
    draw();
  }

  Modal.register('register', render);
})();
