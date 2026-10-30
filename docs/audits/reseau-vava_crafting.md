# Audit réseau et performance — vava_crafting 1.2.3 — 30 octobre 2026 (T-011)

## Périmètre

Stations (combustible, occupation, accès), recettes, création et réparation, poinçons et baptême. Lus en entier :
`server/stations.lua`, `client/props.lua`, `client/interact.lua` (boucles), `config.lua` (streaming, stations) ; dans
`server/crafting.lua` : `finishCraft` (`:468`), `fuel` (`:500-524`) ; `server/catalog.lua:203-209` (liste publiée) ;
`bridge/server.lua:255-264` (champ du poinçon).

## Envois serveur → client

| Évènement | Fichier:ligne | Cible | Taille estimée | Fréquence |
|---|---|---|---|---|
| `CRAFTED` (résultat) | `server/crafting.lua:468`, `server/repair.lua:184` | l'artisan | 150-300 o | une par objet créé ou réparé |
| `STATION` (combustible) | `server/crafting.lua:522` | l'artisan | 60 o | à chaque ajout de combustible |
| `NOTIFY` | `bridge/server.lua:317` | le joueur | 50-150 o | messages |
| réponse `open` (menu de la station) | RPC `server/main.lua:62` | le demandeur | recettes de la station avec ingrédients : 1 à 5 Ko | à chaque ouverture |

## GlobalState et state bags

| Écriture | Fichier:ligne | Taille | Fréquence | Qui en a besoin |
|---|---|---|---|---|
| `GlobalState['vava_crafting:station:<id>'] = { fuel, busy }` | `server/stations.lua:75-82` (appelé par `setBusy`, `consumeFuel`, `addFuel`, `:131-172`) | environ 60 o | **deux écritures par création au moins** (occupée puis libre), plus une par unité de combustible consommée ou ajoutée | les joueurs à portée de la station |
| `GlobalState['vava_crafting:stations']` = liste complète (id, type, nom, x, y, z, cap, modèle) | `server/stations.lua:85-87`, `:89-92` | environ 110 o par station (8 aujourd'hui : 0,9 Ko) | au démarrage et à chaque station ajoutée par un autre module (`adopt`, `:65-72`) : la liste entière | tous les clients tant que les stations ne sont pas posées par zone ; avec l'Atelier (T-104), les seuls abonnés de la zone |

## Boucles client

| Boucle | Fichier:ligne | Au repos | En action | Remarque |
|---|---|---|---|---|
| props, station la plus proche | `client/props.lua:153-170` | **1 000 ms fixes**, toutes les stations connues, en jeu seulement | idem | pas d'intervalle adaptatif |
| déplacement pendant un geste | `client/interact.lua:238-240` | — | 250 ms | |
| compte à rebours du baptême (page) | `web/js/view-naming.js:56` | — | 1 s, seulement boîte ouverte | |

## Props et streaming

Props locaux à moins de 80 m (`config.lua:65`), retirés hors de portée, à la sélection et à l'arrêt
(`client/props.lua:166`, `:230-234`).

## NUI et fichiers web

Invite dédoublonnée. `web/` : 307 869 o, dont 213 553 o communs (T-012) ; `web/js/devmock.js` (8 170 o) livré.

## BLOQUANT

Aucun.

## IMPORTANT

- `server/stations.lua:75-87` — **état de chaque station et liste complète dans GlobalState** — déjà prévu par T-017.
  Précisions versées dans T-017 : `busy` bascule deux fois par création et part chez tous les joueurs ; les envoyer
  aux seuls abonnés de la zone de la station ; la liste des stations posées devient la définition de zone de l'Atelier
  (plus de liste globale réécrite en entier à chaque ajout).
- `client/props.lua:153-170` — **boucle à intervalle fixe sur toutes les stations** — même correction que la récolte
  (T-018) : stations regroupées par zone, intervalle allongé loin de toute station.

## MINEUR

- `server/crafting.lua:522` — **combustible envoyé trois fois** à l'artisan : évènement `STATION`, réponse du RPC
  (`:523`) et state bag global (`stations.addFuel` → `publish`). Garder la réponse du RPC seule (ou l'abonnement de
  zone après T-017).
- `bridge/server.lua:263` — **champ du poinçon en visibilité `owner` sans lecteur côté client** — aucun fichier
  `client/` ne lit `vava_crafting:mark` : il part à chaque chargement et à chaque changement pour rien ; `private`
  suffit (le menu le renvoie déjà).

## Points solides

- Publication au seul changement (`stations.lua:78-79`) ; liste publiée seulement quand une station s'ajoute.
- Résultats et refus envoyés au seul artisan ; props locaux, streaming par distance, aucun `Wait(0)`.

## À vérifier en jeu

- `/vava_reseau` chez un joueur loin de la forge pendant une création : deux écritures aujourd'hui, aucune après T-017.

VERDICT : À CORRIGER
