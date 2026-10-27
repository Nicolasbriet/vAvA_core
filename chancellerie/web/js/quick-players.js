'use strict';
/*
 * web/js/quick-players.js
 * Rôle : accès rapide aux joueurs connectés, depuis n'importe quelle page : un bouton en tête de la colonne (avec le
 *        nombre de joueurs, tenu à jour par les relevés) ou la touche J ouvre une fenêtre avec la liste — numéro de
 *        connexion, nom FiveM, personnage, rang, latence — et une recherche. Avec un rang du Conseil, un clic sur un
 *        joueur ouvre sa fiche (identifiants, administration) ; sans rang, la liste se lit seulement.
 */

const QuickPlayers = (() => {
  const Q = STRINGS.quickPlayers;
  const SHORTCUT = 'j';

  let context = null;
  let refs = null;
  let open = false;
  let players = [];
  let filter = '';

  const realm = () => Boolean(context && context.account() && context.account().rank);

  function setCount(count) {
    if (!refs) return;
    refs.count.textContent = count === null || count === undefined ? '—' : String(count);
  }

  /** Joueurs connectés : par le Registre avec un rang du Conseil (personnage, rang), sinon par players.json. */
  async function load() {
    if (realm()) {
      const ready = await GAME.ensure();
      const result = ready.ok ? await GAME.call('players') : ready;
      if (!result.ok) return { error: result.error };
      return {
        list: UI.list(result.result).map((p) => ({ id: p.source, name: p.name, character: p.character, rank: p.rank, ping: p.ping })),
      };
    }
    const server = await API.get('/api/server');
    if (!server.ok) return { error: server.error };
    if (server.state !== 'running') return { error: 'server_stopped' };
    if (!Array.isArray(server.players)) return { error: 'bridge_unreachable' };
    return { list: server.players.map((p) => ({ id: p.id, name: p.name, ping: p.ping })) };
  }

  function openFiche(player) {
    UI.close();
    PlayersView.focus(player.id);
    context.navigate('joueurs');
  }

  function renderList() {
    if (!open) return;
    const needle = filter.trim().toLowerCase();
    const shown = players.filter((p) => !needle || String(p.id) === needle
      || [p.name, p.character].some((text) => text && text.toLowerCase().includes(needle)));
    if (!players.length) {
      refs.list.replaceChildren(UI.el('p', 'empty', Q.empty));
      return;
    }
    if (!shown.length) {
      refs.list.replaceChildren(UI.el('p', 'empty', Q.noMatch));
      return;
    }
    const clickable = realm();
    const rows = shown.map((player) => {
      const row = UI.el('tr', null, null, [
        UI.el('td', 'cell-number', String(player.id)),
        UI.el('td', 'cell-strong', player.name),
        UI.el('td', null, player.character || (clickable ? STRINGS.players.noCharacter : '')),
        UI.el('td', 'cell-sub', player.rank || ''),
        UI.el('td', 'cell-end', STRINGS.players.ms(player.ping)),
      ]);
      if (clickable) row.addEventListener('click', () => openFiche(player));
      return row;
    });
    refs.list.replaceChildren(UI.el('table', `ledger${clickable ? ' is-clickable' : ''}`, null, [
      UI.el('thead', null, null, [UI.el('tr', null, null, Q.columns.map((c, i) => UI.el('th', i === 4 ? 'cell-end' : null, c)))]),
      UI.el('tbody', null, null, rows),
    ]));
  }

  async function refresh() {
    const result = await load();
    if (!open) return;
    if (result.error) {
      players = [];
      refs.list.replaceChildren(UI.el('p', 'empty', STRINGS.error(result.error)));
      return;
    }
    players = result.list;
    setCount(players.length);
    refs.title.textContent = Q.count(players.length);
    renderList();
  }

  async function show() {
    if (open || !context) return;
    open = true;
    filter = '';
    const search = UI.el('input', 'field-input quick-search');
    search.type = 'search';
    search.placeholder = Q.search;
    search.setAttribute('aria-label', Q.search);
    search.addEventListener('input', () => {
      filter = search.value;
      renderList();
    });
    // Entrée : le seul joueur restant (ou le premier) ouvre sa fiche
    search.addEventListener('keydown', (event) => {
      if (event.key !== 'Enter' || !realm()) return;
      event.preventDefault();
      const first = refs.list.querySelector('tbody tr');
      if (first) first.click();
    });
    refs.title = UI.el('p', 'cell-sub quick-count');
    refs.list = UI.el('div', 'quick-list', null, [UI.el('p', 'empty', '…')]);
    const body = UI.el('div', 'quick-players', null, [
      search, refs.title, refs.list, UI.el('p', 'hint', realm() ? Q.hintRealm : Q.hintPlain),
    ]);
    const closed = UI.reading({ title: Q.title, body, confirm: Q.close });
    search.focus();
    refresh();
    await closed;
    open = false;
  }

  return {
    /** Bouton dans la colonne, touche J. */
    init(appContext) {
      context = appContext;
      refs = { button: document.querySelector('[data-action="quick-players"]'), count: document.querySelector('.quick-players-count') };
      refs.button.querySelector('.quick-players-label').textContent = Q.button;
      refs.button.title = Q.shortcut;
      refs.button.addEventListener('click', show);
      document.addEventListener('keydown', (event) => {
        if (event.key.toLowerCase() !== SHORTCUT || event.ctrlKey || event.metaKey || event.altKey) return;
        const target = event.target;
        // jamais pendant une saisie, ni dialogue déjà ouvert, ni hors de la coquille
        if (target.closest('input, textarea, select, [contenteditable="true"]')) return;
        if (!document.querySelector('.dialog').hidden || document.getElementById('shell').hidden) return;
        event.preventDefault();
        show();
      });
    },

    /** Nouveau relevé : le nombre de joueurs du bouton. */
    metrics(sample) {
      setCount(sample && sample.state === 'running' ? sample.players : null);
    },

    /** Arrivée ou départ annoncé par le serveur de jeu : la liste ouverte se relit. */
    players() {
      if (open) refresh();
    },
  };
})();
