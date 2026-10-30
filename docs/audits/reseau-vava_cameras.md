# Audit réseau et performance — vava_cameras 1.1.1 — 30 octobre 2026 (T-011)

## Périmètre

Caméras du Conseil : l'écran d'un joueur filmé par sa page NUI (WebGL + `captureStream`) et envoyé en WebRTC, de
joueur à spectateur, sans passer par le serveur ; mur des caméras en jeu. Lus en entier : `config.lua`,
`server/sessions.lua` (envois), `client/capture.lua`, `client/wall.lua`, `web/js/capture.js:40-120`, `fxmanifest.lua`.

## Envois serveur → client

| Évènement | Fichier:ligne | Cible | Taille estimée | Fréquence |
|---|---|---|---|---|
| `START` | `server/sessions.lua:99` | le joueur filmé | 150 o (session, STUN, capture, qualité) | une par caméra ouverte |
| `OFFER` | `server/sessions.lua:63` | le spectateur | offre SDP, jusqu'à 20 000 o (`config.lua:32`) | une par caméra (voir T-026 pour les offres répétées) |
| `ANSWER` | `server/sessions.lua:137` | le joueur filmé | réponse SDP, 2 à 5 Ko | une par caméra |
| `ENDED`, `STOP` | `server/sessions.lua:65`, `:80` | spectateur ou joueur filmé | 40 o | fin |
| réponse `players` (mur ouvert) | RPC, `client/wall.lua:48-56` | le membre du Conseil | 40 o par joueur connecté (64 joueurs : 2,5 Ko) | **toutes les 5 s** tant que le mur est ouvert |

Le flux vidéo lui-même ne passe pas par FXServer : il part de la connexion **montante du joueur filmé**.

## GlobalState et state bags

Aucun.

## Boucles

| Boucle | Fichier:ligne | Au repos | En action | Remarque |
|---|---|---|---|---|
| relecture des joueurs du mur | `client/wall.lua:48-56` | — | 5 s, mur ouvert (Conseil) | |
| dessin de l'image du jeu (page du joueur filmé) | `web/js/capture.js:75-81`, `:84-94` | — | `requestAnimationFrame` cadencé à 20 images/s tant qu'au moins un spectateur regarde ; arrêté au dernier départ (`:97-104`) | coût GPU et encodage chez le joueur filmé |

## Fichiers web

`web/` : 306 480 o, téléchargés par **tous** les joueurs (la page de capture doit exister chez chacun). Dont 243 457 o
communs (T-012), et deux fichiers livrés jamais utilisés : `web/img/paper.png` (57 122 o ; `web/css/wall.css` n'utilise
que la couleur `--paper`) et `web/fonts/cinzel_decorative_400.woff2` (14 416 o ; seule la graisse 700 est déclarée,
`wall.css:11`). `web/js/devmock.js` (5 249 o) livré.

## BLOQUANT

Aucun.

## IMPORTANT

- `config.lua:17-21`, `:28-29` — **aucun plafond du débit montant imposé au joueur filmé** — une capture par joueur,
  mais un encodeur et un débit **par spectateur** : jusqu'à 6 spectateurs (`viewersPerPlayer`), soit jusqu'à
  6 × 1 200 kbit/s = 7,2 Mbit/s en vue pleine, pris sur la connexion montante d'un joueur qui n'a rien demandé (une
  connexion ADSL monte souvent à 1 Mbit/s ; WebRTC baisse le débit quand elle sature, mais le jeu et la voix partagent
  la même voie et en pâtissent, et chaque encodeur coûte du processeur). Correction : budget montant total par joueur
  filmé en config (ex. 1 500 kbit/s), réparti entre ses spectateurs (une seule vue pleine à la fois, les autres en
  case), refus `budget` au-delà ; mesurer en jeu les images par seconde et le ping du joueur filmé avec 1, 3 et 6
  spectateurs. Tâche T-047.

## MINEUR

- `client/wall.lua:48-56` — **liste complète des joueurs toutes les 5 s** au Conseil qui a le mur ouvert : envoyer les
  arrivées et départs seulement (2,5 Ko toutes les 5 s à 64 joueurs, par membre).
- `web/img/paper.png`, `web/fonts/cinzel_decorative_400.woff2` — **71 538 o livrés à chaque joueur et jamais
  chargés** — à retirer des `files` (ou avec T-012).

## Points solides

- Aucune image ne passe par le serveur ; capture partagée, ouverte au premier spectateur et arrêtée au dernier ;
  dessin cadencé sur la fréquence de capture, pas sur celle de l'écran.
- Signalisation ciblée (joueur filmé, spectateur) ; mur réservé au Conseil.

## À vérifier en jeu

- Images par seconde et ping du joueur filmé avec 1, 3 et 6 spectateurs, en case puis en vue pleine.
- resmon de `vava_cameras` chez un joueur jamais filmé (la page doit rester inerte).

VERDICT : À CORRIGER
