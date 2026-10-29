# Feuille de route : de vAvA_core 0.7 à une version jouable d'Eldoria

## Définition de la version jouable (1.0.0-alpha)

Un joueur arrive par un **écran de chargement** à l'image d'Eldoria, **crée son personnage**, apparaît dans le bourg
avec presque rien, et vit une soirée de **GTA RP classique** : il parle, troque, aide, apprend un métier auprès d'un
autre joueur, récolte, cultive, forge, rejoint une confrérie, se bat avec une arme qu'un forgeron a faite, se soigne,
rentre chez lui. Le staff fait vivre le monde en jeu avec l'Atelier : zones, stations, confréries, gestes, techniques
et sorts se créent sans développeur ni redémarrage. Tout ce qui a de la valeur est
décidé par le serveur, rien n'est envoyé à qui n'en a pas besoin, et le serveur tient une session à 32 joueurs sans
dégradation visible. Les assets définitifs (carte, montures, vêtements, armes) se branchent ensuite par la config.

## Les phases

| Phase | Contenu | Porte de sortie (validée par un humain) |
|---|---|---|
| 0. Socle | CI, lint, tests unitaires de l'existant, procédures de test en jeu, première session de test complète | T-009 |
| 1. Sécurité, performance, réseau | Audits complets, outil de mesure réseau, ressource web commune, abonnements de zone, revue des boucles | T-019 |
| 2. Arrivée | Écran de chargement, arrivée du nouveau personnage, premiers pas dans le Codex | — |
| 3. L'Atelier : socle et créateurs du monde | Cadre de l'Atelier, définitions versionnées, outil de placement, créateurs de récolte, agriculture, artisanat, confréries (jobs), portes | T-109 |
| 4. Combat v1 | Chaîne de dégâts commune, armes, moteur de techniques, défense, endurance, styles, magie branchée sur la chaîne | T-119 |
| 5. Interactions RP | Troc face à face, don, fouille et liens, parchemins, présentations | T-039 |
| 6. Les arts de l'Atelier | Gestes (et émotes), éditeur de techniques, effets, sorts, invocations, transformations | T-129 |
| 7. Société | Équipement porté, logis, cachot | — |
| 8. Monde | Temps, saisons et météo, montures (squelette), région de remplacement | T-059 |
| 9. Version jouable | Session de charge, liste de mise en ligne, 1.0.0-alpha | T-062 |

Le détail des tâches, leurs dépendances et leurs critères sont dans `BACKLOG.md`. Les références de conception
sont `ATELIER.md` (éditeurs en jeu) et `COMBAT_V1.md` (combat), avec les maquettes de `docs/maquettes/`.

## Comment les agents travaillent

```
                 BACKLOG.md (tâche éligible suivante)
                               │
          ┌────────────────────┴───────────────────┐
   nouveau système ?                         petite tâche
          │                                        │
   vava-architecte → specs/T-xxx.md                │
          └────────────────────┬───────────────────┘
                               ▼
              vava-dev-lua  /  vava-dev-nui  (+ vava-testeur)
                               ▼
                    ./scripts/verifier.sh
                               ▼
     vava-securite + vava-reseau-perf (+ vava-gardien-lore)
                               ▼
         corrections → statut « à tester en jeu » → commit
```

Chaque tâche est faite sur sa branche `agents/T-xxx`, fusionnée dans `agents/integration` seulement si
`verifier.sh` passe. **`main` n'est jamais touchée par un agent.** Le porteur du projet teste en jeu ce qui est
« à tester en jeu », passe les tâches à « validée » ou crée une tâche de correction, puis fusionne
`agents/integration` dans `main` quand une phase est propre ; la Chancellerie propose alors la mise à jour au
serveur.

## Le rôle de l'humain (indispensable)

Les agents ne peuvent pas lancer GTA : tout ce qui se voit, s'entend ou se joue à plusieurs se vérifie à la main.
Rythme conseillé : une session de test d'une à deux heures tous les deux ou trois jours, en suivant les procédures
de `docs/tests/`, et une revue rapide des rapports d'audit. Les tâches marquées **HUMAIN** dans le backlog sont les
tiennes ; les **portes de phase** empêchent les agents d'empiler une phase sur une autre qui n'a pas été jouée.

## Mode « en continu »

`scripts/agents/boucle.sh` enchaîne les tâches éligibles une par une, chacune dans une session Claude Code
headless séparée (contexte neuf, pas de dérive), s'arrête quand il n'y a plus de tâche éligible, quand le fichier
`STOP` existe, ou après `MAX` tâches. Voir `scripts/agents/LISEZMOI.md`.
