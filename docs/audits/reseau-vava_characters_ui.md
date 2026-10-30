# Audit réseau et performance — vava_characters_ui 1.0.1 — 30 octobre 2026 (T-011)

## Périmètre

Écran de sélection et de création des personnages (client seul, RPC du core). Lus : `client/main.lua`,
`client/preview.lua`, `client/camera.lua`, `client/nui.lua`, `config.lua`, `fxmanifest.lua`.

## Envois serveur → client

Aucun évènement propre : la liste des personnages et la création passent par les RPC du core (réponse au seul
demandeur, quelques centaines d'octets par personnage), seulement pendant la sélection.

## GlobalState, state bags, props

Aucun. L'aperçu agit sur le ped du joueur, figé et invisible des autres pendant la sélection (`client/players/spawn.lua`
du core).

## Boucles client

| Boucle | Fichier:ligne | Au repos | En action | Remarque |
|---|---|---|---|---|
| attentes de l'aperçu (modèle, collisions) | `client/preview.lua:29-31` | — | 50 ms, bornées, pendant la sélection | |
| transition de caméra | `client/camera.lua:49` | — | un `SetTimeout` | |
| envoi groupé de la page | `web/js/bridge.js:64` | — | `requestAnimationFrame` le temps d'un envoi | |

Rien ne tourne une fois le personnage en jeu.

## NUI et fichiers web

`web/` : 248 241 o, dont 156 431 o communs (T-012) ; `web/js/devmock.js` (3 851 o) livré. Cette page est la première
chargée par un nouveau joueur : elle profitera de `vava_ui` (T-012) et de l'écran de chargement (T-020).

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

Aucun.

VERDICT : OK
