# vava_farming — l'agriculture du royaume

Des **parcelles** communales ou privées faites d'emplacements où l'on sème, arrose, fertilise, récolte et arrache. La
croissance se calcule sur les dates : l'humidité baisse, la plante pousse tant que la terre est humide, marque une
pause à sec, flétrit puis meurt si personne ne vient. La **fertilité** paie chaque récolte et se refait par la
rotation, le compost et la jachère. La qualité de la récolte vient de la graine, de la main du cultivateur, de la
régularité de l'arrosage et de la terre ; les graines récupérées gardent ce palier. Le **grenier commun** est un
conteneur de l'inventaire ancré à son lieu, dont chaque dépôt et retrait est journalé. Le serveur décide de tout et
demande l'XP à `vava_skills`.

Ordre de démarrage : après `vAvA_core` (≥ 0.6.0), `vava_inventory` (≥ 1.4.0), `vava_skills` (≥ 1.0.0),
`vava_gathering` (≥ 1.0.0 : faucille) et `vava_crafting` (≥ 1.1.0 : composteur). Facultatifs : `vava_hud`,
`vava_admin` (droit `metiers`), `vava_chat`.

## Règles (config.lua)

| Règle | Défaut | Clé |
|---|---|---|
| Croissance | pousse si humidité > 20 ; à sec : pause, flétrie après 6 h, morte après 18 h ; arroser une flétrie la fait repartir | `growth` |
| Fertilité | 80 au départ ; − coût de la culture par récolte ; même famille − 10, famille différente + 10 ; compost + 25 ; jachère + 10 par jour vide | `fertility`, `crops[].fertilityCost`, `crops[].family` |
| Qualité | graine × 0,35 + compétence × 0,35 + régularité × 0,15 + fertilité × 0,15 ± 5 → paliers 20 / 40 / 60 / 85 ; provenance = nom de la parcelle | `quality` |
| Régularité | 100 − 100 × heures de sécheresse ÷ durée de croissance | — |
| Graines | chance 30 % + 0,5 %/niveau (≤ 90 %), 1 à 2 graines au palier de la récolte | `seeds` |
| Gestes | semer 3 s, arroser 2,5 s, fertiliser 2,5 s, récolter 4,5 s (× 0,6 avec une faucille en main), arracher 3 s ; XP du semis = 25 % de celle de la culture ; finir trop loin abandonne le geste (rien n'est consommé) | `actions`, `quality.plantXpShare` |
| Seau | 5 charges, rempli aux puits ; tenu en main | `bucket`, `wells` |
| Déchets | une plante flétrie ou morte arrachée rend 1 à 2 déchets végétaux | `compost.waste` |
| Composteur | type de station + recette (3 déchets → 1 compost, Agriculture) ajoutés à `vava_crafting`, station placée par `addStation` | `composter` |
| Cultures de départ | blé 90 min, carotte 30, chou 45, lin 60 (durées d'essai) | `crops` |
| Journal | plantations, récoltes Excellent+, arrachages, Conseil ; grenier (une ligne par minute, personnage, objet et sens) ; 90 jours | `logTier`, `logRetentionDays`, `persistence.granaryLogMax` |

### Parcelles et emplacements

Une parcelle : centre, cap, lignes × colonnes, espacement (positions par `geometry.slotPosition`, les mêmes côté
client et serveur), propriétaire nul (communale) ou `{ kind = 'character', id }` (privée ; un futur module de foyer
déclare son genre par `registerAccess`), grenier facultatif. Chaque emplacement garde : culture, palier de la graine,
date de semis, croissance effective, humidité, fertilité, sécheresse (depuis quand, heures cumulées), arrosages,
flétri, mort, famille précédente, date du dernier calcul. **Aucune boucle de croissance** : tout est recalculé quand
on touche l'emplacement ; la boucle lente de 10 s republie seulement les stades qui ont changé (state bag
`vava_farming:parcel:<id>` : culture, stade, état de chaque emplacement), pour que les plantes poussent sous les yeux.

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

## Base de données (sql/0001_farming.sql, 0002_granary_log_minute.sql)

`vava_farming_slots`, `vava_farming_granaries`, `vava_farming_granary_log` (colonne `minute` et clé unique minute,
grenier, personnage, objet, sens depuis 0002), `vava_farming_log`. Écriture groupée toutes les 10 s et à l'arrêt ; un
emplacement qui vient de donner ou de consommer des objets (semis, récolte, compost, arrachage) est écrit **aussitôt**,
pour qu'un crash ne le rende pas tel qu'avant (récolte rejouée), une seule écriture à la fois par emplacement.

## API

Exports : `getParcel(id)`, `getParcels()`, `getSlot(parcelle, n)`, `getCrop(id)`, `granaryOf(parcelle)`,
`registerAccess(kind, fn(ownerId, characterId))`, `getSession(joueur)`. Registre `vava_farming:crops` (cultures,
extensible). Hooks : `vava_farming:acting` (before, annulable : `{ source, characterId, parcel, slot, action, crop }`),
`harvested` (after : `+ item, quantity, quality, tier, seeds`), `granary` (after : `{ parcel, action = deposit |
withdraw, source, characterId, item, quantity }`). Détail : `docs/api.md`.

## Conseil (droit `metiers`)

`/agriculture parcelles` · `/agriculture parcelle <id>` · `/agriculture fertilite <id> <n> <0-100>` ·
`/agriculture pousser <id> <n>` (mûrit) · `/agriculture arroser <id>`.

## Tests en jeu

1. **Semis** : graines de blé (deux paliers) → l'emplacement libre du champ communal propose Planter, le palier se
   choisit ; la graine du palier choisi est consommée ; XP d'Agriculture.
2. **Pousse** : la plante avance de stade sans qu'on y touche (state bag relu toutes les 10 s) ; `/agriculture
   pousser champ_communal 1` mûrit d'un coup.
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
