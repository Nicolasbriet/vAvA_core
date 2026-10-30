# Audit réseau et performance — vava_hud 1.3.0 — 30 octobre 2026 (T-011)

## Périmètre

Jauges, notifications, barre de progression, retrait de l'interface native de GTA. Lus en entier :
`client/main.lua`, `client/native.lua`, `client/gauges.lua` (`:95-140`), `config.lua`.

## Envois serveur → client

Aucun : le HUD n'a pas de partie serveur ; les modules l'appellent par exports côté client.

## GlobalState, state bags, props

Aucun.

## Boucles client

| Boucle | Fichier:ligne | Au repos | En action | Remarque |
|---|---|---|---|---|
| visibilité et interface native | `client/main.lua:90-95` | **250 ms, permanente** : 3 natives d'état + 2 bascules (`native.lua:17-20`) | idem | message à la page seulement au changement |
| fin de progression | `client/progress.lua:110` | — | un `SetTimeout` par barre | |

## NUI et fichiers web

Jauges envoyées à la page seulement quand leur valeur change (`client/gauges.lua:101-103`, `:118-120`) ; les
modules arrondissent avant d'appeler (santé au centième, `vava_health/client/main.lua:56-61`). `web/` : 185 128 o,
dont 156 431 o communs (T-012) ; `web/js/devmock.js` (2 693 o) livré. La page est chargée chez tous les joueurs en
permanence (HUD toujours visible) : c'est elle qui profitera le plus de polices déjà en cache après T-012.

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

- `client/main.lua:90-95` — **boucle de visibilité en double avec celle du chat** (`vava_chat/client/visibility.lua:37-42`,
  300 ms) : un hook client « HUD visible » publié par le HUD au changement éviterait la seconde. 250 ms reste
  raisonnable ; à mesurer à la porte T-019.

## Points solides

- Aucun envoi réseau ; aucune boucle par image ; page prévenue au seul changement ; jauges et progressions purgées à
  l'arrêt de la ressource qui les a posées.

## À vérifier en jeu

- resmon de `vava_hud` au repos (cible ≤ 0,02 ms).

VERDICT : OK
