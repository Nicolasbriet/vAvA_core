'use strict';
/*
 * web/js/strings.js
 * Rôle : tous les textes affichés par le Codex (français).
 */

const STRINGS = Object.freeze({
  title: 'Codex',
  tabs: { commands: 'Commandes', keys: 'Touches' },
  search: { placeholder: 'Rechercher une commande…', keysPlaceholder: 'Rechercher une touche…', count: (n) => (n > 1 ? `${n} entrées` : `${n} entrée`) },
  sections: {
    favorites: 'Signets',
    recent: 'Dernières pages',
    results: 'Résultats',
    undeclared: 'Non décrites',
    undeclaredHint: 'Enregistrées auprès du jeu, pas encore décrites au registre : lançables en texte libre.',
    allChapters: 'Tout',
  },
  scopes: { player: 'Tous', admin: 'Conseil', console: 'Console' },
  badges: { key: 'touche', hold: 'maintenir', ui: 'interface' },
  detail: {
    empty: 'Choisissez une commande à gauche, ou tapez pour chercher.',
    emptyKeys: 'Choisissez une touche à gauche.',
    syntax: 'Syntaxe',
    line: 'Ligne lancée',
    run: 'Lancer',
    runHint: ['Entrée', 'lancer'],
    consoleOnly: 'Cette commande ne se lance que depuis la console du serveur ; elle est montrée pour mémoire.',
    missing: (name) => `Il manque « ${name} ».`,
    optional: 'facultatif',
    favorite: 'Mettre en signet',
    unfavorite: 'Retirer le signet',
    keyNote: 'Chaque touche se change dans Paramètres › Raccourcis › FiveM. Le Codex montre la vôtre.',
    keyHold: 'À maintenir : agit à l\'appui et au relâchement.',
    keyDefault: (key) => `Par défaut : ${key}`,
    undeclaredArgs: 'arguments',
    undeclaredNote: 'Commande non décrite : écrivez ses arguments tels que vous les taperiez.',
    placeholder: (name) => name,
  },
  settings: {
    keepOpen: 'Rester ouvert après « Lancer »',
    keepOpenHint: 'Une commande qui ouvre une interface ferme toujours le Codex d\'abord.',
  },
  // [touche, action] : légende en bas de l'écran
  hints: [
    ['↑ ↓', 'parcourir'],
    ['Entrée', 'choisir, lancer'],
    ['Tab', 'champ suivant'],
    ['Échap', 'retour, fermer'],
  ],
  errors: {
    default: 'Action impossible.',
    unknown: 'Cette commande n\'est pas dans le Codex.',
    refused: 'Cette commande ne vous est pas ouverte.',
    console: 'Cette commande ne se lance que depuis la console du serveur.',
    favorites_full: 'Vous avez atteint le nombre de signets permis : retirez-en un.',
    no_character: 'Aucun personnage chargé.',
    invalid_request: 'Demande refusée.',
    rate_limited: 'Doucement…',
    timeout: 'Le serveur ne répond pas.',
    client_error: 'Erreur de l\'interface.',
  },
  ran: (line) => `Lancé : /${line}`,
});

/** Message lisible pour un code d'erreur. */
function errorMessage(code) {
  return STRINGS.errors[code] || (typeof code === 'string' && code.length > 0 && !code.includes('_') ? code : STRINGS.errors.default);
}

/** Texte replié pour la recherche : sans accents ni majuscules. */
function fold(text) {
  return String(text || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
}
