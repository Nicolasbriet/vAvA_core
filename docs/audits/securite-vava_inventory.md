# Audit sécurité — vava_inventory 1.6.4 — 29 octobre 2026 (T-010)

## Périmètre

Rôle : inventaire en grille, source de vérité des objets du royaume (conteneurs de personnage, sacs au sol, coffres
et greniers d'autres modules, catalogue de développement), opérations validées côté serveur, métadonnées par pile,
exports « tout ou rien » pour les autres modules.

Fichiers lus en entier : `fxmanifest.lua`, `config.lua`, `shared/constants.lua`, `shared/grid.lua`,
`server/main.lua`, `server/core.lua`, `server/api.lua`, `server/operations.lua`, `server/containers.lua`,
`server/viewers.lua`, `server/drops.lua`, `server/positions.lua`, `server/hands.lua`, `server/items.lua`,
`server/persistence.lua`, `server/characters.lua`, `server/commands.lua`, `server/catalog.lua`,
`client/main.lua`, `client/nui.lua`, `client/drops.lua`, `client/hands.lua`, `client/core.lua`,
`web/index.html`, `web/js/bridge.js`, `web/js/app.js`, `web/js/model.js`, `web/js/view.js`, `web/js/menu.js`,
`web/js/drag.js`, `web/js/grid.js`, `sql/0001_containers.sql`, `sql/0002_items.sql`. Lus en partie :
`web/js/strings.js` (fonctions `errorMessage`, `categoryLabel`, `kilos`), `web/js/devmock.js` (garde `inGame`).
Pour le contexte : `server/core/rpc.lua`, `shared/lib/schema.lua`, `shared/core/hooks.lua`,
`server/core/ratelimit.lua`, `server/players/fields.lua` et `sync.lua` (extraits), `config/server.lua` (limites),
`modules/vava_health/server/links.lua` (gardes à terre), `modules/vava_gathering/server/harvest.lua:112-124`
(l'outil tenu est lu par l'export `held`, pas par le state bag), `modules/vava_farming/bridge/server.lua:164-165`
et `modules/vava_admin/server/actions.lua:219` (appelants de l'export `open`).

Non lus : `web/css/style.css`, polices et images (aucune logique) ; `README.md` et `docs/tests/inventaire.md`
(procédures, pas de code) ; `tests/spec/inventory_grid_spec.lua` (tests de géométrie, hors menace réseau).

Correctifs annoncés par `docs/plan/rapports/T-005.md`, retrouvés dans le code : `isReadable`
(`server/operations.lua:244-246`), `not_found` pour une pile ou un conteneur cible que le joueur n'a pas sous les
yeux (`:280-281`, `:465`, `:494`, `:627`), révisions montées avant toute publication (`:206`,
`server/containers.lua:256`), main qui attend une pile gardée à part (`server/hands.lua:141-146`, `:154-169`),
`planReturn` qui cesse de chercher après un échec (`shared/grid.lua:149-161`), copie des gestes prévus tenue à
jour (`web/js/model.js:147-183`), touche de fermeture relue (`client/main.lua:51-55`). Correctifs 1.6.4 : export
`close` (`server/api.lua:154-159`, `server/operations.lua:426-440`, `client/main.lua:121`), écritures du
déchargement rejouées (`server/characters.lua:92-96`), conteneur relu après ses écritures en attente
(`server/containers.lua:288`, `server/persistence.lua:149-154`).

## Points d'entrée

Schémas déclarés dans `server/main.lua:24-35` ; limites dans `config.lua:73-77` : `open` = 4 en rafale, 1/s ;
`action` = 20 en rafale, 10/s ; `use` = 4 en rafale, 1/s. Au-dessus : limite globale du core (40 en rafale,
20/s, `config/server.lua:92`) et 8 requêtes simultanées par joueur (`:33`). Toute valeur est validée puis
normalisée par le core (`server/core/rpc.lua:133-141`, `shared/lib/schema.lua:198-248`) : NaN, ±inf, flottants
non entiers, tables à métatable et clés hors du nombre annoncé sont refusés avant le handler.

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `vava_inventory:open` | RPC | `{ CONTAINER }` entier −2⁵³..2⁵³ (`main.lua:25`) | `open` | personnage lié (`operations.lua:373-374`) ; un sac désigné n'est ajouté que s'il est de type `drop` **et** à portée lue côté serveur (`:376-380`, `drops.lua:93-99`, `positions.lua:16-21`) | réponse identique que l'identifiant existe ou non ; état complet renvoyé au seul appelant (`:361-364`) |
| `vava_inventory:close` | RPC | `{}` (`main.lua:44`) | `action` | aucune nécessaire ; écriture demandée au plus une fois par `flushIntervalMs` et par joueur (`operations.lua:450-453`) | — |
| `vava_inventory:move` | RPC | `{ INSTANCE 1..2⁵³, CONTAINER, COORD 0..31, COORD, ROTATED bool }` (`:45`) | `action` | pile vue et à portée (`resolve` `:276-286` : besace propre ou conteneur ouvert, distance du sac ou de l'ancrage `:262-270`), cible vue et à portée (`:465-466`), place dans la grille et poids (`:467`, `:298-303`, `grid.lua:40-52`), hook `before` puis révision des deux conteneurs (`:471`, `:227-238`) | `not_found` indifférencié pour tout ce que le joueur ne voit pas |
| `vava_inventory:split` | RPC | `{ INSTANCE, QUANTITY 1..10⁶, CONTAINER, COORD, COORD, ROTATED }` (`:46`) | `action` | idem `move`, plus objet empilable et `quantity < instance.quantity` (`:491-492`) ; la nouvelle pile copie les métadonnées (`:506`) | — |
| `vava_inventory:merge` | RPC | `{ INSTANCE, INSTANCE, OPTIONAL_QUANTITY }` (`:47`) | `action` | deux piles vues et à portée (`:522-525`), même objet, empilable, métadonnées strictement égales (`:526`), plafond de pile (`:530-531`), poids du conteneur cible (`:532`), hook + révision (`:535`) | — |
| `vava_inventory:drop` | RPC | `{ INSTANCE, OPTIONAL_QUANTITY }` (`:48`) | `action` | pile vue et à portée (`:558`), `quantity ≤ pile` (`:561`), jamais depuis un sac (`:562`), sac réutilisé ou créé à la position **serveur** du ped (`drops.lua:65`, `:105-114`), plafonds 10 par personnage et 300 au total (`drops.lua:64`), poids du sac (`:566`, `:577`), hook + révision, sac vide supprimé sur refus (`:584-588`) | — |
| `vava_inventory:use` | RPC | `{ INSTANCE }` (`:49`) | `use` | besace propre seulement (`:621-628`), définition connue et utilisable (`:630-637`), hook `before` (santé : à terre, soin inutile ; besoins : satiété, geste en cours) puis révision (`:641-643`), `onUse` isolé par `pcall` (`:649-653`), présence de la pile revérifiée **après** `onUse` avant de retirer une unité (`:658`), `consumed` transmis aux hooks `after` (`:672-673`) | une unité au plus par appel, même si `onUse` cède la main |
| `vava_inventory:hotbarSet` | RPC | `{ SLOT 1..5, SLOT_CONTENT 0..2⁵³ }` (`:53`) | `action` | pile de sa propre besace (`:683-686`) ; champ `vava_inventory:hotbar` validé par le core à l'écriture (`:692`, `server/players/fields.lua:100-104`, schéma `main.lua:69-73`) | un raccourci périmé (objet parti) échoue en `not_found`/`no_access` (`:623-628`) |
| `vava_inventory:hotbarUse` | RPC | `{ SLOT }` (`:54`) | `use` | même chemin que `use` (`:702`) | refus rédigé par un module notifié (`:704`) |
| `vava_inventory:hold` | RPC | `{ SLOT_CONTENT }` (`:40`) | `action` | pile de sa besace (`:727`), objet déclaré tenable (`:730`), hook `before` (`vava_health` refuse à terre, `links.lua:25-35`, priorité 10) puis révision (`:735`), champ public validé par le core (`hands.lua:35-45`, `:207`) | voir MINEUR 1 (cadence) |
| `vava_inventory:catalog` | RPC | `{ CATEGORY ^[%w_]*$ ≤ 32, PAGE 1..999, QUERY ≤ 48 }` (`:33-35`, `:55`) | `action` | `cfg.enabled` **et** droit `staff` de vava_admin (ou ACE) revérifiés côté serveur (`catalog.lua:222-229`, `:280`) ; recherche en `find` littéral, sans motif (`:79`) ; page ramenée dans les bornes (`:169`) | catalogue de développement voulu (CLAUDE.md) ; RPC enregistré même désactivé, mais refusé (`:280`) |
| `/catalogue` | commande | arguments texte, nombre tenté par `tointeger` (`catalog.lua:253-268`) | aucune (commande FiveM) | même `allowed` (`:254`) ; console : cible obligatoire (`:257-258`) ; ouverture inscrite au journal du Conseil (`:266`) | un refus ne coûte qu'un appel d'export et une notification à l'appelant |
| Retours NUI `move`, `split`, `merge`, `drop`, `use`, `hotbarSet`, `hold`, `catalog`, `close` | NUI | aucun (données brutes) | — | chaque retour isolé par `xpcall` (`client/nui.lua:30-40`) et **relayé tel quel au RPC** (`client/main.lua:128-145`) : le serveur revalide tout ; aucun effet local | `catalog` : `query` tronquée à 48 (`:138`) |
| `add`, `remove`, `exchange`, `canCarry` | export | `item` connu du registre, `quantity` 1..10⁶, `metadata` objet JSON borné (`operations.lua:855-879`, `:100-132`) ; cible joueur ou `{ container }` (`api.lua:22-36`) | — | `ready` exigé ; hooks `vava_inventory:remove`/`add` avec `owner = GetInvokingResource()` (`api.lua:51`, `:58`, `:66`) ; plan puis application sans attente (`:999-1027`) | le droit de l'appelant est par contrat celui du module (pas de vérification possible ici) |
| `setMetadata`, `patchMetadata`, `count`, `getItems` | export | `instanceId` entier, `metadata`/`patch` validés après fusion (`:807-813`, `:825-843`), `filter` table (`api.lua:78`, `:101`) | — | hook `vava_inventory:metadata` avec copies `before`/`after` (`:785-798`) | — |
| `createContainer`, `containerOf`, `held`, `hold`, `open`, `close` | export | `checkSpec` : dimensions 1..32, poids ≥ 0 (`containers.lua:333-338`) ; `anchor` : nombres finis, `0 < radius ≤ 25` (`operations.lua:388-395`) ; `source` entier (`api.lua:120`, `:129`, `:138`, `:156`) | — | `open` : distance à l'ancrage à l'ouverture (`:410`) puis à chaque opération (`:269`, `viewers.lua:76-80`) et balayage toutes les 2 s (`viewers.lua:39-59`) ; `hold` par export : mêmes contrôles qu'un geste, `owner` transmis (`:719-742`) | voir MINEUR 5 (ouverture sans ancrage) |
| `codexList` | export | nom de liste (`commands.lua:59-73`) | — | lecture seule | — |
| `core:registry:added` / `removed` | hook | payload du core | — | filtré sur le registre `vava_inventory:items` (`items.lua:67-69`, `:78-79`, `hands.lua:109-116`, `operations.lua:766-768`) ; définitions validées par le schéma du registre à l'ajout (`items.lua:35-62`, `server/core/registry.lua:97`) | retour des piles gardées à part synchrone, révision montée (`containers.lua:256`) |
| `core:character:created` / `loaded` / `unloading` | hook | payload du core | — | `loaded` : personnage actif revérifié après les requêtes (`characters.lua:77-79`) ; `unloading` : fermeture chez les spectateurs avant l'écriture (`:88`) | voir MINEUR 7 (course) |
| `vava_inventory:hands` (joueur, public) | state bag | schéma `hands.lua:35-45` | — | écrit par le seul serveur via le core (`hands.lua:207`, `server/players/sync.lua:82`), **jamais lu côté serveur** (aucune lecture dans `server/`, ni dans vava_gathering qui passe par l'export `held`) ; les clients n'affichent que ce qui correspond à `GlobalState['vava_inventory:heldModels']`, écrit par le serveur (`hands.lua:96`, `:108`, `client/hands.lua:70-79`) | un client ne peut qu'afficher chez les autres un accessoire déjà déclaré (cosmétique) |
| `vava_inventory:drop` (entité) | state bag | identifiant du conteneur | — | écrit par le serveur (`drops.lua:78`) ; côté client, simple indice pour `open`, que le serveur revérifie (`operations.lua:376-380`) | — |

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

- `modules/vava_inventory/server/main.lua:40`, `:48` et `config.lua:75` — **`drop` et `hold` partagent la limite `action` (20 en rafale, 10/s)** — un client qui alterne jeter / ramasser ou prendre / reposer en main dix fois par seconde fait créer et supprimer une entité réseau (`drops.lua:72`, `:53`) ou réécrire un state bag public (`hands.lua:207`) à 10 Hz, le tout répliqué par OneSync à chaque joueur proche : amplification de bande passante payée par le serveur, sans gain d'objet. Correction : une limite propre à `DROP` et `HOLD`, par exemple `{ capacity = 4, refillPerSecond = 1 }` comme `use`.
- `modules/vava_inventory/server/items.lua:44` — **`image` d'une définition non restreinte à `nui://`** — un module (demain un objet édité dans l'Atelier) peut déclarer `https://…` ; `web/js/view.js:43-44` l'affecte à `img.src` et chaque client irait chercher une adresse externe (fuite d'adresse IP, règle « aucune ressource externe »). vava_hud impose déjà le préfixe pour ses icônes (`modules/vava_hud/client/gauges.lua:18`, `:72`). Correction : `pattern = '^nui://[%w_%-]+/'` sur `image`.
- `modules/vava_inventory/server/operations.lua:855-879` — **listes `removals` et `additions` parcourues par `ipairs`** — une liste non séquentielle (`{ [2] = … }`, trou après un `nil`) passe la validation et l'échange réussit sans rien retirer ni ajouter au-delà du trou : un module qui bâtirait sa liste à partir d'indices d'interface croirait un retrait effectué. Correction : refuser `invalid_request` quand une clé n'est pas dans `1..#list` (même contrôle que `shared/lib/schema.lua:375-379`).
- `modules/vava_inventory/server/operations.lua:460-615` et `server/catalog.lua:200-206`, `:266`, `:271-272` — **aucune journalisation des gestes sensibles** — ramasser dans le sac posé par un autre personnage, sortir un objet d'une besace ouverte en fouille (`vava_admin/server/actions.lua:219`), prendre au catalogue (seule l'ouverture est inscrite au journal du Conseil) ne laissent aucune trace (CLAUDE.md § Sécurité 6). Correction : `core.log.info` ou journal vava_admin par un abonné `after` pour `move`/`split`/`merge` dont `from` appartient à un autre personnage (`container.ownerId`, ou `owner` du sac dans `drops.lua`), et pour chaque regarnissage du catalogue dans `refill`.
- `modules/vava_inventory/server/operations.lua:405-418` et `server/viewers.lua:76-80` — **conteneur ouvert sans ancrage : accès conservé tant que le client ne dit pas `close`** — un client modifié qui garde son entrée de spectateur après l'ouverture d'un coffre ou d'un grenier ouvert sans `anchor` peut continuer à y puiser de n'importe où (`canOperate` répond vrai sans ancrage, `:269`). Les appelants actuels sont corrects : vava_farming passe un ancrage (`bridge/server.lua:164-165`), vava_admin ouvre une besace fermée au déchargement de son porteur (`characters.lua:88`). Correction défensive : avertir en console quand un conteneur conservé qui n'est pas une besace est ouvert sans ancrage, ou l'ancrer par défaut à la position serveur du joueur avec `anchor.maxRadius`.
- `modules/vava_inventory/server/drops.lua:93-99`, `:105-114` — **distance des sacs sans égard au routing bucket** — aucun bucket n'est utilisé dans le dépôt aujourd'hui ; le jour où des instances arrivent (intérieurs, donjons), un joueur d'un autre bucket aux mêmes coordonnées pourrait ouvrir ou remplir un sac qu'il ne voit pas. Correction : mémoriser `GetEntityRoutingBucket(entity)` à la création et le comparer à `GetPlayerRoutingBucket(src)` dans `inRange` et `near`.
- `modules/vava_inventory/server/characters.lua:58-80` et `:82-101` — **course déchargement / rechargement d'un même personnage** — `onLoaded` (après `findOwned`, qui cède la main, `:59`) peut lier au nouveau `source` un conteneur encore en mémoire qu'un `onUnloading` en cours d'écriture (`:92-96`) va retirer (`containers.unload`, `:100`) : le joueur revenu n'a plus de besace jusqu'à une nouvelle sélection. Fenêtre de quelques dizaines de millisecondes, aucun gain pour un client : robustesse seulement. Correction : marquer le conteneur « en déchargement » et le faire attendre ou recharger dans `onLoaded`.
- `modules/vava_inventory/server/operations.lua:372-384` et `server/viewers.lua:188-199` — **un sac ouvert reste regardé une fois le joueur éloigné** — chaque opération est bien refusée (`drops.inRange`, `:267`), mais les différences continuent d'être envoyées au spectateur parti jusqu'à sa fermeture ou l'expiration du sac : lecture à distance du contenu, aucun gain d'objet. Correction : ancrer le sac à sa position à l'ouverture (`interactDistance` comme rayon) pour que le balayage des ancrages le ferme aussi.

## Points solides

- Une seule porte réseau : onze RPC à schéma complet et borné, aucun `RegisterNetEvent` serveur ; aucune métadonnée, position ou résultat n'est accepté du client (les métadonnées n'ont pas de RPC, les distances sont lues sur le ped serveur, `positions.lua:16-21`).
- Concurrence maîtrisée : identifiants attribués en mémoire (`containers.lua:125-128`), chaque mutation d'un bloc sans attente, hooks encadrés par un relevé de révision qui refuse en `conflict` tout conteneur changé ou déchargé pendant l'attente (`operations.lua:227-238`) ; `use` revérifie la pile après `onUse` et ne retire qu'une unité (`:658-669`).
- Place, poids, pile, empilement par égalité stricte des métadonnées, « tout ou rien » des échanges : tous recalculés côté serveur (`:298-303`, `:526-532`, `:889-973`), aucune valeur du client n'est crue.
- Le state bag public des mains ne fait foi nulle part côté serveur et les clients le confrontent à la liste publiée par le serveur (`client/hands.lua:70-79`) ; le catalogue revérifie le droit à chaque geste (`catalog.lua:222-229`).
- Persistance : SQL exclusivement paramétré via `core.db` (`containers.lua:23-28`, `persistence.lua:22-25`), journal écrit en une transaction, rejoué en cas d'échec, écritures sérialisées (`persistence.lua:69-118`), déchargement qui attend ses écritures (`characters.lua:92-96`).
- Interface : aucune insertion HTML (`textContent`, `append` de chaînes, `replaceChildren` dans `view.js`, `menu.js`), les libellés, descriptions, noms de créateur, histoire et lignes libres sont affichés comme texte ; les retours NUI ne font rien sans RPC validé.

VERDICT : OK
