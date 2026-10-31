# vava_health — la santé du royaume

La vie des personnages, gardée d'une session à l'autre, et la **mise à terre** à la place de la mort de GTA : un
personnage gravement blessé tombe et reste au sol ; un autre joueur peut le **relever**, sinon il **rend l'âme** et se
réveille au lieu de soins. Personne ne se relève seul : on a besoin des autres. La récupération automatique de GTA est
coupée ; on se soigne par objets (bandes, potions) ou en se faisant relever. Le serveur décide de tout : **il tient la
vie de chaque joueur** (le client l'applique, rien de ce qu'il garde à l'écran ne compte), met à terre, relève et porte
au lieu de soins ; le client applique et affiche.

Depuis 1.3.0, `vava_health` porte aussi la **chaîne de dégâts commune** (`docs/plan/COMBAT_V1.md` § 1) : un coup
d'épée, une boule de feu, la faim passent tous par l'export `hit`, ses modificateurs (esquive, parade, blocage,
boucliers, résistances déclarés par les autres modules) et son journal ; les coups natifs de GTA entre joueurs sont
annulés par le serveur. Depuis 1.4.0, un coup **déjà lancé** debout (projectile en vol, présage d'un sort) porte encore
si son auteur tombe à terre avant l'impact, et `vocabulary()` donne l'interrupteur `pvp` aux modules.

Ordre de démarrage : après `vAvA_core` (≥ 0.10.0) et `vava_ui` (≥ 1.0.0, polices, grain et ornements de l'écran à
terre ; déclaré en dépendance, à ne jamais arrêter sur un serveur ouvert), avant les modules qui lisent l'état « à
terre ». Facultatifs :
`vava_inventory` (objets de soin, gestes bloqués à terre), `vava_needs` (faim et soif figées à terre), `vava_hud`
(médaillon Santé, notifications). Les modules qui tiennent compte de l'état à terre (récolte, artisanat, agriculture,
magie, voix, Registre) appellent l'export `isDowned` : la règle n'est écrite qu'ici.

## Règles (config.lua, config_client.lua)

Depuis 1.5.0 (T-132), les réglages sont dans deux fichiers et chacun n'est écrit qu'une fois : `config_client.lua`
porte ce que lit le client (`initial`, `downThreshold`, `naturalRegen`, `downed`, le geste `assist.gesture`, la touche
maintenue `respawn.holdMs`, `client`, `keys`, `labels`, `messages`, `hud`), et le serveur aussi ; `config.lua` porte ce
que lit le seul serveur (relevés, `chain`, `sync`, `spawn`, `natives`, `journal`, le reste de `assist` et de `respawn`,
`healing`, `rateLimits`) et complète la table sans réécrire une clé de `config_client.lua`. Les joueurs ne
téléchargent que les constantes, `config_client.lua`, `shared/vitality.lua`, les `client/*.lua`, l'écran et ses
icônes ; `config.lua` est servi au seul serveur.

**Mise à jour vers 1.5.0 (T-132)** : un `config.lua` modifié et gardé par l'installeur de la Chancellerie (le nouveau
posé en `config.lua.nouveau`) garde l'ancienne forme : le module démarre, mais la console le signale (« config.lua
garde la forme d'avant 1.5.0 … ») et un réglage client changé dans ce fichier reste sans effet. Reportez vos réglages
dans `config.lua` et `config_client.lua` d'après les nouveaux fichiers.

| Règle | Défaut | Clé |
|---|---|---|
| Vie | de 0 à 1 : part de la vie GTA au-dessus du seuil de mise à terre ; 1 pour un nouveau personnage | `initial` |
| Seuil de mise à terre | vie GTA 100 (seuil « blessé mortellement » du jeu) | `downThreshold` |
| Récupération de GTA | coupée | `naturalRegen` |
| Vie du serveur | valeur de référence ; coups, soins et `setHealth` la changent, le client l'applique ; écrite dans le personnage à chaque transition et à chaque soin, au plus toutes les 10 s après des coups (si elle a bougé d'au moins 1 %), au départ et à l'arrêt du module | `sampleMs`, `sampleEpsilon` |
| Lecture du ped | ped de chaque joueur lu toutes les 500 ms ; 3 s de grâce après une apparition ou une relève ; ignoré 1,5 s + 2 × ping (1 s au plus) après chaque ordre de vie ; plus bas que le serveur de plus de 2 % : perte native acceptée ; au seuil : mise à terre ; plus haut : vie du serveur renvoyée après 2 s, puis après un délai doublé à chaque correction sans effet (jusqu'à 30 s, 2 s de nouveau dès l'accord ; console à la 1re puis toutes les 10) | `pollMs`, `graceMs`, `sync` |
| Apparition non confirmée | ped lu d'office 20 s après l'ordre d'apparition, s'il existe | `spawn.confirmTimeoutMs` |
| Chaîne de dégâts | 100 points pour une vie pleine ; un coup de 200 au plus ; onze types, quatre parties du corps, onze étiquettes (listes fermées) ; 20 coups par seconde d'une même source sur une même cible ; un renvoi permis, pas un renvoi de renvoi ; 32 modificateurs ; combats entre joueurs permis (`pvp`) | `chain` |
| Dégâts natifs | coups d'arme ou de poing d'un joueur sur un autre (ou sur une victime introuvable), explosions, feux et projectiles lancés par un joueur : annulés par le serveur ; une ligne de console par joueur et par minute | `natives` |
| Journal des coups | écrit par lots de 50 toutes les 10 s, 2 000 lignes en attente au plus, purgé après 30 jours | `journal` |
| Tir ami | coupé côté client à chaque apparition (confort) | `client.protect` |
| À terre | rendre l'âme possible après 3 min ; porté d'office au lieu de soins après 10 min ; un ped resté debout est recouché toutes les 5 s | `downed` |
| Relever | personne à terre la plus proche à 2 m (positions serveur), geste de 8 s, distance revérifiée à la fin (+ 1 m), 25 % de vie ; objet requis et consommé facultatif | `assist` (`assist.gesture` dans `config_client.lua`) |
| Rendre l'âme | touche maintenue 3 s ; lieu de soins le plus proche, 50 % de vie | `respawn` (`respawn.holdMs` dans `config_client.lua`) |
| Soins par objet | `effects = { health = 20 }` : + 20 % ; refusé à 98 % et plus | `healing.fullAt` |
| Touches | `G` relever, `E` rendre l'âme (réglables dans Paramètres > Raccourcis > FiveM) ; `G` est cité par l'écran de chargement : changer cette touche par défaut oblige à retoucher le conseil de `modules/vava_loading/web/js/strings.js` | `keys`, `labels` |
| Débit | relever : 3 demandes, puis 1 toutes les 2 s ; rendre l'âme : 2, puis 1 toutes les 5 s | `rateLimits` |
| Médaillon | « Santé », ambre à 30 %, rouge à 10 % | `hud` |
| Messages | tous les textes vus par le joueur | `messages` |

Les lieux de soins sont provisoires (deux points de la carte de GTA) : à remplacer quand la carte médiévale arrive.

### Le seuil, sans ambiguïté

La vie GTA 100 est ambiguë : selon le jeu, un ped posé exactement à 100 peut rester debout. Le module ne s'y fie
jamais (`shared/vitality.lua`, testé dans `tests/spec/health_vitality_spec.lua`) :

- au seuil ou dessous, le serveur met à terre, puis ordonne **toujours** au client de coucher son ped (vie GTA 0) ;
- une vie nulle demandée par le serveur (`/vie 0`, sort, `setHealth(0)`) couche le ped à 0, jamais à 100 ;
- à terre, un ped lu au seuil ou au-dessus n'a pas été couché (ordre perdu, client modifié) : il est recouché toutes
  les 5 s, et la console du serveur le note une fois par mise à terre.

La dernière perte de faim ou de soif suit la même règle : elle passe par la chaîne (`privation`) et met à terre dès
que la vie du serveur atteint 0.

### La chaîne de dégâts

Tout ce qui blesse un joueur passe par `exports.vava_health:hit(cible, paquet)`, côté serveur, après les vérifications
du module qui frappe (portée, arme, technique, sort). Dans l'ordre, sans céder la main entre la lecture de la vie et
son écriture :

1. paquet fermé et borné (`shared/packet.lua`) ; le serveur y ajoute la ressource appelante (`origin`, jamais fournie
   par l'appelant), un numéro de coup et le personnage de la source ;
2. garde-fous : type `monde` réservé aux pertes natives de ce module (`invalid_kind`) ; 20 coups par seconde d'une
   même source sur une même cible (`too_many_hits` ; une rafale d'un joueur n'épuise pas le compte des autres) ; un
   coup lancé pendant un autre (renvoi) permis une fois (`too_deep` au-delà) ;
3. préconditions, sans hook ni journal : cible à terre, coup annulé (`downed`) ; `chain.pvp = false` : tout coup venu
   d'un autre joueur annulé (`pvp_off`) ; source à terre, annulé (`source_downed`), sauf un effet qui dure
   (`tags.overTime`), un renvoi (`tags.reflected`), ou un coup **déjà lancé** alors que la source était debout (1.4.0 :
   `tags.launched` et `launchedAt`, l'instant du lancement posé par le module serveur qui frappe ; la source est tombée
   après lui, et il date d'au plus `chain.launchedMaxMs`, 4 s) ;
4. hook `vava_health:hit` `before` : un module peut refuser (trêve, prison, évènement du Conseil) ; un abonné **en
   erreur** ne refuse rien, le coup passe (une ligne de console par minute) ;
5. modificateurs du registre `vava_health:modifiers`, dans l'ordre fixe des étapes **annulation → esquive → parade →
   blocage → bouclier → résistance**, puis la priorité (0 à 99) et la clé ; arrêt à la première annulation ;
6. application : vie du serveur baissée, ordre de vie envoyé à la seule cible en fin de tour (plusieurs coups d'un même
   tour : un seul message), mise à terre **aussitôt** si elle atteint 0 ;
7. hook `after` (tout coup qui a atteint l'étape 4, annulé compris) et journal.

Un modificateur **rend un résultat**, il ne modifie rien : `{ cancel = 'raison' }`, `{ blocked = n }`,
`{ absorbed = n }`, `{ resisted = n }` (retirés, au plus le montant courant) ou `{ added = n }` (faiblesse, au plus le
montant de départ, total au plus 200). Un rendu invalide (négatif, non fini, autre type) est ignoré ; un modificateur
en erreur est **ignoré pour ce coup** (une panne de bouclier ne rend personne invulnérable), une ligne d'erreur par
minute ; un modificateur lent (plus de 5 ms) est signalé, jamais coupé. Règles pures testées :
`tests/spec/health_chain_spec.lua`, `health_packet_spec.lua`, `health_sync_spec.lua` ; harnais serveur :
`health_hit_spec.lua`.

Les pertes que GTA applique lui-même (chute, noyade, feu du décor, animal) sont lues sur le ped et acceptées telles
quelles, **sans modificateurs** (un bouclier arrête les coups et les sorts, pas une chute) ; elles passent par le hook
`after` (`origin = 'vava_health'`, `kind = 'monde'`, `tags.native`). Les coups natifs entre joueurs (poings, armes,
explosions, feux, projectiles lancés par un joueur) sont **annulés par le serveur** avant d'atteindre la victime.

### Un client qui ment

La vie du serveur fait foi pour tout (`hit`, `isDowned`, `get`, soins, mise à terre). Un client qui ignore l'ordre de
vie ou se remet à plein est corrigé après 2 s, puis de plus en plus rarement tant qu'il insiste (4, 8, 16, puis 30 s ;
console à la 1re correction, puis toutes les 10) : il ne gagne rien face aux coups, aux sorts ni à la faim. En
revanche, un ped gardé au maximum **échappe aux pertes natives** (chute, noyade, PNJ du monde), que le serveur ne lit
que sur le ped : les attaques de PNJ hostiles, quand il y en aura, devront passer par `hit`. Celui qui ne confirme pas
son apparition est lu d'office après 20 s. Une mise à terre native nomme l'auteur que déclare le client de la victime
(`GetPedSourceOfDeath`) : il n'est jamais transmis comme `killer`, seulement comme `claimedKiller`
(`killerUnverified`). **Limite connue** : un client modifié peut garder
son ped debout à l'écran alors qu'il est à terre pour le serveur ; rien ne lui est permis (`isDowned` partout), il est
recouché toutes les 5 s ; aucun serveur FiveM ne peut imposer la vie d'un ped joueur.

### À terre

L'écran « wasted » de GTA est remplacé par l'écran « Vous êtes à terre » (page sans focus : la caméra reste libre) :
délai avant de pouvoir rendre l'âme, délai avant d'être porté au lieu de soins, touche à maintenir (celle que le joueur
a choisie dans ses raccourcis), barre quand quelqu'un le relève (son nom n'est jamais montré). À terre :

- aucun geste sur les objets (déplacer, diviser, jeter, utiliser, prendre en main ; un module peut encore faire reposer
  l'objet tenu) ; l'inventaire ouvert à la chute (grenier, coffre, fouille, sac au sol) se ferme aussitôt (export
  `close` de l'inventaire 1.6.4, appel isolé) et se rouvre comme d'habitude une fois relevé ; faim et soif figées ;
- ni récolte, ni artisanat, ni agriculture : ces modules refusent côté serveur et taisent leur invite (`E` ne sert
  plus qu'à rendre l'âme) ;
- aucun sort ne le touche (ni dégâts, ni état, ni recul) ; il ne peut pas incanter ;
- la voix est limitée à Chuchoter et Parler (`vava_voice`).

Se déconnecter ou changer de personnage à terre ne sert à rien : on revient à terre, avec le temps restant (le temps
hors ligne ne compte pas). Un coup mortel reçu juste avant de partir met à terre, si le jeu donne encore la vie au
départ.

## Base de données

L'état vit dans le champ de personnage `vava_health:state` (`{ health, downed, downedFor }`, visible du seul joueur),
sauvegardé avec le personnage. Les soins du Conseil sont au journal de `vava_admin`.

Journal des coups `vava_health_hits` (`sql/0001_hits.sql`) : tout coup **venu d'un autre joueur** qui a atteint la
chaîne (annulé compris) et **toute mise à terre** par la chaîne ou par une perte native, avec le personnage touché et
celui à l'origine, la ressource appelante, le type, la technique ou le sort, l'arme, les points avant et après
modificateurs (bloqués, absorbés, résistés), la raison d'une annulation et la position lue par le serveur. Ne sont
pas inscrits : la faim, la chute et les autres coups sans source qui ne mettent pas à terre, les coups refusés, les
coups sur une cible déjà à terre. Écrit par lots (une requête paramétrée), tout ce qui attend part à l'arrêt du
module ; lignes de plus de 30 jours retirées au démarrage puis chaque jour.

## Pour les autres modules

```lua
local health = exports.vava_health
if health:isDowned(source) then return false, 'downed' end   -- refuser une action à terre
local result, code = health:hit(target, {                     -- un coup (points sur 100), après vos vérifications
    amount = 12, kind = 'tranchant', source = source, technique = 'taille_descendante',
    tags = { melee = true, parryable = true },
})
if result and result.applied > 0 then --[[ réaction, XP, usure ]] end
health:revive(source, 0.5)                                   -- relever sur place
```

`hit` rend `{ id, amount, applied, blocked, absorbed, resisted, added, cancelled?, stage?, downed, health }` ou
`nil, code`. Un modificateur se déclare au registre `vava_health:modifiers` (clé `<ressource>:<nom>`, au plus un par
étape et par module — un second est retiré aussitôt —, qui lit ses propres données), dans le `setup` si le registre existe et de nouveau sur
`core:module:ready` quand `name == 'vava_health'` : exemple complet dans `examples/vava_example_combat`. Contrat : un
modificateur ne cède jamais la main (ni `Wait`, ni base, ni `callClient`) et ne lance pas `hit` lui-même (un renvoi se
fait depuis le hook `after`, avec `tags.reflected`).

`damage(source, part)` reste, **déprécié** pour les coups et les sorts : il passe par la chaîne (`kind = 'pur'`,
`tags.legacy`, sans source) ; la magie appelle `hit` elle-même depuis `vava_magic` 2.9.0 (T-116).

**Coup déjà lancé** (1.4.0) : un module qui lance quelque chose qui frappera plus tard (projectile, présage, flèche) note
`GetGameTimer()` au lancement et l'envoie avec le coup : `tags = { …, launched = true }, launchedAt = instant`. L'un
sans l'autre, ou un instant qui n'est pas un entier positif : `invalid_launch`. Le coup porte même si son auteur est
tombé à terre entre-temps, à condition qu'il soit tombé **après** le lancement (instant de la mise à terre tenu par
`vava_health`) et que le lancement date d'au plus `chain.launchedMaxMs` ; sinon `source_downed`. Un client ne fournit
jamais cet instant. Ce n'est pas `overTime`, réservé aux effets qui durent.

`vocabulary()` donne aussi `pvp` (1.4.0) : un module coupe ses effets sans dégâts entre joueurs (poussées, gel…) quand
`chain.pvp = false`, comme la chaîne coupe les dégâts.

Exports complets (`hit`, `vocabulary`, `modifiers`, `get`, `isDowned`, `setHealth`, `heal`, `damage`, `down`,
`revive`), codes et hooks (`vava_health:hit`, `downed`, `reviving` annulable, `revived`, `respawned`) : `docs/api.md`,
section `vava_health`. Export client `get()` : `{ health, downed }` du joueur local. Appeler `isDowned` par son bridge,
isolé (`pcall`), module absent = pas à terre.

## Réseau

Le serveur lit le ped lui-même (une native par joueur et par demi-seconde) : le client n'envoie rien. Tous les envois
passent par `core.net.send` (comptés dans `/vava_reseau`), vers le **seul** joueur concerné : la vie fixée par le
serveur (`vava_health:set`, ≈ 26 o, une fois par tour au plus, quel que soit le nombre de coups ; une correction au
plus toutes les 2 s, seulement à un client en retard ou modifié), son champ (à chaque transition, aux soins, au plus
toutes les 10 s après des coups, et toutes les 10 s à terre), l'ordre de le coucher, de le relever ou de le porter au
lieu de soins, le geste de la relève. **Rien à l'attaquant ni aux proches** : le résultat d'un coup revient au module
qui l'a lancé. Aucun envoi à tous, aucun GlobalState, aucun state bag. Coût d'un combat à six (un coup reçu par
seconde chacun) : ≈ 160 o/s pour tout le serveur. Deux RPC sans argument, à débit limité (relever, rendre l'âme) ;
aucun RPC ne peut demander un dégât (`hit` est un export serveur). Les règles pures de la chaîne (`shared/packet.lua`,
`shared/chain.lua`, `shared/sync.lua`) sont servies au seul serveur (`server_scripts`) : le client n'en télécharge
rien. Client : une lecture de la vie toutes les 500 ms
pour le médaillon (envoyé à `vava_hud` seulement s'il change), aucune boucle par image.

## Conseil

Pas de commande propre : Registre du Conseil → Joueurs → Soins → **Soigner** (droit `heal`) relève à 100 % un joueur à
terre ou rend toute sa vie à un joueur debout (exports `isDowned`, `revive`, `setHealth`), inscrit au journal.

## À vérifier en jeu

La procédure complète est `docs/tests/sante.md`, et `docs/tests/combat.md` § 1 pour la chaîne de dégâts. En priorité :

- **Chaîne** (`combat` 1-2 à 1-14, avec `vava_example_combat`) : coups appliqués aussitôt, mise à terre sans attendre la
  lecture du ped, modificateurs dans l'ordre, un modificateur en erreur ignoré.
- **`weaponDamageEvent` annulé** (`combat` 1-15, 1-16) : B ne voit ni perte ni réaction de coup ; A peut voir du sang ou
  un tressaillement local (prédiction de son client) : à noter, sans conséquence. Champs `hitGlobalId` /
  `hitGlobalIds` selon la version de FXServer (les deux sont lus).
- **Tir ami coupé** (`NetworkSetFriendlyFireOption(false)`, `SetCanAttackFriendly`) : A ne parvient plus à viser B pour
  un coup de poing (confort ; sans eux, l'annulation serveur suffit).
- **Fenêtre d'application** (1,5 s + 2 × ping) : un soin n'est jamais pris pour une perte, même à 150 ms de ping
  (`combat` 1-7).
- **Client qui ment** : `/tricher` → vie remise en 2 à 3 s, une ligne de console (`combat` 1-21).
- **Coup déjà lancé** (1.4.0, `combat` 1-32 et `magie` 18-12) : un projectile lancé debout porte encore si son auteur
  tombe pendant le vol ; un coup arrivé plus de 4 s après le lancement, non.
- `vava_needs` 1.2.1 avec un `vava_health` plus ancien : repli sur `damage` (facultatif).

1. **Seuil** : `/vie 0` (outil `vava_dev_characters`), la dernière perte de faim ou de soif, un sort qui vide la vie →
   le personnage s'effondre aussitôt et reste au sol sous l'écran à terre (`sante` 2-1, 12).
2. **Réglages de mort de GTA** : ni fondu au noir, ni retour automatique à l'hôpital, voile de mort effacé en 1,5 s.
3. **Relève** : geste du soignant (`amb@medic@standing@tendtodead@base`), distances de 2 m puis 3 m mesurées d'un
   personnage debout à un corps couché ; relève sur place sans décalage (`NetworkResurrectLocalPlayer`).
4. **Touche** : réaffecter « Rendre l'âme » dans les raccourcis FiveM → l'écran à terre montre la nouvelle touche.
5. **Redémarrages** : `restart vava_health` ou `restart vava_hud` à terre → médaillon Santé vide, rouge, de retour dans
   la demi-seconde.
6. **Métiers** : à terre près d'un arbre, d'une station ou d'une parcelle → aucune invite ; `E` ne fait que rendre
   l'âme. Grenier ouvert à la chute → l'inventaire se ferme aussitôt, rien n'est déplacé (`metiers` 5-13).
7. **Rendu de l'écran** : `web/index.html?state=downed` (ou `ready`, `patient`, `holding`, `assist`) dans un
   navigateur, depuis le dépôt (option `--allow-file-access-from-files` pour les polices) : la ligne hors jeu de la
   page charge `modules/vava_ui/web/dev/horsjeu.js` et les données simulées de `web/dev/devmock.js` (jamais livrés).
   En jeu, polices, grain, filet et losange arrivent de `vava_ui` (`docs/tests/interfaces.md`).
