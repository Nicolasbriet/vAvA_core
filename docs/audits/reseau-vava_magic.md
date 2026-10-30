# Audit réseau et performance — vava_magic 2.6.3 — 30 octobre 2026 (T-011)

## Périmètre

Onze sorts, incantation, projectiles, zones au sol, états élémentaires, effets vus des autres (state bags du ped),
sigils et registres du Murmure, roue et HUD de mana. Le module n'a jamais été joué en charge (README). Lus en
entier : `server/world.lua`, `server/zones.lua` (`:60-260`), `server/mana.lua` (`:30-50`), `server/states.lua`
(`:60-95`), `server/registers.lua` (`:125-168`), `server/spells/murmure.lua` (`:85-135`), `client/ambient.lua`,
`client/controls.lua` (`:120-305`), `client/targeting.lua` (`:60-140`), `config.lua` (effets, zones, ambiance,
registres) ; relevés par recherche : chaque `TriggerClientEvent`, `world.broadcast`, `world.setState`, boucle et
création d'objet du module.

## Envois serveur → client

| Évènement | Fichier:ligne | Cible | Taille estimée | Fréquence |
|---|---|---|---|---|
| `PROJECTILE` (lancer) | `server/projectiles.lua:270-274` ; raté `:256` | joueurs à moins de `broadcastRadius` (150 m) du lanceur, positions serveur (`server/world.lua:61-74`, `:108-112`) | environ 150 o | un par projectile |
| `PROJECTILE_END` (impact) | `server/projectiles.lua:191` | joueurs à moins de 150 m de l'impact | 60 o | un par projectile |
| `BURST` (nova, vague, rempart, secousse, combinaisons) | `server/spells/nova_ardente.lua:41`, `vague.lua:54`, `rempart.lua:136`, `secousse.lua:63`, `server/combos.lua:67` | joueurs à moins de 120-150 m | 100-150 o | un par sort |
| `ZONE` (zone au sol) | `server/zones.lua:199-204` | chaque joueur qui passe à moins de `syncRadius` (150 m), une fois, y compris ceux qui arrivent après coup (vérification toutes les 500 ms tant qu'une zone existe, `:207-243`) | 150 o | une par zone et par joueur proche |
| `ZONE_END` | `server/zones.lua:253` | les joueurs qui l'ont reçue | 10 o | fin de zone |
| `HIT`, `PUSH`, `TARGETED` | `server/combat.lua:76`, `spells/nova_ardente.lua:52`, `spells/vague.lua:69`, `server/projectiles.lua:94` (au plus une fois par 3 s et par couple, `config.lua:861`) | la victime ou la cible | 10-40 o | par coup |
| `DAMAGE` (sans vava_health) | `bridge/server.lua:281` | la victime | 10 o | par coup, repli seulement |
| `CONDITIONS` (minuteurs des états) | `server/states.lua:88` | le joueur touché | 30 o par état | à chaque état posé ou levé |
| `MANA` | `server/mana.lua:46` | le mage | 30 o | au changement seulement ; la page anime la remontée (aucun envoi périodique) |
| `SHEET` (vue de la fiche) | `server/sheets.lua:258-261` | le mage | fiche entière : environ 30 o par sort connu + combinaisons, 0,3 à 0,6 Ko | à chaque gain d'XP signalé, changement de sort choisi |
| `FRAGMENTS` (Murmure) | `server/spells/murmure.lua:99-121` | joueurs à moins de 3 m, une fois chacun | mots en clair, jusqu'à 300 signes | une par lecteur pendant l'incantation |
| `MURMUR` | `server/spells/murmure.lua:212` | le destinataire | jusqu'à 300 signes | un par murmure |
| `REGISTER` (pages d'un registre) | `server/registers.lua:154-167` | le porteur | **jusqu'à 200 pages** de 300 signes + correspondant (160) : jusqu'à 100 Ko | à chaque ouverture du registre |
| sigils, combinaisons, abandon, grimoire, messages, commandes du Conseil | `server/sigils.lua:121`, `:157`, `:203` ; `combos.lua:64` ; `casting.lua:176` ; `main.lua:133` ; `bridge/server.lua:138` ; `admin.lua:49`, `:227` | les seuls joueurs concernés | < 200 o | à l'action |

Aucun envoi à tous. Un projectile coûte deux messages aux observateurs proches (lancer, impact), plus un message à la
cible ; un sort de zone un message par joueur proche.

## GlobalState et state bags

| Écriture | Fichier:ligne | Taille | Fréquence | Qui en a besoin |
|---|---|---|---|---|
| state bag `casting` du ped (sort et niveau) | `server/casting.lua:226`, retiré `:173`, `:276` | 30 o | début et fin de chaque incantation | joueurs de la zone de culling du mage (réplication d'entité) ; le dessin s'arrête à 15-150 m côté client |
| state bag `conditions` du ped | `server/states.lua:87`, `:229` | 20-40 o | à chaque état posé ou levé | idem |
| state bag `light` du ped (Lueur portée) | `server/spells/lueur.lua:125`, `:177`, `:78` | 60 o | allumage, couleur, extinction | idem |
| state bag `glow` du ped (yeux du Murmure) | `server/spells/murmure.lua:128-134` | 5 o | 5 s par murmure reçu | idem |
| state bag `orb` d'un orbe ancré (objet réseau) | `server/spells/lueur.lua:138-141` | 60 o | à la pose | joueurs proches de l'orbe ; 40 orbes au plus, 1 par mage (`config.lua:770`) |

Aucune écriture dans GlobalState.

## Boucles client

| Boucle | Fichier:ligne | Au repos | En action | Remarque |
|---|---|---|---|---|
| recherche des effets proches | `client/ambient.lua:423-440` | **250 ms, permanente**, chez tous les joueurs (mages ou non) | idem | le dessin par image ne démarre que s'il y a un effet à portée |
| dessin des effets | `client/ambient.lua:429-435` | — | par image tant qu'un effet est à portée | justifié |
| mode magie | `client/controls.lua:272-304` | — | par image tant que le mode est éveillé et actif ; s'endort après 20 s sans viser ni lancer (`config.lua:84`) ; conditions relues toutes les 200 ms | justifié |
| incantation | `client/casting.lua:206-229` | — | par image ou 100 ms selon le sort, pendant l'incantation | justifié |
| roue des sorts | `client/wheel.lua:83-89` | — | par image, roue ouverte | justifié |
| cible verrouillée | `client/targeting.lua:91-118` | — | par image tant qu'une cible est verrouillée ; verrou relâché après `idleMs` | justifié |
| projectiles | `client/projectiles.lua:231-246` | — | par image tant qu'un projectile vole ou qu'un éclair s'efface | justifié |
| zones au sol | `client/zones.lua:153-184` | — | par image si une zone est visible, sinon `SCAN_MS`, tant qu'une zone ou une trace existe (traces : 20 s) | justifié |
| états du joueur local | `client/states.lua:58-78` | — | par image tant qu'un état l'exige (gel, chancellement) | justifié |
| Nova ardente | `client/spells/nova_ardente.lua:64-76` | — | par image pendant l'effet | justifié |
| nuages, vague, libération des lots de particules | `client/clouds.lua:66-78`, `client/spells/vague.lua:66-76`, `client/fx.lua:43-45` | — | lentes, tant qu'il y a quelque chose | |

Les neuf boucles par image du module (huit `Wait(0)` et `client/zones.lua:184`) sont toutes dans un état actif qui se termine : rien à corriger pour T-018 hors de la
recherche permanente de `ambient.lua`.

## Props, effets et streaming

Projectiles : objets locaux supprimés à l'impact (`client/projectiles.lua:118`, `:262`). Rempart et orbes : objets
réseau du serveur, plafonnés, supprimés à la fin (`server/spells/rempart.lua:105`, `lueur.lua:88`). Particules et
lumières plafonnées (`config.lua:96-100` : 24 lumières, 40 particules en boucle, lots libérés après 60 s), niveau de
détail selon la distance (complet à 30 m, rien au-delà de 150 m).

## NUI et fichiers web

Réticule et HUD envoyés au seul changement (`client/controls.lua:129-138`) ; minuteurs animés par la page
(`web/js/hud.js:77`, `conditions.js:62`, `wheel.js:262`) seulement tant qu'il y a quelque chose à animer. `web/` :
431 225 o, le plus lourd du dépôt : 243 457 o communs (T-012), `web/img/runes.png` (38 087 o, texture des runes,
propre au module), `web/css/style.css` (38 897 o), `web/js/devmock.js` (15 610 o, livré). `config.lua` (89 384 o) est
partagé et téléchargé par chaque client : il contient aussi les textes et réglages serveur (à garder en tête si le
poids des scripts compte).

## BLOQUANT

Aucun.

## IMPORTANT

- `server/registers.lua:154-167` — **registre entier envoyé à chaque ouverture, en évènement fiable** — jusqu'à
  200 pages de 300 signes et un correspondant de 160 signes : jusqu'à 100 Ko en un message, renvoyé à chaque
  ouverture du même registre. Correction : n'envoyer que les 20 pages les plus récentes et le nombre total, la page
  demandant les plus anciennes par RPC (curseur sur l'identifiant de page) ; au-delà du seuil de T-013, envoi latent.
  Tâche T-048.

## MINEUR

- `client/ambient.lua:423-440` — **recherche des effets toutes les 250 ms chez tous les joueurs, même sans aucun state
  bag suivi** — à vide, chaque passage alloue deux tables et lit la position du joueur. Ne lancer la boucle que quand
  un gestionnaire de state bag (`:106-110`) reçoit une valeur, l'arrêter quand toutes les listes suivies sont vides.
  Gain : un thread de moins au repos chez chaque joueur.
- `server/sheets.lua:258-261` — **fiche entière renvoyée à chaque gain d'XP** — 0,3 à 0,6 Ko par sort lancé ; envoyer
  le sort, son XP et son niveau, comme le fait `vava_skills` (`server/progression.lua:72`).
- `server/spells/rempart.lua:114-127` — **montée du Rempart en 8 déplacements serveur par bloc** (et autant à la
  descente) : chaque `SetEntityCoords` d'un objet réseau part chez les joueurs de la zone ; un seul state bag « monte
  depuis t » sur chaque bloc et une animation locale coûteraient un message au lieu de 16.
- `client/controls.lua:130` — **`string.format` à chaque image en visant** pour comparer le réticule : comparer les
  champs (couleur, portée) sans construire de chaîne.

## Points solides

- Le module le plus soigné du dépôt côté réseau : tout envoi ciblé par positions **serveur** (`world.broadcast`),
  zones au sol envoyées aux seuls joueurs qui approchent (modèle « abonnement » déjà appliqué), effets vus des autres
  par state bags d'entité (répliqués par proximité), mana sans envoi périodique.
- Toutes les boucles par image sont liées à un état qui se termine ; plafonds de lumières, de particules, de zones
  (60) et d'orbes ; niveaux de détail par distance.

## À vérifier en jeu

- resmon de `vava_magic` au repos chez un non-mage (cible ≤ 0,02 ms), puis pendant un combat de 4 mages (≤ 0,15 ms).
- `/vava_reseau` à 2 joueurs à 200 m l'un de l'autre pendant qu'un mage lance : rien chez l'autre.
- Taille réelle de `REGISTER` sur un registre plein.

VERDICT : À CORRIGER
