# Audit sécurité — ressources d'exemple : vava_example 1.1.1, vava_example_items 1.1.1, vava_dev_characters 1.2.0, vava_anim_test 1.0.1 — 29 octobre 2026 (T-010)

## Périmètre

Quatre ressources du dossier `examples/` : un module de démonstration de l'API (notes publiées), un jeu d'objets
d'exemple pour l'inventaire, les commandes de test des personnages et de la survie, l'outil de test des animations.

Fichiers lus en entier : `vava_example/{fxmanifest.lua, config.lua, server/main.lua, client/main.lua,
sql/0001_create_notes.sql, sql/0002_add_note_character.sql}` ; `vava_example_items/{fxmanifest.lua, server/main.lua}` ;
`vava_dev_characters/{fxmanifest.lua, config.lua, server/main.lua, client/main.lua}` ; `vava_anim_test/{fxmanifest.lua,
config.lua, server/main.lua, client/main.lua, README.md}`. Lus pour ce qu'elles appellent : `vava_health/server/api.lua`
(`setHealth`, `down`, `get`), `vava_needs/server/api.lua` (`set`), `vava_inventory/server/api.lua` (`add`),
`server/players/characters.lua` et `spawn.lua` (`characters.spawn`), `server/core/rpc.lua`, `config/server.lua`.

Non lus : `vava_anim_test/stream/vava_sword_1h.ycd` (binaire, 96 Ko), les SVG de `vava_example_items/web/items`
(images servies telles quelles). Aucune des quatre n'a de NUI : le point 7 (innerHTML) est sans objet.

État de déploiement : la sauvegarde de `server.cfg` que la Chancellerie garde sur ce poste (`chancellerie/data/`, dossier
ignoré par git, non lu au-delà des lignes `ensure`) montre `vava_example`, `vava_example_items` et `vava_dev_characters`
démarrées sur le serveur de test local. C'est attendu en développement ; la question de ce rapport est ce qui se passe
si elles restent au moment d'ouvrir.

## Faut-il les retirer d'un serveur ouvert au public ?

| Ressource | À retirer ? | Ce qu'elle permet si elle reste |
|---|---|---|
| `vava_dev_characters` | **Oui, impérativement** | tout joueur se donne n'importe quel objet du registre (100 par appel, 5 d'affilée puis 1 par seconde), se remet toute sa vie, se met à terre, remet faim et soif à 100, se téléporte à sa dernière position connue ; aucun droit, aucun ACE, aucune convar ne l'en empêche ; rien n'est journalisé (voir BLOQUANT) |
| `vava_example` | Oui (démonstration) | `/note <type> <texte>` écrit une ligne en base toutes les 5 s par joueur, 500 octets, jamais lue ni purgée ; `example_ping` est réservé à la console et à l'ACE `command.example_ping` (voir IMPORTANT) |
| `vava_example_items` | Oui, à remplacer par les objets des modules du royaume (contenu provisoire) | aucune entrée réseau : huit définitions d'objets et leurs images ; une « Bande de lin » rend 20 % de vie (`server/main.lua:53`), lue par `vava_health` ; ces objets ne s'obtiennent que par le catalogue de développement (décision prise), les commandes de test ou un autre module |
| `vava_anim_test` | Oui (le README le dit : « serveur de développement seulement ») | commandes locales au client (`/anim`, `/animstop`, `/animprop`, `/animflags`, `/epee`) : animation sur son propre ped et accessoire **local** (`CreateObject(…, false, …)`, `client/main.lua:182`), ce qu'un client modifié fait de toute façon ; les commandes paraissent au Codex pour tous (`scope = 'player'`, `server/main.lua:28-52`) ; le `.ycd` de 96 Ko est téléchargé par chaque client ; aucune surface serveur |

## Points d'entrée

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `vava_dev_characters:give` (`/objet`) | RPC | objet : chaîne 1–64 motif `^[%w_%-%.:]+$` ; quantité : entier 1–100 optionnel (`server/main.lua:68-69`, `config.lua:15`) | 5, +1/s (`config.lua:13`) | **aucune** : `exports.vava_inventory:add(source, item, quantity or 1)` (`:73`) ; l'inventaire n'exige qu'un personnage actif et de la place | n'importe quel objet du registre, sans droit ni journal |
| `vava_dev_characters:health` (`/vie`) | RPC | nombre 0–100 optionnel (`:25`, `:60`) | 5, +1/s | aucune ; `vava_health:setHealth(source, pourcent / 100)` (`:31`) puis lecture | soin complet à volonté |
| `vava_dev_characters:down` (`/aterre`) | RPC | aucun argument (`:62`) | 5, +1/s | aucune ; `vava_health:down(source, 'test')` (`:63`) | — |
| `vava_dev_characters:needs` (`/besoins`) | RPC | deux nombres 0–100 optionnels (`:58`) | 5, +1/s | aucune ; `vava_needs:set` (`:46`), bornes revérifiées par le module des besoins | faim et soif à volonté |
| `vava_dev_characters:respawn` (`/respawn`) | RPC | aucun argument (`:54`) | 2, +0,1/s | personnage actif (`server/players/characters.lua:537-542`) | téléportation à la dernière position connue ou au point par défaut (`server/players/spawn.lua:65-75`) |
| `/perso liste\|creer\|choisir\|quitter\|supprimer` | commandes client → RPC du core | ceux du core (`characters.registerRpc`) | ceux du core | celles du core (compte propriétaire, état de session) | même pouvoir que l'interface de sélection, rien de neuf côté serveur |
| `vava_example:postNote` (`/note`) | RPC | type : chaîne 1–32 motif `^[%w_]+$` ; contenu : chaîne 1–500 (`server/main.lua:154-156`) | 3, +0,2/s (`config.lua:21`) | type connu du registre, longueur ≤ `maxLength` du type (200 / 120), personnage actif, hook `notePost` annulable (mots interdits), insertion paramétrée (`:50-65`) | compteur par personnage (`:74`), schéma entier ≥ 0 ; table jamais purgée |
| `example_ping <id>` | commande console (`RegisterCommand(…, true)`, `:162`) | id entier | — | réservé console / ACE ; réponse du client validée par `returns` entier ≥ 0 (`:93`) et traitée comme déclarative | bon exemple |
| `vava_example:ping` | RPC serveur → client | — | — | — | renvoie `GetGameTimer()` (`client/main.lua:35`) |
| registre `vava_inventory:items` | registre (vava_example_items) | schéma de l'inventaire | — | validé par le core | 8 objets |
| registre `core:commands` | registre (vava_anim_test) | schéma du core | — | — | chapitre « Tests », portée joueur |
| `/anim`, `/animstop`, `/animprop`, `/animflags`, `/epee` | commandes client (vava_anim_test) | arguments lus par `tonumber` / `tointeger`, modèle vérifié par `IsModelInCdimage` | — | **aucune (rien ne part au serveur)** | effets locaux seulement |

Aucun `RegisterNetEvent` serveur, aucun `TriggerClientEvent` dans ces quatre ressources (grep sur `examples/*/server`).

## BLOQUANT

- `examples/vava_dev_characters/server/main.lua:66-74` — **Don d'objets sans aucun droit** — tant que la ressource
  tourne, tout joueur appelle `vava_dev_characters:give` (ou tape `/objet hache_fer 100`) et reçoit n'importe quel objet
  du registre : outils, graines, compost, bandes de soin, 100 unités par appel, cinq appels d'affilée puis un par seconde
  (`config.lua:13-15`) ; l'économie du troc et la progression des métiers sont annulées, rien n'est inscrit au journal.
  Le fxmanifest le dit (`fxmanifest.lua:4`, « À ne pas déployer en production : aucun contrôle d'administration »), mais
  rien dans le code ne l'empêche d'être démarrée par erreur, et elle l'est sur le serveur de test. Correction : (1) ne
  jamais `ensure` cette ressource sur le serveur public, l'écrire dans le README racine et la procédure de déploiement ;
  (2) la rendre inoffensive par construction : `setup` renvoie `false` si `GetConvar('vava_env', 'prod') ~= 'dev'`, et
  chaque handler refuse si `IsPlayerAceAllowed(source, 'vava.dev')` est faux, chaque don passant par `vava_admin:log`
  quand le Registre est là.
- `examples/vava_dev_characters/server/main.lua:29-37`, `:60-63`, `:46` — **Vie, mise à terre et besoins à volonté** —
  `/vie 100` rend toute sa vie en plein combat (`vava_health:setHealth`, `:31`), `/aterre` met à terre, `/besoins 100 100`
  efface faim et soif ; mêmes conditions, même absence de droit et de journal. Correction : la même garde que ci-dessus.

## IMPORTANT

- `examples/vava_example/server/main.lua:50-76` — **Notes illimitées en base** — si la ressource reste, `/note` insère
  une ligne de 500 octets au plus toutes les 5 s par joueur (`config.lua:21`), jamais lue par le jeu, jamais purgée
  (aucune rétention dans `sql/0001_create_notes.sql`) : remplissage lent de `vava_example_notes` (≈ 17 000 lignes par
  joueur et par jour) sans autre effet (le nom d'auteur vient du personnage, `:57-58`, le contenu n'est affiché nulle
  part). Correction : retirer la ressource avant d'ouvrir ; si elle doit servir d'exemple vivant, plafonner le nombre de
  notes par personnage et purger au démarrage comme le font les journaux des modules.

## MINEUR

- `examples/vava_anim_test/server/main.lua:28-52` — les commandes de test paraissent au Codex de tous les joueurs
  (`scope = 'player'`) ; effets locaux seulement, mais un outil de développement n'a pas à figurer dans le Codex d'un
  serveur ouvert : à retirer avant ouverture (le README § « Passer en production » le prévoit).
- `examples/vava_anim_test/stream/vava_sword_1h.ycd` — 96 Ko téléchargés par chaque client tant que la ressource tourne ;
  le README indique de déplacer le `.ycd` dans le module qui s'en sert.
- `examples/vava_example_items/server/main.lua:29-67` — contenu de démonstration (pain, bière, épée, bourse, corde) à
  remplacer par les objets des modules du royaume ; aucune entrée réseau, aucun risque en soi.
- `examples/vava_dev_characters/client/main.lua:105-113` — `/perso supprimer <id>` efface un personnage sans
  confirmation ; c'est le RPC du core qui décide (compte propriétaire), rien de nouveau côté serveur, mais un outil de
  test qu'un joueur distrait peut regretter.

## Points solides

- Les quatre ressources passent par l'API du core : RPC à schéma complet et borné (`vava_dev_characters/server/main.lua:25`,
  `:68-69` ; `vava_example/server/main.lua:154-156`), débits réglés, SQL paramétré (`vava_example:65`), `returns` imposé
  à l'appel serveur → client et réponse traitée comme déclarative (`:93`, `:96`), commande console restreinte (`:162`).
- Aucun `RegisterNetEvent` serveur, aucun envoi à `-1`, aucune NUI, aucun secret.
- `vava_example_items` et `vava_anim_test` n'ouvrent aucune surface serveur ; leurs effets sont des définitions ou
  des commandes locales.
- Les en-têtes annoncent sans ambiguïté ce qui ne doit pas être déployé (`vava_dev_characters/fxmanifest.lua:4`,
  `vava_anim_test/fxmanifest.lua:7`, README de `vava_anim_test`) : il ne manque que la garde dans le code et la consigne
  de déploiement.

VERDICT : À CORRIGER (deux BLOQUANT dans `vava_dev_characters`, à neutraliser par le code et par la procédure de déploiement avant l'ouverture)
