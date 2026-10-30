# Audit réseau et performance — vava_gathering 1.2.4 — 30 octobre 2026 (T-011)

## Périmètre

Récolte (zones à vitalité, nœuds à charges, pêche), props des nœuds, blips. Lus en entier : `server/zones.lua`,
`server/nodes.lua`, `server/fishing.lua`, `server/main.lua` (boucle lente), `client/props.lua`, `client/interact.lua`,
`client/main.lua`, `client/blips.lua`, `config.lua` (streaming, zones, nœuds), `fxmanifest.lua`.

## Envois serveur → client

| Évènement | Fichier:ligne | Cible | Taille estimée | Fréquence |
|---|---|---|---|---|
| `NOTIFY` | `bridge/server.lua:209` | le joueur | 50-150 o | résultat d'une récolte, refus |
| `BITE` (la touche) | `server/fishing.lua:28` | le pêcheur | 40 o | une par lancer |
| réponse `zones` (panneau) | RPC | le demandeur | 4 zones × 120 o | à l'ouverture du panneau |

## GlobalState et state bags

| Écriture | Fichier:ligne | Taille | Fréquence | Qui en a besoin |
|---|---|---|---|---|
| `GlobalState['vava_gathering:zone:<id>'] = { band, scarred, vitality }` | `server/zones.lua:123-129` | environ 90 o (clé comprise) | à chaque récolte réussie qui fait changer la **vitalité entière** (coût 1,5 à 2,5 : presque chaque récolte) ; puis à chaque point regagné (passage de la boucle lente toutes les 10 s, `server/main.lua:102-109`, `server/zones.lua:205-212`) : environ 18 par heure pour les 4 zones | les joueurs à portée de la zone ; **le client ne lit que `band` et `scarred`** (`client/props.lua:76-79`), jamais `vitality` |
| `GlobalState['vava_gathering:node:<id>'] = charges` | `server/nodes.lua:75-79` | environ 50 o | à chaque charge prise ou rendue, et à chaque charge regagnée | les joueurs à portée du nœud |

Une récolte coûte donc environ 140 o × joueurs connectés. À 64 joueurs et 15 récoltants (une récolte toutes les
5 s chacun) : 3 récoltes/s × 140 o × 64 ≈ 27 Ko/s sortants, dont plus de 90 % chez des joueurs qui n'ont aucun nœud à
portée. Avec les zones créées par l'Atelier (T-102), le nombre de clés GlobalState croît sans borne et chacune est
aussi envoyée à chaque connexion.

## Boucles client

| Boucle | Fichier:ligne | Au repos | En action | Remarque |
|---|---|---|---|---|
| props et nœud le plus proche | `client/props.lua:157-174` | **1 000 ms fixes**, une distance par nœud de la config (12), en jeu seulement | idem | pas d'intervalle adaptatif à la distance |
| déplacement pendant un geste | `client/interact.lua:198-209` | — | 250 ms pendant une récolte | |
| barre de tension (page) | `web/js/view-tension.js:68`, `:107` | — | `requestAnimationFrame` pendant la barre | |
| chargement de modèle | `client/props.lua:119` | — | 50 ms, borné à 5 s | |

## Props et streaming

Props locaux créés à moins de 80 m (`config.lua:75`), modèle épuisé selon la bande, supprimés hors de portée, à la
sélection et à l'arrêt (`client/props.lua:170`, `:230-234`). Blips posés une fois, retirés à la sélection et à l'arrêt.

## NUI et fichiers web

Invite envoyée à la page seulement quand sa signature change (`client/interact.lua:145-148`). `web/` : 277 833 o,
dont 213 553 o communs (T-012) ; `web/js/devmock.js` (3 604 o) livré.

## BLOQUANT

Aucun.

## IMPORTANT

- `server/zones.lua:123-129` et `server/nodes.lua:75-79` — **état local publié dans GlobalState, envoyé à tous à chaque
  récolte** — déjà prévu par T-015 (abonnements de zone). Précisions versées dans T-015 : publier par zone (abonnés de
  la zone seulement, nœuds compris), et **retirer `vitality` de ce qui est publié** (`:124`) : le client n'en a pas
  besoin, et c'est elle qui fait partir une écriture à presque chaque récolte et à chaque point regagné ; seule la
  bande et la cicatrice changent ce que voit le joueur. Gain immédiat, même avant T-014 : environ deux écritures sur
  trois en moins.
- `client/props.lua:157-174` — **boucle à intervalle fixe, coût proportionnel au nombre de nœuds** — 1 000 ms où que
  soit le joueur, et chaque passage mesure tous les nœuds de la config ; l'Atelier en créera des centaines. CLAUDE.md
  demande un intervalle adaptatif à la distance. Correction (T-018) : mesurer d'abord la distance aux zones (centre et
  rayon), ne mesurer les nœuds que d'une zone à portée, et espacer à 2-3 s quand aucune zone n'est à moins de
  `streaming.radius` + rayon.

## MINEUR

Aucun en dehors des fichiers web communs (T-012).

## Points solides

- Écritures GlobalState au seul changement (valeur publiée retenue, `zones.lua:125-127`, `nodes.lua:76`).
- Props locaux, streaming par distance, nettoyage complet ; invite NUI dédoublonnée ; pas de boucle par image.
- Pêche : un seul évènement par lancer, au seul pêcheur.

## À vérifier en jeu

- resmon de `vava_gathering` au repos loin de toute zone puis près d'un nœud.
- `/vava_reseau` (T-013) chez un joueur à l'autre bout de la carte pendant qu'un autre récolte : aujourd'hui 2
  écritures par récolte, 0 attendu après T-015.

VERDICT : À CORRIGER
