# Audit réseau et performance — vava_chancellerie 1.3.1 (et `chancellerie/`) — 30 octobre 2026 (T-011)

## Périmètre

Pont HTTP entre FXServer et le panneau web de la Chancellerie (Node, `chancellerie/`). Lus : `server/link.lua`
(`:20-30`), `server/push.lua`, `server/http.lua`, `fxmanifest.lua` ; dans `chancellerie/` : la taille de `web/`.

## Envois serveur → client

| Évènement | Fichier:ligne | Cible | Taille estimée | Fréquence |
|---|---|---|---|---|
| `ADMIN_NOTIFY` | `server/link.lua:27` | le joueur qui lie son compte | 80 o | à la liaison |

Les échanges avec le panneau passent par HTTP entre FXServer et le processus Node de la même machine
(`server/http.lua`, `server/push.lua`) : rien ne part vers les joueurs.

## GlobalState, state bags, boucles client, props

Aucun : la ressource n'a pas de script client.

## Fichiers web

`chancellerie/web/` (582 564 o, dont 243 457 o de polices et textures communes) est servi par le panneau Node aux
seuls membres du staff qui l'ouvrent dans un navigateur : **pas téléchargé par les joueurs**. Il garde ses propres
copies ; T-012 peut les laisser (le panneau n'a pas accès à `nui://`).

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

Aucun.

VERDICT : OK
