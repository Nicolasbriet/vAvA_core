# Abonnements de zone — procédure de test en jeu

Procédure pour vérifier en jeu `core.zones` (core 0.11.0, T-014) : les zones d'un module ne partent qu'aux joueurs
proches, décidés par le serveur à chaque passage (une fois par seconde), puis seulement leurs changements ; sortie avec
une marge (pas d'aller-retour en bordure) ; `/vava_reseau zones` ; et `vava_voice` 1.3.0, premier module à s'en servir
(plus d'envoi à tous pour les zones de voix). Comptez une heure ; les tests à deux joueurs sont marqués
**(2 joueurs)**. Chaque test dit quoi faire et ce qui doit se passer ; si ce n'est pas le cas, notez l'étape, ce que
vous avez vu, et la ligne de console correspondante (serveur, ou `F8` du joueur).

## 0. Préparation

1. Ordre de démarrage habituel ([LISEZMOI.md](LISEZMOI.md) § Préparation commune) : rien ne change.
2. **Comptes** : A est Sénéchal ou Souverain (droit `tools`, pour `/vava_reseau` et `/zonesvoix`) ; B sans rang, sauf
   au test 14 (Souverain).
3. **Consoles** : celle du serveur, et `F8` des deux joueurs. Pour voir les demandes d'instantané côté client
   (« instantané redemandé »), passer `log.clientLevel = 'debug'` dans `config/shared.lua` du core le temps du test 3-1.
4. **Distances** : une zone de voix de rayon 10 m est connue d'un joueur à 50 m de son centre (rayon + 40 m de
   `subscribeMargin`), et oubliée au-delà de 75 m (+ 25 m de `exitMargin`). Mesurer au jugé, ou avec le nombre de pas
   (un pas de course ≈ 1,5 m).

## 1. Démarrage et vue d'ensemble

| # | Faire | Attendu |
|---|---|---|
| 1 | `ensure vAvA_core` (ou démarrage du serveur). | Console : `[zones] passage toutes les 1000 ms, cases de 256 m`, puis `module 'vava_voice' v1.3.0 prêt`. |
| 2 | A : `/vava_reseau zones`. | « Zones : N (vava_voice N) ; 0 ou 1 abonnements ; passage : dernier 0,xx ms, moyen 0,xx ms, au plus 0,xx ms sur la minute. » (N = zones de voix en base ; « Aucune zone déclarée. » s'il n'y en a pas). Sous Windows, « dernier » et « au plus » valent souvent 0,00 ou 1,00 (horloge par pas d'une milliseconde) : c'est « moyen » qui compte. |
| 3 | `F1` (Codex) → chapitre Core → « Compteur réseau ». | Quatrième action « Zones et abonnements », joueur facultatif. |
| 4 | Console du serveur : `vava_reseau zones`, puis `vava_reseau zones <n° de A>`. | Les mêmes lignes, préfixées « Réseau : », en console ; la seconde liste les zones suivies par A ; console : « Zones d'un joueur consultées : joueur … (par 0) ». |

## 2. Zones de voix, envoyées aux seuls joueurs proches

| # | Faire | Attendu |
|---|---|---|
| 1 | **(2 joueurs)** A crée « Tribune » (×2, rayon 10 m) avec `/zonesvoix` ; B est à plus de 500 m. A : `/vava_reseau joueur <B>`, attendre une minute, relancer. | Aucune ligne `vAvA:zone:*` dans le détail de B. |
| 2 | **(2 joueurs)** B marche vers Tribune ; A : `/vava_reseau zones <B>` quand B est à 45 m du centre. | `vava_voice:z<n°>` dans la liste de B ; registre (`F10`) → Journal : « Zones d'un joueur consultées » au nom de A, joueur B. B entre dans Tribune, `W` : cercle de Parler à 10 m (l'effet s'applique en 0,5 s au plus, comme avant). |
| 3 | **(2 joueurs)** B dans Tribune ; A passe Tribune à ×0,5. | Chez B, l'effet change sans reconnexion en 1,5 s au plus ; `/vava_reseau joueur <B>` (suivi lancé au test 1) : `vAvA:zone:diff` sous `vava_voice`, environ 100 o. |
| 4 | **(2 joueurs)** B à 500 m ; A modifie puis supprime une zone près de lui (A). | Rien chez B (`/vava_reseau joueur <B>` : pas de nouvelle ligne `vAvA:zone:*`). |
| 5 | **(2 joueurs)** B dans Tribune ; A supprime Tribune. | L'effet disparaît chez B en 0,5 s au plus ; `/vava_reseau zones <B>` ne la cite plus. |
| 6 | B s'éloigne lentement de Tribune (recréée, rayon 10 m) jusqu'à 70 m, puis revient à 60 m, puis repart à 80 m ; A lance `/vava_reseau zones <B>` à chaque étape. | Toujours suivie à 70 m et à 60 m (sortie seulement au-delà de 75 m) ; plus suivie à 80 m. |
| 7 | B se téléporte loin (outil du Registre, ou « S'y rendre » vers une zone lointaine s'il est du Conseil). | Moins de 2 s après, `/vava_reseau zones <B>` ne cite plus les zones quittées et cite celles d'arrivée. |
| 8 | B retourne à la sélection du personnage, puis rejoue. | Pendant la sélection : « Joueur … : 0 zone(s) suivie(s) ». Une seconde après l'apparition : les zones proches reviennent. |
| 9 | **(2 joueurs)** B dans Tribune ; console : `restart vava_voice`. | Après le redémarrage, l'effet revient chez B (sans reconnexion) dans les 2 s qui suivent `module 'vava_voice' v1.3.0 prêt`. |
| 10 | **(2 joueurs)** B se déconnecte dans Tribune ; A : `/vava_reseau zones`. | Aucune erreur serveur ; un abonnement de moins. |

## 3. Arrivée dans un lieu chargé

| # | Faire | Attendu |
|---|---|---|
| 1 | A crée 30 zones de voix dans un rayon de 100 m, s'en éloigne à 1 km, puis y revient (téléportation). | À l'arrivée, `/vava_reseau joueur <A>` : `vAvA:zone:state` ≈ 30 envois de ~150 o, tous fiables ; aucune ligne « instantané redemandé » en `F8` (niveau debug, § 0-3). Supprimer ensuite ces zones. |
| 2 | **(2 joueurs)** Console : `vava_reseau_essai <B> 256` deux fois de suite, puis aussitôt A crée une zone près de B. | Les deux essais partent (plafond par joueur : 512 Ko) ; la zone arrive chez B normalement (petit instantané fiable, jamais retenu par le latent en route). |
| 3 | **(2 joueurs)** Console : `vava_reseau_essai <B> 256` deux fois ; A crée 30 zones de voix près de B ; aussitôt, B se téléporte loin (ou retourne à la sélection). | Aucune zone fantôme chez B : `/zonesvoix` fermé, `W` au milieu des anciennes zones (si B y revient plus de 75 m plus loin, plus tard) n'applique aucun effet qui ne devrait pas être là ; F8 en debug : aucune erreur. (Un instantané latent doublé par la sortie est ignoré à son arrivée.) |

## 4. Éditeur des zones de voix **(2 joueurs)**

| # | Faire | Attendu |
|---|---|---|
| 1 | B (Souverain) ouvre `/zonesvoix` près d'une zone ; A, à côté, la modifie (nom, rayon). | La zone se met à jour dans la liste et le dessin de B, sans rouvrir. |
| 2 | A modifie une zone à 1 km de B ; B garde l'éditeur ouvert, puis le ferme et le rouvre. | Rien ne change chez B tant que l'éditeur reste ouvert ; à la réouverture, la zone est à jour. |
| 3 | B ouvre une zone lointaine en modification ; A la supprime ; B clique « Sceller ». | « Cette zone n'existe plus. » ; la liste de B se remet à jour d'elle-même (la zone disparaît). |

## 5. Coût

| # | Faire | Attendu |
|---|---|---|
| 1 | `resmon` client au repos. | `vAvA_core` à 0,00 ms (aucune boucle ajoutée) ; `vava_voice` inchangé. |
| 2 | Avec le plus de joueurs possible (32, 64…), en partie immobiles, en partie en mouvement dans une ville : console du serveur `profiler record 300` (300 images), puis `profiler view` ; chercher `vAvA_core` et la durée des fonctions `runPass` / `pass` du fichier `zones.lua`. En parallèle, `/vava_reseau zones` pour l'ordre de grandeur. | Hors jeu (Lua seul, 2 048 zones, 64 joueurs) : 0,03 ms immobiles, 0,2 ms en mouvement sur des zones éparses, 1,7 ms en ville (1,5 × 1,5 km, rayons 2 à 30 m), 6,4 ms en ville très dense ; plus quatre natives par joueur. Noter les valeurs du profiler avec le nombre de joueurs, de zones et le lieu. `os.clock` (la ligne de `/vava_reseau zones`) ne suffit pas pour mesurer : pas d'une milliseconde sous Windows, temps de tout le processus sous Linux. |
| 3 | `./scripts/audit-reseau.sh`. | Aucun BLOQUANT ; plus aucune exception des zones de voix dans `scripts/audit-exceptions.txt`. |

## Réglage du passage

`zones.passMs` (`config/server.lua` du core, 1 000 ms) se règle sans rien changer d'autre : 2 000 ms divise le coût par
deux et reste sûr avec la marge par défaut de 50 m (un cavalier au galop, environ 15 m/s, parcourt 30 m entre deux
passages) ; au-delà, une zone peut arriver après le joueur. Les zones de voix ont 40 m de marge : à 2 s, un galopant
peut entrer dans la zone avant qu'elle n'arrive (l'effet s'applique alors une seconde plus tard). Recommandation :
garder 1 s ; un joueur immobile ne coûte presque rien (il n'est pas recalculé), le coût vient des joueurs qui bougent
dans un lieu chargé de zones.

## À vérifier en jeu (ce qui n'a pas pu l'être hors jeu)

- **`sendPacked`** (décision 4) : une chaîne produite par `msgpack.pack_args` traverse un export intacte (longueur et
  contenu identiques). Essai pour un développeur, dans un module de test (`vava_example`), côté serveur :
  `core.net.sendPacked(nil, source, 'vava_example:essai', msgpack.pack_args('é', 42, { a = true }))` et côté client
  `RegisterNetEvent('vava_example:essai', function(...) print(json.encode({ ... })) end)` : la console `F8` doit écrire
  `["é",42,{"a":true}]`. Si `sendPacked` rend `false, 'unsupported'`, le serveur est en estimation (console
  `[net] estimation …`) : le module renvoie alors par `core.net.send` (repli prévu).
- Les évènements de zone venus du serveur sont acceptés par le client : il ignore ceux déclenchés localement par une
  autre ressource (`GetInvokingResource()` doit valoir `nil` pour un évènement du serveur). Si aucune zone n'arrive
  jamais (test 2-2), c'est la première chose à regarder.
- Position du ped côté serveur juste après l'apparition confirmée (`refreshPlayer`) : bonne, ou encore l'ancienne (les
  zones arrivent alors au passage suivant, 1 s plus tard) — test 2-8.
- Durée réelle d'un passage à 32 et 64 joueurs (test 5-2) ; précision de `os.clock` sur le système du serveur (pas
  d'une milliseconde sous Windows ; temps processeur du serveur entier sous Linux, donc un majorant).
- Ordre fiable entre un `vAvA:zone:state` et les `vAvA:zone:diff` qui suivent : aucune ligne « instantané redemandé »
  en usage normal (test 3-1).
- Cavalier au galop qui entre dans une zone de récolte (T-015) : l'état est-il là avant que les props n'apparaissent
  (marge de 100 m, passage de 1 s) ?
