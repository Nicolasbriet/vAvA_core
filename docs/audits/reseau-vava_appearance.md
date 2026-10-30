# Audit réseau et performance — vava_appearance 1.0.1 — 30 octobre 2026 (T-011)

## Périmètre

Apparence du personnage (modèle, visage, vêtements) rangée dans un champ et appliquée au ped. Lus en entier :
`server/main.lua`, `client/main.lua`, `client/apply.lua` (recherche des boucles), `fxmanifest.lua`.

## Envois serveur → client

| Envoi | Fichier:ligne | Cible | Taille estimée | Fréquence |
|---|---|---|---|---|
| champ `vava_appearance` (`owner`) | `server/main.lua:39` | le joueur | 0,5 à 1,5 Ko (composants, traits) | au chargement et à chaque changement d'apparence |

Les autres joueurs voient l'apparence par la synchronisation du ped de OneSync : rien n'est envoyé par le module.

## GlobalState, state bags, props, NUI

Aucun. Pas de page NUI (l'éditeur est dans `vava_characters_ui`).

## Boucles client

Aucune : l'apparence est appliquée au hook `core:character:fieldChanged` et à l'apparition (`client/main.lua:20-36`).

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

Aucun.

VERDICT : OK
