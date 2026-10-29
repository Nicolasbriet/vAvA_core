# Audit sécurité — vava_health 1.1.4 — 29 octobre 2026 (T-010)

## Périmètre

Rôle : la vie des personnages, la mise à terre à la place de la mort de GTA, la relève par un autre joueur, le retour
au lieu de soins, les soins par objets ; exports pour les autres modules (`isDowned`, `damage`…).

Lu en entier : `fxmanifest.lua`, `config.lua`, `shared/constants.lua`, `shared/vitality.lua`,
`server/{core,state,life,assist,links,api,commands,main}.lua`, `client/{core,body,screen,hud,keys,main}.lua`,
`web/index.html`, `web/js/{screen,strings}.js`. Côté core : `server/core/rpc.lua`, `shared/lib/schema.lua`,
`shared/core/hooks.lua` (ordre des priorités : croissant, `:48-51` ; défaut 100, `config/shared.lua:23`),
`server/players/characters.lua` (`unload` `:367-384`, `withSession` `:202-221`, RPC `core:characters:spawned`
`:572-582`), `server/players/spawn.lua` (`send` `:43-52`, `at` `:65-75`), `server/players/fields.lua` (`set`,
synchrone, `:100-109`). Voisins : `vava_inventory/server/operations.lua` (hook `use` : payload `:640`, `consumed`
`:672-673`, `guarded` `:227-238`), `vava_magic/bridge/server.lua:278` (les dégâts des sorts passent par `damage`).

Non lu : `web/css/style.css`, `web/js/devmock.js`, `docs/tests/sante.md`, les modules métiers qui appellent
`isDowned` (relus par T-006).

Corrections de T-006 retrouvées dans le code : ordre de coucher à chaque mise à terre, `death` comprise
(`server/life.lua:149`) ; ped lu au seuil ou au-dessus recouché toutes les 5 s (`:255-264`) ; mise à terre par
`vitality.fallen` (`:269`, `:343`) ; vie relue au départ (`:341-347`) ; touche « rendre l'âme » relue
(`client/keys.lua:91-95`, `client/main.lua:52`, `web/js/screen.js:71` en `textContent`) ; inventaire ouvert fermé à la
chute (1.1.4, `server/links.lua:86-88`, appel isolé `:74-82`).

## Points d'entrée

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `vava_health:assist` | RPC (`server/main.lua:39`) | `{}` | 3 puis 1 toutes les 2 s (`config.lua:75`) | personnage apparu et debout (`assist.lua:116-117`) ; un seul geste par relevant (`:118`) ; personne à terre la plus proche à 2 m, positions lues par le serveur, pas déjà prise en charge (`:119`, `:45-56`) ; objet requis compté (`:121-124`) ; hook `vava_health:reviving` (`:125-126`) puis revérification après le hook (`:128`) ; **8 s tenues par le serveur** (`SetTimeout`, `:134`) ; à la fin : relevant debout et apparu, patient toujours à terre, distance ≤ 3 m, objet retiré (`:97-105`) | annulé si l'un des deux tombe, est relevé, part ou se déconnecte (`life.lua:148,171,192,350`) ; voir MINEUR 1 (monde de routage) |
| `vava_health:giveUp` | RPC (`server/main.lua:41`) | `{}` | 2 puis 1 toutes les 5 s (`config.lua:76`) | à terre (`:25`) ; `downedFor ≥ 180 000 ms` compté par le serveur (`:26`, `life.lua:244`) ; lieu de soins le plus proche choisi par le serveur (`life.lua:186`, `:114-123`) | le maintien de 3 s (`client/keys.lua:65-83`) n'est qu'un confort : le délai de 3 min est serveur |
| `get`, `isDowned`, `setHealth`, `heal`, `damage`, `down`, `revive` | exports serveur (`server/api.lua:32-79`) | source entier ; parts de vie 0–1 finies (`:27-29`) ; `revive` ≥ 0,01 ; `cause` chaîne libre | — (ressources serveur seulement) | `ready`, personnage suivi (`:16-22`) ; `setHealth` refuse à terre et avant l'apparition (`life.lua:212-213`) ; `revive` exige à terre (`:166`) ; `down` refuse un joueur déjà à terre (`:143`) | aucun `GetInvokingResource` : voulu (API ouverte aux modules) ; voir MINEUR 4 |
| `core:character:loaded` / `spawned` / `unloading` | hooks `after` (`life.lua:372-376`, déchargement en priorité 10) | payload du core | — | `loaded` revérifie que le personnage est encore actif (`:312-315`) ; vie relue au départ si le ped l'est encore (`:338-352`) | `spawned` vient de la RPC `core:characters:spawned` envoyée par le client : voir IMPORTANT 2 |
| `vava_inventory:move/split/merge/drop/use` (before, priorité 10), `vava_inventory:hold` (before, priorité 10), `vava_inventory:use` (before, after), `vava_needs:decay` (before), `vava_health:downed` (after) | hooks (`server/links.lua:93-108`) | payload de l'inventaire : `source` présent (`operations.lua:640`), `effects` de la définition serveur, `consumed` après coup | — | à terre : tout geste refusé en premier (10 < 100) ; `hold` refusé seulement pour un geste du joueur (`owner == nil`, `:34-36`) ; soin refusé à ≥ 98 % hors terre (`:51-58`) ; soin appliqué seulement si une unité a été consommée (`:60-64`) | voir MINEUR 5 (objet à effets multiples) |
| `vava_health:set` / `down` / `revive` / `respawn` / `channel` / `message` | évènements client (`client/main.lua:112-161`) | types vérifiés (nombre, table, clé connue) | — | — | `set` appliqué par le client : IMPORTANT 1 ; `down` refusé → recouché toutes les 5 s |
| champ `vava_health:state` | champ de personnage, visibilité `owner` (`server/state.lua:35-45`) | `health` 0–1, `downed` booléen, `downedFor` 0–600 000 | — | écrit par le serveur seul, clampé (`:62-68`) | le client ne fait que lire (`client/main.lua:99-101`) |
| boucle serveur | lecture toutes les 500 ms (`life.lua:381-389`, `check` `:238-278`) | — | — | `GetEntityHealth` du ped, cause et auteur lus côté serveur (`:270`, `:102-110`) ; retour d'office à 10 min (`:245-247`) | la valeur lue est celle que le client réplique : IMPORTANT 1 |
| `ready` | callback NUI (`client/screen.lua:52-57`) | aucune donnée lue | — | — | seul callback ; la page ne reçoit que des nombres et une lettre de touche, en `textContent` (`web/js/screen.js:67,71`) ; durée de transition depuis un nombre vérifié (`:53`, `client/main.lua:141,150`) |

## BLOQUANT

Aucun.

## IMPORTANT

- `server/life.lua:66`, `:78`, `:269`, `:275` et `client/main.lua:112-114` — **la vie GTA appartient au client
  (connu : T-110)** — le serveur ne lit que `GetEntityHealth(ped)` répliquée par le client et lui demande d'appliquer
  `vava_health:set` ; un client modifié qui ignore `set`, ou repose sa vie au maximum, ne subit aucun dégât décidé par
  le serveur (sorts : `vava_magic/bridge/server.lua:278` → `damage`), n'est jamais mis à terre par la boucle, et
  voit même cette vie pleine enregistrée toutes les 10 s (`:275-276`) puis servie par `currentHealth` (`:78`) à `heal`
  et à `not_injured`. Ce qu'il gagne à forger `set` : rien de plus qu'un `SetEntityHealth` local. Ce qu'il gagne à
  refuser `down` : rien (recouché toutes les 5 s, `:255-264`, et tout ce qui compte est refusé par `isDowned` côté
  serveur). Correction : T-110, déjà au backlog (vie tenue côté serveur, la vie du ped ne servant qu'à détecter les
  coups natifs) ; rien de nouveau à ouvrir.
- `server/life.lua:239`, `:213`, `:302`, `:341` et `server/assist.lua:116` — **la porte `entry.spawned` repose sur une
  déclaration du client** — `spawned` ne passe à vrai qu'au hook `core:character:spawned` (`:318-323`), émis par le
  core quand le client appelle lui-même la RPC `core:characters:spawned` (`server/players/characters.lua:572-582`) ;
  rien ne l'y oblige (`server/players/spawn.lua:43-52` : le core n'en fait dépendre que le temps de jeu et
  l'échantillonnage de position). Un client modifié qui fait apparaître son ped sans confirmer n'est jamais lu par la
  boucle (`:239`), `setHealth`/`heal`/`damage` lui répondent `not_spawned` (`:213`), sa vie n'est jamais relue au départ
  (`graceUntil = huge`, `:302`, `:341`) et personne ne peut le relever ni le compter à terre : immunité complète aux
  dégâts et à la mise à terre, tout en jouant (le chat le sert dès `loaded`, `vava_chat/server/main.lua:79` ; la voix,
  elle, reste coupée). Même effet que le point précédent, par un autre chemin, qui survivrait à une vie tenue côté
  serveur si `setHealth` garde cette porte : classé IMPORTANT et non BLOQUANT parce qu'il n'ouvre rien de plus que la
  limite connue. Correction : à verser à T-110 : ne pas conditionner la lecture ni l'écriture de la vie à la
  déclaration du client (joueur « apparu » dès que `GetPlayerPed(src) ~= 0` et `DoesEntityExist` après l'ordre
  d'apparition, avec le délai de grâce), ou faire confirmer `spawned` par le core lui-même quand le ped existe.

## MINEUR

- `server/assist.lua:36-41` et `:45-56` — **la relève ignore le monde de routage** — la distance est calculée sans
  `GetPlayerRoutingBucket`, contrairement au chat (`vava_chat/server/audience.lua:25,30`) : deux joueurs superposés
  dans deux instances pourraient se relever. Aucune instance de joueurs aujourd'hui (vava_world prépare des buckets) ;
  à aligner avant les propriétés et instances.
- `server/life.lua:188-196` — **l'état est engagé avant que l'apparition soit accordée** — `respawn` écrit
  `downed = false` et 50 % (`persist`, `:191`) puis appelle `characters.spawn` ; en cas d'échec (`no_character` si la
  session n'est plus active, `characters.lua:537-542`), le joueur reste au sol avec un ped mort et sans écran, et
  reviendrait debout à 50 % à sa reconnexion. Aucun chemin trouvé pour le provoquer depuis un client : `respawn`,
  `unload` et `withSession` sont synchrones. Robustesse : remettre `downed = true` (ou ne persister qu'après le
  `spawn`) si `characters.spawn` échoue.
- `server/assist.lua:134` — **geste perdu à un `restart vava_health`** — le `SetTimeout` et les canaux disparaissent
  avec la ressource ; les deux clients gardent leur barre (« Quelqu'un vous relève… ») jusqu'à la prochaine
  transition, rien n'est accordé. Correction : un `onResourceStop` qui envoie `cancel` aux canaux ouverts.
- `server/api.lua:66-71` — **`cause` sans borne** — l'export `down(src, cause)` accepte une chaîne de longueur
  quelconque, transmise telle quelle au hook `vava_health:downed` ; serveur seulement. Borner à 32 caractères et à un
  motif, par cohérence avec les raisons de `vava_voice:limitRange`.
- `server/links.lua:51-58` et README (« refusé si l'on n'est pas blessé ») — **un objet à effets multiples n'est pas
  refusé** — `beforeUse` laisse passer un objet qui a d'autres effets que `health` (`foreign`, `:53`), alors que
  `afterUse` applique quand même le soin (`:60-64`) : une « potion soin + faim » se consomme à 100 % de vie. Doc à
  préciser, ou refuser aussi dans ce cas quand aucun autre module ne réclame l'objet.

## Points solides

- Deux RPC sans argument, à débit limité ; tout ce qui a de la valeur est décidé et minuté par le serveur : choix de
  la personne à terre (positions lues côté serveur, rien n'est diffusé pour la repérer), geste de 8 s tenu par
  `SetTimeout`, distance et états revérifiés à la fin, délai de 3 min avant de rendre l'âme, retour d'office à 10 min,
  lieu de soins le plus proche.
- La mise à terre est une lecture du serveur (500 ms) avec cause et auteur lus côté serveur ; l'ordre de coucher part
  à chaque mise à terre et un ped resté debout est recouché toutes les 5 s, journalisé une fois ; la déconnexion à
  terre ne sert à rien (état persistant, vie relue au départ, priorité 10 au déchargement).
- Gardes de l'inventaire en priorité 10, donc avant tout autre abonné (ordre croissant), avec `source` présent dans
  chaque payload ; soin appliqué seulement si une unité a vraiment été consommée ; inventaire fermé à la chute par un
  appel isolé.
- Courses fermées : revérification après le hook `reviving` (`assist.lua:128`), un seul geste par relevant et par
  patient, annulation sur chaque transition et au départ des deux côtés.
- Écran NUI sans focus, un seul callback (`ready`), aucune donnée joueur, `textContent` partout, aucun `innerHTML`
  (grep) ; champ de personnage borné par schéma et visible du seul propriétaire ; aucune requête SQL propre.

VERDICT : À CORRIGER (dans T-110, déjà au backlog : les deux IMPORTANT relèvent de la même chaîne ; aucun BLOQUANT)
