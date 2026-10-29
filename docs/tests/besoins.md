# Besoins — procédure de test en jeu

Procédure pour vérifier en jeu `vava_needs` 1.1.2 (faim et soif) avec ses voisins : médaillons de `vava_hud` 1.3.0,
objets de `vava_inventory` 1.6.1, mise à terre de `vava_health` 1.1.3, Registre du Conseil. Le module n'a ni
commande ni RPC : la faim et la soif ne changent que par le temps, les objets, le Registre et l'API des autres modules.
Comptez 45 minutes seul avec les outils de test (§ 0.2) ; les tests à deux joueurs sont marqués **(2 joueurs)**. Un
test se cite « besoins 3-4 ».

## 0. Préparation

1. **Préparation commune** : [LISEZMOI.md](LISEZMOI.md) (ordre de démarrage, compte du Conseil, catalogue, consoles,
   resmon, remontée des écarts).
2. **Outils de test** (serveur de test seulement : aucun contrôle d'administration, tout joueur peut s'en servir) :
   activer `vava_example_items` et `vava_dev_characters`, rangés dans `[vava-dev]` (page Ressources de la
   Chancellerie, ou `ensure vava_example_items` puis `ensure vava_dev_characters` dans la console du serveur).
   Commandes utilisées ici : `/besoins` (affiche « faim 100.0 · soif 100.0 » dans le chat), `/besoins <faim> <soif>`
   (fixe, de 0 à 100), `/vie [pourcentage]`, `/aterre`, `/objet <nom> [quantité]`, `/perso quitter`. Sans
   `vava_example_items`, aucun objet ne désaltère : dans les modules, seuls `ragout_de_lievre` (+40), `chou` (+15) et
   `carotte` (+8) nourrissent.
3. **Objets** (`/catalogue` ou `/objet`) : `pain` ×8 (Miche de pain, faim +35), `pomme` ×3 (faim +12, soif +4),
   `eau` ×3 (Outre d'eau, soif +40), `biere` ×2 (Chope de bière, soif +25, faim +5), `ragout_de_lievre` ×1,
   `carotte` ×2. Glisser une miche sur le raccourci `1` de la ceinture.
4. **Lire les valeurs** : `/besoins` (une décimale), ou Registre (`F10`) → Joueurs → vous : Faim et Soif en pour cent.
   Les médaillons n'affichent pas de chiffre. Invulnérabilité (Registre → Outils) éteinte.
5. **Réglages pour aller vite** (facultatif, `vava_needs/config.lua`, puis `restart vava_needs`, à remettre après) :
   - `tickMs = 15000` (défaut `60000`) : un passage du serveur toutes les 15 s ; la baisse par minute ne change pas,
     mais les pertes de vie à 0 (§ 4) vont 4 fois plus vite. Garder un multiple de `activity.sampleMs` (15000).
   - `needs[1].durationHours = 0.5` (faim, défaut `4`) et `needs[2].durationHours = 0.5` (soif, défaut `3`) : de 100
     à 0 en 30 min. Indispensable sans `/besoins` pour atteindre les paliers.
   - Les vitesses des § 1 et 2 supposent les valeurs par défaut.

## 1. Médaillons et baisse avec le temps

D'après la configuration : faim de 100 à 0 en 4 h de jeu au repos (−0,42 par minute), soif en 3 h (−0,56 par minute) ;
un passage du serveur par minute applique le temps écoulé depuis le précédent. La part du temps passée à courir à pied
(vitesse horizontale d'au moins 4 m/s, relevée côté serveur toutes les 15 s) multiplie la baisse, jusqu'à × 1,5. Rien
ne baisse hors connexion, ni sur l'écran de sélection.

| # | Faire | Attendu |
|---|---|---|
| 1 | Créer un personnage neuf et apparaître. | En bas à gauche, de gauche à droite : médaillons Santé, Faim, Soif (puis Voix si `vava_voice` tourne). Anneaux pleins, teinte laiton. `/besoins` → « faim 100.0 · soif 100.0 ». |
| 2 | Échap (menu pause), puis revenir au jeu. | Médaillons masqués pendant le menu, de retour ensuite. |
| 3 | `/besoins` ; rester immobile 10 min ; `/besoins`. | Faim −4,2 et soif −5,6, à un passage près (±0,4 et ±0,6). L'anneau Soif a perdu un peu plus que l'anneau Faim. |
| 4 | `/besoins` ; sprinter (`Maj`) le plus possible pendant 4 min ; `/besoins`. | Baisse plus forte qu'immobile (−1,7 et −2,2 en 4 min), jusqu'à −2,5 et −3,3 si tout le temps est passé au-dessus de 4 m/s. Un personnage essoufflé qui ralentit compte moins. |
| 5 | Registre (`F10`) → Joueurs → vous. | Faim et Soif en pour cent, arrondis, conformes à `/besoins`. |
| 6 | `/besoins` ; `/perso quitter` ; rester 3 min sur l'écran de sélection ; reprendre le personnage ; `/besoins`. | Médaillons masqués pendant la sélection ; à la reprise, mêmes valeurs qu'avant (à un passage près si l'un est tombé entre la lecture et le départ). |

## 2. Paliers et effets

Paliers : bas à 30 et moins, critique à 10 et moins, épuisé à 0. Un message à chaque franchissement vers le bas, par
une notification du HUD en haut à droite (laiton au palier bas, ambre au critique, rouge à 0) ; aucun en remontant.
Anneau ambre au palier bas, rouge avec une lueur pulsante au critique. Tant qu'un besoin est critique, l'endurance
maximale tombe à 35 % (`criticalStamina`).

| # | Faire | Attendu |
|---|---|---|
| 1 | `/besoins 31 31` ; attendre 3 min immobile. | Au 2e passage (2 min au plus) : « Vous avez la gorge sèche. », anneau Soif ambre. Au 3e (3 min au plus) : « Votre ventre gargouille. », anneau Faim ambre. Chaque message une seule fois. |
| 2 | `/besoins 11 11` ; attendre 3 min. | Aucun message tout de suite (déjà au palier bas). Puis « La soif vous affaiblit : vous ne tenez plus la course. » et « La faim vous affaiblit : vous ne tenez plus la course. » ; anneaux rouges, pulsants. |
| 3 | Sprinter. | Essoufflé bien plus tôt qu'à l'ordinaire (endurance maximale à 35 %) (à confirmer : effet visible du sprint). |
| 4 | Manger une miche. | Faim vers 45, anneau Faim redevenu laiton, aucun message. L'endurance reste réduite : la soif est encore critique. |
| 5 | Boire une outre. | Soif vers 50 ; endurance rendue. |
| 6 | `/besoins 100 100`, puis `/besoins 5 100`. | Un seul message : « La faim vous affaiblit : vous ne tenez plus la course. » (le palier atteint, pas le palier bas franchi en route). |
| 7 | `/besoins 40 100`, puis `/besoins 25 100`. | « Votre ventre gargouille. » de nouveau : chaque nouvelle descente sous un palier est annoncée. |

## 3. Manger et boire

Un objet qui déclare des effets de faim ou de soif perd une unité et les applique aussitôt (valeurs plafonnées à 100),
puis le personnage joue 3 s le geste de sa catégorie (`nourriture` : manger ; `boisson` : boire ; autre : manger),
sans accessoire, du haut du corps seulement. Refusé, l'objet restant dans la besace, si chacun des besoins qu'il
comble est à 95 ou plus, ou pendant les 3 s du geste précédent.

| # | Faire | Attendu |
|---|---|---|
| 1 | Besace (`I`) : survoler la miche, la pomme, l'outre. | Fiche : « Faim +35 » ; « Faim +12 » et « Soif +4 » ; « Soif +40 ». |
| 2 | Personnage à 100 / 100 : double-clic sur la miche. | Refusé dans l'inventaire : « Vous n'avez plus faim. » ; la miche reste. |
| 3 | Même chose avec l'outre, puis la pomme. | « Vous n'avez plus soif. » ; « Vous êtes rassasié. » (la pomme comble les deux, tous deux pleins). |
| 4 | `/besoins 95 50` puis la miche ; `/besoins 94 50` puis la miche. | À 95 : refusée (« Vous n'avez plus faim. »). À 94 : mangée, faim 100 (plafonnée), une miche de moins. |
| 5 | `/besoins 50 50` ; clic droit sur la miche → Utiliser ; marcher pendant le geste. | Faim 85 aussitôt (l'anneau remonte), une miche de moins ; geste de manger pendant 3 s sans empêcher la marche. |
| 6 | Dans les 3 s, double-clic sur une autre miche ; puis de nouveau après 3 s. | D'abord « Vous n'avez pas encore fini. », miche gardée ; ensuite mangée : faim 100, et non 120. |
| 7 | Outre d'eau. | Geste de boire ; soif vers 90 (50 + 40, moins la baisse écoulée). |
| 8 | `/besoins 100 60` ; pomme. | Acceptée (la soif en profite) : soif 64, faim 100 ; geste de manger (catégorie nourriture). |
| 9 | Chope de bière. | Geste de boire ; soif vers 89 (64 + 25), faim reste 100 (plafond). |
| 10 | `/besoins 40 100` ; ragoût de lièvre, puis une carotte (3 s plus tard). | Faim 80 puis 88 ; geste de manger. |
| 11 | Inventaire fermé, faim 50 : touche `1` (miche en raccourci). Puis `/besoins 100 100` et `1`. | Mangée comme au double-clic. À 100 : notification « Vous n'avez plus faim. », miche gardée. |
| 12 | **(2 joueurs)** L'un mange devant l'autre. | L'autre voit le geste ; ses propres médaillons ne bougent pas. |

## 4. À zéro

À 0, chaque passage du serveur (60 s) retire des points de vie GTA : 2 pour la faim, 4 pour la soif, 6 quand les deux
sont épuisés ; aucun message à chaque perte. Avec `vava_health` (le cas du serveur), aucun plancher : le joueur finit
à terre, et à terre la faim, la soif et les pertes s'arrêtent. Sans lui, la vie ne descend pas sous 10 % de la jauge
(`health.floor`). Pour un ped de 200 points de vie (le cas habituel, à confirmer pour un modèle féminin), un point vaut
1 % de la jauge Santé.

| # | Faire | Attendu |
|---|---|---|
| 1 | `/besoins 0 100`. | « Vous mourez de faim. » (notification rouge), une fois ; anneau Faim vide. Santé −2 % à chaque passage. |
| 2 | `/besoins 100 0`, puis `/besoins 0 0`. | « Vous mourez de soif. », Santé −4 % par passage ; puis « Vous mourez de faim. » de nouveau (nouvelle descente), −6 % par passage. La vie ne remonte jamais seule. |
| 3 | `/vie 20`, `/besoins 0 0`, attendre immobile. | Santé 14, 8, 2 %, puis le personnage tombe au 4e passage (4 min au plus) : écran « Vous êtes à terre » (santé 2). La dernière perte couche le ped (vie GTA 0, jamais le seuil de 100) : il s'effondre aussitôt et reste au sol ; debout sous l'écran à terre, c'est à me remonter. |
| 4 | À terre : `/besoins`, puis encore 3 min plus tard. | « faim 0.0 · soif 0.0 » les deux fois ; la Santé ne bouge plus. |
| 5 | Registre → vous → Soigner. | Relevé sur place, Santé 100 % ; les pertes reprennent au passage suivant (−6 %). |
| 6 | Registre → vous → Nourrir. | Faim et Soif à 100, anneaux pleins ; plus aucune perte. |
| 7 | (Facultatif, sans `vava_health`) `/vie 20`, `/besoins 0 0`, console du serveur `stop vava_health` ; attendre 3 min ; `ensure vava_health` puis `ensure vava_dev_characters`. | Au retour du module, médaillon Santé à 10 % (plancher), personnage debout (à confirmer : GTA ne rend pas de vie pendant l'arrêt). Ensuite le plancher est levé : à terre au 2e passage. |

## 5. Persistance et reconnexion

| # | Faire | Attendu |
|---|---|---|
| 1 | `/besoins 40 60` ; juste après un passage, `/besoins` (noter) ; quitter (`F8` → `quit`) ; attendre 5 min ; revenir. | Mêmes valeurs que la lecture notée : rien ne baisse hors connexion (la minute entamée au départ n'est pas comptée). |
| 2 | Revenir avec la faim à 25. | À la reprise, « Votre ventre gargouille. » est annoncé de nouveau (il peut passer pendant le fondu d'apparition : à confirmer) ; anneau ambre. |
| 3 | Revenir avec la soif à 5. | « La soif vous affaiblit : vous ne tenez plus la course. » ; endurance réduite dès l'apparition. |
| 4 | Faim 50 : manger une miche et quitter pendant le geste. | Au retour : faim 85 (l'effet s'applique à l'utilisation, pas à la fin du geste), une miche de moins. |
| 5 | Choisir le personnage puis quitter pendant l'écran noir d'apparition ; revenir ; rester 5 min immobile. | Baisse normale (−2,1 et −2,8), pas doublée ; aucune ligne `besoins du personnage #n non écrits` dans la console du serveur. |
| 6 | Second personnage du même compte. | Ses propres valeurs (100 / 100 s'il est neuf) ; le premier retrouve les siennes. |
| 7 | Console du serveur `vava_saveall`, puis la requête du § 9. | `"vava_needs:state"` porte les valeurs de `/besoins` (deux décimales). |

## 6. Conseil

| # | Faire | Attendu |
|---|---|---|
| 1 | Registre (`F10`) → Joueurs → vous → Soins → Nourrir. | « C'est fait. » ; fiche : Faim 100 %, Soif 100 % ; anneaux pleins ; aucun message dans le jeu ; onglet Journal : « a nourri ». |
| 2 | **(2 joueurs)** Nourrir l'autre (droit `heal`, dès Gardien). | Ses médaillons se remplissent, les vôtres ne bougent pas. |

## 7. Redémarrage du module

| # | Faire | Attendu |
|---|---|---|
| 1 | Faim 25, soif 8 : console `restart vava_needs`. | Médaillons Faim et Soif absents un instant, puis de retour avec les mêmes valeurs ; « Votre ventre gargouille. » et « La soif vous affaiblit : vous ne tenez plus la course. » annoncés de nouveau ; endurance de nouveau réduite. La baisse reprend au passage suivant (le temps de l'arrêt n'est pas compté). |
| 2 | Faim 50 : manger une miche, `restart vava_needs` pendant le geste, puis une autre miche aussitôt. | Le geste va à son terme, faim 85 gardée ; la seconde miche passe sans attendre 3 s (le délai est remis à zéro). |
| 3 | `restart vava_hud`. | Médaillons Faim et Soif aussitôt de retour, avec leurs valeurs. |
| 4 | `stop vava_needs` ; manger une miche ; `ensure vava_needs`. | Pendant l'arrêt, plus de médaillons, et la miche disparaît sans effet (l'inventaire consomme, plus personne ne lit l'effet) : écart signalé, à éviter sur un serveur ouvert. |
| 5 | Après un `restart`, `/besoins`. | Si la commande ne répond plus, `ensure vava_dev_characters` (il dépend de `vava_needs` : à confirmer). |

## 8. Tentatives de triche

| # | Faire | Attendu |
|---|---|---|
| 1 | Faim 50, miche en raccourci : appuyer dix fois très vite sur `1`. | Une seule miche mangée ; pendant les 3 s, « Vous n'avez pas encore fini. » (4 notifications à l'écran au plus) ; au-delà de 4 appuis en une seconde, les appuis sont ignorés sans message (débit de l'inventaire : 4, puis 1 par seconde). |
| 2 | Faim 50 : trois doubles-clics très rapides sur la même pile de miches. | Une seule unité consommée (+35) ; les autres refusées. |
| 3 | Faim 95 : dix doubles-clics sur la miche. | Toujours « Vous n'avez plus faim. », aucune miche perdue. |
| 4 | À terre (`/aterre`) : double-clic sur une miche, puis touche `1`. | « Vous êtes à terre. » les deux fois ; rien de consommé, faim inchangée. |
| 5 | Changer de personnage à faim 5 pour revenir rassasié. | Le personnage repris retrouve faim 5 (5-6). |

## 9. Resmon et base

| Ressource | Au repos | Pendant l'action |
|---|---|---|
| `vava_needs` | 0,01 ms au plus : aucune boucle côté client (les valeurs arrivent par le champ du personnage, une fois par minute) | Manger, boire : 0,01 ms au plus (un fil court charge l'animation, 1 s au plus) |

Cibles : 0,02 ms au repos, 0,15 ms en action.

```sql
SELECT id, first_name, last_name, JSON_EXTRACT(data, '$."vava_needs:state"') AS besoins
FROM vava_characters WHERE deleted_at IS NULL;
```

- Valeur attendue : `{"hunger": 72.5, "thirst": 60.25}` (deux décimales). Aucune table propre au module.
- Écriture en base : toutes les 5 min (`persistence.saveIntervalMs` du core) et à chaque départ ; `vava_saveall` dans la
  console du serveur pour forcer.
- Journal du Conseil : `vava_admin_logs`, `action = 'feed'`.

## 10. Ce que je ne peux pas avoir vérifié hors jeu

- Les gestes : dictionnaires `mp_player_inteat@burger` et `mp_player_intdrink` (flag 49 : haut du corps, marche
  possible). Un dictionnaire non chargé en 1 s laisse le personnage immobile et écrit `animation 'x' non chargée` dans
  la console du client.
- L'effet réel de `SetPlayerMaxStamina` à 35 % sur la course (§ 2-3).
- Le seuil de course (4 m/s horizontaux) : le trot par défaut compte-t-il ? Le § 1-4 le montrera.
- La dernière perte de vie à 0 couche le ped à une vie GTA de 0 (avec `vava_health`), au lieu de le poser au seuil de
  100 où GTA pourrait le laisser debout ; et `vava_health` recouche de toute façon un ped resté au seuil (§ 4-3).
- Le rendu des médaillons et des notifications : `modules/vava_hud/web/index.html?values=0.8,0.62,0.08` dans un
  navigateur.
