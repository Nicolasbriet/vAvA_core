'use strict';
/*
 * vava_pause/web/js/views.js
 * Rôle : rendu de la bannière (teintes, titre, rubriques), du panneau de chaque rubrique (Personnage, Carte, Réglages,
 *        Le Conseil, Codex en attente), de la plaque, du dialogue Quitter et des avis. Tout texte est posé par
 *        textContent ; les couleurs ne sont posées qu'après PauseModel.color ; aucune donnée du jeu en HTML.
 *        Les commandes portent data-act (et ses arguments en data-*) : app.js les reçoit par délégation.
 * Dépendances : strings.js, model.js
 */

const PauseViews = (() => {
  const S = STRINGS;
  const M = PauseModel;
  const SVG = 'http://www.w3.org/2000/svg';
  let root = null;
  let refs = null;
  let statusTimer = null;

  function h(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
  }

  function button(className, text, act, data) {
    const node = h('button', className, text);
    node.type = 'button';
    if (act) node.dataset.act = act;
    if (data) for (const [key, value] of Object.entries(data)) node.dataset[key] = String(value);
    return node;
  }

  function svg(viewBox, className, paths) {
    const node = document.createElementNS(SVG, 'svg');
    node.setAttribute('viewBox', viewBox);
    node.setAttribute('aria-hidden', 'true');
    if (className) node.setAttribute('class', className);
    for (const [d, fill] of paths) {
      const path = document.createElementNS(SVG, 'path');
      path.setAttribute('d', d);
      path.setAttribute('fill', fill);
      node.append(path);
    }
    return node;
  }

  /** Titre de panneau à lettrine : « Personnage » → P rouge + « ersonnage ». */
  function title(text, id) {
    const chars = Array.from(text);
    const node = h('h2', 'pt');
    node.id = id;
    node.append(h('span', 'lt', chars[0] || ''), chars.slice(1).join(''));
    return node;
  }

  function head(text, id) {
    const row = h('div', 'ph');
    const close = button('cross', null, 'close');
    close.setAttribute('aria-label', S.close);
    row.append(title(text, id), close);
    return row;
  }

  function init(app) {
    root = app;
    refs = {
      ban: app.querySelector('.ban'),
      name: app.querySelector('.ban-name'),
      charge: app.querySelector('.arms-charge'),
      nav: app.querySelector('.ban-nav'),
      foot: app.querySelector('.ban-foot'),
      guild: app.querySelector('.ban-guild'),
      tome: app.querySelector('.tome:not(.dialog)'),
      leaf: app.querySelector('.tome:not(.dialog) .leaf'),
      plate: app.querySelector('.plate'),
      veil: app.querySelector('.veil'),
      dialog: app.querySelector('.dialog'),
      dialogLeaf: app.querySelector('.dialog .leaf'),
      status: app.querySelector('.status'),
    };
    refs.nav.setAttribute('aria-label', S.menu);
    return refs;
  }

  // La bannière --------------------------------------------------------------------------------------------

  function renderBanner(state) {
    const colors = M.banner(state.royal, state.guild);
    refs.ban.style.setProperty('--dye', colors.cloth);
    refs.ban.style.setProperty('--dye-dark', colors.clothDark);
    refs.ban.style.setProperty('--field', colors.field);
    const charge = `img/charges.svg#${colors.charge}`;
    if (refs.charge.getAttribute('src') !== charge) refs.charge.setAttribute('src', charge);
    const name = state.guild ? state.guild.short : S.title;
    refs.name.textContent = name;
    refs.name.classList.toggle('is-long', Array.from(name).length > 10);
    refs.guild.hidden = !state.guild;
    refs.guild.textContent = state.guild ? S.guildFoot(state.guild.label) : '';
    refs.foot.textContent = state.gamepad ? S.footGamepad : S.foot(state.closeKey);
    renderNav(state);
  }

  function renderNav(state) {
    const nodes = [];
    for (const entry of M.entries(state.downed)) {
      if (entry.kind === 'sep') {
        const sep = h('div', 'ban-sep');
        sep.setAttribute('aria-hidden', 'true');
        nodes.push(sep);
        continue;
      }
      const node = button('bn', null, 'entry', { id: entry.id });
      node.classList.toggle('is-small', Boolean(entry.small));
      node.classList.toggle('is-quit', entry.id === 'quitter');
      const active = state.dialog ? entry.id === 'quitter' : entry.id === state.rubric;
      node.classList.toggle('is-active', active);
      if (active) node.setAttribute('aria-current', 'true');
      node.append(svg('0 0 10 10', 'bn-mark', [['M5 0 10 5 5 10 0 5z', 'currentColor']]), S.rubrics[entry.id]);
      nodes.push(node);
    }
    if (state.downed) nodes.push(h('p', 'ban-note', S.downed));
    refs.nav.replaceChildren(...nodes);
  }

  /** Boutons de la bannière, dans l'ordre (pour le clavier et la manette). */
  const navButtons = () => Array.from(refs.nav.querySelectorAll('.bn'));

  // Le panneau ---------------------------------------------------------------------------------------------

  function renderPanel(state) {
    const rubric = state.rubric;
    const codexHidden = rubric === 'codex' && state.codex === 'docked';
    refs.tome.hidden = !rubric || codexHidden || state.dialog;
    root.classList.toggle('is-codex', codexHidden);
    if (refs.tome.hidden) {
      refs.leaf.replaceChildren();
      return;
    }
    refs.tome.dataset.rubric = rubric;
    refs.tome.setAttribute('aria-labelledby', `titre-${rubric}`);
    refs.leaf.classList.toggle('has-ribbons', rubric === 'reglages');
    const build = { personnage, carte, reglages, conseil, codex }[rubric];
    refs.leaf.replaceChildren(...(build ? build(state) : []));
  }

  // Personnage

  function meter(label, value, max, tint) {
    const f = M.fraction(value, max);
    if (f === null) return null;
    const row = h('div', 'meter');
    const gauge = h('div', 'gauge');
    const fill = h('span');
    fill.style.setProperty('--f', String(f));
    fill.style.setProperty('--c', tint);
    gauge.append(fill);
    row.append(h('span', 'lbl', label), gauge, h('span', 'meter-value', `${Math.round(f * 100)} %`));
    return row;
  }

  function tag(text, ink) {
    const node = h('span', 'tag', text);
    const color = M.color(ink);
    if (color) node.style.color = color;
    return node;
  }

  function fact(label, value) {
    const wrap = h('div');
    wrap.append(h('dt', 'lbl', label), h('dd', null, value));
    return wrap;
  }

  function rankInk(state, rank) {
    return M.color(state.rankInks && state.rankInks[rank]) || M.RANK_INKS[rank] || M.RANK_INKS.novice;
  }

  function personnage(state) {
    const P = S.personnage;
    const skills = state.data ? state.data.skills : [];
    const guild = state.guild;
    const main = M.mainSkill(skills);
    const trade = main && main.level >= 20 ? main : null;

    const left = h('div', 'pers-col');
    const id = h('div', 'pers-id');
    const medal = h('div', 'medal');
    const inner = h('div', 'medal-in');
    inner.setAttribute('role', 'img');
    inner.setAttribute('aria-label', P.portrait);
    inner.append(svg('0 0 88 96', null, [['M44 14a20 20 0 1 1 0 40a20 20 0 1 1 0-40z', '#7d6545'], ['M6 96c4-26 20-38 38-38s34 12 38 38z', '#7d6545']]));
    medal.append(inner);
    const who = h('div', 'pers-who');
    who.append(h('span', 'pers-name', state.local.name || ''), h('span', 'muted', state.data ? M.subtitle(skills, guild) : ''));
    id.append(medal, who);

    const tags = h('div', 'tags');
    if (trade) tags.append(tag(trade.rankLabel || trade.rank, rankInk(state, trade.rank)));
    if (guild) tags.append(tag(guild.short, guild.field || '#3c5a6e'));

    const facts = h('dl', 'facts');
    facts.append(fact(P.guild, guild ? guild.label : P.noGuild));
    if (guild && guild.grade) facts.append(fact(P.grade, guild.grade));
    facts.append(fact(P.trade, trade ? trade.label : P.noTrade));
    if (trade) facts.append(fact(P.rank, trade.rankLabel || trade.rank));
    if (!state.data) facts.replaceChildren(fact(P.guild, '—'), fact(P.trade, '—'));

    const status = h('div', 'state');
    status.append(h('h3', 'gt', P.state));
    const meters = [
      meter(P.health, state.local.health, 1, '#8e2c1d'),
      meter(P.hunger, state.local.hunger, 100, '#a2702a'),
      meter(P.thirst, state.local.thirst, 100, '#3d6378'),
    ].filter(Boolean);
    status.append(...meters);
    left.append(id, tags, facts);
    if (meters.length > 0) left.append(status);

    const right = h('div', 'pers-col');
    right.append(h('h3', 'gt', P.skills));
    if (state.dataStatus !== 'ready') {
      right.append(h('p', 'rest', state.dataStatus === 'failed' ? P.failed : P.loading));
    } else if (skills.length === 0) {
      right.append(h('p', 'rest', P.none));
    } else {
      const view = M.table(skills, state.expanded);
      const wrap = h('div', 'skills-wrap');
      const table = h('table', 'skills');
      const headRow = h('tr');
      for (const label of [P.art, P.rank, P.progress, P.level]) {
        const th = h('th', 'lbl', label);
        th.scope = 'col';
        headRow.append(th);
      }
      const thead = h('thead');
      thead.append(headRow);
      const tbody = h('tbody');
      for (const skill of view.rows) {
        const tr = h('tr');
        const progress = h('td', 'prog');
        const gauge = h('div', 'gauge');
        const fill = h('span');
        fill.style.setProperty('--f', String(skill.level / 100));
        gauge.append(fill);
        progress.append(gauge);
        const rank = h('td');
        rank.append(tag(skill.rankLabel || skill.rank, rankInk(state, skill.rank)));
        tr.append(h('td', 'art', skill.label), rank, progress, h('td', 'lvl', String(skill.level)));
        tbody.append(tr);
      }
      table.append(thead, tbody);
      wrap.append(table);
      right.append(wrap);
      const rest = M.restLine(view.hidden, view.hiddenNovice);
      right.append(h('p', 'rest', rest ? `${rest} ${P.rust}` : P.rust));
    }
    const actions = h('div', 'leaf-foot');
    const total = skills.length;
    const collapsed = M.table(skills, false);
    if (state.dataStatus === 'ready' && (collapsed.hidden > 0 || state.expanded)) {
      actions.append(button('plain', state.expanded ? P.showLess : P.showAll(M.numberWord(total)), 'expand'));
    } else actions.append(h('span'));
    if (state.resources.sheet) actions.append(button('ink', P.sheet, 'sheet'));
    right.append(actions);

    const body = h('div', 'pers');
    body.append(left, right);
    return [head(P.title, 'titre-personnage'), body];
  }

  // Carte, Codex en attente

  function carte() {
    const C = S.carte;
    const actions = h('div', 'leaf-actions');
    actions.append(button('ink', C.open, 'map'));
    return [head(C.title, 'titre-carte'), h('p', 'plain-text', C.text), actions];
  }

  function codex(state) {
    const text = state.codex === 'closed' ? S.codex.closed : S.codex.opening;
    return [head(S.rubrics.codex, 'titre-codex'), h('p', 'plain-text muted', text)];
  }

  // Réglages

  function lever(on, act, data, label) {
    const node = button('lever', null, act, data);
    node.setAttribute('aria-pressed', on ? 'true' : 'false');
    if (label) node.setAttribute('aria-label', label);
    const track = h('span', 'lt-track');
    track.append(h('span', 'lt-knob'));
    node.append(track, h('span', 'lt-state', on ? S.reglages.on : S.reglages.off));
    return node;
  }

  function row(name, help, control) {
    const node = h('div', 'row');
    const text = h('span', 'row-text');
    text.append(h('span', 'row-name', name));
    if (help) text.append(h('span', 'row-help', help));
    node.append(text);
    if (control) node.append(control);
    return node;
  }

  function settingRow(state, def) {
    const value = M.settingValue(def, state.settings.values);
    if (def.kind === 'lever') return row(def.label, def.help, lever(value === true, 'setting', { key: def.key }, def.label));
    const stamps = h('div', 'stamps');
    stamps.setAttribute('role', 'group');
    stamps.setAttribute('aria-label', def.label);
    def.choices.forEach((choice, i) => {
      const stamp = button('stamp', def.labels[i], 'setting', { key: def.key, index: i });
      stamp.setAttribute('aria-pressed', choice === value ? 'true' : 'false');
      stamps.append(stamp);
    });
    return row(def.label, def.help, stamps);
  }

  function voiceRows(state) {
    const R = S.reglages;
    if (!state.resources.voice) return [h('p', 'rest', R.voiceOff)];
    const out = [];
    const voice = state.local.voice;
    const distance = voice ? M.meters(voice.distance) : null;
    if (voice && typeof voice.label === 'string' && distance) out.push(row(R.voiceRange(voice.label.slice(0, 32), distance), null, null));
    const key = M.voiceKey(state.data && state.data.keys, state.keyLabels);
    if (key) out.push(row(R.voiceChange, null, h('kbd', null, key)));
    return out;
  }

  function keyRows(state) {
    const R = S.reglages;
    const keys = state.data ? state.data.keys : null;
    if (!Array.isArray(keys)) return [h('p', 'rest', state.dataStatus === 'failed' ? S.personnage.failed : R.keysLoading)];
    const groups = M.keyGroups(keys, state.keyLabels);
    if (groups.length === 0) return [h('p', 'rest', R.keysNone)];
    return groups.map((group) => {
      const node = h('div', 'keys-group');
      if (group.chapter) node.append(h('h3', 'gt', group.chapter));
      for (const key of group.rows) {
        const line = h('div', 'key-row');
        const label = h('span', null, key.label);
        if (key.hold) label.append(h('span', 'key-hold', R.hold));
        line.append(label, h('kbd', null, key.key));
        node.append(line);
      }
      return node;
    });
  }

  function reglages(state) {
    const R = S.reglages;
    const tab = state.tab;
    const ribbons = h('div', 'ribbons');
    ribbons.setAttribute('role', 'tablist');
    ribbons.setAttribute('aria-label', R.tablist);
    for (const id of M.TABS) {
      const ribbon = button('ribbon', R.tabs[id], 'tab', { tab: id });
      ribbon.setAttribute('role', 'tab');
      ribbon.setAttribute('aria-selected', id === tab ? 'true' : 'false');
      ribbon.tabIndex = id === tab ? 0 : -1;
      ribbons.append(ribbon);
    }
    const rows = h('div', 'rows');
    rows.setAttribute('role', 'tabpanel');
    const defs = state.settings.defs.filter((def) => def.tab === tab);
    rows.append(...defs.map((def) => settingRow(state, def)));
    if (tab === 'voix') {
      rows.prepend(...voiceRows(state));
      if (state.resources.voice) rows.append(row(R.voiceTalk, R.voiceTalkHelp, button('plain', R.voiceSettings, 'gameSettings')));
    }
    if (tab === 'touches') rows.append(h('p', 'rest', R.keysHelp), ...keyRows(state));
    if (rows.children.length === 0) rows.append(h('p', 'rest', R.empty));

    const foot = h('div', 'leaf-foot');
    if (tab === 'touches') foot.append(button('plain', R.keysChange, 'keyBindings'), h('span'));
    else foot.append(button('plain', R.reset, 'reset'), h('span', 'muted', state.settingsNote || R.saved));
    return [ribbons, head(R.titles[tab], 'titre-reglages'), rows, foot];
  }

  // Le Conseil

  function conseil(state) {
    const C = S.conseil;
    const council = state.council;
    const out = [head(C.title, 'titre-conseil')];
    const card = M.requestCard(council.request);
    if (card) {
      const node = h('div', 'card');
      node.dataset.tone = card.tone;
      const seal = h('span', 'seal');
      seal.setAttribute('aria-hidden', 'true');
      const text = h('span', 'row-text');
      text.append(h('span', 'card-title', card.title), h('span', 'card-text', card.text));
      node.append(seal, text);
      out.push(node);
    }
    const kinds = h('div', 'field-block');
    const stamps = h('div', 'stamps');
    stamps.setAttribute('role', 'group');
    stamps.setAttribute('aria-label', C.kind);
    for (const kind of M.KINDS) {
      const stamp = button('stamp', C.kinds[kind], 'kind', { kind });
      stamp.setAttribute('aria-pressed', kind === council.kind ? 'true' : 'false');
      stamps.append(stamp);
    }
    kinds.append(h('span', 'lbl', C.kind), stamps);

    const message = h('label', 'field-block is-grow');
    const fieldHead = h('span', 'field-head');
    const count = h('span', 'count', C.count(M.bytes(council.text), M.MAX_TEXT));
    count.dataset.ref = 'count';
    fieldHead.append(h('span', 'lbl', C.message), count);
    const area = h('textarea', 'lines');
    area.placeholder = C.placeholder;
    area.value = council.text;
    area.spellcheck = false;
    area.dataset.ref = 'text';
    message.append(fieldHead, area);

    const ready = state.councilOpen;
    const forced = M.positionForced(council.kind);
    const sendRow = h('div', 'send-row');
    const side = h('div', 'send-side');
    const position = lever(forced || council.withPosition, 'position', null, C.position);
    position.querySelector('.lt-state').textContent = C.position;
    position.disabled = forced || !ready;
    side.append(position);
    if (forced) side.append(h('span', 'row-help', C.positionPlayer));
    const send = button('seal-b', council.sending ? C.sending : C.send, 'send');
    send.disabled = !ready || council.sending;
    sendRow.append(side, send);

    const error = h('p', 'form-error', ready ? council.error : C.errors.council_unavailable);
    error.setAttribute('role', 'alert');
    error.dataset.ref = 'error';
    out.push(kinds, message, sendRow, error, h('p', 'foot-note', C.anonymous));
    return out;
  }

  /** Met à jour le compteur d'octets sans refaire le panneau. */
  function updateCount(state) {
    const count = refs.leaf.querySelector('[data-ref="count"]');
    if (count) count.textContent = S.conseil.count(M.bytes(state.council.text), M.MAX_TEXT);
  }

  // Plaque, dialogue, avis --------------------------------------------------------------------------------

  function renderPlaque(state) {
    const parts = M.plaque(state.local, state.data);
    refs.plate.hidden = parts.length === 0;
    const nodes = [];
    parts.forEach((part, i) => {
      if (i > 0) {
        const mark = h('i');
        mark.setAttribute('aria-hidden', 'true');
        nodes.push(mark);
      }
      nodes.push(h('span', null, part));
    });
    refs.plate.replaceChildren(...nodes);
  }

  function renderDialog(state) {
    refs.veil.hidden = !state.dialog;
    refs.dialog.hidden = !state.dialog;
    if (!state.dialog) {
      refs.dialogLeaf.replaceChildren();
      return;
    }
    const Q = S.quitter;
    const top = h('div', 'dialog-head');
    const seal = h('span', 'seal is-big');
    seal.setAttribute('aria-hidden', 'true');
    const heading = h('h2', 'dialog-title', Q.title);
    heading.id = 'titre-quitter';
    top.append(seal, heading);
    const div = h('div', 'dialog-div');
    div.setAttribute('aria-hidden', 'true');
    const pair = h('div', 'dialog-pair');
    const disconnect = button('ink', Q.disconnect, 'leave', { mode: 'disconnect' });
    const quit = button('seal-b', Q.quit, 'leave', { mode: 'quit' });
    const stay = button('brass-b', Q.stay, 'stay');
    disconnect.disabled = quit.disabled = state.leaving;
    pair.append(disconnect, quit);
    refs.dialog.setAttribute('aria-labelledby', 'titre-quitter');
    refs.dialogLeaf.replaceChildren(top, div, h('p', 'dialog-saved', Q.saved), h('p', 'dialog-note', Q.note), stay, pair);
    if (state.leaving) refs.dialogLeaf.append(h('p', 'muted', Q.leaving));
  }

  /** Avis bref sous le panneau (rien n'est répété : un nouvel avis remplace l'ancien). */
  function status(message) {
    clearTimeout(statusTimer);
    refs.status.textContent = message || '';
    refs.status.hidden = !message;
    if (message) statusTimer = setTimeout(() => { refs.status.hidden = true; }, 3500);
  }

  return { init, renderBanner, renderNav, navButtons, renderPanel, renderPlaque, renderDialog, updateCount, status };
})();
