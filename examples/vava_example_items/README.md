# vava_example_items — objets d'exemple de l'inventaire

Huit objets de démonstration avec leurs images : `pain`, `pomme`, `eau`, `biere` (nourriture et boissons, effets lus
par `vava_needs`), `bandage` (Bande de lin, +20 % de vie, lue par `vava_health`), `epee`, `bourse`, `corde`. Montre
comment un module déclare des objets, sert leurs images (`nui://vava_example_items/web/items/…`) et les redéclare quand
l'inventaire redémarre. Ressource de **développement** : contenu provisoire, à remplacer par les objets des modules du
royaume.

## La garde (1.2.0)

La ressource n'ouvre aucune entrée réseau : ce qu'elle « offre », ce sont des définitions d'objets, dont un soin. Ils
ne s'obtiennent que par le catalogue de développement, les outils de `vava_dev_characters` ou un autre module, mais
une définition présente sur un serveur ouvert reste un objet de plus au catalogue et une Bande de lin qui soigne.

| Condition | Effet |
| --- | --- |
| Convar `vava_env` absente ou différente de `dev` | `setup` refuse (« mode développement absent ») : aucun objet déclaré, rien au catalogue. |
| `set vava_env dev` | Les huit objets sont déclarés, et redéclarés à chaque annonce `core:module:ready` de l'inventaire. |

Piles déjà en jeu quand le module ne déclare plus ses objets : l'inventaire les **garde à part** (ni affichées, ni
utilisables, jamais effacées) ; elles reviennent à leur place dès que le module tourne de nouveau en mode développement.
Aucun module du royaume ne dépend de ces objets.

## Dépendances

`vAvA_core` ≥ 0.3.0, `vava_inventory` ≥ 1.1.0 ; `vava_needs` et `vava_health` pour les effets.

## À vérifier en jeu

Procédure : [docs/tests/developpement.md](../../docs/tests/developpement.md), § 4.
