'use strict';
/*
 * web/js/suggest.js
 * Rôle : suggestions de commandes sous la saisie dès qu'elle commence par « / » : celles déclarées par les
 *        ressources ou décrites par le registre du Codex (aide et paramètres, sous-commandes « metiers niveau »),
 *        puis les autres commandes permises. Une commande complète montre ses paramètres, celui en cours d'écriture
 *        en rouge, avec son aide ; ses sous-commandes restent proposées tant qu'aucun paramètre n'est écrit. Tab
 *        complète le nom (ou la sous-commande), et passe à la suivante si on appuie encore.
 */

const Suggest = (() => {
  const list = document.getElementById('suggestions');
  const declared = new Map();
  let commands = [];
  let shown = [];
  let cycle = null;
  // noms complétables par Tab pour la saisie courante (phase du nom)
  let completable = [];

  function add(entries) {
    for (const entry of entries || []) {
      if (entry && typeof entry.name === 'string') declared.set(entry.name, entry);
    }
  }

  function remove(name) {
    declared.delete(name);
  }

  function setCommands(names) {
    commands = Array.isArray(names) ? names : [];
  }

  function hide() {
    shown = [];
    list.hidden = true;
    list.replaceChildren();
  }

  /** Toutes les commandes connues : déclarées d'abord (elles ont une aide), puis les autres. */
  function catalog() {
    const entries = [...declared.values()];
    for (const name of commands) {
      if (!declared.has(name)) entries.push({ name, help: '', params: [] });
    }
    return entries;
  }

  function row(entry, paramIndex) {
    const params = entry.params || [];
    const name = UI.el('span', 'suggestion-name', `/${entry.name}`, params.map((param, index) =>
      UI.el('span', `suggestion-param${index === paramIndex ? ' is-current' : ''}`, `<${param.name}>`)));
    const current = params[paramIndex];
    return UI.el('li', 'suggestion', null, [name, UI.el('span', 'suggestion-help', current && current.help ? current.help : entry.help)]);
  }

  /** Liste montrée ; `selected` : rang de la commande choisie par Tab. */
  function render(entries, paramIndex, selected) {
    shown = entries;
    list.replaceChildren(...shown.map((entry, index) => {
      const node = row(entry, paramIndex);
      if (index === selected) node.classList.add('is-selected');
      return node;
    }));
    list.hidden = false;
  }

  /** Saisie changée : suggestions recalculées (la liste parcourue par Tab reste tant qu'on ne tape rien d'autre). */
  function update(value) {
    if (cycle && value === cycle.value) return render(cycle.list, -1, cycle.index);
    cycle = null;
    if (!value.startsWith('/')) return hide();
    const typed = value.slice(1).toLowerCase();
    const entries = catalog();
    const lower = (entry) => entry.name.toLowerCase();
    // phase du nom : les noms (et sous-commandes) qui commencent par la saisie
    const starting = entries.filter((entry) => lower(entry).startsWith(typed));
    // phase des paramètres : la saisie dépasse un nom complet ; le nom le plus long l'emporte (« metiers niveau »
    // avant « metiers »)
    const passed = entries.filter((entry) => typed.startsWith(`${lower(entry)} `)).sort((a, b) => b.name.length - a.name.length);
    let matches;
    let paramIndex = -1;
    if (passed.length) {
      const best = passed[0];
      const rest = typed.slice(best.name.length + 1);
      // paramètre en cours : nombre de mots après la commande (un espace final ouvre le suivant)
      paramIndex = rest.split(' ').length - 1;
      matches = [best].concat(starting.filter((entry) => entry !== best));
      completable = starting;
    } else {
      // la commande exacte d'abord, puis celles qui ont une aide, puis l'ordre alphabétique
      const rank = (entry) => (lower(entry) === typed ? 0 : 2) + (entry.help ? 0 : 1);
      matches = starting.sort((a, b) => rank(a) - rank(b) || a.name.localeCompare(b.name));
      completable = matches;
    }
    matches = matches.slice(0, UI.config().suggestionsMax || 6);
    if (!matches.length) return hide();
    render(matches, paramIndex, -1);
  }

  /** Tab : la saisie complétée (« /commande » ou « /commande sous-commande »), ou null s'il n'y a rien à compléter. */
  function complete(value) {
    if (cycle && cycle.value === value) {
      cycle.index = (cycle.index + 1) % cycle.list.length;
    } else {
      const candidates = completable.filter((entry) => shown.includes(entry));
      if (!candidates.length) return null;
      cycle = { list: candidates, index: 0, value: '' };
    }
    cycle.value = `/${cycle.list[cycle.index].name} `;
    render(cycle.list, -1, cycle.index);
    return cycle.value;
  }

  return { add, remove, setCommands, update, complete, hide };
})();
