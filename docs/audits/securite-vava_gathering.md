# Audit sécurité — vava_gathering 1.2.4 — 29 octobre 2026 (T-010)

## Périmètre

Rôle : la récolte du royaume (zones à vitalité, nœuds à charges, outils en main qui s'usent, qualité en palier, pêche à
la barre de tension, commandes du Conseil). Le serveur décide de tout et demande l'XP à `vava_skills`.

Fichiers lus en entier : `fxmanifest.lua`, `config.lua`, `shared/constants.lua`, `shared/geometry.lua`,
`server/core.lua`, `server/main.lua`, `server/harvest.lua`, `server/fishing.lua`, `server/nodes.lua`, `server/zones.lua`,
`server/quality.lua`, `server/admin.lua`, `server/commands.lua`, `server/api.lua`, `server/journal.lua`,
`server/catalog.lua`, `bridge/server.lua`, `client/main.lua`, `client/interact.lua`, `client/fishing.lua`,
`client/nui.lua`, `client/props.lua`, `client/blips.lua`, `web/js/app.js`, `web/js/bridge.js`, `web/js/ui.js`,
`web/js/view-prompt.js`, `web/js/view-zones.js`, `web/js/view-tension.js`, `sql/0001_gathering.sql`, `README.md`.
Lus pour comprendre ce que le module délègue : `vava_inventory/server/api.lua`, `operations.lua` (`exchange`, `use`,
`guarded`), `main.lua` (liste des RPC), `vava_skills/server/api.lua` (`getLevel`, `addXp`), `vava_health/server/links.lua`
et `shared/constants.lua`, `server/core/rpc.lua` (pipeline), `config/server.lua` (bornes), `shared/core/hooks.lua`.

Non lus : `web/css`, `web/fonts`, `web/img`, `web/items` (aucune logique), `web/js/strings.js` (textes),
`web/js/devmock.js` (données simulées, n'est appelé qu'en dehors du jeu : `bridge.js:8-13`), `web/index.html` (seulement
passé au crible `innerHTML` / `insertAdjacentHTML` / `eval` : aucune occurrence).

Corrections annoncées par T-003 et T-006, retrouvées dans le code : refus `downed` au début (`server/harvest.lua:100`) et
à la fin, après la consommation du jeton (`:198`, `:200`) ; côté client, l'invite se tait et la touche ne part pas
(`client/interact.lua:110`, `:132`, `:291-292`) ; dernière charge prise une fois (`:221-222`, 1.2.2) ; écritures
groupées sans perte (`nodes.lua:153-168`, `zones.lua:214-232`).

## Points d'entrée

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `vava_gathering:begin` | RPC | `NODE` : chaîne 1–48, motif `^[%l%d_]+$` (`server/main.lua:30`) | 4, +1/s (`config.lua:107`) | personnage actif, pas à terre, nœud connu, une seule session, cooldown 1,5 s, distance lue côté serveur (2,5 + 1,5 m), charges, outil en main du genre requis et non brisé, place pour 1 unité, hook `harvesting` annulable, session relue après le hook (`harvest.lua:97-138`) | durée du geste calculée par le serveur (`:146`), jeton par geste, oubli après 30 s (`:149-151`) |
| `vava_gathering:cancel` | RPC | `TOKEN` : entier 1–2³¹−1 (`main.lua:31`) | 4, +1/s | jeton de la session du joueur seulement (`harvest.lua:160-162`) | toujours vrai, rien d'autre |
| `vava_gathering:finish` | RPC | `TOKEN` | 4, +1/s | session du joueur de genre `harvest`, durée annoncée − 400 ms écoulée (`:269-272`), distance, jeton consommé avant toute attente (`:198`), pas à terre, charges, même instance d'outil qu'au début (`:208`), charge prise avant l'ajout (`:222`) | rendement, palier, échec de la bande, usure et XP décidés par le serveur (`quality.lua`, `:218-252`) |
| `vava_gathering:reel` | RPC | `TOKEN`, `BOOL` (`main.lua:31-32`, `:84`) | 4, +1/s | session de genre `fishing`, touche survenue, fenêtre [durée − 500 ms ; durée + 4 s] (`fishing.lua:38-49`), puis mêmes contrôles que `finish` | `held` est déclaratif (`fishing.lua:50`) : voir IMPORTANT |
| `vava_gathering:zones` | RPC | aucun argument (`main.lua:85`) | 3, +0,5/s | personnage actif (`main.lua:86`) | lecture seule : toutes les zones, vitalité et distance au joueur (`main.lua:37-48`) |
| `/recolte` | commande (`RegisterCommand(…, false)`, `admin.lua:77`) | arguments texte ; zone et nœud résolus par le catalogue (type vérifié, `catalog.lua:192`, `:204`) ; vitalité `tonumber` bornée 0–100 (`admin.lua:57-58`) | aucune (commande) | `Bridge.IsAllowed` : console, sinon `vava_admin:can(src, 'metiers')`, sinon ACE `metiers.admin` (`bridge/server.lua:177-183`), vérifié avant toute action (`admin.lua:37`) | `vitalite` et `recharger` : journal du module + Registre (`admin.lua:60`, `:67`, `zones.lua:187`) |
| `vava_gathering:bite`, `vava_gathering:notify` | évènements serveur → client | — | — | toujours vers le seul joueur concerné (`fishing.lua:28`, `bridge/server.lua:209`) | aucun envoi à `-1` |
| `GlobalState['vava_gathering:zone:<id>']`, `['…:node:<id>']` | state bag global (écrit par le serveur) | `{ band, scarred, vitality }`, entier (`zones.lua:128`, `nodes.lua:78`) | au seul changement | le serveur ne lit aucun state bag venu d'un client ; le client s'en sert pour l'affichage (`client/props.lua`) | connu : T-015 |
| `getZone`, `getZones`, `setVitality`, `nodeState`, `getResource`, `getTool`, `getSession`, `codexList` | exports (serveur → serveur) | `setVitality` : nombre fini 0–100 (`api.lua:38`) ; `getSession` : entier | — | `not_ready` avant le setup | `setVitality` journalise le module appelant (`api.lua:39`, `zones.lua:187`) |
| registre `vava_gathering:tools` | registre du core | `TOOL_SCHEMA` : genre borné, puissance 0,1–5, bonus et usure bornés (`catalog.lua:19-27`) | — | validé par le core à chaque ajout | ouvert aux autres modules |
| `core:character:unloading`, `core:player:dropped` | hooks écoutés | — | — | session et cooldown oubliés (`main.lua:95-96`, `harvest.lua:278-280`) | déconnexion en plein geste : rien n'est pris |
| `tensionDone`, `zonesRefresh`, `zonesWaypoint`, `close` | callbacks NUI | `zonesWaypoint` : id chaîne ≤ 48, motif (`client/main.lua:119`) ; `tensionDone` : jeton entier, ratio nombre (`client/fishing.lua:46-50`) | — | rien côté serveur sans RPC (`reel`, `zones`) ; handlers isolés par `xpcall` (`client/nui.lua:32-40`) | — |

Aucun `RegisterNetEvent` ni `RegisterServerEvent` côté serveur (grep sur `server/` et `bridge/`).

## BLOQUANT

Aucun.

## IMPORTANT

- `modules/vava_gathering/server/fishing.lua:50` — **Réussite de la pêche déclarée par le client** — la part du
  temps dans la zone est mesurée par la page (`web/js/view-tension.js:81`), comparée au seuil côté client
  (`client/fishing.lua:50`) et envoyée en booléen : un client modifié répond `reel(token, true)` sans jouer et prend un
  poisson à chaque touche ; l'effet reste borné par ce que le serveur garde (moment de la touche, fenêtre de temps,
  distance, charge, vitalité, rendement, cooldown : `fishing.lua:41-49`, `harvest.lua:192-252`), soit le gain d'un
  joueur qui réussirait toujours la barre. Le README (§ La pêche) et `docs/api.md` documentent ce choix, mais il reste
  une « réussite calculée côté client » (CLAUDE.md § Sécurité, règle 1) et n'est pas dans les décisions déjà prises.
  Correction : faire tirer la réussite par le serveur (chance selon le niveau de Pêche et la bande, comme
  `quality.failed`), la barre ne pouvant que *faire rater* (un `held = false` annule, un `held = true` n'impose rien) ;
  ou inscrire l'exception dans CLAUDE.md « Décisions déjà prises » pour qu'elle ne soit plus relevée.

## MINEUR

- `modules/vava_gathering/server/harvest.lua:195` — une fin « trop loin » ne consomme pas le jeton : le client peut
  rappeler `finish` jusqu'à l'expiration (30 s) une fois revenu ; sans gain (la distance est revérifiée), mais
  l'agriculture abandonne le geste dans ce cas (`vava_farming/server/actions.lua:364-366`). Durcissement : consommer le
  jeton avant le test de distance, comme pour `downed`.
- `modules/vava_gathering/server/harvest.lua:178` — le retour de `PatchMetadata` est ignoré : un hook `metadata` qui
  refuse l'écriture (module tiers) donne une récolte sans usure. Durcissement : journaliser le refus, ou refuser la
  récolte.
- `modules/vava_gathering/server/journal.lua` — aucune ligne par récolte (épuisements, cicatrices, réactions et Conseil
  seulement) ; le hook `harvested` existe (`harvest.lua:257`). Non exigé par CLAUDE.md § Sécurité 6 ; utile pour
  enquêter sur un pic de matières. Optionnel.
- `modules/vava_gathering/server/harvest.lua:108` — un `begin` refusé sur un nœud vide envoie une notification : un
  client peut se faire envoyer un évènement par seconde (débit du RPC), sans effet sur les autres joueurs.
- `GlobalState` pour l'état des zones et des nœuds (`zones.lua:128`, `nodes.lua:78`) : connu, T-015.

## Points solides

- Une seule porte : cinq RPC à schéma complet et borné, débits réglés en config, aucun évènement réseau brut.
- Position lue côté serveur au début et à la fin (`bridge/server.lua:82-86`, `harvest.lua:106`, `:195`), durée du geste
  tenue par le serveur (`:272`), cooldown et session unique par joueur (`:103-105`, `:138`), expiration (`:149`).
- Ordre des opérations pensé contre les courses : jeton consommé (`:198`), cooldown posé (`:218`) et charge prise (`:222`)
  avant le premier appel qui peut céder la main ; charge rendue si la besace refuse (`:241`) ; deux joueurs sur la
  dernière charge : un seul servi.
- Outil : même instance au début et à la fin (`:208`), solidité en métadonnées écrites par le serveur ; aucun RPC
  client de l'inventaire n'écrit de métadonnées (`vava_inventory/server/main.lua:38-51`).
- SQL paramétré partout (`zones.lua:34-37`, `nodes.lua:19-20`, `journal.lua:16-17`), état relu à la demande, écritures
  groupées sans perte ; handler en erreur capturé par le core (`server/core/rpc.lua:144`) : aucun chemin de crash trouvé.
- NUI : `textContent` et `createElement` seulement, callbacks sans effet serveur hors RPC ; droits du Conseil vérifiés
  côté serveur et journalisés.

VERDICT : À CORRIGER (un point IMPORTANT, à trancher : correction serveur ou exception inscrite dans CLAUDE.md)
