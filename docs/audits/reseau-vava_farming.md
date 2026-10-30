# Audit réseau et performance — vava_farming 1.2.3 — 30 octobre 2026 (T-011)

## Périmètre

Parcelles et emplacements, puits, greniers communaux, composteur (station d'artisanat). Lus en entier :
`server/slots.lua`, `client/props.lua`, `client/interact.lua` (boucles), `config.lua` (streaming, parcelles) ; dans
`server/actions.lua` : `settle` (`:340-350`) ; `server/main.lua` (boucle lente) ; `shared/growth.lua` (états).

## Envois serveur → client

| Évènement | Fichier:ligne | Cible | Taille estimée | Fréquence |
|---|---|---|---|---|
| `SLOT` (vue d'un emplacement) | `server/actions.lua:349` | le joueur qui agit | environ 200 o | après chaque geste (semer, arroser, récolter…) |
| `NOTIFY` | `bridge/server.lua:273` | le joueur | 50-150 o | messages |

## GlobalState et state bags

| Écriture | Fichier:ligne | Taille | Fréquence | Qui en a besoin |
|---|---|---|---|---|
| `GlobalState['vava_farming:parcel:<id>'] = { slots = { … } }` | `server/slots.lua:140-155` | **la parcelle entière** : environ 36 o par emplacement + clé, soit 470 o pour le champ communal (12 emplacements) | à chaque geste qui change un emplacement visible (semis, récolte, arrachage), à chaque changement de stade ou d'état d'un seul emplacement, relu toutes les 10 s par la boucle lente (`:158-167`) | les joueurs à portée de la parcelle |

Un seul emplacement qui change renvoie les 12 à tous les joueurs connectés : 470 o × joueurs, contre environ 40 o pour
la seule différence aux seuls joueurs proches. Le champ communal compte 12 emplacements ; les parcelles créées par
l'Atelier (T-103) en auront davantage.

## Boucles client

| Boucle | Fichier:ligne | Au repos | En action | Remarque |
|---|---|---|---|---|
| props, cible la plus proche | `client/props.lua:175-215` | **1 000 ms fixes**, en jeu seulement ; emplacements mesurés seulement si leur parcelle est à portée (`:181-194`) ; puits et greniers toujours mesurés | idem | pas d'intervalle adaptatif |
| déplacement pendant un geste | `client/interact.lua:257-259` | — | 250 ms | |
| animation de remplissage | `client/interact.lua:323-327` | — | une attente de 1,5 s | |

## Props et streaming

Props locaux par emplacement, puits et grenier, à moins de 80 m ; retirés hors de portée, à la sélection et à l'arrêt
(`client/props.lua:211`, `:277-281`). Modèle choisi selon le stade publié.

## NUI et fichiers web

Invite dédoublonnée. `web/` : 286 690 o, dont 213 553 o communs (T-012) ; `web/js/devmock.js` (4 951 o) livré.

## BLOQUANT

Aucun.

## IMPORTANT

- `server/slots.lua:140-155` — **instantané complet de la parcelle dans GlobalState à chaque petit changement** — déjà
  prévu par T-016. Précisions versées dans T-016 : n'envoyer aux abonnés de la parcelle que la différence
  `{ parcelle, n°, crop, stage, state }` de chaque emplacement changé ; l'état complet seulement à l'abonnement.
- `client/props.lua:175-215` — **boucle à intervalle fixe** — 1 000 ms partout ; le pré-filtre par parcelle est bon,
  mais puits et greniers sont mesurés à chaque passage et l'intervalle ne s'allonge pas loin des champs. Correction
  (T-018) : 2-3 s quand aucune parcelle ni aucun puits n'est à moins de `streaming.radius`.

## MINEUR

- `client/props.lua:198`, `:204` — **clés de props construites par concaténation à chaque passage**
  (`'granary:' .. parcel.id`, `'well:' .. well.id`) : chaînes recalculées chaque seconde ; les précalculer comme
  `spotsOf` le fait pour les emplacements.

## Points solides

- Publication au seul changement de signature (`slots.lua:151-153`) ; emplacements mesurés seulement quand leur
  parcelle est à portée ; props locaux nettoyés ; aucun `Wait(0)`.

## À vérifier en jeu

- `/vava_reseau` chez un joueur loin du champ pendant qu'un autre sème : une écriture de 470 o aujourd'hui, rien
  après T-016.
- resmon au repos loin des champs.

VERDICT : À CORRIGER
