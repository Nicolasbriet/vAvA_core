# vava_chancellerie — le pont de la Chancellerie

Le pont entre la Chancellerie (panneau web, programme Node.js à part : `chancellerie/`, guide dans
`docs/chancellerie.md`) et le serveur de jeu. Il reçoit les demandes du panneau et les fait exécuter, au nom du compte
du panneau, par le Registre du Conseil (`vava_admin`), les zones de voix (`vava_voice`), le ciel et l'heure
(`vava_time`) et les caméras (`vava_cameras`) ; il prévient la Chancellerie en direct (signalements, arrivées et
départs, caméras, rangs changés) ; il relie un compte du panneau à son joueur et tient la liste blanche Discord à la
connexion. Serveur seulement : rien n'est envoyé aux joueurs, sauf le résultat de leur liaison (affiché par vava_admin).

Ordre de démarrage : en dernier, après `vava_admin`, `vava_voice`, `vava_cameras`, `vava_time` et `vava_codex` (ordre
complet : `README.md` à la racine du dépôt).

## Installation

1. Placer le dossier dans `resources/[vava]/vava_chancellerie` (avec la Chancellerie : il est installé avec vAvA).
2. `ensure vava_chancellerie` en dernier. Aucune table, aucun réglage à poser à la main : la Chancellerie passe la clé
   du pont et sa propre adresse à FXServer sur la ligne de commande, à chaque lancement (`+set
   vava_chancellerie_token`, `+set vava_chancellerie_url`), jamais dans le `server.cfg`.
3. Serveur lancé sans la Chancellerie (txAdmin, à la main) : le pont reste fermé, la liste blanche n'est pas vérifiée ;
   la console le dit au démarrage (« serveur lancé sans la Chancellerie : le pont reste fermé »).

| Dépendance | Rôle | Sans elle |
| --- | --- | --- |
| `vAvA_core` ≥ 0.5.0 | joueurs, hooks, registre des commandes | obligatoire |
| `vava_admin` ≥ 1.3.0 | demandes du Conseil, droits des rangs, journal, rangs des comptes reliés | obligatoire |
| `vava_voice` ≥ 1.1.0 | zones de voix lues, modifiées et supprimées depuis le web | page Zones de voix vide |
| `vava_cameras` ≥ 1.0.0 | écran des joueurs depuis le web | pas de caméras depuis le web |
| `vava_time` ≥ 1.0.0 | ciel et heure du royaume lus et réglés depuis le web (1.4.0) | page Ciel et heure : « ne sont pas lancés » |

## Règles (config.lua)

| Règle | Défaut | Clé |
| --- | --- | --- |
| Réglages posés au lancement | `vava_chancellerie_token` (clé), `vava_chancellerie_url` (adresse de la Chancellerie) | `convars` |
| Clé minimale | 32 signes ; plus courte, le pont reste fermé | `tokenMin` |
| Évènements vers la Chancellerie | `/api/bridge/event` ; perdus si elle est fermée, signalés une fois par minute au plus | `eventPath`, `pushWarnEveryMs` |
| Corps de requête | 64 Ko au plus | `bodyMax` |
| Caméras | droit `watch` pour regarder ; la vue en grand passe par la demande `watchScreen` du Registre ; une case sans mur ouvert depuis 2 h est inscrite au journal | `cameras` |
| Liaison d'un compte | commande `chancellerie <code>`, 5 essais par minute, messages au joueur | `link` |
| Liste blanche Discord | réponse attendue 8 s à la connexion d'un joueur ; messages quand elle ne répond pas | `whitelist` |
| Journal du Registre | « Zone de voix modifiée », « Zone de voix supprimée », « Mur des caméras ouvert », « Cases du mur regardées » | `messages` |

## Ce que fait le pont

- **Entrée** : l'adresse HTTP du serveur de jeu (`http://127.0.0.1:<port>/vava_chancellerie/…`). Il n'accepte que les
  requêtes venues de la machine elle-même et portant la clé tirée par la Chancellerie à ce lancement (en-tête
  `x-vava-token`) ; corps borné, lu en JSON, chaque demande dans son propre thread, toujours une réponse.
- **Demandes du Conseil** : passées telles quelles au Registre (`webRequest`), qui vérifie le droit du rang, le schéma,
  la cible et son rang, et inscrit l'action à son journal au nom de « Chancellerie : <compte> ».
- **Zones de voix** : lues (droit `view`), modifiées et supprimées (droit `tools`) auprès de vava_voice ; droit vérifié
  et journal tenu par le Registre. Le nom suit la règle de l'éditeur en jeu (40 signes).
- **Ciel et heure** (1.4.0, `server/time.lua`) : demandes `time` (droit `view`), `timeClock` et `timeWeather` (droit
  `tools`) transmises à vava_time (`webState`, `webClock`, `webWeather`), qui revalide chaque valeur ; droit vérifié
  auprès du Registre (`webCan`), décision inscrite à son journal (`webLog`) si elle change quelque chose. Un fichier du
  pont ajoute ses demandes à `routes.requests`.
- **Caméras** : ouvertes auprès de vava_cameras une fois le droit `watch` accordé — la vue en grand par la demande
  « écran du joueur » du Registre (cible vérifiée, au journal), les cases d'un mur sur le seul droit, l'ouverture du mur
  étant inscrite au journal. Le pont ne sait pas quand un mur du navigateur se ferme (onglet fermé, redémarrage) : au
  lieu de refuser une case, il inscrit au journal (« Cases du mur regardées », numéro du joueur) la première case d'un
  compte qui n'a ouvert aucun mur depuis `cameras.tileLogMs` (2 h, durée maximale d'une caméra), puis au plus une ligne
  toutes les 2 h (1.4.1). Une ligne ne compte que si le Registre l'a acceptée : sinon la case suivante réessaie. Aucune
  case n'est donc regardée sans trace au journal. Routes `/cameras/wall`,
  `/cameras/players`, `/camera/start`, `/camera/answer`, `/camera/stop`.
- **Évènements vers la Chancellerie** (requête HTTP locale, avec la clé, sans attendre de réponse) : signalements,
  arrivées et départs des joueurs, offre et fin des caméras du web, arrêt du module des caméras, rang du Conseil donné
  ou retiré (la Chancellerie revérifie alors le droit de chaque compte qui regarde), pont prêt (elle applique alors les
  rangs des comptes reliés et dit si sa liste blanche est active).
- **Liaison d'un compte du panneau** : le joueur tape en jeu (console `F8`) `chancellerie 482913`, avec le code affiché
  par la page Comptes ; le pont envoie à la Chancellerie le code, la license, les identifiants `fivem:` et `discord:`
  et le numéro de compte vAvA du joueur ; elle relie le compte et applique son rang du Conseil en jeu. Le joueur lit le
  résultat (relié, code inconnu, trop d'essais, Chancellerie injoignable).
- **Liste blanche Discord** : à la connexion d'un joueur (hook `core:player:connecting`, avant toute création de
  données), le pont demande à la Chancellerie s'il peut entrer et lui montre sa réponse. Sans réponse en 8 s : refusé si
  la liste blanche était active à la dernière réponse, accepté sinon.

## Sécurité

- Le port du jeu est public (et relayé par Cfx.re) : la machine locale **et** la clé du lancement sont exigées ; la clé
  n'est jamais écrite dans le `server.cfg` et la Chancellerie la masque dans la console.
- Le pont ne décide de rien : chaque demande est revérifiée par le module qui l'exécute (droit du rang, cible, schéma),
  et journalisée par le Registre. Les exports réservés au pont (`vava_admin:web*`, `vava_voice:webUpdateZone`,
  `webDeleteZone`, `vava_cameras:web*`, `vava_time:web*`) refusent toute autre ressource appelante.
- Liaison : 5 essais par minute et par joueur ; un code vaut 5 minutes, une fois ; après 5 codes faux, la license
  attend (règles tenues par la Chancellerie).

## Arborescence

```
vava_chancellerie/
├── fxmanifest.lua · config.lua
├── shared/   constants.lua (modules reliés, hooks)
└── server/   core · auth (machine locale, clé) · push (évènements vers la Chancellerie) · link (liaison d'un compte)
              whitelist (liste blanche) · routes (demandes du panneau) · time (ciel et heure) · http (écoute)
              commands · main
```

## À vérifier en jeu

Avec la Chancellerie lancée (elle démarre FXServer) et un compte du panneau qui a un rang du Conseil :

1. Console du serveur au démarrage : aucun « pont fermé ». Chancellerie : page Joueurs en direct, arrivées et départs.
2. Depuis le web : avertir, soigner, immobiliser un joueur ; le Journal du Conseil l'inscrit au nom de
   « Chancellerie : <compte> » ; un compte Gardien est refusé sur un Souverain pour une action protégée par le rang.
3. Zones de voix : modifier un nom (40 signes accentués acceptés), supprimer ; l'éditeur en jeu suit (voir
   `docs/tests/voix.md`, section 5).
4. Caméras : page Caméras (mur), puis « Regarder l'écran » ; révoquer le rang du compte pendant qu'il regarde : ses
   caméras s'éteignent (« Droit refusé »). Case demandée sans ouvrir le mur : une ligne « Cases du mur regardées »
   (`docs/tests/registre.md`, § 10, test 13).
5. Liaison : page Comptes → « Relier un joueur », puis `chancellerie <code>` en jeu ; le rang s'applique en jeu ;
   un code faux répond « Code inconnu ou expiré ».
6. Liste blanche (si elle est réglée) : un joueur sans le rôle Discord est refusé avec le message de la Chancellerie.
7. FXServer lancé sans la Chancellerie : le pont reste fermé (console), le jeu marche normalement.
8. Ciel et heure : régler l'heure et imposer un ciel depuis la page Ciel et heure ; les joueurs le voient, le Journal
   du Conseil l'inscrit (voir `docs/tests/temps.md`, section 6).
