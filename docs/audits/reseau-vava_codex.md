# Audit réseau et performance — vava_codex 1.1.2 — 30 octobre 2026 (T-011)

## Périmètre

Panneau de toutes les commandes et touches (F1), préférences (favoris, dernières pages), suggestions du chat. Lus en
entier : `server/main.lua`, `server/suggestions.lua`, `server/prefs.lua` (champ), `client/main.lua` ; dans
`server/catalog.lua` : `visible`, `options` (`:100-237`) ; `bridge/server.lua:60-80`, `:170-177`.

## Envois serveur → client

| Évènement | Fichier:ligne | Cible | Taille estimée | Fréquence |
|---|---|---|---|---|
| réponse `open` : **tout le contenu visible** (entrées, chapitres, commandes non décrites pour le Conseil, préférences) | `server/main.lua:26-35`, demandé par `client/main.lua:82-97` | le demandeur | 31 déclarations au registre `core:commands` dans le dépôt, avec sous-commandes, arguments, aides et touches : estimé 10 à 30 Ko selon les droits, à mesurer | **à chaque ouverture du Codex** (F1) |
| réponse `options` (valeurs d'un argument) | `server/catalog.lua:209-237` | le demandeur | hors Conseil, les seuls joueurs proches ; listes de registres bornées (`MAX_OPTIONS`) | à la demande d'un formulaire |
| `NOTIFY` | `bridge/server.lua:176` | le joueur | 50-150 o | messages |
| suggestions du chat | export `server/suggestions.lua:79-81`, envoyé par vava_chat avec le profil | le joueur | une entrée par commande permise | une fois par apparition |
| champ `vava_codex:prefs` (`owner`) | `server/prefs.lua:50` | le joueur | jusqu'à 24 favoris + 12 dernières pages : environ 1,8 Ko | au chargement et **à chaque commande lancée depuis le Codex** ; aucun fichier `client/` ne le lit (les préférences arrivent avec `open`) |

## GlobalState, state bags, boucles, props

Aucun. Une seule attente côté client (`client/main.lua:135-138`, rendue du focus après une commande).

## NUI et fichiers web

Contenu envoyé à la page à l'ouverture. `web/` : 246 502 o, dont 156 431 o communs (T-012) ;
`web/js/devmock.js` (11 429 o) livré.

## BLOQUANT

Aucun.

## IMPORTANT

- `server/main.lua:26-35` et `client/main.lua:82-97` — **catalogue complet renvoyé à chaque ouverture, sans version ni
  cache** — le contenu du Codex ne change qu'au démarrage ou à l'arrêt d'un module et quand les droits du joueur
  changent, mais il repart en entier (10 à 30 Ko, en évènement fiable) à chaque appui sur F1. `SECURITE_RESEAU.md`
  § Bande passante 5 : une fois, gardé par le client avec une version, renvoyé seulement si elle change. Correction :
  numéro de version du catalogue (incrémenté par les hooks `core:registry:added`/`removed` sur `core:commands`) et
  empreinte des droits du joueur ; `open(versionConnue)` ne renvoie que les préférences quand rien n'a changé ; page
  qui garde le contenu entre deux ouvertures ; au-delà du seuil de T-013, envoi latent. Tâche T-046.

## MINEUR

- `server/prefs.lua:50` — **préférences en `owner` sans lecteur côté client** — `private` suffit ; évite environ 1,8 Ko
  par commande lancée depuis le Codex (voir `reseau-vAvA_core.md`).

## Points solides

- Options des arguments « joueur » limitées aux joueurs proches hors du Conseil ; listes de registres bornées.
- Aucune boucle, aucun envoi périodique ; touches résolues côté client.

## À vérifier en jeu

- Taille de la réponse `open` pour un joueur et pour un Souverain (compteur T-013).

VERDICT : À CORRIGER
