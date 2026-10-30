# vava_farming — l'agriculture du royaume

Des **parcelles** communales ou privées faites d'emplacements où l'on sème, arrose, fertilise, récolte et arrache. La
croissance se calcule sur les dates : l'humidité baisse, la plante pousse tant que la terre est humide, marque une
pause à sec, flétrit puis meurt si personne ne vient. La **fertilité** paie chaque récolte et se refait par la
rotation, le compost et la jachère. La qualité de la récolte vient de la graine, de la main du cultivateur, de la
régularité de l'arrosage et de la terre ; les graines récupérées gardent ce palier. Le **grenier commun** est un
conteneur de l'inventaire ancré à son lieu, dont chaque dépôt et retrait est journalé. Le serveur décide de tout et
demande l'XP à `vava_skills`.

Ordre de démarrage : après `vAvA_core` (≥ 0.11.0 : abonnements de zone, 1.7.0), `vava_ui` (≥ 1.0.0, polices, grain, papier et coins des
interfaces ; à ne jamais arrêter sur un serveur ouvert), `vava_inventory` (≥ 1.4.0), `vava_skills` (≥ 1.0.0),
`vava_gathering` (≥ 1.0.0 : faucille) et `vava_crafting` (≥ 1.1.0 : composteur). Facultatifs : `vava_hud`,
`vava_admin` (droit `metiers`), `vava_chat`, `vava_health` (aucun geste à terre), `vava_time` (saisons : vitesse de
pousse et de dessèchement, lues par l'export `getSeason` ; nuits de gel, reçues par ses hooks `vava_time:frostWarning`
et `vava_time:frost`).

Rendu hors jeu : `web/index.html?view=prompt` ou `?view=menu&state=growing` (paramètres en tête de
`web/dev/devmock.js`, jamais livré) dans un navigateur, depuis le dépôt (option `--allow-file-access-from-files` pour
les polices).

## Règles (config.lua)

| Règle | Défaut | Clé |
|---|---|---|
| Croissance | pousse si humidité > 20 ; à sec : pause, flétrie après 6 h, morte après 18 h ; arroser une flétrie la fait repartir | `growth` |
| Saisons (`vava_time`, facultatif) | pousse × 1,25 au printemps, × 1 l'été, × 0,75 l'automne, × 0,25 l'hiver ; la terre sèche × 1 au printemps, × 1,5 l'été (arroser plus souvent), × 0,75 l'automne, × 0,25 l'hiver : l'hiver, une culture met quatre fois plus longtemps, mais un arrosage tient quatre fois plus. Une valeur invalide ou infinie compte pour 1, au-delà de 10 pour 10. Sans `vava_time` : aucun effet ; pendant son démarrage (saison pas encore connue), rien ne pousse ni ne sèche, le temps est compté ensuite à la bonne saison ; à chaque changement de saison, les emplacements plantés sont réécrits (1.4.1) | `seasons` |
| Gel (`vava_time`, facultatif ; décidé le 30 octobre 2026) | en hiver, chaque nuit gèle avec 40 % de chances (probabilité dans `vava_time`). Dès que la nuit est tirée (au premier passage du jour), le monde l'annonce : « La nuit sera froide. » dans `/date` (`vava_time`) et « gel annoncé cette nuit » sur la fiche d'une plante vivante (menu de l'emplacement, marqué si la plante y est exposée), pour tous, même arrivés après 17 h ; plus rien une fois le gel tombé. Au soir (17 h du royaume), avertissement au propriétaire en jeu d'une parcelle privée où une plante est exposée et aux joueurs à moins de 60 m d'une parcelle commune exposée, à personne d'autre ; à la tombée de la nuit (21 h), toute plante vivante ni couverte ni résistante au froid meurt (la plante est morte : seul Arracher reste) et les mêmes sont prévenus. Résiste au froid : le chou seul | `frost`, `crops[].frostHardy`, `messages.frostTonight` |
| Couvrir (`vava_time`) | geste de 3 s, en **automne** (pour se préparer) et en **hiver** seulement : hors saison, ou sans `vava_time`, le menu ne le propose pas et le serveur le refuse au début comme à la fin du geste (« Aucun gel à craindre en cette saison. »). Consomme d'abord un paillis de **2 déchets végétaux** (tiges flétries et feuilles mortes), ou, s'il en manque, **1 compost** ; la plante est protégée jusqu'à sa récolte ou son arrachage | `frost.cover`, `frost.coverSeasons`, `actions.cover` |
| Fertilité | 80 au départ ; − coût de la culture par récolte ; même famille − 10, famille différente + 10 ; compost + 25 ; jachère + 10 par jour vide | `fertility`, `crops[].fertilityCost`, `crops[].family` |
| Qualité | graine × 0,35 + compétence × 0,35 + régularité × 0,15 + fertilité × 0,15 ± 5 → paliers 20 / 40 / 60 / 85 ; provenance = nom de la parcelle | `quality` |
| Régularité | 100 − 100 × heures de sécheresse ÷ durée de croissance | — |
| Graines | chance 30 % + 0,5 %/niveau (≤ 90 %), 1 à 2 graines au palier de la récolte | `seeds` |
| Gestes | semer 3 s, arroser 2,5 s, fertiliser 2,5 s, récolter 4,5 s (× 0,6 avec une faucille en main), couvrir 3 s, arracher 3 s ; XP du semis = 25 % de celle de la culture ; finir trop loin abandonne le geste (rien n'est consommé) | `actions`, `quality.plantXpShare` |
| Seau | 5 charges, rempli aux puits ; tenu en main | `bucket`, `wells` |
| Déchets | une plante flétrie ou morte arrachée rend 1 à 2 déchets végétaux (perdus si la besace est pleine : l'arrachage se fait quand même, et le cultivateur en est prévenu) | `compost.waste` |
| Ordre de la récolte (1.5.1) | la plante est prise (récolte) ou arrachée **avant** que quoi que ce soit n'entre dans la besace : de deux cultivateurs qui finissent le même geste sur la même plante, un seul est servi, l'autre lit « Ce geste n'est plus en cours. » ; une récolte refusée par la besace pleine rend la plante (mûre, couverte si elle l'était et si la couverture est payée, fertilité intacte), sauf si quelqu'un a semé entre-temps (journalisé en console) ; ce qu'un autre a fait sur l'emplacement vide pendant l'attente est gardé (compost : la fertilité rendue en tient compte) et un gel tombé entre-temps frappe la plante rendue ; rien n'a bougé : aucune écriture en base pour rien, et la parcelle est republiée aussitôt | — |
| Composteur | type de station + recette (3 déchets → 1 compost, Agriculture) ajoutés à `vava_crafting`, station placée par `addStation` | `composter` |
| Cultures de départ | blé 90 min, carotte 30, chou 45, lin 60 (durées d'essai) | `crops` |
| Props | créés par le client à 80 m ; une parcelle et son grenier forment un groupe, les puits sont groupés par case de 200 m : seules les cibles d'un groupe à portée sont mesurées ; relues toutes les secondes près d'un groupe, toutes les 2,5 s quand aucune cible n'est à moins de 140 m (80 m + 60 m de marge d'approche) (1.5.2) | `streaming` |
| Parcelles connues d'un joueur (1.7.0) | celles dont il est à moins de leur rayon (emplacements et grenier) + 100 m (80 m de portée des props + 20 m de battement : un cavalier au galop entre deux passages du core), décidées par le serveur sur sa position ; oubliées 25 m plus loin (props retirés). À l'arrivée, la parcelle entière (définition, emplacements) ; ensuite, seuls les emplacements qui changent de culture, de stade ou d'état, aux seuls joueurs proches, regroupés par parcelle (une nuit de gel : un envoi par parcelle touchée). Puits : config, connus de tous | `streaming.radius`, `streaming.subscribeSlack` |
| Journal | plantations, récoltes Excellent+, arrachages, couvertures, plantes prises par le gel (une ligne par nuit, par parcelle), Conseil ; grenier (une ligne par minute, personnage, objet et sens) ; 90 jours | `logTier`, `logRetentionDays`, `persistence.granaryLogMax` |

### Parcelles et emplacements

Une parcelle : centre, cap, lignes × colonnes, espacement (positions par `geometry.slotPosition`, les mêmes côté
client et serveur), propriétaire nul (communale) ou `{ kind = 'character', id }` (privée ; un futur module de foyer
déclare son genre par `registerAccess`), grenier facultatif. Chaque emplacement garde : culture, palier de la graine,
date de semis, croissance effective, humidité, fertilité, sécheresse (depuis quand, heures cumulées), arrosages,
flétri, mort, couvert contre le gel, famille précédente, date du dernier calcul. **Aucune boucle de croissance** : tout est recalculé quand
on touche l'emplacement ; la boucle lente de 10 s republie seulement les emplacements dont le stade ou l'état a changé,
pour que les plantes poussent sous les yeux.
Les modèles de `stages` se partagent la croissance à parts égales, sauf le dernier, réservé à la plante mûre : il
n'apparaît qu'à 100 %, quand « mûr » s'affiche et que la récolte est possible (1.2.3). Les heures de sécheresse d'une
plante s'arrêtent à sa mort.

### Ce que reçoivent les joueurs (1.7.0, T-016)

Chaque parcelle est une **zone du core** (`core.zones`, `server/zones.lua`, règles pures dans
`shared/parcelzone.lua`) : centre de la parcelle, rayon qui couvre ses emplacements et son grenier, marge de 100 m.
Le serveur décide seul qui la reçoit, sur la position qu'il lit une fois par seconde ; le client ne demande rien.
- **À l'arrivée** : l'état entier, une fois (`def` : nom, centre, cap, grille, grenier et son modèle ; `s<n°>` :
  culture, stade, état de chaque emplacement ; environ 600 o pour le champ communal).
- **Ensuite** : seuls les emplacements qui changent de culture, de stade ou d'état (environ 40 o chacun), aux seuls
  joueurs proches. Les changements d'une parcelle faits dans le même tour partent ensemble : une nuit de gel, un passage
  de la croissance ou `/agriculture arroser` font un envoi par parcelle touchée. Avant la 1.7.0, la parcelle entière
  (470 o pour le champ communal) partait à tous les joueurs connectés à chaque changement, par un state bag global ;
  l'ancienne clé `vava_farming:parcel:<id>` est effacée au démarrage si elle traîne encore, et plus rien n'est écrit dans
  `GlobalState`. Seules les parcelles encore dans la config sont effacées ainsi : après une mise à jour depuis une
  version antérieure à 1.7.0 qui retire des parcelles, **redémarrer le serveur**, pas seulement la ressource.
- **En s'éloignant** (25 m au-delà) : la parcelle est oubliée, ses props retirés. Retour à la sélection,
  déchargement : de même.
- **Parcelle créée, déplacée ou changée en jeu** (Atelier, T-103) : `zones.share(parcelle, valeurs)` la déclare, ou la
  déplace et remplace son état ; `zones.drop(id)` la retire. Les joueurs proches la reçoivent (ou l'oublient) sans
  reconnexion, les autres en arrivant. **Pas encore branché** : aucune commande ne crée, ne déplace ni ne supprime de
  parcelle aujourd'hui ; T-103 appellera `zones.share` à la création et au déplacement, `zones.drop` à la suppression.
- **Arrivée** : une parcelle reçue (ou changée, ou quittée) fait aussitôt un passage du client, sans attendre sa boucle
  lente ; la marge de 20 m ne couvre donc que l'attente du passage du core (1 s : 15 m au galop).
- **Rien de secret** dans cet état (un client modifié peut mentir sur sa position et le recevoir de loin) : le nom de
  la parcelle et de son grenier y est (public, comme leur lieu), mais ni propriétaire, ni humidité, ni fertilité, ni qualité à venir, ni contenu du grenier ; le menu d'un emplacement les
  demande au serveur (`vava_farming:open`), qui revérifie la distance, comme au début et à la fin de chaque geste, au
  puits et au grenier.

### Grenier commun

Un conteneur conservé de l'inventaire (`kind = 'granary'`) par parcelle qui en déclare un, créé au premier démarrage,
ouvert au joueur qui a accès à la parcelle (communale : tous ; privée : son propriétaire, ou le genre branché par
`registerAccess`) et se tient à portée du grenier, avec un **ancrage** : l'inventaire revérifie la distance à chaque
geste et ferme le grenier chez qui s'éloigne. Les dépôts et retraits (déplacer, diviser, fusionner, jeter) sont
publiés geste par geste par le hook `vava_farming:granary` et journalés dans `vava_farming_granary_log`, **regroupés
par minute** : une ligne par minute, grenier, personnage, objet et sens (`deposit` | `withdraw`), quantités
additionnées, `at` = début de la minute. Ces lignes attendent en mémoire (au plus `persistence.granaryLogMax` ; pleine,
l'attente s'écrit aussitôt, et ce qui n'y tient plus pendant une panne de la base est perdu et signalé) et partent avec
l'écriture groupée et à l'arrêt ; une même minute écrite en plusieurs fois reste une seule ligne. Les lignes écrites
avant la migration 0002 (une par geste, `minute` nul) restent telles quelles. La récolte d'une parcelle communale va
dans la besace du récolteur, qui la dépose au grenier.

## Base de données (sql/0001_farming.sql, 0002_granary_log_minute.sql, 0003_slot_cover.sql)

`vava_farming_slots` (colonne `covered` depuis 0003), `vava_farming_granaries`, `vava_farming_granary_log` (colonne
`minute` et clé unique minute, grenier, personnage, objet, sens depuis 0002), `vava_farming_log`. Écriture groupée
toutes les 10 s et à l'arrêt (les plantes prises par le gel partent avec elle) ; un emplacement qui vient de donner ou
de consommer des objets (semis, récolte, compost, couverture, arrachage) est écrit **aussitôt**,
pour qu'un crash ne le rende pas tel qu'avant (récolte rejouée), une seule écriture à la fois par emplacement.

## API

Exports : `getParcel(id)`, `getParcels()`, `getSlot(parcelle, n)`, `getCrop(id)`, `granaryOf(parcelle)`,
`registerAccess(kind, fn(ownerId, characterId))`, `getSession(joueur)`. Registre `vava_farming:crops` (cultures,
extensible). Hooks : `vava_farming:acting` (before, annulable : `{ source, characterId, parcel, slot, action, crop }`),
`harvested` (after : `+ item, quantity, quality, tier, seeds`), `granary` (after : `{ parcel, action = deposit |
withdraw, source, characterId, item, quantity }`). Détail : `docs/api.md`.

## Conseil (droit `metiers`)

`/agriculture parcelles` · `/agriculture parcelle <id>` · `/agriculture fertilite <id> <n> <0-100>` ·
`/agriculture pousser <id> <n>` (mûrit et arrose la terre) · `/agriculture arroser <id>`.

## Tests en jeu

1. **Semis** : graines de blé (deux paliers) → l'emplacement libre du champ communal propose Planter, le palier se
   choisit ; la graine du palier choisi est consommée ; XP d'Agriculture.
2. **Pousse** : la plante avance de stade sans qu'on y touche (stades relus toutes les 10 s), le modèle mûr
   n'apparaissant qu'à 100 % ; `/agriculture pousser champ_communal 1` mûrit d'un coup, terre arrosée (la plante
   ne reflétrit pas dans la foulée).
3. **Arrosage** : seau en main vide → « remplissez-le » ; au puits, `E` remplit (5 charges) ; arroser remet l'humidité
   à 100 et consomme une charge.
4. **Sécheresse** : laisser une plante à sec (ou abaisser `wiltAfterHours`) → flétrie (prop), arroser la fait repartir ;
   plus longtemps → morte, seul Arracher reste (déchets végétaux).
5. **Récolte** : à la main puis avec la faucille (plus rapide) ; produit au palier avec « Champ communal » en
   provenance ; parfois des graines du même palier ; fertilité en baisse ; replanter la même famille coûte plus, une
   autre rend un peu.
6. **Compost** : 3 déchets au composteur du champ (station de l'artisanat ajoutée par ce module) → compost ;
   Fertiliser + 25.
7. **Grenier** : `E` près du grenier → l'inventaire s'ouvre sur le conteneur ; déposer, s'éloigner → il se ferme ;
   `vava_farming_granary_log` garde dépôts et retraits, une ligne par minute, personnage, objet et sens.
8. **Privé** : le jardin de la config appartient au personnage n° 1 ; un autre lit « ne vous appartient pas » (sur ses
   emplacements comme sur son grenier s'il en déclare un).
9. **Redémarrage** : `restart vava_farming` → emplacements retrouvés, croissance rattrapée d'après les dates.
10. **À terre** (`vava_health`) : près d'un emplacement, d'un puits ou d'un grenier, se faire mettre à terre →
    l'invite disparaît, `E` ne sert qu'à rendre l'âme. Tombé pendant un geste : rien n'est appliqué (« Vous êtes à
    terre. »).
11. **Saisons** (`vava_time`) : voir `docs/tests/temps.md` (section des métiers) — en hiver, une culture met quatre fois
    plus longtemps et un arrosage tient quatre fois plus ; l'été, la terre sèche une fois et demie plus vite ;
    `stop vava_time` → plus aucun effet.
12. **Couvrir et gel** (`vava_time`) : voir `docs/tests/metiers.md` (agriculture, gel) — Couvrir consomme 2 déchets
    végétaux (ou 1 compost s'il en manque) et marque la plante « couverte contre le gel » ; absent du menu et refusé au
    printemps et en été ; refusé à terre, trop loin, sans rien pour couvrir, sur un chou ou sur une plante déjà
    couverte ; « gel annoncé cette nuit » sur la fiche dès que la nuit est tirée ; une nuit de gel avertit au soir les
    seuls cultivateurs concernés et tue à 21 h les plantes exposées.
13. **Ordre de la récolte** (1.5.1, à deux) : deux cultivateurs qui récoltent ou arrachent la même plante → un seul est
    servi ; besace pleine à la fin d'une récolte → la plante reste, mûre et couverte si elle l'était. Détail :
    `docs/tests/metiers.md` (agriculture, tests 14 à 17).
14. **Props à distance** (1.5.2) : plantes, puits et grenier apparaissent à 80 m et disparaissent au-delà, comme avant ;
    `resmon` loin de tout puis au champ : `vava_farming` plus bas loin de tout. Détail : `docs/tests/metiers.md` § 6.
15. **Parcelles reçues par les seuls joueurs proches** (1.7.0, à deux) : un joueur au champ, l'autre à plus de 500 m ;
    semer, arroser, récolter → `/vava_reseau joueur <n°>` du joueur loin : aucun envoi de `vava_farming` ; celui du
    champ : `vAvA:zone:diff` d'environ 40 o par geste visible. Le joueur loin revient : les plantes sont là, au bon
    stade, dès 80 m. Détail et mesure `profiler record` : `docs/tests/metiers.md` § 5.2.

## À vérifier en jeu (1.7.0)

- Les plantes apparaissent à 80 m comme avant, à pied comme au galop (jamais à 45-50 m : une parcelle reçue fait
  aussitôt un passage du client), et à l'arrivée par téléportation (au plus une seconde de plus : le passage du core).
- Après `restart vava_farming` près du champ : les plantes reviennent une seule fois, au bon stade.
- Une nuit de gel près du champ : les plantes mortes changent de prop ensemble ; `/vava_reseau` : un seul
  `vAvA:zone:diff` par parcelle touchée.
- `profiler record` : coût du passage des zones du core avec les parcelles (attendu négligeable : deux zones).
