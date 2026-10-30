# vava_example_atelier — exemple de l'Atelier du Conseil

Ressource de **développement** (T-100) : la preuve qu'un module déclare ses ateliers **sans une ligne d'interface**.
Serveur seulement : ni client, ni page. **Jamais sur un serveur ouvert au public** : sans `set vava_env dev`, le module
refuse de démarrer (« mode développement absent ») et ne déclare rien.

## Ce qu'elle déclare

| Atelier | Famille, droit | Types |
|---|---|---|
| `vava_example_atelier:panneaux` — « Panneaux du bourg (exemple) » | le monde, `metiers` | `panneau` (mise en page « page », les huit widgets, trois groupes dont un replié, deux réglages côte à côte, étapes) ; `affiche` (mise en page « volet ») |
| `vava_example_atelier:proclamations` — « Proclamations (exemple) » | la société, `staff` (Souverain : sert au test des droits) | `proclamation` |

Données gardées **en mémoire**, tirées de `config.lua` (deux panneaux, une affiche, une proclamation) : rien n'est écrit
en base. Fonctions lues par l'Atelier : `index`, `read`, `validate`, `options` (source `quartiers`), `compare`.

Règles propres au module (`shared/rules.lua`, rendues par `validate`) :
- nom unique parmi les panneaux (accents et casse ignorés, l'entrée elle-même exclue) : « Un panneau porte déjà ce
  nom. » ;
- panneau éclairé ⇒ affiché au moins un jour : « Un panneau éclairé reste au moins un jour : la lanterne doit valoir la
  peine. » ;
- langue « Runes » ⇒ texte de 120 caractères au plus : « Les runes se gravent lentement : 120 caractères au plus. »

Modèles du réglage « Apparence » : modèles vanilla provisoires (`-- PLACEHOLDER` dans `config.lua`), marqués
`provisional` : l'Atelier affiche « Modèle provisoire : il sera remplacé automatiquement… ».

## Commande

`/atelier_exemple journal <panneaux|proclamations> <texte>` (Conseil, droit effectif de l'atelier choisi ; aussi depuis
la console du serveur, au nom de « Console ») : écrit par l'export `journal` de l'Atelier une ligne `note` sur la
première entrée de l'atelier, avec le texte pour résumé (160 octets au plus). Sert à éprouver l'export, l'affichage, la
pagination et la recopie au journal du Registre avant T-101. Déclarée au Codex (chapitre « Tests »).

## Installation

Avec `set vava_env dev` au `server.cfg` du serveur de test : `ensure vava_example_atelier` après `vava_atelier`.
L'ordre n'est pas critique : les ateliers sont déclarés au démarrage du module si l'Atelier tourne, et redéclarés au
hook `vava_atelier:editorsReady` à chaque démarrage de l'Atelier. `vava_atelier` n'est volontairement pas en
`dependency` du manifeste (FiveM arrêterait l'exemple à chaque `restart vava_atelier` sans le relancer).

## Fichiers

| Fichier | Rôle |
|---|---|
| `config.lua` | commande, données de départ, quartiers, modèles provisoires |
| `shared/guard.lua` | pur : mode développement (testé : `tests/spec/examples_atelier_spec.lua`) |
| `shared/rules.lua` | pur : règles des panneaux et encadré « Pour comparer » (même test) |
| `shared/forms.lua` | formulaires des trois types (acceptés tels quels : `tests/spec/atelier_formschema_spec.lua`) |
| `server/main.lua` | déclaration des deux ateliers, fonctions lues par l'Atelier, commande |

Contrôles en jeu : [docs/tests/atelier.md](../../docs/tests/atelier.md) et [docs/tests/developpement.md](../../docs/tests/developpement.md).
