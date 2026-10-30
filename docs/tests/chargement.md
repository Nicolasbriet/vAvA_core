# Écran de chargement — procédure de test en jeu

Procédure pour vérifier en jeu l'écran de chargement d'Eldoria (`vava_loading` 1.0.0) et son passage à la sélection
du personnage (`vAvA_core` 0.13.0, `vava_characters_ui` 1.2.0). Elle suit l'ordre d'une connexion : l'ouverture, la
progression, le passage, puis les cas dégradés, le coût et le réseau. Comptez une heure seul ; les tests à deux joueurs
sont marqués **(2 joueurs)**. Chaque test dit quoi faire et ce qui doit se passer ; si ce n'est pas le cas, notez le
test, ce que vous avez vu, et la ligne de console correspondante.

## 0. Préparation

1. **Serveur de test à jour** : `vAvA_core` 0.13.0, `vava_loading` 1.0.0, `vava_characters_ui` 1.2.0. **Ordre de
   démarrage** (`server.cfg`, ou la Chancellerie 1.8.1 qui le fait seule), après `oxmysql` : `vAvA_core`, `vava_ui`,
   `vava_loading`, `vava_chat`, `vava_world`, `vava_time`, `vava_appearance`, `vava_characters_ui`, puis les autres
   (voir [LISEZMOI.md](LISEZMOI.md)).
2. **Premier passage** : `debug.journal = true` dans `modules/vava_loading/web/js/config.js` (journal de calibrage à
   l'écran). **À remettre à `false`** après le test 1-4 (le test unitaire refuse `true`).
3. **Une connexion = quitter FiveM complètement puis se reconnecter** : une simple reconnexion depuis le jeu ne recharge
   pas tout, et l'écran de chargement ne repasse pas toujours.
4. **Consoles** : celle du serveur, et celle du client (`F8`, dès que la sélection est là). Les lignes qui commencent
   par `[vava_loading]` ou `[vAvA]` sont les plus parlantes.
5. Si possible, **filmer l'écran** (outil de capture à 60 images/s) pour la section 3 : le passage se juge image par
   image.

## 1. Premier chargement (cache vidé)

| # | Faire | Attendu |
|---|---|---|
| 1 | Vider le cache de FiveM, se connecter. | Dès la fin de la carte de connexion : noir, puis le filet d'étincelle, les lettres d'« Eldoria » qui s'embrasent une à une avec des étincelles, le rideau qui se lève sur le paysage (≈ 3 s). Aucune page blanche, aucun texte de secours (polices justes : titre en capitales décoratives très grasses, texte en EB Garamond). |
| 2 | Se reconnecter et cliquer « Passer l'ouverture » (ou n'importe où) pendant l'ouverture. | Le paysage et les textes apparaissent aussitôt. `Espace` ou `Entrée` font de même si le clavier parvient à la page (à noter). |
| 3 | Regarder la progression jusqu'au bout. | Les six feux s'allument dans l'ordre, chacun avec une gerbe ; le pourcentage ne recule jamais ; « n / N fichiers » pendant « Les artisans ouvrent leurs ateliers » si le jeu l'envoie. |
| 4 | Lire le journal à l'écran (`debug.journal`), le photographier. | Liste des messages et de leur instant. Noter au rapport l'instant du premier message de chaque étape et la durée totale ; recalculer `stages` (`web/js/config.js`) pour que chaque étape occupe une part proportionnelle à sa durée moyenne (sur 3 connexions), puis remettre le journal à `false`. |
| 5 | Pendant le chargement : extraits et conseils. | Un extrait toutes les 9 s à gauche, un conseil toutes les 6,5 s à droite, touches dans un cartouche ; jamais deux fois le même de suite. |

## 2. Allure

| # | Faire | Attendu |
|---|---|---|
| 1 | Bouger la souris. | Les plans du paysage glissent légèrement, les plus proches davantage ; la caméra avance lentement. |
| 2 | Regarder le château et le ciel. | Fenêtres qui vacillent, étoiles qui scintillent, brume qui dérive, de temps en temps une étoile filante (niveau `haute`). |
| 3 | Regarder le sceau derrière le titre. | Deux anneaux qui tournent en sens contraires, runes **lisibles** (pas de carrés vides), halo qui respire. |
| 4 | Jeu en 1280 × 720 fenêtré, puis 2560 × 1440 si possible. | Tout tient à l'écran ; titre, extraits, conseils et feux lisibles et sans chevauchement. |
| 5 | Regarder le coin inférieur droit. | Aucun indicateur du jeu par-dessus le pourcentage ; sinon régler `--foot-gap` (`web/css/style.css`) et le noter. |
| 6 | Écouter. | Silence (aucune musique livrée) ; pas de musique du jeu par-dessus. Bouton musique absent. |

## 3. Passage à la sélection

| # | Faire | Attendu |
|---|---|---|
| 1 | Laisser finir le chargement. | 6e feu : « Le bourg prépare votre arrivée » ; puis 100 %, gerbes sur les six feux, l'éclair doré « Le royaume vous attend ». |
| 2 | Regarder la fin de l'éclair (filmer si possible, image par image). | La page se dissout sur la sélection (Registre des âmes, caméra en place). **Aucune image noire** entre l'éclair et la sélection. Si la page coupe net au lieu de se dissoudre : noter (repli voulu), toujours sans noir. |
| 3 | Aussitôt la sélection visible, cliquer « Jouer ». | La souris répond tout de suite ; plus de curseur de l'écran de chargement. |
| 4 | Retour à la sélection en jeu (`/perso quitter`, outil de développement). | Comportement d'avant : écran noir puis sélection ; aucun écran de chargement, aucune erreur en `F8`. |

## 4. Cas dégradés (serveur de test)

| # | Faire | Attendu |
|---|---|---|
| 1 | `stop vava_characters_ui`, se reconnecter. | Après le 6e feu, l'écran attend ≈ 20 s puis joue l'éclair et se ferme (filet `selectionFallbackMs`) : écran noir ensuite (aucune sélection, voulu). `ensure vava_characters_ui` : la sélection s'ouvre. |
| 2 | Retirer `vava_loading` (aucune ligne `ensure`), se reconnecter. | Écran de chargement de FiveM par défaut ; le core ferme comme avant ; la sélection s'ouvre. |
| 3 | `restart vava_loading` en jeu. | Rien ne s'affiche, aucune erreur en `F8`. |
| 4 | `spawn.loadingScreen.resource = ''` dans `config/shared.lua` du core, redémarrer le serveur, se connecter. | Écran de chargement fermé dès la mise en attente (noir bref avant la sélection : comportement de 0.12.0). Remettre `'vava_loading'`. |

## 5. Coût

| # | Faire | Attendu |
|---|---|---|
| 1 | Sur la machine la plus modeste disponible : 3 connexions avec `effects.level = 'basse'`, 3 avec `'haute'` (`web/js/config.js` ; chronomètre : clic « Se connecter » → sélection visible). | Écart des moyennes ≤ 5 %. Au-delà : `effects.level = 'moyenne'` par défaut, noté au rapport. |
| 2 | Gestionnaire des tâches pendant le chargement (`haute`). | Processus du navigateur de FiveM sous ≈ 10 % d'un processeur ; noter la valeur. |
| 3 | Journal ou `?fps=1` hors jeu sur la même machine. | Niveau atteint après dégradation noté au rapport. |
| 4 | Une fois en jeu : `resmon 1` en `F8`. | `vava_loading` à 0,00 ms (aucune boucle). |

## 6. Réseau **(2 joueurs)**

| # | Faire | Attendu |
|---|---|---|
| 1 | A en jeu suit son trafic (`/vava_reseau joueur <A>`, [reseau.md](reseau.md)) ; B se connecte. | A ne reçoit aucun évènement lié à l'arrivée de B ni à `vava_loading`. |
| 2 | A et B se connectent en même temps. | Deux écrans de chargement indépendants, chacun passe à sa propre sélection. |
| 3 | Chancellerie ou console du serveur : `./scripts/audit-reseau.sh`. | `vava_loading : … octets (≤ 1,5 Mo)`, aucune ligne BLOQUANT sur `web/fonts/`. |

## 7. Ce que je ne peux pas avoir vérifié hors jeu

Par ordre d'importance :

- l'absence d'image noire au passage (3-2), qui dépend de l'ordre réel des appels du core, de `vava_characters_ui` et
  de `vava_loading` dans le jeu ;
- les messages que FiveM envoie vraiment à la page et leur ordre (1-4) : les seuils des feux sont provisoires ;
- la transparence de la page de chargement pendant la dissolution (3-2) ;
- les runes du sceau dessinées par la police système `Segoe UI Historic` (2-3) ;
- le coût de l'animation sur une petite machine (5-1) ;
- la souris et le clavier sur l'écran de chargement (1-2) ;
- `localStorage` gardé d'une connexion à l'autre (seulement si une musique est ajoutée) ;
- un indicateur du jeu dessiné par-dessus le pied de page (2-5).

## 8. Comment me remonter un problème

Pour chaque anomalie : le numéro du test (ex. « chargement 3-2 »), ce qui s'est passé, la ou les lignes de la console
serveur ou client (`F8`) au même moment, et si possible la vidéo du passage.
