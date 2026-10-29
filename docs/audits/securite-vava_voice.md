# Audit sécurité — vava_voice 1.2.2 — 29 octobre 2026 (T-010)

## Périmètre

Rôle : chat vocal de proximité sur le Mumble intégré à FXServer (aucune autre ressource vocale) : quatre portées,
micro coupé hors du jeu, portée réduite à terre, zones de voix créées en jeu par le Conseil et modifiables depuis la
Chancellerie par le pont.

Lu en entier : `fxmanifest.lua`, `config.lua`, `shared/constants.lua`, `shared/label.lua`,
`sql/0001_voice_zones.sql`, `server/{core,store,presence,links,zones,api,commands,main}.lua`,
`client/{core,nui,hud,mumble,ring,zones,range,editor,main}.lua`, `web/index.html`,
`web/js/{bridge,editor,strings}.js`. Côté core : `server/core/rpc.lua`, `shared/lib/schema.lua`,
`server/players/{accounts,characters,spawn}.lua` (quand `core:player:joined` et `core:character:spawned` partent).
Voisins : `vava_admin/server/api.lua` (`can`, `log`), `vava_admin/server/audit.lua` (`audit.clean`),
`vava_admin/shared/constants.lua` (`LOG_LIMITS`), `scripts/audit-exceptions.txt`.

Non lu : `web/css/style.css`, `web/js/devmock.js` (hors jeu seulement, `web/js/bridge.js:13`), `docs/tests/voix.md`.
Ce qui touche à Mumble lui-même (salons, portée réglée par le client, absence de contrôle d'accès aux salons) est une
limite de FiveM, documentée dans le README (« Sécurité et coût ») et `docs/api.md` : elle n'est pas comptée ici.

Corrections de T-008 retrouvées dans le code : nom compté en signes et refusé pour un signe invisible
(`shared/label.lua:41-54`, 1.2.2 `label_unreadable` `:44-47`), schéma borné à 160 octets avec motif ancré
(`server/main.lua:27`), un seul « Sceller » à la fois (`client/editor.lua:219`, `web/js/editor.js:128-139`),
focus rendu à l'arrêt (`client/main.lua:114-116`, `client/editor.lua:125-130`), limite renvoyée avec la liste des
zones (`server/main.lua:62-65`, `server/presence.lua:92-94`), aucun micro rendu à l'arrêt (`server/main.lua:109-111`,
aucun gestionnaire d'arrêt).

## Points d'entrée

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `vava_voice:zones` | RPC (`server/main.lua:89`) | `{}` | 3 puis 1 toutes les 5 s (`config.lua:94`) | aucune (lecture) ; la limite de portée repart au seul demandeur s'il est en jeu (`presence.lua:92-94`) | renvoie toutes les zones : voir MINEUR 3 |
| `vava_voice:editor` | RPC (`:90`) | `{}` | 5 puis 1/s (`config.lua:95`) | droit `tools` par `vava_admin:can` (`guarded`, `:36-41`, `links.lua:46-49` : sans vava_admin, personne) | `canTeleport` = droit `teleport` relu (`:46`) |
| `vava_voice:zoneCreate` | RPC (`:91`) | `LABEL` chaîne 1–160 octets, motif `^[^\0-\31\127]+$` (`:27`, `shared/label.lua:33-34`) ; `RADIUS` 2–60 ; `HEIGHT` 2–30 ; `MULTIPLIER` enum (`:28-30`) | 10 puis 1/s (`config.lua:96`) | droit `tools` ; 200 zones au plus (`zones.lua:125`) ; nom en signes (`:126`) ; centre = position du membre lue par le serveur (`:128`, `:60-65`) ; rayon et hauteur ramenés au pas (`:132`) ; écrit en base avant diffusion (`:134`) ; journal du Registre (`:142`) | diffusion à `-1` (`:143`, `:71-78`) : MINEUR 1 |
| `vava_voice:zoneUpdate` | RPC (`:92`) | `ID` entier 1–2^32−1 (`:25`) + mêmes bornes + `BOOL` recentrage | 10 puis 1/s | droit `tools` ; zone existante (`zones.lua:158`) ; recentrage sur la position lue par le serveur (`:201-205`) ; journal (`:210`) | |
| `vava_voice:zoneDelete` | RPC (`:93`) | `ID` | 10 puis 1/s | droit `tools` ; zone existante (`:178`) ; journal (`:222`) | |
| `vava_voice:zoneReach` | RPC (`:94`) | `ID` | 10 puis 1/s | droit `tools` (`guarded`) **et** `teleport` (`:53`) ; zone existante ; `SetEntityCoords` serveur (`:56`) | non journalisé : MINEUR 2 |
| `isActive`, `limitRange`, `releaseRange`, `getZones` | exports serveur (`server/api.lua:35-62`) | source entier > 0 ; raison `^[%w_%-]+$` ≤ 32, préfixée par `GetInvokingResource` (`:23-26`) ; maximum 1–4 | — | `ready` exigé | deux modules ne lèvent jamais la limite l'un de l'autre |
| `webUpdateZone`, `webDeleteZone` | exports serveur (`:85-101`) | id entier ; nom chaîne (règle `label.clean` dans `zones.webUpdate`) ; rayon, hauteur dans les bornes, effet dans la liste (`:69-80`, `:88-90`) | — | `GetInvokingResource() ~= 'vava_chancellerie'` → `forbidden` (`:87`, `:98`, `config.lua:91`) ; journal tenu par le pont | diffusion à `-1` comme en jeu |
| `core:player:joined` / `core:character:spawned` / `core:character:unloading` / `core:player:dropped` | hooks `after` (`server/main.lua:79-87`) | payload du core | — | micro coupé par `MumbleSetPlayerMuted` hors du jeu (`presence.lua:49,57`) ; limite « à terre » relue à l'apparition (`links.lua:74-81`) | redémarrage : coupe ceux qui ne sont pas en jeu (`main.lua:100-105`) |
| `vava_health:downed` / `revived` / `respawned`, `vava_admin:toolsReady` | hooks `after` (`links.lua:89-94`) | — | — | limite au seul joueur (`presence.lua:72-87`) | |
| `vava_voice:limit`, `vava_voice:zone` | évènements client (`client/main.lua:80-93`) | entier (`:81`, `range.lua:74-80`) ; zone validée champ par champ (`client/zones.lua:24-33`) | — | — | `zone` est envoyé à tous |
| `ready`, `close`, `startNew`, `edit`, `preview`, `cancel`, `save`, `delete`, `reach` | callbacks NUI (`client/nui.lua:50`, `client/editor.lua:162-250`) | `save` : nom chaîne, réglages ramenés aux bornes (`:94-106`), id entier ; `delete`/`reach` : id entier | — | tout ce qui change quelque chose passe par un RPC (`:212-214`, `:232`, `:241`) ; `reach` revérifie `canTeleport` localement puis le serveur | aucun effet serveur sans RPC ; `xpcall` par callback (`nui.lua:38-48`) |
| `vava_voice_zones` | SQL (`server/store.lua:38,49,59,69`) | `?` partout | — | — | `label VARCHAR(40)` = 40 signes utf8mb4, cohérent avec `labelMax` |

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

- `server/zones.lua:73-75` — **chaque changement de zone part à tous les joueurs** (`TriggerClientEvent(EVENTS.ZONE,
  EVERYONE, …)`) — connu et tracé (T-014, abonnements de zone) ; une ligne pour mémoire. La ligne n'est pas non plus
  dans `scripts/audit-exceptions.txt`.
- `server/main.lua:50-58` — **« S'y rendre » n'est pas inscrit au journal du Registre** — un membre du Conseil qui a
  `teleport` se téléporte au centre d'une zone sans trace, alors que le README (« chaque action revérifiée et inscrite
  au journal du Registre ») et `docs/api.md` le laissent entendre ; `links.record` n'est appelé que pour créer,
  modifier, supprimer (`zones.lua:142`, `:210`, `:222`). Correction : `links.record(src, 'Zone de voix rejointe',
  { zone = zone.label })` dans `reach` (texte à ajouter à `config.messages`).
- `server/main.lua:62-65` et `config.lua:94` — **liste complète des zones à chaque appel** — jusqu'à 200 zones
  (≈ 25 Ko) renvoyées 3 fois puis toutes les 5 s à qui les demande : un client modifié peut tirer ≈ 5 Ko/s en continu
  sur la bande passante payée, alors que les changements lui arrivent déjà par `vava_voice:zone`. Correction : numéro
  de version des zones renvoyé au client et comparé avant de renvoyer la liste (règle 5 de `SECURITE_RESEAU.md`), ou
  limite plus basse (1 puis 1 toutes les 30 s : les essais du client sont à 2 s d'écart, `config.lua:44-45`, et
  n'ont lieu qu'à l'apparition).
- `server/zones.lua:125` et `:134-141` — **plafond de 200 zones vérifié avant l'insertion** — `store.insert` cède la
  main ; deux créations simultanées à 199 zones en font 201. Conseil seulement, sans effet de sécurité. Correction :
  compter la place avant d'écrire (`count = count + 1` avant `store.insert`, rendue en cas d'échec).
- `sql/0001_voice_zones.sql:2` — **commentaire « pieds du membre du Conseil »** alors que le centre est la position du
  ped (les hanches : `config.lua:59-60`, README, `docs/api.md`, corrigés par T-008). Une migration publiée ne se
  modifie pas : à noter seulement, le commentaire SQL reste faux.

## Points solides

- Six RPC, tous à schéma fermé (entiers et nombres bornés, enum pour l'effet, nom borné en octets avec motif sans
  caractère de contrôle) et à débit limité ; le droit du Conseil est revérifié par `vava_admin:can` à chaque appel, et
  « S'y rendre » exige en plus `teleport` ; sans vava_admin, personne n'édite.
- Le centre d'une zone n'est jamais envoyé par le client : lu par le serveur sur le ped du membre (`zones.lua:60-65`) ;
  le nom est compté en signes après nettoyage, UTF-8 valide exigé, invisibles refusés (`shared/label.lua`) ; chaque
  zone est écrite en base avant d'être diffusée.
- Les exports du panneau web sont réservés au pont par `GetInvokingResource` (`server/api.lua:87,98`) et revalident
  chaque valeur ; les raisons de limite sont préfixées par la ressource appelante.
- Le serveur impose ce qu'il peut imposer : `MumbleSetPlayerMuted` à l'arrivée, à la sélection et au déchargement, et
  au redémarrage pour ceux qui ne sont pas en jeu ; la limite « à terre » part au seul joueur et revient avec la liste
  des zones. Le reste (portée, salons) est une limite de FiveM, dite clairement dans le README.
- Page de l'éditeur : aucun `innerHTML` (grep), `textContent` partout (`web/js/editor.js:23-29`) ; aucun callback NUI
  n'a d'effet sans RPC ; SQL paramétré.

VERDICT : OK
