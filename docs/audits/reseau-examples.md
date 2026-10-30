# Audit réseau et performance — ressources d'exemple et de développement — 30 octobre 2026 (T-011)

## Périmètre

`examples/vava_example` 1.1.1, `examples/vava_example_items` 1.1.1, `examples/vava_dev_characters` 1.2.0,
`examples/vava_anim_test` 1.0.1. Lus : les scripts client et serveur de chacune (recherche des envois, boucles,
créations d'objets), leurs `fxmanifest.lua`, la taille de leurs fichiers livrés.

## Envois serveur → client

Aucun `TriggerClientEvent` dans `examples/`. `vava_example` montre `callClientWith` avec `returns` vers un seul joueur
(`server/main.lua:90-99`, commande de console) ; le reste passe par les RPC du core, réponse au seul demandeur.

## GlobalState, state bags

Aucun.

## Boucles client

Aucune permanente. Attentes de chargement bornées dans `vava_anim_test` (`client/main.lua:52-59`, `:168-175`,
10 ms, délai en config) ; un fil par commande dans `vava_dev_characters` et `vava_example`.

## Props

`vava_anim_test` : un accessoire local à la fois, supprimé avant le suivant et à l'arrêt (`client/main.lua:145-148`,
`:193-197`).

## Fichiers livrés

| Ressource | Fichiers | Poids |
|---|---|---|
| `vava_example_items` | `web/items/*.svg` (8 icônes) | 51 017 o, dont `corde.svg` seul 33 576 o |
| `vava_anim_test` | `stream/vava_sword_1h.ycd` | 95 927 o |

## BLOQUANT

Aucun (le danger de ces ressources sur un serveur ouvert est traité par T-024).

## IMPORTANT

Aucun.

## MINEUR

- `examples/vava_example_items/web/items/corde.svg` — **icône de 33,6 Ko** quand les sept autres pèsent 2 à 3 Ko :
  tracé à simplifier (ou WebP de 64 px) ; elle sert de modèle aux futures icônes d'objets.
- `examples/vava_anim_test/stream/` — **96 Ko streamés à chaque joueur** si la ressource est démarrée : à ne démarrer
  que sur le serveur de développement (liste de T-024).

## Points solides

- Les exemples montrent les bonnes pratiques : `returns` borné dans `callClientWith`, attentes bornées, accessoire
  supprimé à l'arrêt.

VERDICT : OK
