# vava_dev_characters — outils de test des personnages, de l'inventaire, de la faim et de la santé

Ressource de **développement** : elle n'a rien à faire sur un serveur ouvert au public. Elle est rendue inoffensive
par le code (1.3.0) : même démarrée par erreur, elle n'offre rien sans le mode développement, et rien à qui n'a pas
le droit.

## La garde

| Condition | Effet |
| --- | --- |
| Convar serveur `vava_env` absente ou différente de `dev` | `setup` refuse : console `module 'vava_dev_characters' … refusé : setup a refusé le démarrage : mode développement absent (convar vava_env ≠ dev) : rien n'est offert`. Aucun RPC n'existe ; `/perso` répond « outils de développement inactifs sur ce serveur ». |
| `set vava_env dev` | Le module démarre, avec un avertissement en console. Chaque commande est revérifiée par le serveur à chaque appel. |
| Joueur sans droit | Refus `not_allowed` : « réservé au Conseil (droit staff) ou à l'ACE vava.dev ». |
| Droit vava_admin `staff` (Souverain) | Accès. Chaque changement est inscrit au journal du Registre (`vava_admin:log`). |
| ACE `vava.dev` | Accès, avec ou sans vava_admin. Le journal du Registre n'accepte que les membres du Conseil : sans rang, la ligne va à la console du serveur. |

La valeur doit être exactement `dev` (pas `DEV`, pas `development`). Elle est lue au démarrage du module (après
`set vava_env dev` en console : `restart vava_dev_characters`) et **relue à chaque appel** : `set vava_env prod` ferme
aussitôt toutes les commandes, sans redémarrage.

```cfg
# server.cfg du serveur de TEST seulement (jamais sur le serveur public)
set vava_env dev
# facultatif : un testeur qui n'est pas Souverain
add_ace identifier.license:0123456789abcdef vava.dev allow
```

## Commandes

| Commande | Effet | Journal |
| --- | --- | --- |
| `/perso liste \| creer <prénom> <nom> <h\|f> \| choisir <id> \| quitter \| supprimer <id>` | personnages du compte, par les RPC du core (le client demande d'abord l'accès au serveur) | — (actions du core) |
| `/respawn` | réapparition à la dernière position connue | « Outil de test : réapparition » (position de départ, lue par le serveur) |
| `/objet <nom> [quantité]` | objet du registre donné au personnage actif (100 au plus) | « Outil de test : objet donné » (objet, quantité) |
| `/besoins [faim] [soif]` | lit, ou fixe, la faim et la soif | « Outil de test : besoins fixés » (lecture non inscrite) |
| `/vie [pourcentage]` | lit, ou fixe, la vie | « Outil de test : vie fixée » (lecture non inscrite) |
| `/aterre` | met à terre | « Outil de test : mise à terre » |

`/perso` passe par les RPC du core, que l'écran de sélection utilise aussi : la garde de cette ressource retire la
commande, pas le pouvoir (le core reste seul juge : compte propriétaire, état de la session).

## Réglages (`config.lua`)

| Clé | Défaut | Rôle |
| --- | --- | --- |
| `access.permission` | `staff` | droit vava_admin qui ouvre les outils |
| `access.ace` | `vava.dev` | ACE qui ouvre les outils, avec ou sans vava_admin |
| `accessRateLimit` | 5, +1/s | demandes d'accès de `/perso` |
| `giveRateLimit`, `maxGiveQuantity` | 5, +1/s ; 100 | dons |
| `needsRateLimit`, `healthRateLimit`, `respawnRateLimit` | 5, +1/s ; 5, +1/s ; 2, +0,1/s | autres commandes |
| `journal` | libellés ci-dessus | libellés du journal du Registre (32 octets au plus) |
| `refusals` | — | textes affichés pour `not_allowed` et `unknown_rpc` |

## RPC

| Nom | Arguments | Limite | Contrôles |
| --- | --- | --- | --- |
| `vava_dev_characters:access` | aucun | `accessRateLimit` | accès |
| `vava_dev_characters:give` | objet (1–64, `^[%w_%-%.:]+$`), quantité (1–100, facultative) | `giveRateLimit` | accès, puis l'inventaire (personnage actif, place) |
| `vava_dev_characters:health` | pourcentage 0–100 facultatif | `healthRateLimit` | accès, puis vava_health |
| `vava_dev_characters:down` | aucun | `healthRateLimit` | accès, puis vava_health |
| `vava_dev_characters:needs` | faim, soif 0–100 facultatives | `needsRateLimit` | accès, puis vava_needs |
| `vava_dev_characters:respawn` | aucun | `respawnRateLimit` | accès, personnage actif |

Aucun évènement, aucun envoi à d'autres joueurs. Les appels à vava_admin sont isolés (`pcall`) : un Registre arrêté ou
en erreur ne donne jamais l'accès.

## Dépendances

`vAvA_core` ≥ 0.4.0, `vava_inventory` ≥ 1.1.0, `vava_needs` ≥ 1.1.0, `vava_health` ≥ 1.0.0 ; facultatif : `vava_admin`
(droit et journal). Logique pure testée : `tests/spec/examples_guard_spec.lua`.

## À vérifier en jeu

Procédure : [docs/tests/developpement.md](../../docs/tests/developpement.md).
