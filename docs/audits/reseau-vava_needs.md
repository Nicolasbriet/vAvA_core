# Audit réseau et performance — vava_needs 1.1.2 — 30 octobre 2026 (T-011)

## Périmètre

Faim et soif : baisse décidée par une boucle serveur, effets, consommation. Lus en entier : `server/decay.lua`
(`:120-224`), `server/consume.lua` (`:60-94`), `server/state.lua` (`:35-62`), `client/main.lua`, `client/effects.lua`,
`client/hud.lua`, `config.lua`, `fxmanifest.lua`.

## Envois serveur → client

| Évènement | Fichier:ligne | Cible | Taille estimée | Fréquence |
|---|---|---|---|---|
| champ `vava_needs:state` (`owner`) | `server/state.lua:60`, écrit par la boucle de baisse | le joueur | 30 o (`hunger`, `thirst`) | **une fois par minute** (`config.lua:42`) et à chaque objet consommé |
| `STARVE` | `server/decay.lua:131` | le joueur | 5 o | une fois par minute, seulement besoin épuisé |
| `CONSUME` (geste) | `server/consume.lua:81` | le joueur | 15 o | par objet consommé |

C'est l'envoi régulier attendu d'un joueur au repos (« ≈ 0 par minute hors besoins/HUD », `SECURITE_RESEAU.md`).

## GlobalState, state bags, props

Aucun.

## Boucles client

Aucune permanente. Chargement d'animation borné (`client/effects.lua:119-132`, 10 ms, au plus 1 s).

## NUI et fichiers web

Pas de page propre : deux icônes SVG (`web/icons/*.svg`, 1 401 o) passées au HUD. Jauges mises à jour au changement.

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

Aucun.

## Points solides

- Le module le plus léger : un champ par minute au seul joueur, aucune boucle client, aucune police ni texture.

VERDICT : OK
