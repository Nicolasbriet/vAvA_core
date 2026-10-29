# Audit sécurité — vava_skills 1.1.3 — 29 octobre 2026 (T-010)

## Périmètre

Fichiers lus en entier : `fxmanifest.lua`, `config.lua`, `shared/constants.lua`, `shared/progression.lua`,
`server/main.lua`, `server/core.lua`, `server/api.lua`, `server/admin.lua`, `server/commands.lua`, `server/journal.lua`,
`server/registries.lua`, `server/sheets.lua`, `server/shortages.lua`, `server/progression.lua`, `server/mentoring.lua`,
`server/lessons.lua`, `bridge/server.lua`, `client/main.lua`, `client/nui.lua`, `web/index.html`, `web/js/app.js`,
`ui.js`, `model.js`, `view-skills.js`, `view-mentoring.js`, `view-knowledge.js`, `view-shortages.js`, `strings.js`
(`errorMessage`), `sql/0001_skills.sql`, `README.md`, section `vava_skills` de `docs/api.md`, `docs/plan/rapports/T-003.md`
(les règles testées — plafond par niveau, rangs, rendements, `clampLevel` — sont bien celles de
`shared/progression.lua:275-342`). Lus pour les garanties extérieures : `vava_admin/server/api.lua` (`can`, `log`),
`server/players/characters.lua` du core (aucun RPC client n'écrit un champ de personnage).

Rôle : fondation des métiers — niveaux, XP, rangs, budget et rouille, pénurie, mentorat et Renommée, savoirs transmis
(leçons, fragments, fondateurs, lignées) ; les modules métiers appellent `addXp`, le serveur décide de tout.

Non lu : `web/css/style.css`, polices, images ; `web/js/devmock.js` (hors jeu).

## Points d'entrée

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `vava_skills:sheet` | RPC | `{}` (`server/main.lua:69`) | 3 puis 0,5/s (`config.lua:115`) | fiche chargée (= personnage actif) (`main.lua:70-72`) | ne renvoie que la fiche du demandeur ; noms des maîtres, apprentis et professeurs liés à lui |
| `vava_skills:setMode` | RPC | `SKILL` chaîne 1–32 `^[%l_]+$`, `MODE` enum `up/keep/down` (`main.lua:29,31,74`) | 6 puis 2/s | fiche, compétence du registre, mode connu (`progression.lua:227-239`) | écriture groupée toutes les 10 s |
| `vava_skills:nearby` | RPC | `{}` (`main.lua:75`) | 3 puis 0,2/s (`mentor`) | fiche ; positions lues sur les peds serveur, rayon 10 m (`mentoring.lua:150-161`) | rend nom de personnage, numéro de session et distance arrondie |
| `vava_skills:propose` | RPC | `PLAYER` entier 1–65 535, `SKILL` (`main.lua:32,79`) | 3 puis 0,2/s | fiche, compétence, cible ≠ soi avec fiche, rang Maître et 10 h de jeu du serveur, comptes différents, cible pas déjà mentorée, 3 apprentis au plus, distance serveur 10 m, pas de proposition en attente (`mentoring.lua:199-231`) | proposition en mémoire, expire après 60 s à l'horloge serveur |
| `vava_skills:answer` | RPC | `PROPOSAL` entier 1–2³¹−1, `BOOL` (`main.lua:33,80`) | 3 puis 0,2/s | proposition adressée à **ce** joueur, non expirée, les deux parties encore là avec le même personnage, distance, places revérifiées et **tenues** pendant l'écriture (`accepting`, `mentoring.lua:239-273`) | deux acceptations simultanées ne dépassent ni les 3 apprentis ni le maître unique |
| `vava_skills:break` | RPC | `MENTORSHIP` entier 1–2³²−1 (`main.lua:34,81`) | 3 puis 0,2/s | fiche, mentorat connu, demandeur maître ou apprenti (`mentoring.lua:339-347`) ; `UPDATE … WHERE ended_at IS NULL` tranche une double rupture (`:352-358`) | journal `mentor_end` |
| `vava_skills:lineage` | RPC | `RECIPE` chaîne 1–64 `^[%l%d_]+$` (`main.lua:30,82`) | 4 puis 0,5/s | fiche, recette du registre ; lignée depuis son propre personnage seulement, ≤ 64 maillons, boucle détectée (`lessons.lua:184-204`) | une lecture par maillon (voir MINEUR) |
| `vava_skills:shortages` | RPC | `{}` (`main.lua:89`) | 3 puis 0,5/s | aucune : liste publique recalculée toutes les 30 min | — |
| `core:character:loaded / unloading`, `core:player:dropped`, `core:character:deleted` | hook | — | — | fiche chargée avant l'apparition puis libérée (écrite au départ), propositions oubliées, mentorats clos à la suppression (`main.lua:97-105`) | départ pendant le chargement traité (`main.lua:55-57`) |
| `addXp`, `getLevel`, `hasRank`, `getSkill(s)`, `knowsRecipe`, `recordLesson`, `addFragment`, `grantRecipe`, `getMentor`, `getApprentices`, `isMentoredNow`, `getRenown`, `getLineage`, `getShortages`, `shortageMultiplier` | export | `addXp` : `amount` entier 0–500, `difficulty` entier 0–100, compétence du registre (`progression.lua:149-155`) ; `recordLesson` : professeur connaît la recette, 10 h de jeu, comptes différents, niveau de l'élève, distance 10 m, 1 h entre deux leçons, place tenue avant l'écriture (`lessons.lua:100-124`) | — | ressources serveur seulement ; `grantRecipe` journalisé au nom du module appelant (`api.lua:96-101`) | aucun RPC client ne porte d'XP, de niveau ni de recette |
| `/metiers niveau · recette · voir` | commande | texte | — | droit `metiers` (`admin.lua:96`, `bridge:161-168`), cible = joueur connecté avec fiche, niveau 0–100 (`progression.lua:253`), recette transmise du registre ; journal du module + Registre (`admin.lua:119,127`) | déclarée `scope = 'admin'` au Codex (`commands.lua:29`) |
| `vava_fondateur` | commande | texte | — | `RegisterCommand(…, true)` (ACE) **et** droit `staff` (`admin.lua:67,138`) ; journal + Registre (`admin.lua:87`) | déclarée `scope = 'console'` au Codex (`commands.lua:36`) |
| `setMode`, `nearby`, `propose`, `answer`, `break`, `lineage`, `shortages`, `refresh`, `close` | NUI | types forcés par le Lua client (`d.accept == true`) | — | chaque geste passe par un RPC ci-dessus (`client/main.lua:118-142`) ; `close` est local | — |
| `vava_skills:skill`, `proposal`, `mentorship`, `recipe`, `lesson`, `notify` | évènement serveur → client | — | — | toujours vers le seul joueur concerné (`progression.lua:72`, `mentoring.lua:64-66,224`, `lessons.lua:86,129-130`) | aucun `-1`, aucun state bag, aucun GlobalState |
| Champ de personnage `vava_skills:*` | — | — | — | aucun (`grep defineField` vide) : tout vit dans les tables du module | — |

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

- `server/lessons.lua:100-117` contre `config.lua:76` — **rang du professeur** : le commentaire de `mentoring.minRank`
  dit « rang pour proposer un mentorat (et pour enseigner une leçon) », mais `recordLesson` n'exige que la connaissance
  de la recette et 10 h de jeu (`:108-109`) ; le README et `docs/api.md` ne parlent pas de rang pour les leçons.
  Trancher : ajouter `rules.hasRank(sheets.level(teacher, def.skill), mentorCfg.minRank)` (code `not_master`) ou
  corriger le commentaire.
- `bridge/server.lua:137-153` — **distances sans instance** : proposition (10 m), bonus du maître (20 m), Arcanes
  (30 m) et leçons (10 m) comparent des coordonnées sans tenir compte du routing bucket ; un joueur d'une autre
  instance aux mêmes coordonnées compte comme présent. Sans portée tant que le serveur n'a qu'une instance ; comparer
  `GetPlayerRoutingBucket` comme vava_codex (`vava_codex/bridge/server.lua:95-99`).
- `server/lessons.lua:184-197` — **lignée en lectures séquentielles** : jusqu'à 64 `SELECT` par appel, 4 puis 0,5/s par
  joueur. La profondeur dépend des données réelles (un joueur ne peut pas la forger), donc pas de levier d'attaque,
  mais un cache court par recette et personnage, ou une requête récursive, borneraient la charge.

## Points solides

- Aucun résultat ne vient du client : l'XP, le niveau, le rang, la Renommée, la pénurie et les recettes connues sont
  calculés par le serveur depuis des appels d'autres ressources serveur ; les huit RPC ne portent que des intentions
  (mode, proposition, réponse, rupture, lectures) avec schémas bornés et motifs ancrés.
- Le mentorat résiste aux courses : la proposition est retirée et les places sont tenues (`accepting`) avant
  l'écriture qui cède la main ; la rupture est tranchée par l'`UPDATE` conditionnel ; la leçon réserve son compteur
  avant l'`INSERT` et le rend en cas d'échec.
- Toutes les décisions dépendant du monde sont relues côté serveur : positions des peds, temps de jeu du personnage
  (`playSeconds` du core), comptes différents, délai d'une heure entre leçons à l'horloge serveur.
- Droits du Conseil vérifiés par le serveur avec refus par défaut quand vava_admin répond mal (`called and allowed ==
  true`), fondateur réservé à `staff` **et** à l'ACE de la commande ; chaque action sensible (leçon, mentorat,
  fondateur, correction, rouille, savoir appris, Arcanes refusées) est au journal, et au Registre pour le Conseil.
- SQL uniquement par `core.db`, paramétré ; la seule construction dynamique (`NamesOf`) n'insère que des `?`
  (`bridge:112-113`). Interface construite par `textContent` seul (`web/js/ui.js:9-15`), noms de personnages
  compris.

VERDICT : OK
