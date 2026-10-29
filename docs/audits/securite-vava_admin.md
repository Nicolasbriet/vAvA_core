# Audit sécurité — vava_admin 1.7.0 — 29 octobre 2026 (T-010)

## Périmètre

Rôle : le Registre du Conseil — rangs et droits, actions sur les joueurs, bans à la connexion, signalements, journal,
outils des modules, pont vers la Chancellerie (`webRequest`, `webSyncStaff`…).

Fichiers lus en entier : `fxmanifest.lua`, `config.lua`, `shared/constants.lua`, `server/{main,core,rpc,requests,
actions,staff,ranks,players,bans,reports,audit,store,web,api,extensions,console,commands,spectate}.lua`,
`sql/0001_admin.sql`, `client/{main,core,nui,panel,tools,notify}.lua`, `web/index.html`, `web/js/{app,bridge,ui,
view-players,view-reports,view-logs,view-bans,view-staff,view-tools,view-announce}.js`. Côté core, pour les garanties
dont le module dépend : `server/core/rpc.lua`, `shared/lib/schema.lua`, `config/server.lua`,
`server/players/accounts.lua` (hook `core:player:connecting`), `scripts/audit-exceptions.txt`.

Non lus : `web/js/strings.js` et `devmock.js` (textes et simulation hors jeu, aucune entrée réseau), `web/css`.
Les modules appelés par les actions (`vava_health`, `vava_needs`, `vava_inventory`) sont hors périmètre : seuls les
appels isolés par `VavaAdmin.call` (pcall) ont été vérifiés.

Corrections annoncées par T-007, vérifiées dans le code :
- identifiants réservés à la Chancellerie : `server/requests.lua:135` (`players.details(target, actor.web == true)`),
  `server/players.lua:117` (`identifiers = withIdentifiers and identifiersOf(src) or nil`), acteur web marqué
  `web = true` en `server/web.lua:83` ; aucune autre lecture de `GetPlayerIdentifierByType` dans le module ;
- immobilisés libérés à l'arrêt : `server/actions.lua:127-137` (`releaseAll`), appelé par `server/main.lua:65-70` ;
- retour d'observation : place lue sur le ped côté serveur en `server/spectate.lua:92-93`, champ privé déclaré
  `visibility = 'private'` en `:162`, numéro d'observation `:95-97`, fin acceptée pour le seul dernier numéro `:107`,
  marque « parti » au déchargement `:119-124`, replacement du seul même personnage `:144` ;
- page Outils pour le Gardien : `web/js/view-tools.js:92` (`visible`) et `web/js/app.js:39`.

## Points d'entrée

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `vava_admin:open`, `session` (web), `players`, `reports`, `staff`, `bans(PAGE)`, `logs(PAGE)` | RPC (`server/rpc.lua:50-60`, catalogue `server/requests.lua`) | `PAGE` entier 0..100000 (`requests.lua:36`) | `read` 10 puis 2/s | rang relu à chaque appel en mémoire (`rpc.lua:41-45` → `staff.actorOf` `staff.lua:63-69`), droit par demande | `players` envoie le pseudo FiveM (`players.lua:71`), jamais d'identifiant |
| `vava_admin:player(TARGET)` | RPC | `TARGET` 1..65535 | `read` | droit `view` ; identifiants seulement si `actor.web` (`requests.lua:135`) | ✓ T-007 |
| `reach`, `bring`, `sendBack`, `freeze(BOOL)`, `heal`, `feed`, `message(TEXT)`, `warn(TEXT)`, `kick(TEXT)`, `ban(HOURS,TEXT)`, `inventory`, `give(ITEM,QUANTITY)`, `spectate` ; web seul : `moveToPlayer(TARGET)`, `moveToCoords(COORD×3)`, `inventoryView`, `watchScreen` | RPC / `webRequest` | `TEXT` 1..500 o, `HOURS` 0..87600, `ITEM` ≤64 `^[%w_%-%.:]+$`, `QUANTITY` 1..1000, `COORD` ±20000 (`requests.lua:32-45`) | `action` 10 puis 2/s | cible connectée et chargée (`players.resolve` `players.lua:34-42`), soi-même refusé sauf liste (`requests.lua:101`), rang strictement supérieur pour les actions protégées (`:102`, `staff.outranks` `staff.lua:87-90`), durée de ban selon le rang (`actions.lua:194`, `ranks.lua:77-81`), journal (`requests.lua:107`) | déplacements et gel par natives serveur (`actions.lua:46`, `:117`) |
| `reportClaim(ID)`, `reportClose(ID)` | RPC | entier 1..2³²−1 | `action` | droit `reports`, signalement existant, journal | course entre deux membres : dernier gagnant, sans dommage |
| `unban(ACCOUNT)` | RPC | entier 1..2³²−1 | `action` | droit `unban` (Souverain), journal | |
| `staffSet(ACCOUNT, RANK)` | RPC | `RANK` ≤32 `^[%w_]*$` | `action` | droit `staff`, jamais soi-même, cible de rang inférieur, rang donné strictement inférieur au sien (`staff.lua:100-106`), journal | fondateurs réservés à la console : respecté |
| `announce(TEXT)` | RPC | ≤500 o | `action` | droit `announce`, journal | seul `TriggerClientEvent(-1)` du module (`requests.lua:177`), inscrit dans `scripts/audit-exceptions.txt` |
| `tool(TOOL, BOOL)` | RPC | `enum` noclip/invisible/godmode/waypoint | `action` | droit `tools`, journal | n'accorde qu'un journal : l'effet est appliqué par le client (`client/panel.lua:58-64`) |
| `moduleTool(KEY)` | RPC | 3..64 `^[%w_%-%.]+:[%w_%-%.]+$` | `read` | droit `view` + droit déclaré par l'outil (`extensions.lua:70-75`) | le module revérifie ensuite chaque action |
| `vava_admin:spectateEnd(SESSION)` | RPC ouverte à tous | entier 1..2³²−1 | `read` | n'efface que la place du personnage de l'appelant, pour son dernier numéro (`spectate.lua:106-114`) | sans observation : aucun effet |
| `vava_admin:report(TEXT)` | RPC ouverte à tous | 1..500 o | `report` 2 puis 1/20 s | session et compte requis, 60 s entre deux par compte, 100 ouverts au plus (`reports.lua:55-64`) | |
| `isStaff`, `can`, `rankOf`, `isFrozen` | export (toute ressource) | — | — | lecture seule | |
| `ban`, `kick`, `log` | export (toute ressource) | `api.lua:21-23`, `audit.clean` (`audit.lua:44-58`) | — | acteur « module <ressource> » au rang console, journal ; `log` exige un membre | code serveur de confiance |
| `webRequest`, `webCan`, `webRanks`, `webSyncStaff`, `webLog` | export réservé au pont | `GetInvokingResource() == config.web.bridge` (`web.lua:72-74`), acteur `{label ≤40, rank connu}` (`:79-84`), arguments revalidés (`:29-68`) | aucune (le pont est local) | mêmes droits, cible, rang et journal que le jeu (`:94-97`) | `webSyncStaff` impose n'importe quel rang à n'importe quel compte : le panneau est la source, voulu et journalisé (`:129-133`) |
| `vava_conseil`, `vava_ban`, `vava_unban`, `vava_kick` | commande console | entiers positifs, motif non vide | — | `source ~= 0` refusé (`console.lua:101`), commande déclarée restreinte (`:103`) | |
| `core:player:connecting` | hook before | — | — | ban actif du compte connu (`bans.lua:26-35`) | voir IMPORTANT |
| `core:player:dropped`, `core:character:unloading/loaded/spawned` | hooks after | — | — | oubli des états en mémoire, place d'observation | |
| `request`, `close`, `stopSpectate`, `notify`, `ready` | callback NUI (`client/panel.lua:81-105`, `client/nui.lua`) | liste fermée de 25 noms (`panel.lua:18-23`), 4 arguments au plus (`:15`) | — | tout part en RPC vers le serveur, qui décide ; isolé par xpcall (`nui.lua:39-47`) | `notify` n'affiche qu'un texte local |
| `vava_admin:notify`, `announcement`, `reportNew` | évènement serveur → client | types vérifiés à la réception (`client/main.lua:64-82`) | — | — | affichage par `textContent` (`web/js/app.js:83-86`) |
| registre `vava_admin:tools` | registre core | `label` 1..40, `hint` ≤160, `permission` enum des droits, 32 entrées (`extensions.lua:38-45`) | — | — | |

## BLOQUANT

Aucun.

## IMPORTANT

- `modules/vava_admin/server/bans.lua:27` et `:29-33` — **vérification de ban qui laisse passer quand le compte ou
  la base manque** — le hook reçoit `accountId = knownAccount` (`server/players/accounts.lua:264-266`), qui vaut `nil`
  aussi bien pour une première venue que pour une erreur passagère de la base (`findAccount` : `accounts.lua:149-153`,
  erreur perdue par `local knownAccount = findAccount(license)`) ; `check` fait alors `return` sans refuser (`:27`), et
  une erreur de la requête de ban elle-même fait aussi `return` (`:29-33`) ; le compte est ensuite chargé normalement
  et le banni joue toute la session. Le client ne déclenche pas la panne, mais un redémarrage de MariaDB pendant une
  connexion suffit. Correction : refuser la connexion (`false, messages.unavailable`) quand `store.activeBan` renvoie
  une erreur, et ajouter un second contrôle au hook `core:player:joined` (compte alors toujours connu) qui `DropPlayer`
  un compte banni, de sorte qu'aucune fenêtre ne reste.

## MINEUR

- `modules/vava_admin/server/requests.lua:175-180` — l'annonce (envoi à **tous** les joueurs, 500 octets) partage la
  limite `action` (10 d'affilée puis 2/s) : un Sénéchal peut arroser tout le serveur à 2 × 500 o/s, et depuis le web
  sans limite propre du pont. Proposer une limite dédiée (`rateLimits.announce`, par exemple 3 puis 1/30 s) et la même
  retenue côté `webRequest`.
- `modules/vava_admin/server/actions.lua:114-121` et `server/players.lua:27-28` — l'état « immobilisé » est un seul
  `FreezeEntityPosition` : un client modifié se dégèle d'une native, et l'état en mémoire n'est ni levé au déchargement
  du personnage ni réappliqué à l'apparition suivante (retour à la sélection puis rejouer : la liste dit « immobilisé »
  et le joueur bouge). Lever `frozen[src]` sur `core:character:unloading` ou réappliquer sur `core:character:spawned` ;
  l'export `isFrozen` reste la vraie garde pour les modules.
- `modules/vava_admin/server/reports.lua:64` — à 100 signalements ouverts, `create` répond `false, 'full'` sans prévenir
  le joueur (le client ignore le résultat, `client/main.lua:61`) : ajouter un message « le Conseil est débordé ». La table
  `lastByAccount` (`:36`) n'est jamais purgée (bornée par le nombre de comptes : acceptable).
- `modules/vava_admin/server/web.lua:29-53` — le pont revalide avec un validateur maison plutôt qu'avec
  `vAvA.lib.schema` (celui des RPC) : tout schéma nouveau dans le catalogue (table, liste, `optional`) y serait refusé
  ou mal vérifié sans que personne ne le voie. Compiler les schémas du catalogue une fois avec `schema.compileList` et
  réutiliser `schema.validateList`.
- `modules/vava_admin/sql/0001_admin.sql:2` et `server/bans.lua` — un ban ne tient qu'au compte (donc à la `license`) :
  un nouveau compte Rockstar le contourne. Choix documenté (« aucun autre identifiant n'est conservé ») ; à peser un
  jour contre un rattachement aux identifiants `discord:`/`fivem:` déjà lus pour la Chancellerie.
- `modules/vava_admin/config.lua:62-66` — `tool`, `wall` des caméras et toute action journalisée tournent à 2 écritures
  par seconde et par membre : un membre peut gonfler `vava_admin_logs` (purge à 90 jours seulement). Sans gravité ;
  une limite plus basse sur les actions purement journalisées (`tool`) suffirait.

## Points solides

- Une seule porte : toutes les intentions du Registre passent par `core.rpc.register` avec le schéma du catalogue
  (`server/rpc.lua:50-60`) ; le droit est relu à chaque appel depuis la mémoire tenue à jour par `staff.set` et
  `staff.force` (aucune reconnexion nécessaire), et l'interface n'a aucun pouvoir : un joueur sans rang reçoit
  `forbidden` sur chaque RPC, quelle que soit la liste `ALLOWED` du client.
- Les actions protégées revérifient la cible, soi-même et le rang (`requests.lua:98-109`) ; les durées de ban sont
  tranchées par le serveur (`ranks.canBan`) ; les fondateurs restent réservés à la console (`staff.lua:106`).
- SQL entièrement paramétré et centralisé dans `server/store.lua:16-39` ; aucune concaténation de valeur.
- Aucun `innerHTML` dans l'interface : noms, motifs, signalements et journal passent par `UI.el` → `textContent`
  (`web/js/ui.js:15-21`, `view-reports.js:46`, `view-logs.js:14-20`).
- Journal complet : chaque demande du catalogue, les commandes de console, les exports `ban`/`kick`/`log` et le pont
  web écrivent par `audit.record` (`audit.lua:64-76`) et publient `vava_admin:action`.
- Les exports du pont refusent toute autre ressource appelante (`web.lua:72-74`) et revalident les arguments ; les
  commandes console refusent un joueur même doté d'un ACE (`console.lua:101`).

VERDICT : OK
