# vava_example_atelier — exemple de l'Atelier du Conseil

Ressource de **développement** (T-100, T-101) : la preuve qu'un module déclare ses ateliers **sans une ligne
d'interface ni de client**, et qu'un atelier gardé se publie, s'essaie et revient en arrière en jeu. Serveur
seulement. **Jamais sur un serveur ouvert au public** : sans `set vava_env dev`, le module refuse de démarrer
(« mode développement absent ») et ne déclare rien ; la garde est relue à chaque redéclaration (hook
`vava_atelier:editorsReady`), à chaque `apply` (refus d'essai) et à chaque commande.

## Ce qu'elle déclare

| Atelier | Famille, droit | Types |
|---|---|---|
| `vava_example_atelier:panneaux` — « Panneaux du bourg (exemple) » | le monde, `metiers` | `panneau` (mise en page « page », les huit widgets, trois groupes dont un replié, deux réglages côte à côte, étapes, lieu orienté) ; `affiche` (volet, féminin, enfant d'un panneau) |
| `vava_example_atelier:proclamations` — « Proclamations (exemple) » | la société, `staff` (Souverain : sert au test des droits) | `proclamation` |

**1.1.0 (T-101) : ateliers gardés.** Les deux ateliers déclarent `apply` et `remove` (les panneaux aussi `trial`,
`endTrial`, `diff`, `validateLot` et `format = 1` ; les proclamations n'ont pas d'essai). Les fiches vivent en mémoire
(`shared/store.lua`) : la config au démarrage — c'est la **graine** que l'Atelier importe en version 1 au premier
démarrage —, puis l'Atelier met le magasin à l'état de la base à chaque synchronisation (la base fait foi : un texte
changé dans la config ne revient pas sans `/atelier_archives original_fiche`). L'original de la config reste lisible
par `read(kind, id, { original = true })`.

Diffusion aux seuls joueurs concernés (§ 6.4 de la spec T-101) :
- chaque panneau qui a un lieu a sa **zone du core** `panneau:<id>` (rayon = sa distance de lecture, plus
  `zone.margin`), état public `{ t = titre, x = texte, l = langue }` : `define` à sa création, `move` si le lieu change,
  `replace` au changement, `remove` au retrait ;
- une publication, un retour en arrière ou un import s'annoncent au chat des seuls abonnés de la zone (à sa création :
  des joueurs à portée calculée par le serveur) ; un joueur loin ne reçoit rien ;
- un **essai** n'est annoncé qu'à son auteur (« [Essai] Le panneau … porterait : … »), sa fin aussi ; rien d'autre ne
  change en jeu.

`diff('panneau', avant, après)` rend « Texte repeint » quand seul le texte change. `validate` accepte un retrait.

Règles propres au module (`shared/rules.lua`, rendues par `validate`) :
- nom unique parmi les panneaux (accents et casse ignorés, l'entrée elle-même exclue) : « Un panneau porte déjà ce
  nom. » ;
- panneau éclairé ⇒ affiché au moins un jour : « Un panneau éclairé reste au moins un jour : la lanterne doit valoir la
  peine. » ;
- langue « Runes » ⇒ texte de 120 caractères au plus : « Les runes se gravent lentement : 120 caractères au plus. »

Et, rendue par `validateLot` (le lot entier, une seule fois : `validate` n'en reçoit que les références) : deux
affiches d'un même panneau ne portent pas le même nom (celles du lot et celles en vigueur) : « Deux affiches d'un même
panneau portent le nom « … ». »

Modèles du réglage « Apparence » et lieux des panneaux : provisoires (`-- PLACEHOLDER` dans `config.lua`).

## Règles (config.lua)

| Clé | Défaut | Rôle |
|---|---|---|
| `boards[i].place` | `{ x, y, z, h }` -- PLACEHOLDER | lieu d'un panneau (près de la forge d'exemple) |
| `posters[i].parent` | `place_du_marche` | panneau où l'affiche est collée |
| `zone.margin` | 40 | marge de la zone du core d'un panneau |
| `zone.readRadius` | 10 | `/atelier_exemple lire` : panneaux à moins de ce rayon du joueur |
| `announce` | — | annonces du chat (publication, retrait, essai, lecture) |
| `readCooldownMs` | 2 000 | délai entre deux « lire » d'un joueur |
| `refuseConvar` | `vava_example_refuse` | en mode développement, `1` fait refuser chaque `apply` (« Refus d'essai demandé. ») |
| `repainted` | « Texte repeint » | résumé `diff` quand seul le texte change |

## Commande

- `/atelier_exemple journal <panneaux|proclamations> <texte>` (Conseil, droit effectif de l'atelier choisi ; aussi
  depuis la console, au nom de « Console ») : une ligne `note` au journal du Conseil sur la première entrée de
  l'atelier.
- `/atelier_exemple lire` (tout joueur, 2 s entre deux) : les panneaux publiés à moins de `zone.readRadius` m (position
  lue par le serveur) avec leur texte, et pour l'auteur d'un essai en cours la version d'essai (« [Essai] … ») : la
  preuve, côté serveur, de ce qui est en vigueur.

Déclarée au Codex (chapitre « Tests »).

## Installation

Avec `set vava_env dev` au `server.cfg` du serveur de test : `ensure vava_example_atelier` après `vava_atelier`.
L'ordre n'est pas critique : les ateliers sont déclarés au démarrage du module si l'Atelier tourne, et redéclarés au
hook `vava_atelier:editorsReady` à chaque démarrage de l'Atelier. `vava_atelier` n'est volontairement pas en
`dependency` du manifeste (FiveM arrêterait l'exemple à chaque `restart vava_atelier` sans le relancer).

## Fichiers

| Fichier | Rôle |
|---|---|
| `config.lua` | commande, données de départ et lieux, zone, annonces, quartiers, modèles provisoires |
| `shared/guard.lua` | pur : mode développement (testé : `tests/spec/examples_atelier_spec.lua`) |
| `shared/rules.lua` | pur : règles des panneaux et encadré « Pour comparer » (même test) |
| `shared/forms.lua` | formulaires des trois types (acceptés tels quels : `tests/spec/atelier_formschema_spec.lua`) |
| `shared/store.lua` | pur : fiches en mémoire, `apply` / `remove` / `read` / `index`, aller-retour exact, `diff` (même test) |
| `server/main.lua` | déclaration des deux ateliers, fonctions lues par l'Atelier, zones et annonces, commande |

## À vérifier en jeu

Contrôles : [docs/tests/atelier.md](../../docs/tests/atelier.md) (§ 10 à 17) et
[docs/tests/developpement.md](../../docs/tests/developpement.md) (§ 6).
