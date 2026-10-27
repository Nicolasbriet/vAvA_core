'use strict';
/*
 * web/js/devmock.js
 * Rôle : inventaire simulé quand la page est ouverte dans un navigateur (hors FiveM), pour travailler le rendu sans
 *        lancer le jeu. Inactif en jeu. Paramètre d'URL : ?drop=1 pour afficher aussi un sac au sol. Les images
 *        viennent du module d'exemple voisin (examples/vava_example_items) quand le dépôt est complet.
 */

const DevMock = (() => {
  const inGame = typeof GetParentResourceName === 'function';
  const art = (name) => `../../../examples/vava_example_items/web/items/${name}.svg`;
  const definitions = {
    pain: { label: 'Miche de pain', description: 'Encore tiède, sortie du four du village.', width: 2, height: 1, weight: 400, stack: 10, category: 'nourriture', image: art('pain'), effects: { hunger: 35 }, usable: true },
    pomme: { label: 'Pomme', description: 'Croquante et un peu acide.', width: 1, height: 1, weight: 150, stack: 20, category: 'nourriture', image: art('pomme'), effects: { hunger: 12, thirst: 4 }, usable: true },
    epee: { label: 'Épée courte', description: 'Lame d\'acier forgée, fourreau de cuir.', width: 1, height: 4, weight: 1800, stack: 1, category: 'arme', image: art('epee'), usable: false },
    bourse: { label: 'Bourse de cuir', description: 'Une petite bourse fermée par un lacet.', width: 1, height: 1, weight: 100, stack: 1, category: 'divers', image: art('bourse'), usable: false },
    corde: { label: 'Rouleau de corde', description: 'Chanvre tressé, une dizaine de toises.', width: 2, height: 2, weight: 1200, stack: 1, category: 'outil', image: art('corde'), usable: false },
  };
  let nextId = 100;
  const own = {
    id: 1, kind: 'character', label: 'Besace', width: 10, height: 6, maxWeight: 25000, weight: 0,
    items: [
      { id: 1, item: 'pain', x: 0, y: 0, rotated: false, quantity: 3, metadata: {} },
      { id: 2, item: 'pomme', x: 2, y: 0, rotated: false, quantity: 7, metadata: {} },
      { id: 3, item: 'epee', x: 9, y: 0, rotated: false, quantity: 1, metadata: {} },
      { id: 4, item: 'bourse', x: 3, y: 0, rotated: false, quantity: 1, metadata: {} },
      { id: 5, item: 'corde', x: 0, y: 2, rotated: false, quantity: 1, metadata: {} },
      { id: 6, item: 'pomme', x: 4, y: 0, rotated: false, quantity: 20, metadata: {} },
    ],
  };
  const drop = {
    id: -1, kind: 'drop', label: 'Sac au sol', width: 6, height: 4, maxWeight: 60000, weight: 0,
    items: [{ id: 7, item: 'pain', x: 0, y: 0, rotated: true, quantity: 1, metadata: {} }],
  };
  const weigh = (container) => container.items.reduce((sum, i) => sum + definitions[i.item].weight * i.quantity, 0);

  function snapshot(withDrop) {
    const containers = [own].concat(withDrop ? [drop] : []);
    for (const container of containers) container.weight = weigh(container);
    return { own: own.id, containers: JSON.parse(JSON.stringify(containers)), definitions, hotbar: [1, 2, 0, 0, 0], closeKey: 'I' };
  }

  async function handle(name, data) {
    await new Promise((resolve) => setTimeout(resolve, 60));
    if (name === 'split') return { ok: true, id: nextId++ };
    if (name === 'use') {
      window.postMessage({ action: 'notify', payload: { message: 'Vous mangez une miche de pain.' } }, '*');
      return { ok: true };
    }
    return { ok: true, data };
  }

  if (!inGame) {
    window.addEventListener('DOMContentLoaded', () => {
      document.body.classList.add('dev');
      const withDrop = new URLSearchParams(window.location.search).get('drop') === '1';
      window.postMessage({ action: 'open', payload: snapshot(withDrop) }, '*');
    });
  }

  return { handle, snapshot, inGame };
})();
