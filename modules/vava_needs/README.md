# vava_needs — la faim et la soif

Deux besoins, de 0 (épuisé) à 100 (satisfait), qui baissent avec le temps de jeu et plus vite à la course. Un besoin
bas se fait sentir (messages, endurance réduite), un besoin épuisé blesse. On mange et on boit ce que l'on a récolté,
cuisiné ou troqué : aucune nourriture ne tombe du ciel. Le serveur décide de tout : il fait baisser les besoins, lit
lui-même l'activité, applique les effets des objets ; le client affiche et joue les gestes.

Ordre de démarrage : après `vAvA_core` (≥ 0.3.0). Facultatifs : `vava_inventory` ≥ 1.1.0 (manger et boire),
`vava_hud` (médaillons Faim et Soif, notifications), `vava_health` (à terre : besoins figés, et un besoin épuisé fait
tomber au lieu de s'arrêter au plancher ; la perte de vie est alors appliquée par le serveur).

## Règles (config.lua)

| Règle | Défaut | Clé |
|---|---|---|
| Besoins | Faim (100 → 0 en 4 h de jeu au repos, −2 points de vie à 0), Soif (en 3 h, −4 à 0) ; ajouter une entrée suffit (fiche d'objet, médaillon, effets suivent) | `needs` |
| Valeur de départ | 100 pour un nouveau personnage, ou un besoin ajouté plus tard | `initial` |
| Paliers | bas à 30, critique à 10, épuisé à 0 ; un message à chaque franchissement vers le bas | `thresholds`, `needs[].messages` |
| Baisse | un passage du serveur par minute pour tous les personnages en jeu ; rien hors connexion ni pendant la sélection | `tickMs` |
| Activité | vitesse horizontale lue côté serveur toutes les 15 s ; à partir de 4 m/s à pied, la baisse va jusqu'à × 1,5 ; un véhicule ne compte pas | `activity` |
| Endurance | maximale à 35 % tant qu'un besoin est critique | `criticalStamina` |
| Vie | avec `vava_health`, perte appliquée par le serveur (export `damage`), plancher levé ; sans lui, appliquée par le client, jamais sous 10 % de la vie au-dessus du seuil de mise à terre (100) | `health` |
| Manger, boire | geste de 3 s ; refusé si chacun des besoins comblés est à 95 ou plus, ou pendant le geste | `consumption` |
| Gestes | manger (`mp_player_inteat@burger`), boire (`mp_player_intdrink`), haut du corps : on peut marcher | `gestures`, `animation` |
| Médaillons | Faim puis Soif, après Santé | `hud` |

### Baisse et paliers

À chaque passage, chaque besoin perd le temps écoulé depuis le précédent × l'activité × les modificateurs posés par
d'autres modules (maladie, auberge, sort : ils se multiplient, 0 fige le besoin). Le hook `vava_needs:decay` (avant,
annulable) suspend la baisse d'un personnage (à terre, prison, zone protégée…) : le temps suspendu n'est pas rattrapé.
Les valeurs sont bornées à 0–100, arrondies à deux décimales, et ne sont écrites que si elles changent.

### À zéro

Un besoin épuisé retire des points de vie GTA à chaque passage (2 pour la faim, 4 pour la soif, 6 les deux). Règles
pures dans `shared/starvation.lua`, testées dans `tests/spec/needs_starvation_spec.lua` :

- avec `vava_health` (1.2.0) : **le serveur décide et applique** la perte. Il la rapporte à la vie au-dessus du seuil
  de mise à terre, d'après la vie maximale du ped lue côté serveur (2 points sur 200 → 2 %), et la passe à l'export
  `damage` de `vava_health` (par `bridge/server.lua`), qui tient la vie et la mise à terre et prévient lui-même le
  client : un client modifié ne peut plus l'ignorer. La perte qui atteint le seuil met la vie à 0 : le ped tombe
  franchement, le joueur est mis à terre, puis peut être relevé, et ses besoins restent figés tant qu'il est à terre.
  À terre, pas encore apparu ou pendant le démarrage de `vava_health` : rien n'est retiré. Ce n'est ni un coup ni un
  sort : elle passe par `damage` tant que la chaîne de dégâts `vava_health:hit` (`docs/plan/COMBAT_V1.md`, T-110)
  n'existe pas ; y entrer ou non (boucliers, résistances) sera à trancher avec elle ;
- sans `vava_health`, seul repli : le serveur envoie la perte au seul joueur, dont le client l'applique sans jamais
  descendre sous le plancher : personne ne reste mort sans recours.

L'endurance réduite d'un besoin critique reste un effet appliqué par le client (native GTA).

### Manger et boire

Un objet de l'inventaire qui déclare `effects = { hunger = 35 }` (ou `thirst`, ou les deux) nourrit ou désaltère : une
unité consommée, effets appliqués aussitôt (plafonnés à 100), geste de sa catégorie (`nourriture` : manger, `boisson` :
boire, autre : manger). Un objet qui porte aussi l'effet d'un autre module (soin, ivresse) n'est jamais refusé pour
cause de satiété. À terre, l'inventaire refuse le geste (`vava_health`).

## Base de données

Aucune table propre : les valeurs vivent dans le champ de personnage `vava_needs:state` (`{ hunger, thirst }`, visible
du seul joueur), sauvegardé avec le personnage. « Nourrir » du Conseil est au journal de `vava_admin`.

## Pour les autres modules

```lua
local needs = exports.vava_needs
needs:add(source, { hunger = 20 })                       -- un repas servi par un aubergiste
needs:setModifier(source, 'maladie', { thirst = 2 })     -- la fièvre assoiffe deux fois plus vite
needs:removeModifier(source, 'maladie')
```

Exports complets (`get`, `set`, `add`, `setModifier`, `removeModifier`), codes et hooks (`vava_needs:decay`
annulable, `vava_needs:changed`) : `docs/api.md`, section `vava_needs`. Export client `get()` : valeurs du joueur local.
Un modificateur ne vit que le temps du personnage chargé et disparaît à l'arrêt du module qui l'a posé.

## Réseau

Aucun RPC : le joueur n'exprime rien de plus que l'utilisation d'un objet, déjà validée par l'inventaire. Vers le seul
joueur concerné : son champ (au passage de la minute s'il a changé, et à chaque repas ou appel d'un module), la perte
de vie à 0 (seulement sans `vava_health` ; avec lui, c'est `vava_health` qui envoie la vie fixée par le serveur), le
geste de consommation. Client : aucune boucle (les valeurs arrivent par le champ, l'endurance est une
native persistante).

## Conseil

Pas de commande propre : Registre du Conseil → Joueurs → Soins → **Nourrir** (droit `heal`) remet faim et soif à 100
(export `set`), inscrit au journal.

## À vérifier en jeu

La procédure complète est `docs/tests/besoins.md`. En priorité :

1. **Seuil** : vie 20 %, faim et soif à 0 (outil `vava_dev_characters`) → le personnage tombe au 4e passage et reste au
   sol sous l'écran à terre (`besoins` 4-3).
2. **Gestes** : dictionnaires `mp_player_inteat@burger` et `mp_player_intdrink` (flag 49 : marche possible).
3. **Endurance** : l'effet réel de `SetPlayerMaxStamina` à 35 % sur la course.
4. **Course** : le seuil de 4 m/s horizontaux (le trot compte-t-il ?).
5. **Redémarrages** : `restart vava_needs` et `restart vava_hud` → médaillons de retour avec leurs valeurs ; messages
   des paliers atteints annoncés de nouveau.
6. **Rendu des médaillons** : `modules/vava_hud/web/index.html?values=0.8,0.62,0.08` dans un navigateur.
7. **Perte décidée par le serveur** (1.2.0) : avec `vava_health`, médaillon et fiche du Registre d'accord à chaque
   passage (−2, −4, −6 %), aucun avertissement en console ; sans lui (`stop vava_health`), repli client au plancher
   (`besoins` 4-7 à 4-9).
