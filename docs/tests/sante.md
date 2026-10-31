# Santé — procédure de test en jeu

Procédure pour vérifier en jeu `vava_health` 1.3.0 : vie tenue par le serveur, blessures, mise à terre décidée par le serveur,
relève par un autre joueur, retour au lieu de soins, soins par objets et par le Conseil, et ses liens avec les
besoins, l'inventaire, la voix et la magie. Comptez 1 h 15, dont 30 min à deux ; les tests à deux joueurs sont marqués
**(2 joueurs)**. Un test se cite « sante 5-3 ». Le ligotage n'existe pas encore : il n'est pas testé. La chaîne de
dégâts (coups, modificateurs, coups natifs annulés, client qui ment) a sa propre procédure : [combat.md](combat.md) § 1.

## 0. Préparation

1. **Préparation commune** : [LISEZMOI.md](LISEZMOI.md) (ordre de démarrage, compte du Conseil, catalogue, consoles,
   resmon, remontée des écarts).
2. **Outils de test** : `vava_dev_characters` et `vava_example_items`, comme en [besoins 0.2](besoins.md) (mode
   développement exigé). Commandes utilisées ici par les deux joueurs : B, hors du Conseil, a besoin de l'ACE
   (`add_ace identifier.license:<licence de B> vava.dev allow` en console). `/vie` (« vie 60 % » ou « à terre »), `/vie <pourcentage>`, `/aterre`,
   `/besoins [faim] [soif]`, `/perso quitter`. Après `/vie <n>`, relire par `/vie` : la réponse de la commande qui
   fixe peut donner l'ancienne valeur.
3. **Objets** (`/catalogue` ou `/objet`) : `bandage` ×6 (Bande de lin, +20 % de vie), `potion_de_soin` ×2 (+20 %),
   `pain` ×2, `hache_fer` ×1. Une miche sur le raccourci `1`.
4. **Se blesser sans commande** : Vol libre (`F2`, droit `tools`), monter de quelques mètres (`Espace`), couper le vol :
   la chute blesse ; de très haut, elle met à terre. Invulnérabilité (Registre → Outils) éteinte.
5. **Lire la vie** : médaillon Santé (le premier en bas à gauche ; ambre à 30 % et moins, rouge pulsant à 10 % et
   moins), `/vie`, ou Registre (`F10`) → Joueurs → vous : Vie en pour cent, étiquette « À terre ».
6. **Réglages pour aller vite** (facultatif, `vava_health/config.lua`, puis `restart vava_health` quand personne n'est
   à terre, à remettre après) :
   - `downed.giveUpAfterMs = 20000` (défaut `180000`) : rendre l'âme possible après 20 s au lieu de 3 min ;
   - `downed.autoRespawnMs = 60000` (défaut `600000`) : porté au lieu de soins après 1 min au lieu de 10.
   Dérouler au moins une fois les tests 4-1 à 4-5 avec les valeurs par défaut (3:00 et 10:00).
7. **Lieux de soins** (provisoires, dans la config) : (298.6, −584.5, 43.3) et (1839.0, 3672.9, 34.3) ; depuis le point
   d'apparition par défaut (−269, −955), le plus proche est le premier.

## 1. Vie et blessures

La vie de 0 à 100 % est la part de la vie GTA au-dessus du seuil de mise à terre (100). Elle est tenue par le
serveur (1.3.0) : il lit le ped toutes les 500 ms pour les pertes natives (chute, noyade) et l'enregistre dans le
personnage à chaque soin et transition, au plus toutes les 10 s après des pertes ; la récupération automatique de GTA
est coupée (`naturalRegen = false`).

| # | Faire | Attendu |
|---|---|---|
| 1 | Personnage neuf : apparaître. | Médaillon Santé plein, avant Faim et Soif. `/vie` → « vie 100 % ». |
| 2 | Chute de quelques mètres (§ 0.4). | L'anneau baisse dans la demi-seconde ; `/vie` donne la même valeur. |
| 3 | Attendre 2 min sans rien faire. | La vie ne remonte pas. |
| 4 | `/vie 25`, `/vie` ; puis `/vie 8`, `/vie`. | « vie 25 % », anneau ambre ; « vie 8 % », anneau rouge et pulsant. |
| 5 | `/vie 40` ; double-clic sur une bande de lin. | Vie 60 % ; une bande de moins ; aucun geste (seuls les objets de faim et de soif en jouent). La fiche de la bande n'annonce pas son effet (la fiche ne liste que Faim et Soif). |
| 6 | `/vie 90` ; potion de soin. | Vie 100 % (plafonnée), potion consommée. |
| 7 | Vie 98 % ou plus : une bande. | Refusé : « Vous n'êtes pas blessé. » ; la bande reste. À 97 % : acceptée, 100 %. |
| 8 | `/vie 40` ; trois doubles-clics rapides sur les bandes. | Les trois passent (100 %, plafond) : aucun délai entre deux soins, seul le débit de l'inventaire (4, puis 1 par seconde) borne. |

## 2. Mise à terre

Le joueur est mis à terre par le serveur dès que sa vie atteint 0 (coup, sort, faim, `/vie 0` : aussitôt) ; une
chute est lue au plus 500 ms après. Délais : rendre l'âme possible après 3 min
(`giveUpAfterMs`), porté au lieu de soins d'office après 10 min (`autoRespawnMs`). Le temps à terre n'est compté que
connecté et apparu.

| # | Faire | Attendu |
|---|---|---|
| 1 | Chute mortelle (§ 0.4), ou `/aterre`. | Le personnage s'effondre et reste au sol ; ni fondu au noir, ni retour automatique de GTA ; l'écran voilé de mort de GTA s'efface en 1,5 s au plus. Voile rouge sombre sur l'écran, encart en bas au centre : « Vous êtes à terre », « Quelqu'un peut vous relever. », « Vous pourrez rendre l'âme dans 3:00 » (décompte à la seconde), « Porté au lieu de soins dans 10:00 ». Médaillon Santé vide, rouge. `/vie` → « à terre ». |
| 2 | Bouger la souris, les touches de déplacement. | La caméra reste libre (l'écran ne prend pas le clavier) ; le personnage ne se relève pas. |
| 3 | Attendre 1 min en regardant le décompte. | Décompte régulier ; il se recale toutes les 10 s sur le serveur (un saut d'une seconde au plus). |
| 4 | Registre (`F10`, il s'ouvre à terre) → Joueurs → vous. | Étiquette « À terre », Vie 0 %. |
| 5 | Codex (`F1`) → chapitre « Santé ». | « Relever une personne à terre » (`G`) et « Rendre l'âme (à terre, maintenir) » (`E`). |
| 6 | Se faire relever (Registre, § 6-2) ; `/vie 60`, puis `/vie 0`. | Le personnage s'effondre aussitôt et reste au sol, sous l'écran à terre (mis à terre par le serveur sans attendre la lecture du ped, raison `api` ; le client le couche à une vie GTA de 0, jamais au seuil de 100) ; médaillon vide, rouge ; `/vie` → « à terre ». Jamais debout sous l'écran à terre : à me remonter s'il l'est. |

## 3. Ce qui est bloqué à terre

| # | Faire | Attendu |
|---|---|---|
| 1 | `I`. | L'inventaire s'ouvre : consultation seulement. |
| 2 | Déplacer un objet dans la besace, diviser une pile, jeter un objet au sol. | Chaque geste refusé dans l'inventaire : « Vous êtes à terre. » ; rien ne bouge. |
| 3 | Double-clic sur une miche, sur une bande ; inventaire fermé, touche `1`. | « Vous êtes à terre. » (notification pour le raccourci) ; rien n'est consommé. |
| 4 | Double-clic sur la hache (prendre en main) ; si un objet était déjà en main, Mains → Reposer. | « Vous êtes à terre. » pour les deux. Un outil placé en raccourci (`1` à `5`) : même refus, notifié « Vous êtes à terre. » (`vava_inventory` 1.6.3). |
| 5 | `G`. | Rien : on ne relève personne en étant à terre. |
| 6 | Personnage mage, sort choisi dans la roue (`Tab`) : clic gauche. | « Vous êtes à terre. » |
| 7 | **(2 joueurs)** Touche de portée de la voix `Z` (marquée W sur un clavier AZERTY). | Seules Chuchoter (1,5 m) et Parler (5 m) restent ; la portée d'avant revient au réveil ou au lieu de soins. |
| 8 | Faim et soif. | Figées (§ 7-1). |
| 9 | Hache en main près d'un chêne de la Forêt de Brume (métiers 3.2) : `/aterre`, puis `E`. Même chose près du fourneau, d'un emplacement de champ, d'un puits, d'un grenier. | L'invite des métiers disparaît dans la seconde ; `E` ne fait que rendre l'âme (« Pas encore : tenez bon. » avant le délai) : aucune récolte, aucun menu, aucun geste, aucun message des métiers. Relevé, l'invite revient. Un grenier, un coffre, une fouille ou un sac ouvert à la chute se ferme aussitôt (`metiers` 5-13). |
| 10 | Hache en main, lancer une récolte (barre en cours), puis `/aterre` avant la fin. | Rien de pris, la charge du nœud reste : le serveur refuse la fin (« Vous êtes à terre. » à la fin de la barre), ou le geste s'interrompt si le corps a glissé en tombant. Même chose pendant une pièce au fourneau (station libérée, rien consommé) et pendant un semis. |

## 4. Rendre l'âme et lieu de soins

| # | Faire | Attendu |
|---|---|---|
| 1 | À terre, `E` avant la fin du premier décompte. | « Pas encore : tenez bon. » à chaque appui, rien d'autre. |
| 2 | Attendre que le décompte arrive à 0:00. | La ligne « Vous pourrez rendre l'âme dans … » cède la place à la touche `E` (celle du joueur) et « Maintenir pour rendre l'âme » ; « Porté au lieu de soins dans 7:00 » continue. |
| 3 | Maintenir `E` une seconde, puis lâcher. | Le trait sous la touche se remplit, puis se vide au relâchement ; rien ne se passe. |
| 4 | Maintenir `E` 3 s. | Fondu, apparition debout au lieu de soins le plus proche (298.6, −584.5 depuis le bourg) ; « On vous a porté jusqu'au lieu de soins. » ; Santé 50 % ; écran levé ; plus d'étiquette « À terre » au Registre. |
| 5 | Retomber et ne rien faire jusqu'au bout du second décompte. | À 0:00 : porté au lieu de soins, même message, 50 %. |
| 6 | Au lieu de soins : `/vie`, puis quitter et revenir. | « vie 50 % » ; au retour, debout au lieu de soins, 50 %. |
| 7 | Paramètres → Raccourcis → FiveM : « Rendre l'âme (à terre, maintenir) » sur `R` ; retomber à terre (réglage court, § 0.6). | L'encart montre `R` dès l'écran à terre ; maintenir `R` 3 s porte au lieu de soins. Remettre `E`. |

## 5. Relever un autre joueur (2 joueurs)

A relève, B est à terre (`/aterre` tapé par B, ou chute). Le serveur choisit la personne à terre la plus proche dans
un rayon de 2 m (mesuré en 3D d'un personnage debout à un corps couché : se placer tout contre) ; geste de 8 s ;
distance revérifiée à la fin seulement, avec 1 m de tolérance (3 m) ; B relevé avec 25 %.

| # | Faire | Attendu |
|---|---|---|
| 1 | A à 3 m de B : `G`. | Chez A : « Personne n'est à terre près de vous. ». Rien chez B. |
| 2 | A tout contre B : `G`. | A : geste penché de soignant ; en bas au centre, « Vous relevez quelqu'un… » et une barre de 8 s. B : « Quelqu'un vous relève… » sous le titre, barre de 8 s ; le nom de A n'apparaît nulle part. |
| 3 | Attendre la fin des 8 s. | A : « Vous avez relevé quelqu'un. ». B : se relève sur place, écran levé, « Vous reprenez vos esprits. », Santé 25 % (ambre) ; `/vie` → « vie 25 % » ; sa portée de voix revient. |
| 4 | A : `G` près de B debout. | « Personne n'est à terre près de vous. » |
| 5 | B de nouveau à terre ; A lance la relève puis tente de s'éloigner à plus de 3 m. | Le geste immobilise probablement A (animation plein corps, à confirmer). S'il parvient à s'éloigner : les barres vont au bout, puis A lit « Le geste a été interrompu. », B reste à terre et relit « Quelqu'un peut vous relever. ». |
| 6 | A lance la relève ; B quitte (`F8` → `quit`). | A : « Le geste a été interrompu. » aussitôt. B, revenu : toujours à terre. |
| 7 | A lance la relève, puis quitte. | B : la barre disparaît, « Quelqu'un peut vous relever. » ; B reste à terre. |
| 8 | A lance la relève, puis tape `/aterre`. | Les deux gestes annulés : A, à terre à son tour, lit « Le geste a été interrompu. » ; B relit « Quelqu'un peut vous relever. ». |
| 9 | Réglage court (§ 0.6) : A lance la relève alors que B peut rendre l'âme ; B maintient `E` 3 s. | B porté au lieu de soins ; A : « Le geste a été interrompu. ». |
| 10 | A lance la relève ; un membre du Conseil soigne B depuis le Registre (§ 6-3). | B relevé à 100 % ; A : « Le geste a été interrompu. ». |
| 11 | A et B à terre côte à côte. | `G` sans effet chez l'un comme chez l'autre. |
| 12 | (3 joueurs, facultatif) Pendant que A relève B, C tout contre B : `G`. | Chez C : « Personne n'est à terre près de vous. » (une personne déjà prise en charge n'est pas proposée). |
| 13 | (Facultatif) `assist.item = 'bandage'` (défaut `nil`), `restart vava_health`. A sans bande : `G` ; puis avec une bande ; puis en jetant la bande pendant le geste. | Sans : « Il vous faut de quoi panser ses plaies. ». Avec : relève normale, une bande retirée à la fin. Jetée en route : « Le geste a été interrompu. », B reste à terre. |

## 6. Soins du Conseil

Registre (`F10`) → Joueurs → le joueur → groupe Soins : Soigner, Nourrir. Droit `heal`, dès Gardien ; sur soi-même
aussi. Soigner relève à 100 % un joueur à terre, ou rend toute sa vie à un joueur debout.

| # | Faire | Attendu |
|---|---|---|
| 1 | `/vie 40` ; Registre → vous → Soigner. | « C'est fait. » ; Santé 100 %, fiche Vie 100 % ; aucun message dans le jeu ; onglet Journal : « a soigné », détails « releve : non ». |
| 2 | À terre : Registre → vous → Soigner. | Relevé sur place, 100 %, « Vous reprenez vos esprits. », écran levé ; journal « releve : oui ». |
| 3 | **(2 joueurs)** B à terre ; A → B → Soigner. | B relevé sur place à 100 %, « Vous reprenez vos esprits. » ; sa portée de voix revient. |
| 4 | **(2 joueurs)** B sur l'écran de sélection ; A → B → Soigner. | « Aucun personnage chargé. » |
| 5 | (Facultatif) Chancellerie → Joueurs → le joueur → Soigner. | « Soigné. » ; même effet qu'au Registre. |

## 7. Santé et besoins

| # | Faire | Attendu |
|---|---|---|
| 1 | `/besoins 50 50` ; `/aterre` ; `/besoins` ; 3 min plus tard, `/besoins` ; se faire relever (Registre), et 1 min après, `/besoins`. | Mêmes valeurs les deux premières fois : faim et soif figées à terre. Après le réveil, une seule minute de baisse (−0,4 et −0,6) : le temps passé à terre n'est pas rattrapé. |
| 2 | Faim et soif à 0, vie 20 % ([besoins 4-3](besoins.md)). | Le personnage tombe ; à terre, la vie ne baisse plus. |
| 3 | **(2 joueurs)** A relève B (25 %), faim et soif de B toujours à 0. | Les pertes reprennent (−6 % par passage pour un ped de 200 points) : B retombe au 5e passage (5 min au plus). |
| 4 | À terre : manger une miche. | « Vous êtes à terre. », miche gardée. |

## 8. Déconnexion et reconnexion

| # | Faire | Attendu |
|---|---|---|
| 1 | `/vie 40` ; quitter (`F8` → `quit`) ; revenir. | Santé 40 % dès l'apparition. |
| 2 | À terre depuis une minute (« rendre l'âme dans 2:00 ») : quitter ; attendre 5 min ; revenir. | Réapparition à la dernière position relevée, aussitôt à terre ; décomptes repris où ils en étaient (vers 2:00 et 9:00, à quelques secondes près) : le temps hors ligne ne compte pas. |
| 3 | À terre : `/perso quitter`, puis reprendre le personnage. | Même chose : toujours à terre, décomptes repris. |
| 4 | **(2 joueurs)** B revenu à terre (test 2) : A le relève. | Relève normale (5-2, 5-3). |
| 5 | (Facultatif) Chute mortelle, puis `quit` dans la seconde de l'impact. | Au retour : à terre (la vie est relue au départ quand le jeu la donne encore). Si l'on revient debout, noter le délai entre l'impact et le départ. |

## 9. Redémarrage du module

| # | Faire | Attendu |
|---|---|---|
| 1 | Debout à 60 % : console `restart vava_health`. | Médaillon Santé absent un instant, puis de retour à 60 % ; toujours aucune récupération de vie. |
| 2 | À terre : `restart vava_health`. | L'écran à terre disparaît puis revient ; toujours à terre ; décomptes repris d'après le dernier enregistrement (10 s en arrière au plus, le temps de l'arrêt non compté) ; inventaire toujours refusé. Médaillon Santé de retour dans la demi-seconde, vide et rouge. |
| 3 | **(2 joueurs)** Pendant une relève : `restart vava_health`. | La relève est perdue : bandeau et barres disparaissent, l'animation de A s'achève d'elle-même, B reste à terre. Un nouvel appui sur `G` relance une relève complète de 8 s. |
| 4 | Debout, puis à terre : `restart vava_hud`. | Médaillon Santé de retour en moins d'une demi-seconde (vide et rouge à terre). |
| 5 | Après un `restart`, `/vie`. | Si la commande ne répond plus, `ensure vava_dev_characters` (il dépend de `vava_health` : à confirmer). |

## 10. Tentatives de triche

| # | Faire | Attendu |
|---|---|---|
| 1 | Relever à distance : A à 5 m de B à terre, `G` ; puis console `F8` → `vava_health_assist`. | « Personne n'est à terre près de vous. » les deux fois : le serveur lit lui-même les positions. |
| 2 | A tout contre B à terre : `G` dix fois en 2 s. | Une seule relève démarre ; les deux appuis suivants : « Quelqu'un s'en occupe déjà. » ; au-delà : « Doucement… » (débit : 3 appuis, puis 1 toutes les 2 s). B est relevé une fois, après 8 s. |
| 3 | À terre, avant le délai : `E` dix fois ; puis `F8` → `+vava_health_giveup`. | « Pas encore : tenez bon. » à chaque fois ; aucun retour au lieu de soins (le serveur revérifie le délai). |
| 4 | À terre : quitter pour revenir debout ; changer de personnage et revenir. | Toujours à terre (8-2, 8-3). |
| 5 | À terre : manger, se soigner, prendre une hache, jeter un objet. | Tout refusé : « Vous êtes à terre. » (§ 3). |
| 6 | À terre : `G` pour se relever soi-même. | Rien. |
| 7 | **(2 joueurs)** Coups natifs : A frappe B au poing, puis avec une arme vanilla. | Aucune perte chez B : [combat 1-15 et 1-16](combat.md). |
| 8 | **(2 joueurs)** A lance une explosion vanilla près de B. | Rien chez B : [combat 1-17](combat.md). |
| 9 | B remet sa vie GTA au maximum sur son client (`/tricher` de `vava_example_combat`). | Vie du serveur remise en 2 à 3 s, une ligne de console : [combat 1-21](combat.md). |

## 11. Resmon et base

| Ressource | Au repos | Pendant l'action |
|---|---|---|
| `vava_health` | 0,01 ms au plus : une lecture de la vie toutes les 500 ms pour le médaillon, aucune boucle à chaque image | À terre : 0,01 ms au plus (la lecture s'arrête, le décompte est tenu par la page) ; relève : 0,01 ms au plus (un fil court charge l'animation) |

Cibles : 0,02 ms au repos, 0,15 ms en action.

```sql
SELECT id, first_name, last_name, JSON_EXTRACT(data, '$."vava_health:state"') AS sante
FROM vava_characters WHERE deleted_at IS NULL;

SELECT created_at, actor_label, action, target_label, details
FROM vava_admin_logs WHERE action IN ('heal', 'feed') ORDER BY id DESC LIMIT 10;
```

- Debout : `{"health": 0.4, "downed": false, "downedFor": 0}` ; à terre : `"downed": true`, `downedFor` en ms (borné
  à 600000) ; après le lieu de soins : `"health": 0.5`.
- Le personnage est mis à jour à chaque transition, toutes les 10 s si la vie a bougé d'au moins 1 % (ou à terre), et
  au départ ; la base suit toutes les 5 min et à chaque départ, `vava_saveall` dans la console du serveur pour forcer.
- Aucune table propre au module ; actions du Conseil dans `vava_admin_logs` (`heal`, détails `releve : oui|non` ;
  `feed`).

## 12. Ce que je ne peux pas avoir vérifié hors jeu

- **Vie tenue par le serveur (1.3.0)** : la vie lue par `/vie`, le Registre et les soins est celle du serveur ; le ped
  ne sert plus qu'à lire les pertes natives et à corriger un client en retard. Une ligne « vie du client au-dessus de
  celle du serveur » ou « apparition non confirmée après 20 s » dans la console du serveur, sans client modifié, est à
  me remonter ([combat](combat.md) § 2).
- Après un soin (`/vie`, bande, Registre), la vie ne doit jamais redescendre seule dans les 3 s (fenêtre
  d'application, `combat` 1-7).

- **Le seuil, à regarder en premier** : `/vie 0`, la dernière perte de faim ou de soif et un sort qui vide la vie
  couchent maintenant le ped à une vie GTA de 0 ; toute mise à terre envoie l'ordre de le coucher, et un ped resté au
  seuil (100) ou au-dessus est recouché toutes les 5 s. Ce que GTA fait à 100 ne compte donc plus ; à confirmer en jeu
  (2-6, 7-2) : le personnage tombe aussitôt et ne se relève jamais seul. Une ligne `joueur N debout sans avoir été
  relevé : remis à terre` dans la console du serveur, sans client modifié, est à me remonter.
- Les réglages de mort de GTA (`PauseDeathArrestRestart`, `IgnoreNextRestart`, `SetFadeOutAfterDeath`) : aucun retour
  automatique, aucun fondu.
- La relève sur place (`NetworkResurrectLocalPlayer`) : même endroit, sans décalage ni chute.
- Le geste du soignant (`amb@medic@standing@tendtodead@base`, flag 1) : bloque-t-il la marche (5-5) ?
- Les distances en 3D avec un corps couché : 2 m pour commencer, 3 m à la fin.
- La remise à terre d'un client qui se relève seul (toutes les 5 s ; une ligne `joueur N debout sans avoir été relevé :
  remis à terre` par mise à terre dans la console du serveur) : il faut un client modifié pour la provoquer.
- L'objet tenu avant la chute reste-t-il visible en main, couché avec le corps ?
- La touche affichée sur l'écran à terre est lue par `GetControlInstructionalButton` (comme le Codex) : sûre pour une
  lettre ; pour une touche sans lettre (souris, pavé), l'écran revient à celle de la config (4-7).
- Le rendu de l'écran : `modules/vava_health/web/index.html?state=downed` (ou `ready`, `patient`, `holding`, `assist`)
  dans un navigateur.
