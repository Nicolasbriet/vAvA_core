'use strict';
/*
 * web/js/view.js
 * Rôle : rendu du livre : rubans de signet, onglets Commandes / Touches, recherche, index par sections (page de
 *        gauche), onglets de chapitre sur la tranche, détail et formulaire (page de droite), réglages, légende.
 */

const View = (() => {
  let refs = null;
  let fields = [];
  let currentRow = null;

  const el = (tag, className, text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  };

  function hint([key, label]) {
    const node = el('span', 'hint');
    node.append(el('kbd', null, key), label);
    return node;
  }

  function init(root) {
    refs = {
      ribbons: root.querySelector('.ribbons'),
      tabs: root.querySelector('.tabs'),
      search: root.querySelector('.search'),
      count: root.querySelector('.search-count'),
      index: root.querySelector('.index'),
      chapters: root.querySelector('.chapters'),
      detail: root.querySelector('.detail'),
      settings: root.querySelector('.settings'),
      toast: root.querySelector('.toast'),
    };
    root.querySelector('.title').textContent = STRINGS.title;
    root.querySelector('.hints').replaceChildren(...STRINGS.hints.map(hint));
    for (const tab of ['commands', 'keys']) {
      const button = el('button', 'tab', STRINGS.tabs[tab]);
      button.type = 'button';
      button.dataset.tab = tab;
      button.setAttribute('role', 'tab');
      refs.tabs.append(button);
    }
  }

  // Page de gauche ---------------------------------------------------------------------------------------------

  function renderTabs() {
    for (const button of refs.tabs.children) button.classList.toggle('is-active', button.dataset.tab === Model.state.tab);
    refs.search.placeholder = Model.state.tab === 'keys' ? STRINGS.search.keysPlaceholder : STRINGS.search.placeholder;
  }

  function badges(row) {
    const list = el('span', 'badges');
    const entry = row.entry;
    if (entry.scope === 'admin') list.append(el('span', 'badge badge-admin', STRINGS.scopes.admin));
    if (entry.scope === 'console') list.append(el('span', 'badge badge-console', STRINGS.scopes.console));
    if (entry.kind === 'command' && entry.key) list.append(el('kbd', 'badge-key', entry.keyLabel || entry.keyDisplay || entry.key));
    if (entry.ui) list.append(el('span', 'badge badge-ui', STRINGS.badges.ui));
    return list;
  }

  function rowNode(row) {
    const node = el('div', 'row');
    node.dataset.row = row.id;
    node.setAttribute('role', 'option');
    node.dataset.chapter = row.entry.module;
    if (row.id === Model.state.selected) node.classList.add('is-selected');
    if (row.key || row.entry.kind === 'key') {
      node.classList.add('row-key');
      node.append(el('kbd', 'row-keycap', row.entry.keyLabel || row.entry.keyDisplay || row.entry.key), el('span', 'row-label', row.entry.label));
      if (row.entry.hold) node.append(el('span', 'badge badge-hold', STRINGS.badges.hold));
      return node;
    }
    const line = el('div', 'row-line');
    line.append(el('span', 'row-syntax', Model.syntax(row)), badges(row));
    const label = row.action && row.action.label ? row.action.label : row.entry.label;
    node.append(line, el('span', 'row-label', row.action && row.action.id ? `${row.entry.label} › ${label}` : label));
    if (Model.isFavorite(row.entry.name)) node.classList.add('is-favorite');
    return node;
  }

  function renderIndex() {
    const sections = Model.sections();
    const nodes = [];
    let count = 0;
    for (const section of sections) {
      const block = el('section', `section section-${section.id}`);
      block.dataset.section = section.id;
      const head = el('h2', 'section-title', section.label);
      if (section.undeclared) head.title = STRINGS.sections.undeclaredHint;
      block.append(head);
      for (const row of section.rows) {
        block.append(rowNode(row));
        count += 1;
      }
      nodes.push(block);
    }
    refs.index.replaceChildren(...nodes);
    refs.count.textContent = STRINGS.search.count(Model.state.rows.length);
    const selected = refs.index.querySelector('.row.is-selected');
    if (selected) selected.scrollIntoView({ block: 'nearest' });
  }

  function renderChapters() {
    const all = el('button', `chapter${Model.state.chapter === '' ? ' is-active' : ''}`, STRINGS.sections.allChapters);
    all.type = 'button';
    all.dataset.chapter = '';
    const nodes = [all];
    for (const chapter of Model.state.chapters) {
      const button = el('button', `chapter${Model.state.chapter === chapter.id ? ' is-active' : ''}`, chapter.label);
      button.type = 'button';
      button.dataset.chapter = chapter.id;
      nodes.push(button);
    }
    refs.chapters.replaceChildren(...nodes);
  }

  function renderRibbons() {
    const nodes = [];
    for (const name of Model.state.prefs.favorites) {
      const entry = Model.state.byName.get(name);
      if (!entry) continue;
      const ribbon = el('button', 'ribbon');
      ribbon.type = 'button';
      ribbon.dataset.name = name;
      ribbon.dataset.chapter = entry.module;
      ribbon.title = entry.label;
      ribbon.append(el('span', 'ribbon-text', entry.kind === 'key' ? entry.label : `/${name}`));
      nodes.push(ribbon);
    }
    refs.ribbons.replaceChildren(...nodes);
  }

  // Page de droite ----------------------------------------------------------------------------------------------

  function emptyDetail() {
    fields = [];
    currentRow = null;
    refs.detail.replaceChildren(el('p', 'detail-empty', Model.state.tab === 'keys' ? STRINGS.detail.emptyKeys : STRINGS.detail.empty));
  }

  function keyDetail(row) {
    const entry = row.entry;
    const head = el('header', 'detail-head');
    head.append(el('p', 'detail-chapter', entry.chapter), el('h2', 'detail-title', entry.label));
    const cap = el('div', 'detail-keycap');
    cap.append(el('kbd', 'keycap-big', entry.keyLabel || entry.keyDisplay || entry.key));
    const facts = el('div', 'detail-facts');
    facts.append(el('p', 'detail-text', STRINGS.detail.keyDefault(entry.keyDisplay || entry.key)));
    if (entry.hold) facts.append(el('p', 'detail-text', STRINGS.detail.keyHold));
    facts.append(el('p', 'detail-note', STRINGS.detail.keyNote));
    refs.detail.replaceChildren(head, cap, facts, favoriteButton(entry));
  }

  function favoriteButton(entry) {
    const on = Model.isFavorite(entry.name);
    const button = el('button', `favorite${on ? ' is-on' : ''}`, on ? STRINGS.detail.unfavorite : STRINGS.detail.favorite);
    button.type = 'button';
    button.dataset.favorite = entry.name;
    button.dataset.on = on ? '1' : '0';
    return button;
  }

  /** Détail d'une ligne de commande : titre, description, syntaxe, formulaire, ligne lancée, bouton. */
  function commandDetail(row) {
    const entry = row.entry;
    const head = el('header', 'detail-head');
    head.append(el('p', 'detail-chapter', entry.chapter));
    const title = row.action && row.action.id ? `${entry.label} › ${row.action.label}` : (row.action && row.action.label ? row.action.label : entry.label);
    head.append(el('h2', 'detail-title', title));
    const description = (row.action && row.action.description) || entry.description;
    const parts = [head];
    if (description) parts.push(el('p', 'detail-text', description));
    if (row.undeclared) parts.push(el('p', 'detail-note', STRINGS.detail.undeclaredNote));
    const syntax = el('p', 'detail-syntax');
    syntax.append(el('span', 'detail-syntax-label', STRINGS.detail.syntax), el('code', null, Model.syntax(row)));
    parts.push(syntax);

    const form = el('form', 'form');
    form.addEventListener('submit', (event) => event.preventDefault());
    fields = row.args.map((arg, i) => Forms.field(row, arg, i + 1, () => updateLine()));
    for (const api of fields) form.append(api.node);
    parts.push(form);

    const lineBox = el('div', 'line-box');
    lineBox.append(el('span', 'line-label', STRINGS.detail.line), el('code', 'line'), el('span', 'line-missing'));
    parts.push(lineBox);

    const actions = el('div', 'detail-actions');
    const run = el('button', 'run', STRINGS.detail.run);
    run.type = 'button';
    run.dataset.run = '1';
    if (!entry.runnable) {
      run.disabled = true;
      parts.push(el('p', 'detail-note is-console', STRINGS.detail.consoleOnly));
    }
    actions.append(favoriteButton(entry), run);
    parts.push(actions);
    refs.detail.replaceChildren(...parts);
    updateLine();
  }

  /** Ligne composée et validité, affichées en direct. */
  function updateLine() {
    if (!currentRow) return null;
    const { line, missing } = Forms.compose(currentRow, fields);
    const code = refs.detail.querySelector('.line');
    const note = refs.detail.querySelector('.line-missing');
    const run = refs.detail.querySelector('.run');
    if (code) code.textContent = `/${line}`;
    if (note) note.textContent = missing ? STRINGS.detail.missing(missing) : '';
    if (run) run.disabled = !currentRow.entry.runnable || missing !== null;
    return { line, missing };
  }

  function renderDetail() {
    const row = Model.state.selected ? Model.row(Model.state.selected) : null;
    if (!row) return emptyDetail();
    currentRow = row;
    if (row.key || row.entry.kind === 'key') {
      fields = [];
      keyDetail(row);
    } else {
      commandDetail(row);
    }
  }

  function renderSettings() {
    const label = el('label', 'setting');
    const box = el('input', 'setting-box');
    box.type = 'checkbox';
    box.checked = Model.state.prefs.keepOpen;
    box.dataset.setting = 'keepOpen';
    label.append(box, el('span', 'setting-text', STRINGS.settings.keepOpen));
    const hint = el('p', 'setting-hint', STRINGS.settings.keepOpenHint);
    refs.settings.replaceChildren(label, hint);
  }

  // Rendu --------------------------------------------------------------------------------------------------------

  function render() {
    renderTabs();
    renderRibbons();
    renderChapters();
    renderIndex();
    renderDetail();
    renderSettings();
  }

  /** Après un changement de sélection : index et détail seulement. */
  function renderSelection() {
    for (const node of refs.index.querySelectorAll('.row')) node.classList.toggle('is-selected', node.dataset.row === Model.state.selected);
    const selected = refs.index.querySelector('.row.is-selected');
    if (selected) selected.scrollIntoView({ block: 'nearest' });
    renderDetail();
  }

  function focusSearch(selectAll) {
    refs.search.focus();
    if (selectAll) refs.search.select();
  }

  /** Premier champ du formulaire, s'il y en a un. */
  function focusFirstField() {
    if (fields.length === 0) return false;
    fields[0].focus();
    return true;
  }

  let toastTimer = null;
  function toast(message, kind) {
    clearTimeout(toastTimer);
    refs.toast.textContent = message;
    refs.toast.dataset.kind = kind || 'info';
    refs.toast.hidden = false;
    toastTimer = setTimeout(() => { refs.toast.hidden = true; }, 2800);
  }

  return {
    init, render, renderSelection, renderIndex, renderRibbons, renderDetail, renderSettings, updateLine, focusSearch, focusFirstField, toast,
    refs: () => refs, currentRow: () => currentRow,
  };
})();
