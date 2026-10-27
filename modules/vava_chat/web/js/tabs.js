'use strict';
/*
 * web/js/tabs.js
 * Rôle : onglets et leurs fils : Général (tout), Actions (/me, /do), Conseil (membres seulement), un onglet par
 *        correspondant privé (ouvert au premier message reçu ou envoyé, fermable, grisé quand il part ; repris s'il
 *        revient sous un nouveau numéro). Pastille des messages non lus ; chaque fil garde ses derniers messages et
 *        reste en bas tant que le joueur n'est pas remonté le lire. Chat fermé : le fil Général est montré.
 */

const Tabs = (() => {
  const tabsNode = document.getElementById('tabs');
  const feedsNode = document.getElementById('feeds');
  const GENERAL = 'general';
  const ACTIONS = 'actions';
  const STAFF = 'staff';
  const MP = 'mp';
  // en deçà (pixels) du bas du fil, un nouveau message y ramène
  const STICK_PX = 24;
  const BADGE_MAX = 9;

  const tabs = new Map();
  let active = GENERAL;
  let open = false;
  let ownId = 0;
  let onChange = () => {};

  function keyOf(chat) {
    return `${MP}:${chat}`;
  }

  function showBadge(tab) {
    tab.badge.hidden = tab.unread === 0;
    tab.badge.textContent = tab.unread > BADGE_MAX ? `${BADGE_MAX}+` : String(tab.unread);
  }

  function scrollDown(tab) {
    tab.feed.scrollTop = tab.feed.scrollHeight;
  }

  /** Fait défiler la rangée d'onglets jusqu'à `button` (sans toucher au reste de la page). */
  function reveal(button) {
    const left = button.offsetLeft - tabsNode.offsetLeft;
    const right = left + button.offsetWidth;
    if (left < tabsNode.scrollLeft) tabsNode.scrollLeft = left;
    else if (right > tabsNode.scrollLeft + tabsNode.clientWidth) tabsNode.scrollLeft = right - tabsNode.clientWidth;
  }

  /** Onglet et fil visibles selon l'état du chat. */
  function render() {
    const shown = open ? active : GENERAL;
    for (const tab of tabs.values()) {
      const isActive = tab.key === active;
      tab.button.classList.toggle('is-active', isActive);
      tab.button.setAttribute('aria-selected', String(isActive));
      tab.feed.classList.toggle('is-shown', tab.key === shown);
    }
    const tab = tabs.get(shown);
    if (tab) scrollDown(tab);
  }

  function create(key, kind, label) {
    const texts = UI.t();
    const button = UI.el('button', `tab tab-${kind}`);
    button.type = 'button';
    button.setAttribute('role', 'tab');
    const labelNode = UI.el('span', 'tab-label', label);
    const badge = UI.el('span', 'tab-badge');
    badge.hidden = true;
    button.append(labelNode, badge);
    const tab = { key, kind, label, chat: null, gone: false, unread: 0, button, labelNode, badge, feed: UI.el('div', 'feed') };
    if (kind === MP) {
      const close = UI.el('span', 'tab-close', '×');
      close.title = texts.closeTab;
      close.addEventListener('click', (event) => {
        event.stopPropagation();
        remove(tab.key);
      });
      button.append(close);
    }
    button.addEventListener('click', () => activate(tab.key));
    tabs.set(key, tab);
    feedsNode.append(tab.feed);
    if (kind === STAFF) tabs.get(ACTIONS).button.after(button);
    else tabsNode.append(button);
    return tab;
  }

  function add(tab, node, own) {
    if (!node) return;
    const feed = tab.feed;
    const visible = feed.classList.contains('is-shown');
    const stick = !visible || !open || feed.scrollHeight - feed.scrollTop - feed.clientHeight < STICK_PX;
    feed.append(node);
    const max = UI.config().maxMessages || 200;
    while (feed.childElementCount > max) feed.firstElementChild.remove();
    if (stick) scrollDown(tab);
    // non lu : onglet qu'on ne regarde pas (Général se lit chat fermé)
    const unseen = open ? tab.key !== active : tab.key !== GENERAL;
    if (!own && unseen) {
      tab.unread += 1;
      showBadge(tab);
    }
  }

  function setup() {
    const texts = UI.t();
    create(GENERAL, GENERAL, texts.tabs.general);
    create(ACTIONS, ACTIONS, texts.tabs.actions);
    tabsNode.addEventListener('wheel', (event) => {
      if (!event.deltaY) return;
      tabsNode.scrollLeft += event.deltaY;
      event.preventDefault();
    }, { passive: false });
    render();
  }

  function activate(key) {
    const tab = tabs.get(key);
    if (!tab) return;
    active = key;
    if (open) {
      tab.unread = 0;
      showBadge(tab);
    }
    reveal(tab.button);
    render();
    onChange(current());
  }

  function remove(key) {
    const tab = tabs.get(key);
    if (!tab || tab.kind === GENERAL || tab.kind === ACTIONS) return;
    tabs.delete(key);
    tab.button.remove();
    tab.feed.remove();
    if (active === key) activate(GENERAL);
  }

  /** Onglet d'une conversation ; un onglet grisé du même nom est repris (correspondant revenu). */
  function conversation(chat, name) {
    const key = keyOf(chat);
    const existing = tabs.get(key);
    if (existing) return existing;
    for (const tab of tabs.values()) {
      if (tab.kind !== MP || !tab.gone || tab.label !== name) continue;
      const previous = tab.key;
      tabs.delete(previous);
      tab.key = key;
      tab.chat = chat;
      tab.gone = false;
      tab.button.classList.remove('is-gone');
      tabs.set(key, tab);
      if (active === previous) {
        active = key;
        onChange(current());
      }
      return tab;
    }
    const tab = create(key, MP, name);
    tab.chat = chat;
    return tab;
  }

  /** Message reçu du serveur : dans Général, et dans son onglet. */
  function receive(message) {
    const own = message.out === true || message.id === ownId;
    add(tabs.get(GENERAL), Lines.build(message, false), own);
    if (message.kind === 'me' || message.kind === 'do') {
      add(tabs.get(ACTIONS), Lines.build(message), own);
    } else if (message.kind === 'mp') {
      add(conversation(message.chat, message.name), Lines.build(message, true), own);
    } else if (message.kind === STAFF && tabs.has(STAFF)) {
      add(tabs.get(STAFF), Lines.build(message), own);
    }
  }

  /** Avis dans un onglet (Général s'il n'existe plus), repris dans Général pour être vu chat fermé. */
  function notice(key, text) {
    const general = tabs.get(GENERAL);
    const tab = tabs.get(key) || general;
    add(tab, Lines.notice(text), true);
    if (tab !== general) add(general, Lines.notice(text), true);
  }

  /** Le correspondant est parti : onglet grisé, saisie fermée. */
  function gone(chat) {
    const tab = tabs.get(keyOf(chat));
    if (!tab || tab.gone) return;
    tab.gone = true;
    tab.button.classList.add('is-gone');
    add(tab, Lines.notice(UI.format(UI.t().placeholder.gone, tab.label)), true);
    if (tab.key === active) onChange(current());
  }

  function setOpen(value) {
    open = value;
    if (open) activate(active);
    else render();
  }

  function setProfile(profile) {
    ownId = profile.id || 0;
    if (profile.staff && !tabs.has(STAFF)) create(STAFF, STAFF, UI.t().tabs.staff);
    if (!profile.staff && tabs.has(STAFF)) remove(STAFF);
    render();
  }

  /** Onglet actif : { key, kind, chat, label, gone }. */
  function current() {
    const tab = tabs.get(active);
    return { key: tab.key, kind: tab.kind, chat: tab.chat, label: tab.label, gone: tab.gone };
  }

  /** chat:clear : tous les fils vidés. */
  function clear() {
    for (const tab of tabs.values()) {
      tab.feed.replaceChildren();
      tab.unread = 0;
      showBadge(tab);
    }
  }

  /** Retour à la sélection du personnage : conversations fermées, fils vidés. */
  function reset() {
    for (const tab of [...tabs.values()]) {
      if (tab.kind === MP) remove(tab.key);
    }
    clear();
    activate(GENERAL);
  }

  return {
    setup, activate, receive, notice, gone, setOpen, setProfile, current, clear, reset,
    onChange: (handler) => { onChange = handler; },
  };
})();
