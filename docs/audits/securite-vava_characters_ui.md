# Audit sécurité — vava_characters_ui 1.0.1 — 29 octobre 2026 (T-010)

## Périmètre

Rôle : l'écran de sélection et l'éditeur de création de personnage (NUI). Ressource **cliente uniquement** : elle
n'enregistre aucun RPC, aucun évènement serveur, aucune table ; chaque action est une intention envoyée au core
(`core:characters:list/select/delete`) ou à `vava_appearance` (`vava_appearance:create`).

Fichiers lus en entier : `fxmanifest.lua`, `config.lua`, `client/{main,core,nui,preview,camera}.lua`,
`web/index.html`, `web/js/{app,bridge,creator,selection,controls,feedback,icons}.js`, `README.md`. Côté core, le
serveur qui tranche réellement : `server/players/characters.lua` (règles de nom, maximum, suppression, RPC),
`config/server.lua` (`characters.*`).

Non lus : `web/js/strings.js`, `web/js/devmock.js`, `web/css/style.css` (textes, simulation hors jeu, style).

Correction T-007 vérifiée : règles de nom tirées du serveur (`client/main.lua:51-55`, `web/js/creator.js:48-75`),
nettoyage à l'arrêt (`client/main.lua:215-224`), scène distincte du point d'apparition (`config.lua:19`).

## Points d'entrée

Aucune entrée réseau propre au module. Les callbacks NUI (locaux au client) et les RPC du core qu'ils déclenchent :

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `list` | NUI → `core:characters:list` | `{}` | core : 5 puis 1/s | session connue ; renvoie la liste du compte, le maximum et les règles de nom (`server/players/characters.lua:563-569`) | |
| `play {id}` | NUI → `core:characters:select` | état `selection` et entier ≥ 1 vérifiés côté client (`client/main.lua:31-33`, `:106-110`) ; serveur : entier 1..2³²−1 | 3 puis 0,2/s | état `joined`, verrou `busy`, personnage **du compte** (`characters.lua:320`), pas déjà chargé (`:323`) | |
| `delete {id}` | NUI → `core:characters:delete` | idem | 2 puis 0,05/s | état `joined`, propriété (`:391`), suppression **douce** `deleted_at` sur `id` + `account_id` (`:395`, `:50`), hook `before` annulable | confirmation dans l'interface (`web/js/app.js:39-52`) ; un personnage chargé ne peut pas être supprimé (état `joined` exigé) |
| `startCreator {sex}`, `setSex {sex}` | NUI (local) | sexe parmi `cfg.models` (`client/main.lua:92`) | — | — | crée le ped d'aperçu **local** (`client/preview.lua:67`, `CreatePed(…, false, false)`) |
| `preview {part, value}`, `applyAll {appearance}`, `textures`, `camera`, `rotate {delta}` | NUI (local) | partie et valeur vérifiées par `vava_appearance.applyPart` (`vava_appearance/client/apply.lua:118-140`), rotation bornée à ±45° par message (`client/main.lua:176`), vue parmi `cfg.cameras` | regroupés par image et une requête en vol par clé (`web/js/bridge.js:33-66`) | — | n'agissent que sur le ped local du joueur |
| `cancelCreator` | NUI (local) | état `creator` | — | — | |
| `create {firstName, lastName, sex, appearance}` | NUI → `vava_appearance:create` | types vérifiés côté client (`client/main.lua:190-194`) ; serveur : voir rapport `vava_appearance` | 2 puis 0,05/s | noms, sexe, maximum par compte, apparence : tout est revalidé par le core et `vava_appearance` | puis `core:characters:select` du personnage créé (`:199`) |
| `core:character:selection`, `core:character:loaded` | hooks client du core | — | — | — | ouverture / fermeture de l'écran |
| `onClientResourceStop` | évènement client | — | — | — | focus rendu, ped et caméra retirés, écran noir (`client/main.lua:215-224`) |

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

- `modules/vava_characters_ui/web/js/controls.js:17` et `:25-27` — seul `innerHTML` des cinq modules audités : il ne
  reçoit que les SVG constants de `web/js/icons.js:7-26`, appelés avec des noms écrits en dur (`creator.js:400`, `:523`,
  `:525-526`, `selection.js:51`, `:58`) ; aucune donnée joueur n'y passe (noms par `text` → `textContent`,
  `selection.js:44-47`, `feedback.js:28-29`). Durcissement pour que l'audit automatique n'ait plus d'exception à
  tolérer : construire les icônes par `document.createElementNS` ou un `<template>` cloné.
- `modules/vava_characters_ui/client/main.lua:155-159` — `textures` transmet `kind`, `id`, `drawable` aux natives après
  un simple contrôle d'entier (`apply.lua:173`) : un `id` hors des emplacements connus n'atteint que le client du
  joueur lui-même. Borner `kind` à `component|prop|hair` et `id` aux listes de `vava_appearance.config` serait plus net.
- `server/players/characters.lua:290-292` et `:395` (core, observation) — le maximum de 3 ne compte pas les personnages
  supprimés (suppression douce) : créer puis supprimer en boucle (limites 2 puis 1/20 s) fait croître `vava_characters`
  d'environ 180 lignes par heure et par compte. Sans effet de jeu ; une purge ou un plafond de suppressions par jour
  règlerait la question.
- Décision encore à prendre, notée sans trancher (`vava_appearance/README.md:67-69`, `docs/plan/rapports/T-007.md`) :
  `core:characters:create` reste ouvert aux clients à côté de `vava_appearance:create` (`characters.lua:570-572`) ;
  un client modifié crée un personnage **sans apparence** (ped par défaut), le maximum et les règles de nom
  s'appliquant toujours.

## Points solides

- Le serveur juge tout : l'interface ne peut appeler que trois RPC du core et celle de `vava_appearance`, chacune avec
  verrou de session, état attendu, propriété du personnage et limites de débit (`characters.lua:202-221`, `:557-591`).
- Règles de nom identiques des deux côtés et jamais recopiées : envoyées par le serveur avec la liste, appliquées à la
  saisie (`creator.js:59-75`) et revérifiées à la création (`characters.lua:111-129`, comptage en caractères UTF-8,
  séparateurs jamais en tête, en fin ni doublés).
- Suppression douce, sur le seul compte propriétaire, avec confirmation explicite et hook `before` annulable.
- Ped d'aperçu local, jamais réseau ; tout ce que la ressource pose est retiré à l'arrêt et au chargement.
- Chaque retour d'interface est isolé par `xpcall` et répond toujours (`client/nui.lua:34-42`) ; les envois d'aperçu
  sont regroupés par image avec une seule requête en vol par réglage.

VERDICT : OK
