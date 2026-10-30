'use strict';
/*
 * vava_atelier/web/js/view-home.js
 * Rôle : accueil (maquette Main) : en-tête (titre, phrase, recherche, bouton rond de fermeture), une section par
 *        famille (seulement celles qui ont une carte), cartes en grille de 2 (icône ronde, nom en Cinzel, étiquette,
 *        description ; « Bientôt » non cliquable), volet droit « Vos brouillons », « Journal du Conseil », « Tout le
 *        journal », note du bas. Recherche : dès 2 lettres, cartes filtrées sur place (sans réseau), puis, après 400 ms
 *        sans frappe, « Dans les ateliers » (RPC search) ; Entrée ouvre le premier résultat.
 * Dépendances : strings.js, format.js, components.js
 */

const HomeView = (() => {
  const { h, icon, round, tag, journalLine } = UI;
  const str = Format.str;
  const SEARCH_DELAY = 400;
  const TONES = new Set(['count', 'upcoming', 'trial', 'draft']);

  function card(entry, actions) {
    const upcoming = entry.upcoming === true;
    const tagText = upcoming ? STRINGS.upcoming : str(entry.tag);
    const tone = upcoming ? 'upcoming' : (TONES.has(entry.tone) ? entry.tone : 'count');
    return h('button', { type: 'button', class: `ent${upcoming ? ' soon' : ''}`, disabled: upcoming, data: { editor: str(entry.editor) },
      onclick: upcoming ? null : () => actions.openEditor(entry.editor) },
      h('span', { class: 'ico' }, icon(entry.icon)),
      h('span', { class: 'ent-text' },
        h('span', { class: 'ent-top' }, h('span', { class: 'nm', text: str(entry.label) }), tagText ? tag(tagText, tone) : null),
        h('span', { class: 'ds', text: str(entry.description) })));
  }

  function draft(entry, actions) {
    const status = str(entry.status);
    const label = STRINGS.status[status] || '';
    return h('button', { type: 'button', class: 'draft', onclick: () => actions.openEntry(entry.editor, entry.kind, entry.id) },
      h('span', { class: 'draft-text' }, h('span', { class: 'draft-title', text: str(entry.title) }), h('span', { class: 'hp', text: str(entry.line) })),
      label ? tag(label, status === 'trial' ? 'trial' : 'draft') : null);
  }

  /**
   * @param model   { content: { families, cards, footnote }, drafts, journal, rank }
   * @param actions { openEditor, openEntry, openHit, openJournal, close, search(text) → Promise }
   */
  function render(model, actions) {
    const content = model.content || {};
    const cards = Format.list(content.cards).filter((c) => c && typeof c.editor === 'string');
    const sections = [];
    for (const family of Format.list(content.families)) {
      const members = cards.filter((c) => c.family === family.id);
      if (members.length === 0) continue;
      sections.push(h('section', { class: 'family', data: { family: str(family.id) } },
        h('h2', { class: 'grp', text: str(family.label) }),
        h('div', { class: 'cards' }, members.map((c) => card(c, actions)))));
    }
    const noCard = h('p', { class: 'hp empty', text: STRINGS.search.noCard, hidden: true });
    const hits = h('section', { class: 'hits', hidden: true });

    const input = h('input', { type: 'search', id: 'home-search', placeholder: STRINGS.search.placeholder, autocomplete: 'off', spellcheck: 'false', maxlength: '48' });
    const searchBox = h('label', { class: 'search', for: 'home-search' }, icon('search', 18, 2), h('span', { class: 'sr', text: STRINGS.search.label }), input);

    const drafts = Format.list(model.drafts);
    const journal = Format.list(model.journal);
    const aside = h('aside', { class: 'home-side' },
      h('section', { class: 'side-block' },
        h('h2', { class: 'side-title', text: STRINGS.drafts.title }),
        drafts.length > 0 ? h('div', { class: 'drafts' }, drafts.map((d) => draft(d, actions))) : h('p', { class: 'hp', text: STRINGS.drafts.none })),
      h('section', { class: 'side-block journal-block' },
        h('h2', { class: 'side-title', text: STRINGS.journal.title }),
        journal.length > 0 ? journal.map((line) => journalLine(line)) : h('p', { class: 'hp', text: STRINGS.journal.none }),
        h('button', { type: 'button', class: 'link', text: STRINGS.journal.all, onclick: () => actions.openJournal() })),
      h('div', { class: 'footnote' },
        str(content.footnote) ? h('p', { class: 'hp', text: content.footnote }) : null,
        str(model.rank) ? h('p', { class: 'hp rank', text: STRINGS.rank(model.rank) }) : null));

    const el = h('div', { class: 'home' },
      h('header', { class: 'home-head' },
        h('div', { class: 'home-titles' }, h('h1', { text: STRINGS.title }), h('p', { class: 'lead', text: STRINGS.subtitle })),
        searchBox,
        round('close', STRINGS.close, () => actions.close())),
      h('div', { class: 'home-body' }, h('main', { class: 'home-main' }, sections, noCard, hits), aside));

    // Recherche -----------------------------------------------------------------------------------------------------
    let timer = 0, seq = 0, results = [], pending = null;

    function filterCards(text) {
      const q = Format.fold(text.trim());
      const active = q.length >= 2;
      let visible = 0;
      for (const section of sections) {
        let shown = 0;
        for (const node of section.querySelectorAll('.ent')) {
          const match = !active || Format.fold(node.textContent).includes(q);
          node.hidden = !match;
          if (match) shown += 1;
        }
        section.hidden = shown === 0;
        visible += shown;
      }
      noCard.hidden = !active || visible > 0;
    }

    function showHits(list, state) {
      results = list;
      if (state === 'off') { hits.hidden = true; hits.replaceChildren(); return; }
      const body = state === 'pending' ? h('p', { class: 'hp', text: STRINGS.search.pending })
        : (list.length === 0 ? h('p', { class: 'hp', text: state || STRINGS.search.none })
          : h('div', { class: 'hit-list' }, list.map((hit) => h('button', { type: 'button', class: 'hit', onclick: () => actions.openHit(hit) },
            h('span', { class: 'hit-title', text: str(hit.title) }), h('span', { class: 'hp', text: STRINGS.search.where(str(hit.where)) })))));
      hits.replaceChildren(h('h2', { class: 'grp', text: STRINGS.search.hits }), body);
      hits.hidden = false;
    }

    function runSearch() {
      clearTimeout(timer);
      timer = 0;
      const text = Format.query(input.value);
      if (Format.chars(text) < 2) { showHits([], 'off'); pending = null; return Promise.resolve(); }
      const mine = ++seq;
      showHits([], 'pending');
      pending = actions.search(text).then((result) => {
        if (mine !== seq) return;
        if (!result.ok) showHits([], errorText(result.error));
        else showHits(Format.list(result.data.hits).filter((hit) => hit && typeof hit.editor === 'string'), '');
      });
      return pending;
    }

    input.addEventListener('input', () => {
      filterCards(input.value);
      clearTimeout(timer);
      timer = 0;
      if (Format.chars(input.value.trim()) < 2) { seq += 1; pending = null; showHits([], 'off'); return; }
      timer = setTimeout(runSearch, SEARCH_DELAY);
    });
    input.addEventListener('keydown', async (event) => {
      if (event.key !== 'Enter') return;
      event.preventDefault();
      if (Format.chars(input.value.trim()) < 2) return;
      if (timer || !pending) await runSearch(); else await pending;
      if (results.length > 0) { actions.openHit(results[0]); return; }
      const first = el.querySelector('.ent:not([hidden]):not([disabled])');
      if (first) first.click();
    });

    return {
      el,
      focus: () => input.focus(),
      /** Échap : vide la recherche si elle a du texte ; vrai si elle a servi. */
      clearSearch() {
        if (input.value === '') return false;
        input.value = '';
        filterCards('');
        seq += 1;
        showHits([], 'off');
        return true;
      },
      setSearch(text) { input.value = text; filterCards(text); return runSearch(); },
    };
  }

  return { render };
})();
