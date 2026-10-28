'use strict';
/*
 * web/js/devmock.js
 * Rôle : inventaire simulé quand la page est ouverte dans un navigateur (hors FiveM), pour travailler le rendu sans
 *        lancer le jeu. Inactif en jeu. Paramètres d'URL : ?drop=1 pour afficher aussi un sac au sol, ?catalog=1 le
 *        catalogue de développement. Les images
 *        viennent du module d'exemple voisin (examples/vava_example_items) quand le dépôt est complet. Les objets
 *        portent des métadonnées du contrat standard (palier, qualité, solidité, signature, histoire, brisé) et une
 *        hache est tenue en main.
 */

const DevMock = (() => {
  const inGame = typeof GetParentResourceName === 'function';
  const art = (name) => `../../../examples/vava_example_items/web/items/${name}.svg`;
  const definitions = {
    pain: { label: 'Miche de pain', description: 'Encore tiède, sortie du four du village.', width: 2, height: 1, weight: 400, stack: 10, category: 'nourriture', image: art('pain'), effects: { hunger: 35 }, usable: true },
    pomme: { label: 'Pomme', description: 'Croquante et un peu acide.', width: 1, height: 1, weight: 150, stack: 20, category: 'nourriture', image: art('pomme'), effects: { hunger: 12, thirst: 4 }, usable: true },
    epee: { label: 'Épée courte', description: 'Lame d\'acier forgée, fourreau de cuir.', width: 1, height: 4, weight: 1800, stack: 1, category: 'arme', image: art('epee'), usable: false, holdable: true },
    bourse: { label: 'Bourse de cuir', description: 'Une petite bourse fermée par un lacet.', width: 1, height: 1, weight: 100, stack: 1, category: 'divers', image: art('bourse'), usable: false },
    corde: { label: 'Rouleau de corde', description: 'Chanvre tressé, une dizaine de toises.', width: 2, height: 2, weight: 1200, stack: 1, category: 'outil', image: art('corde'), usable: false },
    hache: { label: 'Hache de bûcheron', description: 'Fer large emmanché de frêne.', width: 1, height: 3, weight: 2200, stack: 1, category: 'outil', usable: false, holdable: true },
    pioche: { label: 'Pioche', description: 'Pointe de fer sur un manche court.', width: 1, height: 3, weight: 2500, stack: 1, category: 'outil', usable: false, holdable: true },
    buche: { label: 'Bûche de chêne', description: 'Bois dur, sec, prêt à être travaillé.', width: 1, height: 2, weight: 900, stack: 20, category: 'materiau', usable: false },
    minerai: { label: 'Minerai de fer', description: 'Roche lourde veinée de rouille.', width: 1, height: 1, weight: 700, stack: 30, category: 'materiau', usable: false },
  };
  let nextId = 100;
  const own = {
    id: 1, kind: 'character', label: 'Besace', width: 10, height: 6, maxWeight: 25000, weight: 0,
    items: [
      { id: 1, item: 'pain', x: 0, y: 0, rotated: false, quantity: 3, metadata: {} },
      { id: 2, item: 'pomme', x: 2, y: 0, rotated: false, quantity: 7, metadata: {} },
      { id: 3, item: 'epee', x: 9, y: 0, rotated: false, quantity: 1, metadata: {
        name: 'Morsure d\'Aube', quality: 91, tier: 5, durability: 84, max_durability: 100,
        crafter_name: 'Aldric Ferrand', mark: 'AF', crafted_at: 1718000000,
        history: [
          { at: 1718000000, kind: 'creation', by: 'Aldric Ferrand' },
          { at: 1718600000, kind: 'rename', by: 'Aldric Ferrand', note: 'baptisée à la forge du bourg' },
          { at: 1721000000, kind: 'repair', by: 'Bertrand Vauclair', note: 'lame redressée' },
        ],
      } },
      { id: 4, item: 'bourse', x: 3, y: 0, rotated: false, quantity: 1, metadata: {} },
      { id: 5, item: 'corde', x: 0, y: 2, rotated: false, quantity: 1, metadata: {} },
      { id: 6, item: 'pomme', x: 4, y: 0, rotated: false, quantity: 20, metadata: {} },
      { id: 8, item: 'hache', x: 8, y: 0, rotated: false, quantity: 1, metadata: {
        quality: 54, tier: 3, durability: 23, max_durability: 100,
        crafter_name: 'Aldric Ferrand', mark: 'AF', crafted_at: 1722000000,
        history: [{ at: 1722000000, kind: 'creation', by: 'Aldric Ferrand' }],
      } },
      { id: 9, item: 'pioche', x: 7, y: 0, rotated: false, quantity: 1, metadata: {
        quality: 31, tier: 2, durability: 0, max_durability: 80, broken: true,
        crafter_name: 'Gaspard Lenoir', mark: 'GL', crafted_at: 1716000000,
        history: [{ at: 1716000000, kind: 'creation', by: 'Gaspard Lenoir' }, { at: 1724000000, kind: 'repair', by: 'Gaspard Lenoir' }],
      } },
      { id: 10, item: 'buche', x: 2, y: 2, rotated: false, quantity: 12, metadata: { tier: 2, origin: 'Forêt de Brume' } },
      { id: 11, item: 'buche', x: 3, y: 2, rotated: false, quantity: 4, metadata: { tier: 4, origin: 'Forêt de Brume' } },
      { id: 12, item: 'minerai', x: 4, y: 2, rotated: false, quantity: 9, metadata: { tier: 1, origin: 'Mine du Val', lines: [{ label: 'Pureté', value: 'faible' }] } },
    ],
  };
  const drop = {
    id: -1, kind: 'drop', label: 'Sac au sol', width: 6, height: 4, maxWeight: 60000, weight: 0,
    items: [{ id: 7, item: 'pain', x: 0, y: 0, rotated: true, quantity: 1, metadata: {} }],
  };
  // catalogue de développement : une pile pleine de chaque objet, par catégorie puis libellé, filtré par le bandeau
  // (catégorie, recherche sans accents ni casse) et découpé en pages courtes pour montrer la pagination
  const CATALOG_PER_PAGE = 6;
  const catalogState = { category: '', page: 1, query: '' };
  const fold = (text) => text.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  function catalogPage() {
    const names = Object.keys(definitions).sort((a, b) => (definitions[a].category || '').localeCompare(definitions[b].category || '')
      || definitions[a].label.localeCompare(definitions[b].label));
    const counts = {};
    for (const name of names) counts[definitions[name].category || ''] = (counts[definitions[name].category || ''] || 0) + 1;
    const needle = fold(catalogState.query);
    const kept = names.filter((name) => (!catalogState.category || (definitions[name].category || '') === catalogState.category)
      && (!needle || fold(definitions[name].label).includes(needle) || name.includes(needle)));
    const pages = Math.max(1, Math.ceil(kept.length / CATALOG_PER_PAGE));
    const page = Math.min(Math.max(1, catalogState.page), pages);
    let x = 0, y = 0;
    const items = kept.slice((page - 1) * CATALOG_PER_PAGE, page * CATALOG_PER_PAGE).map((item, index) => {
      const def = definitions[item];
      if (x + def.width > 16) { x = 0; y += 4; }
      const placed = { id: 200 + index, item, x, y, rotated: false, quantity: def.stack, metadata: {} };
      x += def.width + 1;
      return placed;
    });
    const categories = Object.keys(counts).sort((a, b) => Number(a === '') - Number(b === '') || a.localeCompare(b)).map((id) => ({ id, count: counts[id] }));
    return {
      id: -2, kind: 'catalog', label: 'Catalogue (développement)', width: 16, height: 10, maxWeight: 0, weight: 0, items,
      catalog: { category: catalogState.category, page, pages, query: catalogState.query, total: kept.length, categories },
    };
  }
  const weigh = (container) => container.items.reduce((sum, i) => sum + definitions[i.item].weight * i.quantity, 0);
  let hands = 8;
  const shown = { drop: false, catalog: false };

  function snapshot(withDrop, withCatalog) {
    const containers = [own].concat(withDrop ? [drop] : [], withCatalog ? [catalogPage()] : []);
    for (const container of containers) container.weight = weigh(container);
    return { own: own.id, containers: JSON.parse(JSON.stringify(containers)), definitions, hotbar: [1, 2, 8, 0, 0], hands, closeKey: 'I' };
  }

  async function handle(name, data) {
    await new Promise((resolve) => setTimeout(resolve, 60));
    if (name === 'split') return { ok: true, id: nextId++ };
    if (name === 'use') {
      window.postMessage({ action: 'notify', payload: { message: 'Vous mangez une miche de pain.' } }, '*');
      return { ok: true };
    }
    if (name === 'hold') {
      const item = own.items.find((entry) => entry.id === data.id);
      if (data.id !== 0 && !(item && definitions[item.item].holdable)) return { ok: false, error: 'not_holdable' };
      hands = data.id;
      window.postMessage({ action: 'hands', payload: { id: hands } }, '*');
      return { ok: true };
    }
    if (name === 'catalog') {
      // comme le serveur : la page demandée revient dans un nouvel état complet
      Object.assign(catalogState, { category: data.category || '', page: Number(data.page) || 1, query: data.query || '' });
      window.postMessage({ action: 'open', payload: snapshot(shown.drop, true) }, '*');
      return { ok: true };
    }
    return { ok: true, data };
  }

  if (!inGame) {
    window.addEventListener('DOMContentLoaded', () => {
      document.body.classList.add('dev');
      const params = new URLSearchParams(window.location.search);
      shown.drop = params.get('drop') === '1';
      shown.catalog = params.get('catalog') === '1';
      window.postMessage({ action: 'open', payload: snapshot(shown.drop, shown.catalog) }, '*');
    });
  }

  return { handle, snapshot, inGame };
})();
