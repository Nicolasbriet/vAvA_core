# Kit agents Eldoria — installation (version 2 : Atelier et combat v1)

Ce kit se copie **à la racine de vAvA_core**. Il n'ajoute aucune dépendance au serveur de jeu : tout ce qu'il
contient sert au développement (agents, tests, vérifications) et n'est jamais chargé par FXServer.

| Chemin | Rôle |
|---|---|
| `CLAUDE.md` | Règles lues par Claude Code et tous les agents : lore, conventions du dépôt, sécurité, performance, bande passante, façon de travailler |
| `.claude/agents/` | 7 agents : architecte, dev Lua, dev NUI, sécurité, réseau/perf, testeur, gardien du lore |
| `docs/plan/ROADMAP.md` | Phases jusqu'à la 1.0.0-alpha et rôle de l'humain |
| `docs/plan/BACKLOG.md` | Tâches en 10 phases, dépendances, critères, statuts (Atelier : T-100 à T-129, combat : T-110 à T-119) |
| `docs/plan/ATELIER.md` | Conception des éditeurs en jeu : architecture, cycle de vie, outil de placement, règles d'interface |
| `docs/plan/COMBAT_V1.md` | Conception du combat : chaîne de dégâts commune, techniques en données, défense, endurance |
| `docs/maquettes/` | Les 6 maquettes de l'Atelier en HTML, ouvrables dans un navigateur |
| `docs/plan/SECURITE_RESEAU.md` | Modèle de menace, objectifs chiffrés, état des lieux du dépôt |
| `docs/plan/ASSETS_PLACEHOLDERS.md` | Travailler sans carte, montures, vêtements ni armes, et les brancher par la config |
| `docs/lore/ELDORIA.md` | Piliers du lore pour les agents (**coller le texte intégral du lore en tête**) |
| `scripts/verifier.sh` | Lint + tests + audit, avant chaque commit d'agent et en CI |
| `scripts/audit-reseau.sh` + `audit-exceptions.txt` | Motifs interdits (broadcast, SQL concaténé, réseau hors RPC, CDN…) et exceptions justifiées |
| `scripts/agents/` | Boucle continue, consigne d'une session, mode d'emploi |
| `tests/`, `.busted`, `.luacheckrc` | Tests unitaires (6 déjà verts sur ton code) et configuration du lint |
| `.github/workflows/verifier.yml` | Vérification automatique à chaque push |

Étapes :
1. Copier le contenu du kit à la racine du dépôt. Si la version 1 du kit est déjà installée, cette version la
   remplace : garder seulement les statuts déjà modifiés dans `BACKLOG.md` (aucune tâche n'a encore commencé si tu
   n'as pas lancé d'agent).
2. Ajouter au `.gitignore` : `.agents/` et `STOP`.
3. Coller le lore intégral dans `docs/lore/ELDORIA.md`.
4. Relire `docs/plan/BACKLOG.md` et ajuster ce qui ne te convient pas : c'est **ton** plan.
5. Commit, puis suivre `scripts/agents/LISEZMOI.md`.
