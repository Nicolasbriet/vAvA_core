'use strict';
/*
 * web/js/register.js
 * Rôle : registre des murmures, livre à deux pages : les murmures consignés à gauche (les plus récents d'abord :
 *        date, envoyé « À … » ou reçu « De … »), le murmure choisi à droite ; « Arracher la page » le retire
 *        (le jeu le demande au serveur, la page tombe s'il l'accepte). Seul le premier lot arrive à l'ouverture ;
 *        « tourner les pages plus anciennes » demande le lot suivant (curseur : la plus ancienne page reçue). Les
 *        lots reçus restent tant que le registre est ouvert ; refermé, il repart du premier lot.
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

  /** Page lisible venue du jeu (numéro entier positif). */
  function isPage(page) {
    return !!page && typeof page === 'object' && Number.isInteger(page.id) && page.id > 0;
  }

  function render(root, data) {
    const texts = UI.t('register');
    const pages = Array.isArray(data.pages) ? data.pages.filter(isPage) : [];
    const known = new Set(pages.map((p) => p.id));
    let count = Number(data.count) || pages.length;
    let selected = pages.length ? pages[0].id : null;
    // lot suivant : avant la plus ancienne page reçue (une page arrachée ne change pas le curseur)
    let cursor = pages.length ? pages[pages.length - 1].id : null;
    let more = data.more === true && cursor !== null;
    let loading = false;

    const counter = UI.el('span', 'page-count');
    const list = UI.el('div', 'page page-left');
    const spread = UI.el('div', 'pages');

    /** Lot plus ancien, demandé au jeu ; un refus laisse le bouton pour réessayer. */
    async function older() {
      if (loading || !more) return;
      loading = true;
      draw();
      const answer = await Bridge.post('register:more', { id: data.id, before: cursor });
      loading = false;
      if (answer && answer.ok && Array.isArray(answer.pages)) {
        const received = answer.pages.filter((page) => isPage(page) && page.id < cursor);
        for (const page of received) {
          if (known.has(page.id)) continue;
          known.add(page.id);
          pages.push(page);
        }
        if (received.length) cursor = Math.min(cursor, ...received.map((page) => page.id));
        // un lot vide n'avance pas : plus rien à demander
        more = answer.more === true && received.length > 0;
      }
      draw();
    }

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
        if (index >= 0) pages.splice(index, 1);
        count = Math.max(0, count - 1);
        selected = pages.length ? pages[Math.max(0, Math.min(index, pages.length - 1))].id : null;
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
      // la liste garde sa position quand un lot s'ajoute au bas
      const scroll = list.scrollTop;
      counter.textContent = UI.format(texts.count, count, Number(data.max) || 0);
      list.replaceChildren();
      if (!pages.length && !more) list.append(UI.el('p', 'empty', texts.empty));
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
      if (more) {
        const button = UI.button(loading ? texts.loading : texts.more, 'more-button', older);
        button.disabled = loading;
        list.append(button);
      }
      spread.replaceChildren(list, detail());
      list.scrollTop = scroll;
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
