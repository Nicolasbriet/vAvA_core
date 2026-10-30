# Audit réseau et performance — vava_inventory 1.6.4 — 30 octobre 2026 (T-011)

## Périmètre

Besaces, conteneurs, sacs au sol, objet tenu en main. Lus en entier : `server/viewers.lua`, `server/hands.lua`,
`server/drops.lua`, `client/hands.lua`, `client/drops.lua`, `config.lua`, `fxmanifest.lua` ; dans
`server/operations.lua` : `notify` (`:71`), `snapshot` (`:344-365`), fermeture (`:425-440`) ; `server/catalog.lua:245`.

## Envois serveur → client

| Évènement | Fichier:ligne | Cible | Taille estimée | Fréquence |
|---|---|---|---|---|
| `SNAPSHOT` | `server/operations.lua:361-364` | le joueur | conteneurs ouverts + raccourcis + **toutes les définitions** des objets présents : 3 à 10 Ko pour une besace garnie | à chaque ouverture de l'inventaire |
| `DELTA` | `server/viewers.lua:194-197` | les seuls joueurs qui regardent ce conteneur | piles changées + définitions encore inconnues : 100 o à 1 Ko | à chaque geste sur un conteneur ouvert |
| `CLOSED` | `server/viewers.lua:55`, `:156` ; `server/operations.lua:438` | spectateurs du conteneur | 10 o | éloignement, sac vidé, fermeture |
| `DISMISS` | `server/operations.lua:432` | le joueur | 5 o | fermeture forcée (mise à terre) |
| `NOTIFY` | `server/operations.lua:71`, `server/catalog.lua:245` | le joueur | 50-150 o | refus, messages |

## GlobalState et state bags

| Écriture | Fichier:ligne | Taille | Fréquence | Qui en a besoin |
|---|---|---|---|---|
| `GlobalState[HELD_MODELS]` (table complète des objets tenables) | `server/hands.lua:96`, `:108` | environ 80 o par objet tenable (aujourd'hui une dizaine : 0,8 Ko) | au démarrage, puis **une écriture complète par objet tenable déclaré ou retiré** | tous les clients (vérification des accessoires) : valeur commune, légitime en GlobalState |
| champ public `vava_inventory:hands` (state bag du joueur, répliqué) | `server/hands.lua:85`, écrit par `:138`, `:145`, `:207` via le core | environ 110 o (`id, item, model, bone, offset[3], rotation[3]`) | à chaque objet pris ou rangé | les seuls joueurs qui voient le porteur ; aujourd'hui **tous les joueurs** le reçoivent |
| `Entity(sac).state[DROP_STATE]` | `server/drops.lua:78` | entier | une fois par sac posé | joueurs dans la zone de culling du sac (réplication d'entité) : correct |

## Boucles client

| Boucle | Fichier:ligne | Au repos | En action | Remarque |
|---|---|---|---|---|
| accessoires en main | `client/hands.lua:155-161` | 1 000 ms **tant qu'au moins un joueur suivi tient quelque chose** | idem | s'arrête d'elle-même |
| attente de l'entité d'un sac | `client/drops.lua:43-50` | — | 100 ms, bornée à 2 s | |
| glisser-déposer (page) | `web/js/drag.js:79` | — | `requestAnimationFrame` pendant un glisser | |

## Props et streaming

Accessoires en main : objets **locaux**, créés au ped du porteur, supprimés à la sortie de portée et à l'arrêt
(`client/hands.lua:81-87`, `:199-202`). Sacs : objet réseau créé par le serveur, plafonds total et par joueur
(`server/drops.lua:64`), supprimé à 10 minutes (`:83-85`).

## NUI et fichiers web

Messages à l'ouverture et à chaque différence ; aucun envoi périodique. `web/` : 278 230 o, dont 156 431 o de
polices et textures communes (T-012) ; `web/js/devmock.js` (9 249 o) est livré aux joueurs par `web/js/*.js`.

## BLOQUANT

Aucun.

## IMPORTANT

- `client/hands.lua:129-139` et `:189-195` — **l'accessoire d'un joueur hors de portée n'est jamais montré quand il
  arrive** — `reconcile` efface la valeur reçue (`wanted[serverId] = nil`, `:137`) quand le porteur n'est pas dans la
  zone de culling du client (`GetPlayerFromServerId` vaut -1), et rien ne la relit quand il y entre : un joueur qui a
  pris sa hache à 1 km arrive sans hache visible tant qu'il ne change pas d'objet ; même chose au démarrage pour les
  joueurs hors de portée (`:189-195` ne parcourt que `GetActivePlayers`). Correction : garder la valeur des joueurs
  hors de portée (ne l'effacer qu'à `nil` ou au départ du joueur) et laisser la boucle lente l'attacher quand le ped
  apparaît, ou porter l'accessoire par un state bag du ped (voir le point suivant). À vérifier en jeu (deux joueurs à
  plus de 500 m).
- `server/hands.lua:75-79`, `:85` — **champ public répliqué à tous les joueurs, avec des valeurs que le client
  recalcule** — chaque prise d'objet part chez tous les joueurs connectés (environ 110 o × joueurs), alors que seuls
  ceux qui voient le porteur en ont besoin, et `model`, `bone`, `offset`, `rotation` sont déjà connus de chaque client
  par `GlobalState[HELD_MODELS]` (le client exige d'ailleurs qu'ils soient identiques, `client/hands.lua:70-79`).
  Correction : ne publier que `{ id, item }` (environ 30 o) et lire le placement dans la liste déclarée ; puis, au choix
  de l'architecte, passer par un state bag du ped (répliqué aux seuls joueurs de la zone de culling, et relu par FiveM
  à l'apparition du ped chez chacun, ce qui règle aussi le point précédent ; à réécrire par le serveur à chaque
  apparition).

## MINEUR

- `server/hands.lua:92-97` — **table des objets tenables réécrite en entier pour chaque objet déclaré** — au
  redémarrage d'un module qui déclare N objets tenables, N écritures complètes partent chez tous les joueurs (somme de
  1 à N fois 80 o ; 40 objets : environ 65 Ko par joueur). Regrouper les déclarations d'un même tick en une écriture
  (`SetTimeout(0)`).
- `server/operations.lua:363` et `server/viewers.lua:167-169` — **définitions renvoyées à chaque ouverture** —
  `definitionsFor(src, instances, true)` oublie ce que le client connaît déjà : chaque ouverture renvoie toutes les
  définitions des objets présents (30 objets : environ 4,5 Ko). Les garder connues tant que la page ne s'est pas
  rechargée (le client demanderait la remise à zéro quand sa page vient de se recharger).
- `web/js/devmock.js` livré aux joueurs (voir T-012).

## Points solides

- Modèle de référence du dépôt pour les conteneurs : abonnement par ouverture, différences seulement, définitions
  envoyées une fois par session, ancrage à un lieu avec balayage serveur lent qui ne tourne que tant qu'un conteneur
  ancré est ouvert (`server/viewers.lua:37-70`).
- Accessoires locaux, jamais réseau, vérifiés contre la liste du serveur ; boucle lente qui s'éteint seule.
- Sacs plafonnés et supprimés à expiration.

## À vérifier en jeu

- Joueur A prend un outil à plus de 500 m de B, puis rejoint B : B doit voir l'outil (échoue aujourd'hui selon la
  lecture du code).
- `/vava_reseau` (T-013) pendant qu'un joueur change d'objet en main : nombre de destinataires.

VERDICT : À CORRIGER
