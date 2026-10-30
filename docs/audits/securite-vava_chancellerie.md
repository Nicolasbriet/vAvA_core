# Audit sécurité — vava_chancellerie 1.3.1 — 29 octobre 2026 (T-010)

## Périmètre

Rôle : le pont HTTP entre le serveur de jeu et le panneau web Node.js (la Chancellerie) — demandes du panneau exécutées
par le Registre, les zones de voix et les caméras au nom d'un compte du panneau ; évènements poussés vers le panneau ;
liaison compte du panneau ↔ joueur par code tapé en jeu ; liste blanche Discord à la connexion.

Fichiers lus en entier : `fxmanifest.lua`, `config.lua`, `shared/constants.lua`, `server/{main,core,http,auth,routes,
link,push,whitelist,commands}.lua`, `README.md`, `docs/chancellerie.md`. Côté panneau, la seule partie qui parle au
pont : `chancellerie/lib/bridge.js`, `lib/routes-game.js`, `lib/camera.js`, `lib/links.js`, `lib/events.js`,
`lib/routes.js:300-347` (aiguillage et vérification des évènements du pont), `lib/process.js:205` (ligne de commande
de FXServer), `lib/http.js:15` (corps borné à 64 Ko).

Non lus : le reste du panneau (comptes, sessions, Discord, installation, interface web), hors périmètre.

Modèle de menace retenu : un attaquant sur le réseau local ou sur la machine ; un compte du panneau de rang inférieur
qui tente une action d'un rang supérieur.

## Points d'entrée

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| Toute requête `http://…/vava_chancellerie/*` | HTTP (`SetHttpHandler`, `server/http.lua:43`) | adresse de boucle locale (`auth.lua:44-46`, port retiré `:32-40`), en-tête `x-vava-token` comparé à temps constant à la clé du lancement (`:52-57`, `:72-75`), clé d'au moins 32 signes sinon pont fermé (`:25-27`) ; corps POST ≤ 64 Ko (`http.lua:58`), JSON sous `pcall` et table exigée (`:62-66`) ; route inconnue → 404 ; handler sous `pcall` dans son thread, toujours une réponse (`:29-38`) | aucune (local) | authentification **avant** la lecture du corps (`http.lua:44-47`) | l'adresse `::ffff:127.0.0.1:port` serait refusée (`hostOf` ne retire le port qu'avec un seul « : ») : fermeture sûre, mais à savoir si FXServer la présentait |
| `GET /ping`, `GET /ranks` | HTTP | — | — | — | version et nombre de caméras ; rangs |
| `POST /request {actor, name, args}` | HTTP (`routes.lua:88-98`) | `args` table ou `{}` | — | passé tel quel à `vava_admin.webRequest` qui revalide acteur, droit, schéma, cible, rang et journalise ; `zones` (droit `view`), `zoneUpdate`/`zoneDelete` (droit `tools`) vérifiés par `webCan` puis délégués à `vava_voice` (`:50-74`) | les arguments des zones ne sont pas bornés ici (validation attendue de `vava_voice`, hors périmètre) |
| `POST /staff/sync {members}` | HTTP (`:104-117`) | 100 membres au plus ; chaque entrée retypée par `webSyncStaff` (`vava_admin/server/web.lua:123-126`) | — | le panneau est la source du rang des comptes reliés ; journal au nom « Chancellerie : <compte> » avec `origine : compte relié` | tout rang, Souverain compris : voulu (compte maître) |
| `POST /cameras/wall`, `/cameras/players {actor}` | HTTP (`:120-131`) | — | — | droit `watch` par `webCan` ; `wall` inscrit au journal | |
| `POST /camera/start {actor, target, quality}` | HTTP (`:133-148`) | `target` entier, `quality` tile/full | — | `full` : demande `watchScreen` du Registre (cible vérifiée, journal) ; `tile` : seul droit `watch` | voir rapport vava_cameras (tile sans journal) |
| `POST /camera/answer {session, sdp}`, `/camera/stop {session}` | HTTP (`:150-162`) | typés par `vava_cameras` (`sessions.lua:132-134`) | — | caméra « web » existante ; **aucun acteur** : l'appartenance de la caméra à un onglet n'est vérifiée que par le panneau (`chancellerie/lib/camera.js:60-61`, `:68-69`) | acceptable tant que le panneau est le seul détenteur de la clé |
| `/chancellerie <code>` | commande joueur (`link.lua:50-80`) | 6 chiffres exactement (`:17`), 5 essais par minute et par joueur (`:33-46`), compte et license requis | — | envoie au panneau code, license, `fivem:`, `discord:`, compte, pseudo ; le panneau tranche : code de 5 min à usage unique, 5 codes faux par license puis 10 min d'attente (`lib/links.js:21-26`, `:118-124`) | force brute : 10⁶ codes, ≈ 30 essais/h par license : hors de portée |
| `core:player:connecting` (liste blanche) | hook before (`whitelist.lua:32-55`) | — | — | réponse du panneau attendue 8 s ; sans réponse : refus si la liste était active, sinon accepté | pas branché si le serveur est lancé sans clé (`:61`) |
| Évènements poussés (`push.send`, `push.request`) | `PerformHttpRequest` vers `vava_chancellerie_url` + `/api/bridge/event` (`push.lua:32-39`, `:46-53`) | — | avertissement au plus une fois par minute | clé en **en-tête**, jamais dans l'URL ; le panneau n'accepte ces évènements que de la boucle locale avec la clé (`lib/bridge.js:42-47`, `lib/routes.js:319-320`) | |
| Hooks `vava_admin:report`, `vava_cameras:web`, `vava_admin:action`, `core:player:joined/dropped`, `onResourceStop(vava_cameras)` | hooks after | — | — | relais vers le panneau ; rang changé → `recheck` des caméras du web | |

## BLOQUANT

Aucun.

## IMPORTANT

- `chancellerie/lib/bridge.js:30-34` et `lib/process.js:205` (lu par `modules/vava_chancellerie/server/auth.lua:20-22`,
  documenté `README.md:17-18`, `docs/chancellerie.md:387-389`) — **la clé du pont voyage sur la ligne de commande de
  FXServer** (`+set vava_chancellerie_token <clé>`) — la ligne de commande d'un processus se lit depuis la machine sans
  être root (`/proc/<pid>/cmdline`, `ps -ef` sous Linux ; Gestionnaire des tâches ou `wmic process` sous Windows pour le
  même utilisateur) ; avec la clé et l'accès local déjà supposés par le modèle de menace, un attaquant appelle
  `/request` avec `actor = { label = 'x', rank = 'souverain' }` (le pont fait confiance au rang annoncé : c'est le
  panneau qui l'établit) et bannit, lève des bans, nomme ou révoque, proclame ; `/staff/sync` lui donne même le rang de
  Souverain en jeu sur n'importe quel compte. Correction : sortir la clé de la ligne de commande — l'envoyer par
  l'entrée standard de FXServer juste après le lancement (`set vava_chancellerie_token …`, que `secrets()` masque déjà
  dans la console), ou l'écrire dans un fichier à droits restreints lu par le pont au démarrage — et, en défense en
  profondeur, refuser au pont tout `actor.rank` supérieur à ce qu'un second secret ou une liste de comptes connus
  autorise pour `/staff/sync`.

## MINEUR

- `modules/vava_chancellerie/server/routes.lua:150-162` — `/camera/answer` et `/camera/stop` n'exigent pas d'acteur :
  tout détenteur de la clé répond ou ferme n'importe quelle caméra du web par son identifiant (24 hex aléatoires).
  Transmettre `actor` et laisser le panneau joindre le compte, ou garder côté pont le compte qui a ouvert la caméra.
- `modules/vava_chancellerie/server/routes.lua:59-61` et `:67-69` — `zoneUpdate` et `zoneDelete` passent
  `args[1..5]` sans aucune borne (type, longueur) avant `vava_voice.webUpdateZone` ; la validation repose entièrement
  sur `vava_voice` (hors périmètre, à confirmer dans son audit). Un typage minimal ici (entier pour l'identifiant,
  chaîne ≤ 40 pour le nom) coûterait trois lignes.
- `modules/vava_chancellerie/server/auth.lua:36-39` — `hostOf` ne retire le port qu'aux adresses à un seul « : » :
  `::ffff:127.0.0.1:51234` n'est pas reconnue comme locale (pont fermé). Fermeture sûre ; si FXServer présentait cette
  forme, le pont serait muet sans message clair. Retirer le port avec `^(.*):%d+$` quand la chaîne contient plus d'un
  « : » et pas de crochets.
- `modules/vava_chancellerie/config.lua:24` — le droit `watch` et le nom `watchScreen` sont recopiés de
  `vava_cameras`/`vava_admin` ; une dérive de l'un sans l'autre ne serait vue qu'en jeu. Lire `VavaCameras.config.permission`
  n'est pas possible d'une ressource à l'autre : à défaut, un test d'intégration ou un commentaire croisé.
- `modules/vava_chancellerie/server/link.lua:23-46` — le compteur d'essais est tenu par numéro de session : une
  reconnexion le remet à zéro. Sans conséquence, le vrai frein étant côté panneau (par license), mais une clé par compte
  (`session.accountId`) serait plus juste.
- `modules/vava_chancellerie/server/whitelist.lua:47-50` — une liste blanche jamais annoncée active (panneau fermé dès
  le premier lancement) laisse entrer tout le monde (`enabled = false` par défaut, `:22`). Comportement documenté ;
  à rappeler dans la page Discord du panneau.

## Points solides

- Authentification avant tout : adresse locale **et** clé de lancement, comparée à temps constant, vérifiées avant la
  lecture du corps (`http.lua:44-47`) ; sans clé le pont reste fermé et la console le dit (`main.lua:57-58`).
- Aucun crash possible par une requête : corps borné, JSON sous `pcall`, handler sous `pcall` dans son propre thread,
  réponse systématique (`http.lua:29-38`, `:57-67`) ; méthode ou route inconnue → 404 sans traitement.
- Le pont ne décide de rien : chaque demande est revalidée par le module qui l'exécute (`webRequest`, `webCan`,
  `webStart`…), tous réservés à la ressource-pont par `GetInvokingResource`, et journalisée au nom « Chancellerie :
  <compte> » ; un compte du panneau de rang inférieur ne peut pas forger son rang, que le panneau tire de sa session
  (`lib/routes-game.js:49`, `lib/bridge.js:94-96`).
- La clé n'apparaît jamais dans une URL ni dans le `server.cfg` ; les évènements vers le panneau sont authentifiés de la
  même façon dans l'autre sens.
- La liaison par code est à usage unique, courte (5 min), bornée des deux côtés, et le pseudo du joueur est nettoyé
  avant d'être gardé (`lib/links.js:127`).

VERDICT : OK
