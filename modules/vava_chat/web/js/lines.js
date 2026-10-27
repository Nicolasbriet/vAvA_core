'use strict';
/*
 * web/js/lines.js
 * Rôle : une ligne du fil pour chaque genre de message, en texte brut : hors-RP (« HRP · [n°] Prénom Nom : … »,
 *        insigne du Conseil), /me et /do en italique doré ou gris-bleu, message privé (sceau de cire, « De … » / « À … »
 *        dans Général, « Nom » / « Vous » dans son onglet), Conseil (rang), messages des autres ressources, avis.
 *        Le nom d'un auteur hors-RP prépare « /mp <n°> » ; une ligne privée de Général ouvre sa conversation.
 */

const Lines = (() => {
  let onWho = () => {};
  let onConversation = () => {};

  /** Rappels : nom cliqué (numéro du joueur), ligne privée cliquée (numéro de conversation). */
  function setHandlers(handlers) {
    onWho = handlers.who || onWho;
    onConversation = handlers.conversation || onConversation;
  }

  function line(kind, children) {
    return UI.el('p', `line line-${kind}`, null, children);
  }

  function tag(text) {
    return UI.el('span', 'tag', text);
  }

  function body(text) {
    return UI.el('span', 'text', text);
  }

  /** « [n°] Prénom Nom », cliquable pour écrire en privé. */
  function author(name, id) {
    const node = UI.el('span', 'who', null, [UI.el('span', 'number', `[${id}]`), document.createTextNode(` ${name}`)]);
    if (id) {
      node.classList.add('is-link');
      node.addEventListener('click', () => onWho(id));
    }
    return node;
  }

  function ooc(message) {
    const texts = UI.t();
    return line('ooc', [
      tag(texts.tags.ooc),
      author(message.name, message.id),
      message.staff ? UI.el('span', 'badge', texts.staffBadge) : null,
      document.createTextNode(' : '),
      body(message.text),
    ]);
  }

  function me(message) {
    return line('me', UI.compose(UI.t().me, UI.el('span', 'who', message.name), body(message.text)));
  }

  function action(message) {
    return line('do', UI.compose(UI.t().do, body(message.text), UI.el('span', 'who', message.name)));
  }

  /** Message privé ; `inTab` : dans l'onglet de la conversation (sans « De » ni « À »). */
  function mp(message, inTab) {
    const texts = UI.t();
    let header;
    if (inTab) {
      header = UI.el('span', 'who', message.out ? texts.you : message.name);
    } else {
      const who = UI.el('span', 'who', null, [UI.el('span', 'number', `[${message.id}]`), document.createTextNode(` ${message.name}`)]);
      header = UI.el('span', null, null, UI.compose(message.out ? texts.mpTo : texts.mpFrom, who));
    }
    const node = line('mp', [
      inTab ? null : UI.el('span', 'seal'),
      inTab ? null : tag(texts.tags.mp),
      header,
      message.staff && !message.out ? UI.el('span', 'badge', texts.staffBadge) : null,
      document.createTextNode(' : '),
      body(message.text),
    ]);
    if (message.out) node.classList.add('is-out');
    if (!inTab) {
      node.classList.add('is-link');
      node.addEventListener('click', () => onConversation(message.chat));
    }
    return node;
  }

  function staff(message) {
    const texts = UI.t();
    return line('staff', [
      tag(texts.tags.staff),
      message.rank ? UI.el('span', 'rank', message.rank) : null,
      message.rank ? document.createTextNode(' · ') : null,
      author(message.name, message.id),
      document.createTextNode(' : '),
      body(message.text),
    ]);
  }

  /** Message d'une autre ressource : auteur facultatif, couleur { r, g, b } facultative. */
  function system(message) {
    const node = line('system', [
      message.author ? UI.el('span', 'author', message.author) : null,
      body(message.text),
    ]);
    if (message.text.includes('\n')) node.classList.add('is-multiline');
    const color = Array.isArray(message.color) && message.color.length === 3 ? `rgb(${message.color.join(', ')})` : null;
    if (color) (message.author ? node.firstChild : node).style.color = color;
    return node;
  }

  function notice(text) {
    return line('notice', [document.createTextNode(text)]);
  }

  const BUILDERS = { ooc, me, do: action, staff, system };

  /** Ligne d'un message ; `inTab` vaut pour un message privé montré dans sa conversation. */
  function build(message, inTab) {
    if (message.kind === 'mp') return mp(message, inTab);
    const builder = BUILDERS[message.kind];
    return builder ? builder(message) : null;
  }

  return { setHandlers, build, notice };
})();
