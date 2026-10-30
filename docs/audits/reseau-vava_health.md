# Audit réseau et performance — vava_health 1.1.4 — 30 octobre 2026 (T-011)

## Périmètre

Vie, mise à terre, aide d'un autre joueur, réveil. Lus en entier : `server/state.lua`, `server/life.lua` (`:80-110`,
`:140-280`, `:375-391`), `server/assist.lua` (`:40-140`), `client/main.lua`, `client/body.lua` (`:90-112`),
`config.lua`.

## Envois serveur → client

| Évènement | Fichier:ligne | Cible | Taille estimée | Fréquence |
|---|---|---|---|---|
| `DOWN` | `server/life.lua:149`, `:263` | le joueur | 5 o | mise à terre ; renvoyé au plus toutes les 5 s à un client qui se relève sans accord (`config.lua:24`) |
| `REVIVE`, `RESPAWN`, `SET`, `MESSAGE` | `server/life.lua:172`, `:194`, `:197`, `:217` | le joueur | 10-20 o | à l'évènement |
| `CHANNEL` (aide) | `server/assist.lua:73-74`, `:106`, `:132-133` | l'aidant et le patient | 40 o | début, fin, abandon d'une aide |
| champ `vava_health:state` (`owner`) | `server/state.lua:43`, écrit par `server/life.lua:85-98` | le joueur | 40 o | **seulement s'il a changé**, au plus toutes les 10 s (`sampleMs`) ; à terre, `downedFor` change donc une fois par 10 s |

## GlobalState, state bags, props

Aucun.

## Boucles

| Boucle | Fichier:ligne | Au repos | En action | Remarque |
|---|---|---|---|---|
| jauge de vie (client) | `client/main.lua:171-176` | **500 ms, permanente** en jeu ; lecture locale, page prévenue au seul changement d'un centième | idem | |
| chargement d'animation (client) | `client/body.lua:94-106` | — | 10 ms, borné à 1 s | |
| lecture des vies (serveur) | `server/life.lua:381-384` | 500 ms, tous les joueurs suivis | idem | serveur seulement, aucun envoi tant que rien ne change |

## NUI et fichiers web

Écran « à terre » : minuteur de la page (`web/js/screen.js:77`) seulement à terre. `web/` : 180 158 o, dont
156 431 o communs (T-012) ; `web/js/devmock.js` (1 137 o) livré.

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

Aucun.

## Points solides

- Écriture du champ au seul changement (`life.lua:85-90`), envois au seul joueur concerné ; renvoi de la mise à terre
  espacé et journalisé une fois.
- Jauge lue localement, arrondie au centième, envoyée au HUD au seul changement.

## À vérifier en jeu

- resmon de `vava_health` au repos (une boucle de 500 ms) : cible ≤ 0,02 ms.

VERDICT : OK
