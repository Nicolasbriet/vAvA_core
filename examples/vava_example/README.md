# vava_example — module minimal de démonstration

Modèle pour écrire un module : registre (`vava_example:noteTypes`), hooks (`vava_example:notePost`, annulable),
RPC dans les deux sens (`vava_example:postNote`, `vava_example:ping`), champ de personnage
(`vava_example:notesPublished`), migrations (`sql/`). Ressource de **développement** : rien à faire sur un serveur
ouvert au public.

## La garde (1.2.0)

| Condition | Effet |
| --- | --- |
| Convar `vava_env` absente ou différente de `dev` | `setup` refuse (« mode développement absent ») : ni `/note`, ni `example_ping`, ni registre. Les migrations sont appliquées avant `setup` par le core : la table `vava_example_notes` existe, vide. |
| `set vava_env dev` | Le module démarre et retire les notes de plus de `retentionDays` jours. |
| `/note` d'un joueur sans droit | Refus `not_allowed`. |
| Droit vava_admin `staff` ou ACE `vava.dev` | Note publiée, sous le plafond par personnage. |

La convar est relue à chaque `/note` : `set vava_env prod` en console la refuse aussitôt, sans redémarrage.

## Commandes

| Commande | Qui | Effet |
| --- | --- | --- |
| `/note <type> <texte>` | droit `staff` ou ACE `vava.dev` | publie une note (`annonce` 200 signes, `rumeur` 120) ; refus `too_many` au plafond, `forbidden_word` pour un mot interdit |
| `example_ping <id>` | console, ou ACE `command.example_ping` | interroge un client et valide sa réponse (valeur déclarée, jamais crue) |

## Réglages (`config.lua`)

| Clé | Défaut | Rôle |
| --- | --- | --- |
| `access` | `staff` / `vava.dev` | droit vava_admin ou ACE qui ouvre `/note` |
| `postRateLimit` | 3, +0,2/s | une note toutes les 5 s en régime établi |
| `maxNotesPerCharacter` | 20 | notes gardées par personnage ; au-delà, refus `too_many` |
| `retentionDays` | 7 | notes plus anciennes retirées à chaque démarrage |
| `noteTypes`, `forbiddenWords` | — | types de notes et mots refusés |

Une seule note à la fois par personnage (verrou du serveur) : deux appels rapprochés ne franchissent pas le plafond.
Logique pure testée : `tests/spec/examples_guard_spec.lua` (garde, plafond).

## Dépendances

`vAvA_core` ≥ 0.2.0 ; facultatif : `vava_admin` (droit).

## À vérifier en jeu

Procédure : [docs/tests/developpement.md](../../docs/tests/developpement.md), § 3.
