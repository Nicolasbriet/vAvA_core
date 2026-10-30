# vava_health — la santé du royaume

La vie des personnages, gardée d'une session à l'autre, et la **mise à terre** à la place de la mort de GTA : un
personnage gravement blessé tombe et reste au sol ; un autre joueur peut le **relever**, sinon il **rend l'âme** et se
réveille au lieu de soins. Personne ne se relève seul : on a besoin des autres. La récupération automatique de GTA est
coupée ; on se soigne par objets (bandes, potions) ou en se faisant relever. Le serveur décide de tout : il lit lui-même
la vie de chaque joueur, met à terre, relève et porte au lieu de soins ; le client applique et affiche.

Ordre de démarrage : après `vAvA_core` (≥ 0.4.0) et `vava_ui` (≥ 1.0.0, polices, grain et ornements de l'écran à
terre ; déclaré en dépendance, à ne jamais arrêter sur un serveur ouvert), avant les modules qui lisent l'état « à
terre ». Facultatifs :
`vava_inventory` (objets de soin, gestes bloqués à terre), `vava_needs` (faim et soif figées à terre), `vava_hud`
(médaillon Santé, notifications). Les modules qui tiennent compte de l'état à terre (récolte, artisanat, agriculture,
magie, voix, Registre) appellent l'export `isDowned` : la règle n'est écrite qu'ici.

## Règles (config.lua)

| Règle | Défaut | Clé |
|---|---|---|
| Vie | de 0 à 1 : part de la vie GTA au-dessus du seuil de mise à terre ; 1 pour un nouveau personnage | `initial` |
| Seuil de mise à terre | vie GTA 100 (seuil « blessé mortellement » du jeu) | `downThreshold` |
| Récupération de GTA | coupée | `naturalRegen` |
| Lecture serveur | vie de chaque joueur apparu toutes les 500 ms ; enregistrée dans le personnage toutes les 10 s si elle a bougé d'au moins 1 % ; 3 s de grâce après une apparition ou une relève | `pollMs`, `sampleMs`, `sampleEpsilon`, `graceMs` |
| À terre | rendre l'âme possible après 3 min ; porté d'office au lieu de soins après 10 min ; un ped resté debout est recouché toutes les 5 s | `downed` |
| Relever | personne à terre la plus proche à 2 m (positions serveur), geste de 8 s, distance revérifiée à la fin (+ 1 m), 25 % de vie ; objet requis et consommé facultatif | `assist` |
| Rendre l'âme | touche maintenue 3 s ; lieu de soins le plus proche, 50 % de vie | `respawn` |
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

La dernière perte de faim ou de soif suit la même règle chez `vava_needs`.

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

Aucune table propre : l'état vit dans le champ de personnage `vava_health:state` (`{ health, downed, downedFor }`,
visible du seul joueur), sauvegardé avec le personnage. Les soins du Conseil sont au journal de `vava_admin`.

## Pour les autres modules

```lua
local health = exports.vava_health
if health:isDowned(source) then return false, 'downed' end   -- refuser une action à terre
health:damage(source, 0.2)                                   -- −20 % de la vie actuelle (0 fait tomber)
health:revive(source, 0.5)                                   -- relever sur place
```

Exports complets (`get`, `isDowned`, `setHealth`, `heal`, `damage`, `down`, `revive`), codes et hooks
(`vava_health:downed`, `reviving` annulable, `revived`, `respawned`) : `docs/api.md`, section `vava_health`. Export
client `get()` : `{ health, downed }` du joueur local. Appeler `isDowned` par son bridge, isolé (`pcall`), module absent
= pas à terre.

## Réseau

Le serveur lit la vie lui-même (une native par joueur et par demi-seconde) : le client n'envoie rien. Vers le seul
joueur concerné : son champ (à chaque transition, et toutes les 10 s si la vie bouge ou à terre), l'ordre de le
coucher, de le relever ou de le porter au lieu de soins, le geste de la relève. Deux RPC sans argument, à débit limité
(relever, rendre l'âme). Client : une lecture de la vie toutes les 500 ms pour le médaillon (envoyé à `vava_hud`
seulement s'il change), aucune boucle par image.

## Conseil

Pas de commande propre : Registre du Conseil → Joueurs → Soins → **Soigner** (droit `heal`) relève à 100 % un joueur à
terre ou rend toute sa vie à un joueur debout (exports `isDowned`, `revive`, `setHealth`), inscrit au journal.

## À vérifier en jeu

La procédure complète est `docs/tests/sante.md`. En priorité :

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
