# Audit sécurité — vava_cameras 1.1.1 — 29 octobre 2026 (T-010)

## Périmètre

Rôle : le mur des caméras du Conseil — le jeu du joueur filmé envoie son image en WebRTC direct à chaque membre qui
regarde (en jeu ou depuis la Chancellerie) ; le serveur ne relaie que la négociation et décide qui regarde qui.

Fichiers lus en entier : `fxmanifest.lua`, `config.lua`, `shared/constants.lua`, `server/{main,core,sessions,links,
players,api,commands}.lua`, `client/{main,core,nui,wall,capture}.lua`, `web/index.html`, `web/js/{wall,capture,viewer,
bridge,strings}.js`. Pour le droit et le journal : `vava_admin/server/api.lua` (exports `can`, `log`).

Non lus : `web/js/devmock.js`, `web/css/wall.css`. La partie navigateur de la Chancellerie (`chancellerie/web/js/
view-cameras.js`) est hors périmètre ; `chancellerie/lib/camera.js` a été lu pour comprendre le pont.

Décisions déjà prises, non relevées : tout membre du Conseil (droit `watch`, Gardien compris) regarde tout le monde
sans règle de rang ; WebRTC direct (adresses IP visibles des deux bouts, STUN public de Google) ; le joueur n'est pas
prévenu.

## Points d'entrée

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `vava_cameras:sendOffer(SESSION, SDP)` | RPC (`server/main.lua:97`) | `SESSION` 24 hex exactement (`:26`), `SDP` 1..20000 o (`:27`) | `capture` 8 puis 2/s | caméra existante et `camera.target == src` (`sessions.lua:120`) : seul le joueur filmé envoie l'offre | aucun drapeau « déjà offert » : voir IMPORTANT |
| `vava_cameras:failed(SESSION, FAILURE)` | RPC | `FAILURE` enum de 4 raisons (`:28`) | `capture` | `camera.target == src` (`sessions.lua:156`) | éteint sa propre caméra, prévient le spectateur |
| `vava_cameras:wall()` | RPC | `{}` | `wall` 4 puis 0,5/s | droit `watch` relu auprès de vava_admin (`guarded` `:34-39`, `links.canWatch` `links.lua:20-23`) ; journal « Mur des caméras ouvert » (`:62`) | liste des joueurs sans soi-même |
| `vava_cameras:players()` | RPC | `{}` | `players` 4 puis 1/s | droit `watch` | relecture toutes les 5 s mur ouvert |
| `vava_cameras:watch(TARGET, QUALITY)` | RPC | `TARGET` 1..65535, `QUALITY` enum tile/full (`:29-30`) | `watch` 40 puis 8/s | droit `watch`, soi-même refusé (`:70`), cible apparue (`sessions.lua:93`, `players.lua:25-28`), 96 caméras en tout et 6 par joueur filmé (`sessions.lua:94-95`), 30 s sans réponse et 2 h au plus (`:104-108`) ; journal pour `full` seulement (`main.lua:75`) | voir IMPORTANT (tile sans journal) |
| `vava_cameras:sendAnswer(SESSION, SDP)` | RPC | idem | `signal` 40 puis 8/s | droit `watch` + spectateur de cette caméra (`viewerIs` `:44-48`, `sessions.lua:133`), une seule réponse (`:135-136`) | la réponse ne va qu'au joueur filmé |
| `vava_cameras:close(SESSION)` | RPC | `SESSION` | `signal` | spectateur de cette caméra (`sessions.lua:146`) | pas de droit requis : ne touche que ses caméras |
| `vava_cameras:leave()` | RPC | `{}` | `wall` | ferme les caméras dont l'appelant est spectateur (`sessions.lua:176-180`) | |
| `count` | export (tous) | — | — | lecture | |
| `webPlayers`, `webStart(target, quality)`, `webAnswer(id, sdp)`, `webStop(id)` | export réservé au pont (`api.lua:26-28`) | `target` entier ≥ 1 (`:44`), qualité connue (`sessions.lua:91`), `id`/`sdp` typés et bornés (`:132-134`) | — | droit et journal vérifiés par le pont auprès du Registre ; spectateur « web » lié à la caméra (`isWebViewer`) | |
| `core:character:unloading`, `core:player:dropped` | hooks after (`main.lua:114-115`) | — | — | caméras du joueur filmé et du spectateur éteintes (`sessions.forget`) | |
| `vava_admin:action` (staffGrant/Revoke) | hook after (`main.lua:82-91`) | — | — | droit relu au tick suivant, caméras révoquées (`sessions.revoke`) | mise à jour sans reconnexion |
| `wall:watch`, `wall:answer`, `wall:close`, `wall:exit`, `capture:offer`, `capture:failed`, `ready` | callback NUI (`client/wall.lua:88-110`, `client/capture.lua:25-35`) | identifiant vérifié `isSession`, SDP ≤ 20000, qualité connue | — | tout repart en RPC ; isolé par xpcall (`client/nui.lua:47-57`) | |
| `vava_cameras:start/answer/stop` (filmé), `offer/ended` (spectateur) | évènements serveur → client | types et identifiant vérifiés (`capture.lua:37-53`, `wall.lua:114-124`) | — | — | |
| hook `vava_cameras:web` | hook after serveur | — | — | — | relayé par le pont à la Chancellerie |

## BLOQUANT

Aucun.

## IMPORTANT

- `modules/vava_cameras/server/sessions.lua:118-123` — **offre relayée sans limite par caméra** — le joueur filmé
  (client modifié) renvoie `sendOffer` en boucle sur sa caméra : chaque appel accepté (`capture` : 8 d'affilée puis 2/s)
  pousse jusqu'à 20 Ko vers le membre qui regarde (`TriggerClientEvent`, `:63`) ou une requête HTTP vers la
  Chancellerie (`:69`) : ≈ 40 Ko/s sortants payés par le serveur tant qu'on le regarde, et le navigateur du web reçoit
  des offres répétées. L'autre sens est déjà protégé (`answered`, `:135-136`). Correction : poser `camera.offered = true`
  à la première offre et répondre `already_offered` ensuite (une renégociation passe par une nouvelle caméra).
- `modules/vava_cameras/server/main.lua:69-77` — **cases de mur (`tile`) sans aucune trace au journal** — seul `full`
  est inscrit (`:75`) ; le journal des cases repose sur l'ouverture du mur, que le serveur n'exige jamais : un membre au
  droit `watch` (Gardien) appelle `vava_cameras:watch(joueur, 'tile')` depuis un client modifié et regarde n'importe
  qui à 480 × 270 pendant 2 h sans qu'aucune ligne n'existe, puis recommence. Même chose depuis le web : la route
  `/camera/start` en `tile` ne demande que le droit (`vava_chancellerie/server/routes.lua:139-141`), pas le passage
  par `/cameras/wall`. Correction : tenir côté serveur un état « mur ouvert » par spectateur (posé par `wall`, levé par
  `leave`, `forget`, `revoke`) et refuser `tile` sans lui ; pour le web, journaliser la première caméra d'un compte
  quand aucun mur n'a été ouvert, ou exiger `/cameras/wall` d'abord.

## MINEUR

- `modules/vava_cameras/server/links.lua:20-23` — le droit ne demande pas de personnage chargé (le client le vérifie en
  `client/wall.lua:70`, pas le serveur) : un membre en sélection de personnage peut ouvrir des caméras. Sans effet
  nuisible ; ajouter `core.characters.getActive(src)` dans `guarded` par cohérence avec le client.
- `modules/vava_cameras/server/main.lua:62` et `:75` — journal à chaque `wall` (0,5/s) et chaque vue en grand (8/s) :
  un membre peut remplir `vava_admin_logs` à bon rythme. Abaisser `rateLimits.wall` ou n'inscrire qu'une vue en grand
  par cible et par minute.
- `modules/vava_cameras/server/sessions.lua:42-44` — identifiants tirés avec `math.random` (non cryptographique). Sans
  conséquence : une caméra n'est utilisable que par son joueur filmé et son spectateur, vérifiés à chaque message ;
  à noter seulement si un jour l'identifiant seul ouvrait un droit.
- `modules/vava_cameras/server/sessions.lua:104-108` — deux `SetTimeout` par caméra (30 s et 2 h) restent armés après
  une fermeture anticipée (sans effet : `list[id]` vide). Borné par 96 caméras ; acceptable.
- `modules/vava_cameras/web/js/wall.js:255-266` — une offre volontairement invalide du joueur filmé fait échouer la
  connexion chez le spectateur, qui retente toutes les 10 s : chaque essai est une nouvelle caméra, un nouvel ordre
  `start` et une nouvelle ligne de journal en vue en grand. Borné, mais un plafond d'essais par joueur et par mur
  éviterait la boucle.

## Points solides

- Chaque message de négociation est vérifié des deux bouts : l'offre n'est acceptée que du joueur filmé
  (`sessions.lua:120`), la réponse et la fermeture que du spectateur lié à la caméra (`:133`, `:146`), une seule réponse
  (`:135`) ; le serveur ne lit jamais le contenu du SDP, borné à 20 000 octets par le schéma.
- Le droit `watch` est relu auprès du Registre à chaque demande du membre (`guarded`) et à chaque rang donné ou retiré
  (`main.lua:82-91`) ; les caméras d'un membre révoqué s'éteignent et son mur l'affiche.
- Limites tenues côté serveur : 6 spectateurs par joueur, 96 caméras, 30 s sans réponse, 2 h au plus ; extinction au
  déchargement du personnage, au départ du filmé ou du spectateur, à la fermeture du mur.
- Les exports du web refusent toute ressource autre que le pont (`api.lua:26-28`) et retypent leurs arguments.
- Interface sans `innerHTML` : noms et numéros de joueurs posés par `textContent` (`wall.js:51-56`, `:116-117`) ; les
  retours NUI revérifient l'identifiant (`isSession`) et la taille du SDP avant d'émettre (`client/wall.lua:100-105`).
- Rien n'est filmé sans ordre du serveur ; dernier spectateur parti, dessin et capture s'arrêtent
  (`web/js/capture.js:96-104`).

VERDICT : OK
