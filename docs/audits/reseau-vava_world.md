# Audit réseau et performance — vava_world 1.1.0 — 30 octobre 2026 (T-011)

## Périmètre

Population de la carte et sons de la ville moderne coupés. Lus en entier : `server/population.lua`,
`client/population.lua`, `client/audio.lua`, `client/main.lua`, `config.lua`, `fxmanifest.lua`.

## Envois, GlobalState, state bags, props, NUI

Aucun envoi serveur → client : la population est coupée par instance côté serveur
(`SetRoutingBucketPopulationEnabled`, `server/population.lua:23-25`), avec un nettoyage unique au démarrage
(`:36-52`). Aucune page NUI, aucun fichier web.

## Boucles client

Aucune : les réglages sont des bascules persistantes, posées au démarrage et à chaque apparition
(`client/population.lua:28-47`, `client/audio.lua:21-30`), jamais à chaque image.

## Effet sur le réseau du serveur

Positif : sans PNJ ni véhicules ambiants, OneSync ne synchronise que les entités des joueurs et des scripts. C'est le
plus gros gain de bande passante du dépôt, déjà acquis.

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

Aucun.

## Points solides

- Décision côté serveur par instance, filet de sécurité client sans aucune boucle par image (les natives `…ThisFrame`
  ne sont pas employées).

VERDICT : OK
