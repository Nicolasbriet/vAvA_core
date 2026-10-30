# Voix — procédure de test en jeu

Procédure pour vérifier en jeu `vava_voice` 1.2.1 : les quatre portées, le médaillon et le cercle au sol, le silence
hors du jeu, la portée réduite à terre, les zones de voix et leur éditeur, leur persistance, le redémarrage. Règles et
réglages : `modules/vava_voice/README.md` (et `docs/api.md`). Comptez une heure ; presque tout se fait à deux, au
casque : **A**, membre du Conseil, et **B**, simple joueur. Un test se cite « voix 3-4 ».

## 0. Préparation

1. **Commun** : ordre de démarrage, compte du Conseil, consoles, mesure du resmon et remontée des écarts :
   [LISEZMOI.md](LISEZMOI.md).
2. **`server.cfg`** : ces deux lignes doivent y être (son 3D du jeu ; voix réglée sur la seule portée de celui qui
   parle) :

   ```cfg
   setr voice_useNativeAudio true
   setr voice_useSendingRangeOnly true
   ```

   La Chancellerie (1.4.2) les écrit d'elle-même (section « Voix ») et les ajoute, avant le lancement de FXServer, à un
   `server.cfg` qui ne les pose pas par `setr` : console et journal de la Chancellerie disent « server.cfg complété ».
   Si elle avertit à la place (« server.cfg à vérifier » : `exec`, `set` au lieu de `setr`, fichier qui n'est pas en
   UTF-8 ou en lecture seule), corriger à la main. Serveur lancé sans elle : les ajouter à la main. Sans elles, les tests 2-5, 2-6 et la section 4 ne mesurent pas le
   comportement voulu.
3. **Chaque joueur** : chat vocal activé dans les réglages du jeu (Paramètres > Chat vocal), micro choisi, casque (sans
   casque, la voix de l'un repart dans le micro de l'autre). On parle en maintenant `N` (touche de GTA par défaut).
4. **Démarrage** : la console du serveur affiche `module 'vava_voice' v1.3.0 prêt` ; la table `vava_voice_zones` est
   créée au premier démarrage (migration `sql/0001_voice_zones.sql`). En jeu, médaillon « Voix » dans le HUD.
5. **Joueurs** : A Souverain (`vava_conseil <compte de A> souverain` : droits `tools` et `teleport`), B sans rang.
6. **Touche de portée** : `W` sur un clavier AZERTY (FiveM la nomme `Z`, d'après sa place sur un clavier QWERTY) ;
   Paramètres > Raccourcis > FiveM : « Portée de la voix (Chuchoter, Parler, Crier, Déclamer) ».
7. **Placer B** : A appuie sur `W` ; le cercle au sol a pour rayon la portée de A ; B se tient juste dedans ou juste
   dehors. Les distances des tableaux sont prises ainsi.
8. **Réglages pour aller vite** (à remettre ensuite, puis `restart` du module) : `vava_voice/config.lua` →
   `ring.durationMs = 10000` (défaut `1500` : le cercle reste le temps de placer B), `zones.max = 1` (défaut `200`,
   pour le seul test 3-17) ; `vava_health/config.lua` → `downed.giveUpAfterMs = 10000` (défaut `180000`, pour 6-4).

## 1. Portées, médaillon et cercle (seul)

| # | Faire | Attendu |
|---|---|---|
| 1 | Première apparition sur ce PC (aucune portée encore choisie). | Médaillon « Voix » rempli à moitié : Parler (5 m) ; pas de cercle au sol. |
| 2 | `W`, quatre fois. | Crier (trois quarts, cercle de 15 m de rayon), Déclamer (plein, 25 m), Chuchoter (un quart, 1,5 m), Parler (moitié, 5 m). Cercle couleur laiton, posé au sol, qui suit le personnage et s'efface en 1,5 s (fondu sur les 0,6 dernières). |
| 3 | Maintenir `N` et parler, puis relâcher. | Le médaillon s'illumine de laiton (0,15 s au plus après le début) et s'éteint au relâchement. |
| 4 | Choisir Crier ; se déconnecter ; revenir. | Toujours Crier (médaillon aux trois quarts) : le choix est gardé sur le PC du joueur. |
| 5 | Chat ouvert (`T`), puis inventaire ouvert (`I`) : `W`. | La portée ne change pas. |
| 6 | Paramètres > Raccourcis > FiveM : choisir une autre touche. | La nouvelle touche change la portée ; `W` ne fait plus rien. |
| 7 | Console du serveur : `restart vava_hud`. | Le médaillon revient, à la portée du moment. |

## 2. Ce qu'entend l'autre joueur **(2 joueurs)**

A parle (`N`), B écoute, sauf mention.

| # | Faire | Attendu |
|---|---|---|
| 1 | A en Chuchoter ; B à 1 m, puis à 4 m. | À 1 m, B entend A ; à 4 m, plus rien. |
| 2 | A en Parler ; B à 4 m, puis à 8 m. | Entend à 4 m ; rien à 8 m. |
| 3 | A en Crier ; B à 12 m, puis à 18 m. | Entend à 12 m ; rien à 18 m. |
| 4 | A en Déclamer ; B à 22 m, puis à 28 m. | Entend à 22 m ; rien à 28 m. |
| 5 | A en Parler, B à 4 m tourne autour de lui, puis s'éloigne lentement jusqu'à 8 m. | La voix vient de la direction de A et baisse avec la distance ; elle s'éteint vers 5 m, au plus tard à 7 m (marge de 2 m qui évite de couper la voix à chaque pas : où le son s'arrête exactement entre 5 et 7 m reste à confirmer). |
| 6 | A en Crier, B en Chuchoter, à 10 m l'un de l'autre ; chacun parle à son tour. | B entend A ; A n'entend pas B : seule compte la portée de celui qui parle. |
| 7 | B se reconnecte et, sur l'écran de sélection du personnage, parle ; A parle aussi. | Ni l'un ni l'autre n'entend rien : le serveur coupe le micro de B, qui reste au salon racine, sans personne à qui parler, tant que son personnage n'est pas apparu. À l'apparition, la voix revient (médaillon visible chez B). |
| 8 | A parle pendant que B quitte le jeu, puis revient. | Rien pendant l'absence ; au retour, B entend et se fait entendre, à la portée gardée sur son PC. |

## 3. Éditeur des zones de voix (A, Conseil)

| # | Faire | Attendu |
|---|---|---|
| 1 | Registre (`F10`) → Outils → « Outils des modules » → « Zones de voix » (« Lieux où la voix porte plus loin (tribune, place du marché) ou moins (bibliothèque, crypte). ») → Ouvrir. | Le Registre se ferme ; le panneau « Zones de voix » s'ouvre sur le côté droit, le monde reste visible : « Les zones proches sont dessinées autour de vous. Quand des zones se chevauchent, la plus petite l'emporte. », « 0 / 200 zones », bouton « Nouvelle zone ici », « Aucune zone pour l'instant. Placez-vous au centre du lieu, puis créez-la. ». Souris libre, personnage immobile. |
| 2 | `Échap`, puis `/zonesvoix`. | Le panneau se ferme ; la commande le rouvre. |
| 3 | « Nouvelle zone ici ». | « Nouvelle zone », « Centrée sur l'endroit où vous vous tenez. », « Nom du lieu », Rayon 10 m, Hauteur 6 m (« Comptée depuis vos hanches ; la zone descend aussi de 1 m sous elles. Séparez ainsi les étages. »), six cachets de « ×0,5 Très feutrée » à « ×3 Porte très loin », « ×2 Porte loin » choisi, et « Chuchoter : 1,5 m → 3 m », « Parler : 5 m → 10 m », « Crier : 15 m → 30 m », « Déclamer : 25 m → 50 m ». Dans le monde : un cylindre doré translucide de 10 m de rayon centré sur A, du sol à 7 m environ. |
| 4 | Faire glisser Rayon et Hauteur ; choisir ×0,5, puis ×1, puis ×3. | Le cylindre suit en direct (rayon de 2 à 60 m, hauteur de 2 à 30 m, par pas de 0,5) ; bleuté pour ×0,5 et ×0,75, beige pour ×1, doré au-delà ; les quatre lignes de portée suivent l'effet. |
| 5 | « Sceller » sans nom. | « Donnez un nom au lieu. » |
| 6 | Nom `Chapelle des évêques et crypte du prieur` (40 signes, 42 octets), « Sceller » ; puis tenter d'y ajouter un 41e signe. | « Zone « Chapelle des évêques et crypte du prieur » scellée. » : le champ et le serveur comptent tous deux en signes (un « é » pour un). Le champ refuse le 41e signe. Supprimer ensuite cette zone. |
| 7 | Nom `Tribune`, rayon 10, effet ×2, `Entrée`. | « Zone « Tribune » scellée. » ; retour à la liste : « Tribune », « ×2 · rayon 10 m · hauteur 6 m », « ici » ; « 1 / 200 zones ». |
| 8 | `Échap` dans un formulaire ; `Échap` dans la liste. | Le premier ramène à la liste (l'aperçu disparaît) ; le second ferme le panneau. |
| 9 | Registre → Journal. | « Zone de voix créée » au nom de A : zone Tribune, rayon 10, hauteur 6, effet 2. |
| 10 | Rouvrir, cliquer « Tribune », rayon 3 m, « Sceller ». | « Modifier la zone », le cylindre de Tribune plus marqué pendant l'édition ; puis « Zone « Tribune » scellée. », « ×2 · rayon 3 m · hauteur 6 m » ; journal « Zone de voix modifiée ». |
| 11 | Fermer, marcher 20 m, rouvrir : Tribune est « à 20 m » ; la cliquer, cocher « Recentrer la zone là où je me trouve », « Sceller ». | En cochant, le cylindre saute sous les pieds de A ; après « Sceller », Tribune est « ici » ; journal « Zone de voix modifiée » avec « deplacee : oui ». |
| 12 | « Nouvelle zone ici », nom `<b>Essai</b> & <img src=x>`, « Sceller ». | Le nom s'affiche tel quel, balises comprises, dans la liste et dans le message « Zone « … » scellée. ». |
| 13 | Cliquer cette zone, « Supprimer », puis « Confirmer la suppression ». | Le premier clic change le bouton en « Confirmer la suppression » ; le second : « Zone « <b>Essai</b> & <img src=x> » supprimée. », la zone quitte la liste et le monde ; journal « Zone de voix supprimée ». |
| 14 | S'éloigner à plus de 150 m, rouvrir, cliquer Tribune, « S'y rendre », puis « Annuler ». | Tribune n'est pas dessinée de si loin ; la liste dit « à N m ». Après « S'y rendre » : A est au centre, « Vous voici au centre de la zone. » ; de retour à la liste, Tribune est « ici ». |
| 15 | « Nouvelle zone ici », nom `Doublon`, puis deux fois `Entrée` très vite (ou `Entrée` maintenu). | Une seule zone « Doublon », un seul message « scellée » : tant que la première demande n'a pas répondu, ni `Entrée` ni « Sceller » ne renvoient rien. Une seule ligne « Doublon » en base. Supprimer ensuite « Doublon ». |
| 16 | « Nouvelle zone ici », nom `Perdue`, sans sceller ; quitter le jeu ; revenir et rouvrir. | Aucune zone « Perdue » : rien n'est écrit avant « Sceller ». |
| 17 | `zones.max = 1` (§ 0-8), `restart vava_voice`, Tribune seule ; rouvrir. Remettre `200` ensuite et redémarrer le module. | « 1 / 1 zones » ; « Nouvelle zone ici » grisé. |
| 18 | « Nouvelle zone ici », nom `Tri` + un caractère invisible (U+200B, collé depuis un éditeur de texte) + `bune`, « Sceller ». | « Ce nom contient des signes illisibles. » (et non « Donnez un nom au lieu. ») ; rien n'est écrit. |

## 4. Zones : ce qu'on entend **(2 joueurs)**

Tribune vaut ×2, rayon 3 m, hauteur 6 m (après 3-10) ; A se tient en son centre.

| # | Faire | Attendu |
|---|---|---|
| 1 | A, dans Tribune, appuie sur `W` jusqu'à revenir à Parler. | Cercle de 10 m (5 × 2) au lieu de 5 ; le médaillon reste à moitié (il montre la portée choisie, pas l'effet de la zone). |
| 2 | B hors de la zone, à 8 m de A, en Parler ; A parle, puis B. | B entend A ; A n'entend pas B : la zone agit sur la voix de qui s'y tient, pas sur l'oreille. |
| 3 | B entre dans Tribune et parle en Parler ; A sort et se place à 8 m. | A entend B (5 × 2 = 10 m). |
| 4 | A passe Tribune à ×0,5 dans l'éditeur ; B, dedans, en Parler ; A hors de la zone, à 5 m, puis à 2 m. | Sans reconnexion, l'effet s'applique chez B en 0,5 s au plus : A n'entend pas B à 5 m (2,5 m de portée, plus la marge de 2 m) ; il l'entend à 2 m. |
| 5 | A crée « Place » (×2, rayon 20 m) centrée sur Tribune (×0,5, rayon 3 m). A dans Tribune : `W` quatre fois ; puis A dans Place, hors de Tribune : `W` quatre fois. | Dans Tribune, le cercle de Parler fait 2,5 m (la plus petite zone l'emporte) ; dans Place seule, 10 m. |
| 6 | Loin de Place, au rez-de-chaussée d'un bâtiment à étage, A crée « Rez » (×0,5, rayon 10 m, hauteur 2 m), puis monte à l'étage (plus de 3 m plus haut, à moins de 10 m à l'horizontale) ; en Parler, `W` quatre fois. | À l'étage, la zone ne s'applique plus : cercle de 5 m. Redescendu, l'effet revient (2,5 m). |
| 7 | B entre dans une zone et en sort sans toucher `W`. | Sa portée change en 0,5 s au plus, sans cercle (le cercle ne paraît qu'à l'appui sur la touche). |
| 8 | A crée une zone pendant que B (sans rang) est en jeu ; B y entre, `W` quatre fois. | L'effet s'applique chez B sans reconnexion. |

## 5. Droits sur les zones **(2 joueurs)**

| # | Faire | Attendu |
|---|---|---|
| 1 | B (sans rang) : `/zonesvoix`. | Rien ne s'ouvre, aucun message. |
| 2 | Console : `vava_conseil <compte de B> gardien` ; B ouvre le Registre (`F10`), puis tape `/zonesvoix`. | Aucun outil « Zones de voix » (le Gardien n'a pas le droit `tools`) ; la commande n'ouvre rien. |
| 3 | Console : `vava_conseil <compte de B> souverain` ; B ouvre l'éditeur sur la liste ; A crée une zone. | Si B est à moins de 50 m de la nouvelle zone (rayon 10 m + 40 m), sa liste se met à jour d'elle-même et la zone paraît aussi dans le monde chez lui ; plus loin, il la voit à la réouverture de son éditeur (1.3.0 : une zone n'est envoyée qu'aux joueurs proches). |
| 4 | B ouvre une zone en modification ; A la supprime ; B clique « Sceller ». | « Cette zone n'existe plus. » |
| 5 | B garde l'éditeur ouvert ; console : `vava_conseil <compte de B> aucun` ; B clique « Sceller » sur une zone, puis ferme et tape `/zonesvoix`. | Le panneau resté ouvert ne se ferme pas de lui-même, mais « Sceller » répond « Votre rang ne le permet pas. » ; ensuite, l'éditeur ne s'ouvre plus. |

## 6. À terre **(2 joueurs)**

| # | Faire | Attendu |
|---|---|---|
| 1 | A en Crier, B à 10 m ; A est mis à terre (voir [sante.md](sante.md)) et parle. | La portée de A tombe à Parler, sans cercle ; médaillon à moitié ; B, à 10 m, ne l'entend plus. |
| 2 | A, à terre : `W` plusieurs fois. | Alterne Chuchoter (cercle de 1,5 m) et Parler (5 m), jamais au-delà. |
| 3 | B relève A (`G` à moins de 2 m, 8 s). | A retrouve Crier (médaillon aux trois quarts), sans cercle ; B l'entend de nouveau à 10 m. |
| 4 | A de nouveau à terre choisit Chuchoter, puis rend l'âme (maintenir `E` 3 s, permis après `downed.giveUpAfterMs`). | Au lieu de soins, A retrouve Crier : le choix fait à terre est oublié. |
| 5 | A, à terre : console `restart vava_voice`. | Après le redémarrage, toujours limité à Parler (`W` : jamais au-delà) : le serveur relit l'état de santé, et le client, qui redemande la limite de portée à son redémarrage, la reçoit de nouveau. |
| 6 | A, à terre, quitte le jeu et revient. | Toujours limité à Parler si vava_health le remet à terre à son retour (voir [sante.md](sante.md)). |

## 7. Tentatives de triche

| # | Faire | Attendu |
|---|---|---|
| 1 | `W` vingt fois, le plus vite possible. | La portée tourne, le cercle repart à chaque appui ; rien n'est envoyé au serveur, rien en console. |
| 2 | A à terre : `W` en rafale. | Jamais au-delà de Parler (6-2). |
| 3 | B (sans rang) : `/zonesvoix` dix fois de suite, le plus vite possible (console `F8` : `zonesvoix`, puis `↑` `Entrée`). | Rien ne s'ouvre, aucun message chez B ; dès que la rafale dépasse cinq demandes (plus une par seconde), console du serveur : « joueur <n> : limite dépassée sur vava_voice:editor ». |
| 4 | Entendre un joueur loin ou parler à tout le serveur. | Impossible sans client modifié ; avec un client modifié, possible : limite de toute voix FiveM, assumée et traitée par le règlement (`docs/api.md`). Rien à tester sans outil. |

## 8. Déconnexion et redémarrage

| # | Faire | Attendu |
|---|---|---|
| 1 | A et B se parlent, A dans Tribune (×2) ; console du serveur : `restart vava_voice`. | Voix coupée un instant puis revenue sans reconnexion ; console `module 'vava_voice' v1.3.0 prêt` ; médaillon revenu à la même portée ; dans Tribune, `W` quatre fois : le cercle montre toujours l'effet (les zones reviennent d'elles-mêmes par les abonnements de zone du core dans les 2 s ; le client redemande la limite de portée à son redémarrage, et réessaie toutes les 2 s, cinq fois au plus, si le serveur n'est pas encore prêt). |
| 2 | Éditeur ouvert : `restart vava_voice`. | Le panneau disparaît, la souris et le clavier reviennent au jeu (le module rend le focus à son arrêt). |
| 3 | A et B tous deux sur l'écran de sélection (se reconnecter) ; console du serveur : `restart vava_voice` ; ils parlent avant, pendant et après le redémarrage. | Ni l'un ni l'autre n'entend rien à aucun moment : à son arrêt, le module ne rend pas le micro des joueurs hors du jeu ; une fois prêt, il les tient toujours coupés. À l'apparition, la voix revient. |
| 4 | Redémarrer tout le serveur. | Les zones sont toujours là : liste de l'éditeur, cylindres, effet en jeu. |
| 5 | B sur l'écran de sélection ; console : `stop vava_voice` (sans `start`) ; B choisit son personnage et parle près de A. | Personne n'entend B : après un `stop` sans redémarrage, ou un redémarrage dont le setup échoue (console : déclaration refusée, pas de « prêt »), les joueurs alors en sélection restent muets jusqu'à leur reconnexion, même en jeu (choix de 1.2.1, voir le rapport T-008). Console : `start vava_voice`, « prêt » ; B, déjà en jeu, est de nouveau entendu sans reconnexion. |

## 9. Ce qu'il faut regarder dans la base

```sql
SELECT `id`, `label`, `x`, `y`, `z`, `radius`, `height`, `multiplier`, `updated_at` FROM `vava_voice_zones` ORDER BY `id`;
```

- Une ligne par zone scellée : centre lu par le serveur à l'endroit où se tenait A, arrondi au centimètre ; rayon et
  hauteur par pas de 0,5 ; `multiplier` parmi 0,5, 0,75, 1, 1,5, 2, 3 ; nom tel que tapé (espaces en trop retirés).
- Une modification change les valeurs et `updated_at` ; un recentrage change `x`, `y`, `z` ; une suppression retire
  la ligne ; une zone jamais scellée n'y est pas (3-16) ; deux « Doublon » trahiraient le défaut de 3-15.
- Le Journal du Registre garde « Zone de voix créée », « Zone de voix modifiée », « Zone de voix supprimée », avec
  zone, rayon, hauteur, effet (et « deplacee » pour un recentrage).

## 10. Resmon

| Moment | `vava_voice` |
|---|---|
| Au repos : en jeu, personne autour | 0,02 ms au plus (relevés toutes les 150, 250 et 500 ms, aucune boucle par image) |
| En parlant (`N`), B à côté | 0,02 ms au plus |
| Cercle au sol, 1,5 s après `W` | 0,15 ms au plus, puis retour au repos |
| Éditeur ouvert, quelques zones à moins de 150 m | 0,15 ms au plus |

## 11. Ce que je ne peux pas avoir vérifié hors jeu

- Le comportement réel des natives Mumble : distance d'écoute réglée par `MumbleSetTalkerProximity` sous
  `voice_useSendingRangeOnly` (2-5, 2-6), endroit exact où la voix s'éteint dans la marge de 2 m, atténuation du son 3D.
- L'état de la cible vocale pendant les quelques secondes où le module est arrêté (8-1), et le silence des joueurs en
  sélection pendant ce temps (8-3).
- La reprise du clavier quand le module s'arrête éditeur ouvert (8-2) ; après un redémarrage, l'arrivée de la liste
  des zones (8-1) et de la limite « à terre » (6-5), désormais redemandées par le client.
- Le seul envoi par `Entrée` dans l'éditeur (3-15) et la saisie d'un nom accentué de 40 signes dans CEF (3-6).
- L'aspect du cercle au sol (marqueur 25, posé 0,95 m sous la position du personnage) et des cylindres (marqueur 1).
- Le rendu de l'éditeur et du médaillon dans CEF : `modules/vava_voice/web/index.html` (ou `?zone=1` pour le
  formulaire) et `modules/vava_hud/web/index.html?values=0.8,0.6,0.3,0.75&talking=1` s'ouvrent dans un navigateur.
