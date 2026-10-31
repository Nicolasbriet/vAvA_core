# Outils de développement — procédure de test en jeu

Procédure pour vérifier en jeu la garde des ressources de `examples/` (T-024) : `vava_dev_characters` 1.3.0,
`vava_example` 1.2.0, `vava_example_items` 1.2.0, `vava_anim_test` 1.1.0, `vava_example_atelier` 1.0.0 (T-100,
§ 6) et `vava_example_combat` 1.0.0 (T-110, § 6 bis). Le point capital est la section 1 : **sans la convar `vava_env`, rien n'est offert**, même ressources démarrées. Puis, en mode développement : réservé au droit
`staff` du Registre ou à l'ACE `vava.dev`, et journalisé. Comptez 45 minutes, dont la moitié à deux ; les tests à
deux joueurs sont marqués **(2 joueurs)**. Un test se cite « developpement 2-3 ».

## 0. Préparation

1. **Préparation commune** : [LISEZMOI.md](LISEZMOI.md) (ordre de démarrage, compte du Conseil, consoles). Le Registre
   (`vava_admin`) doit tourner.
2. **Deux joueurs** : **A**, Souverain (préparation commune) ; **B**, hors du Conseil. Licence de B : Chancellerie →
   Joueurs → fiche de B (ligne `license:…`), écrite ici `<licB>`. Numéro de compte de B : `<B>`.
3. **La convar** : la section 1 se joue **sans** `vava_env`. Vérifier d'abord, console du serveur : `vava_env` (sans
   argument, la console affiche la valeur, à confirmer) ; s'il répond `dev`, retirer la ligne `set vava_env dev` du
   `server.cfg` (page server.cfg de la Chancellerie) et redémarrer le serveur.
4. **Ressources** : les quatre de `[vava-dev]` démarrées (Chancellerie → Ressources → Démarrer, ou console
   `ensure vava_example_items`, `ensure vava_dev_characters`, `ensure vava_example`, `ensure vava_anim_test`).
5. **Base** : gardez ouverte `SELECT COUNT(*), MIN(created_at) FROM vava_example_notes;`.

## 1. Sans la convar : rien n'est offert

| # | Faire | Attendu |
|---|---|---|
| 1 | Console du serveur au démarrage des quatre ressources. | Pour chacune, une ligne rouge `module '<nom>' v… refusé : setup a refusé le démarrage : mode développement absent (convar vava_env ≠ dev) : …`. Aucune ligne `mode développement : … ouverts au droit`. Les ressources restent « lancées » pour FiveM (page Ressources) : c'est attendu. |
| 2 | A (Souverain) : `/objet pain 5`, `/vie 100`, `/aterre`, `/besoins 100 100`, `/respawn`. | Chaque fois dans le chat : « appel impossible (outils de développement inactifs sur ce serveur (mode développement absent)) ». Rien ne change : besace, vie, faim, position. Console du serveur : `RPC inconnu` pour A (attendu). |
| 3 | A : `/perso liste`. | « perso : appel impossible (outils de développement inactifs …) » ; aucune liste. |
| 4 | A : `/note annonce essai`. Puis, console du serveur : `example_ping 1`. | F8 : `appel impossible : unknown_rpc` ; requête du § 0.5 inchangée. `example_ping` : commande inconnue (jamais enregistrée). |
| 5 | A : `/anim vava_sword_1h`, `/epee`, `/animstop`, `/animflags`. | Chaque fois : « outil inactif sur ce serveur (mode développement absent). » ; rien n'est joué, aucune liste de drapeaux. |
| 6 | A : `F1` (Codex), chercher « anim », « Tests ». | Aucune commande de `vava_anim_test` (chapitre « Tests » absent). |
| 7 | A : `/catalogue`, chercher la Miche de pain, la Bande de lin. | Absentes : `vava_example_items` n'a rien déclaré. Une miche gardée d'une session précédente n'apparaît pas dans la besace (gardée à part par l'inventaire, jamais effacée : elle revient au § 4). |

## 2. Mode développement : réservé et journalisé

Poser la convar sans redémarrer le serveur : console `set vava_env dev`, puis `restart vava_example_items`,
`restart vava_dev_characters`, `restart vava_example`, `restart vava_anim_test`.

| # | Faire | Attendu |
|---|---|---|
| 1 | Console du serveur. | Chaque module « prêt » ; pour `vava_dev_characters`, un avertissement `mode développement : /objet, /vie, … ouverts au droit « staff » et à l'ACE « vava.dev » — à ne jamais laisser sur un serveur ouvert au public`. |
| 2 | **(2 joueurs)** B : `/objet pain 5`, `/vie 100`, `/aterre`, `/besoins 100 100`, `/respawn`, `/perso liste`. | Chaque fois : « refusé (réservé au Conseil (droit staff) ou à l'ACE vava.dev) ». Rien ne change chez B. |
| 3 | **(2 joueurs)** B : `/anim vava_sword_1h`, `/animstop`, `/note annonce essai`. | « outil réservé au Conseil (droit staff) ou à l'ACE vava.dev. » ; rien n'est joué. `/note` : F8 `note refusée : not_allowed` ; requête du § 0.5 inchangée. |
| 4 | **(2 joueurs)** B : `F1`, chercher « anim ». | Rien : les commandes de l'outil d'animation ne paraissent qu'au Codex du Conseil qui a le droit `staff`. |
| 5 | A : `/objet pain 5`. | « pain × 5 ajouté » ; cinq miches dans la besace. Registre (`F10`) → Journal : ligne « Souverain <nom de A> · Outil de test : objet donné · objet : pain ; quantite : 5 ». |
| 6 | A : `/vie 40`, puis `/vie`. | Vie à 40 % ; Journal : « Outil de test : vie fixée · vie : 40 ». La lecture seule (`/vie`) n'ajoute **aucune** ligne. |
| 7 | A : `/besoins 50`, puis `/besoins`. | Faim 50, soif inchangée ; Journal : « Outil de test : besoins fixés · faim : 50 ; soif : - ». La lecture n'ajoute rien. |
| 8 | A : `/aterre`, puis se relever (`/vie 100` ou aide de B). | À terre ; Journal : « Outil de test : mise à terre · cause : test ». |
| 9 | A : `/respawn`. | Réapparition à la dernière position connue ; Journal : « Outil de test : réapparition · depuis : <x, y, z où se tenait A> ; vers : dernière position connue ». |
| 10 | A : `/perso liste`. | La liste des personnages de A, comme avant ; rien au Journal (actions du core). |
| 11 | A : `F1`, chapitre « Tests ». | `anim`, `animstop`, `animprop`, `animflags`, `epee`, lançables. |

## 3. ACE et rang, plafond des notes

| # | Faire | Attendu |
|---|---|---|
| 1 | **(2 joueurs)** Console : `add_ace identifier.license:<licB> vava.dev allow`. B : `/objet pomme 2`. | B reçoit deux pommes. Pas de ligne au Journal du Registre (B n'est pas du Conseil) ; console du serveur : `Outil de test : objet donné (joueur <idB>) — objet : pomme ; quantite : 2 (journal du Registre : not_staff)`. |
| 2 | **(2 joueurs)** B : `/epee`. | L'animation se joue (A la voit sur B). `/animstop` l'arrête. |
| 3 | **(2 joueurs)** Console : `remove_ace identifier.license:<licB> vava.dev allow`. B : `/objet pomme 1` tout de suite, puis `/animflags` dans la minute, puis après plus d'une minute. | `/objet` refusé aussitôt (le serveur relit l'ACE à chaque appel). `/animflags` répond encore pendant au plus 60 s (accès gardé par le client, `accessCacheMs`), puis est refusé. |
| 4 | **(2 joueurs)** Console : `vava_conseil <B> senechal`. B : `/objet pomme 1`. | Refusé : le Sénéchal n'a pas le droit `staff`. Remettre `vava_conseil <B> aucun`. |
| 5 | `examples/vava_example/config.lua` : `maxNotesPerCharacter = 3` (défaut `20`), console `restart vava_example`. A : `/note annonce essai`, quatre fois, à 5 s d'écart. | Les trois premières : `note #n publiée` (F8). La quatrième : `note refusée : too_many`. Requête du § 0.5 : 3 lignes pour ce personnage. |
| 6 | En base : `UPDATE vava_example_notes SET created_at = NOW() - INTERVAL 8 DAY;` puis console `restart vava_example`. | Console : `3 note(s) de plus de 7 jours retirée(s)` ; table vide ; `/note annonce essai` accepté de nouveau. Remettre `maxNotesPerCharacter = 20`. |
| 7 | A : console `set vava_env prod` (sans redémarrer aucune ressource). A : `/objet pain 1`, `/note annonce essai`, `/animflags` (après plus d'une minute). | Refusés aussitôt : la convar est relue à chaque appel (« réservé au Conseil… », `not_allowed`). Remettre `set vava_env dev`. |

## 4. Objets d'exemple

| # | Faire | Attendu |
|---|---|---|
| 1 | Mode développement (§ 2). A : `/catalogue`. | Les sept objets d'exemple (Miche de pain, Pomme, Chope de bière, Bande de lin, Épée courte, Bourse de cuir, Rouleau de corde) avec leurs images. L'Outre d'eau et l'Outre vide y sont aussi, mais elles viennent de `vava_provisions` (images de son dossier). |
| 2 | La miche gardée à part au § 1-7 (s'il y en avait une). | De retour à sa place dans la besace, sans reconnexion. |
| 3 | A, une miche en besace, se déconnecte. Console : `set vava_env prod`, `restart vava_example_items`. A se reconnecte, `I`. | Console : `module 'vava_example_items' … refusé : … mode développement absent`, puis au chargement de A `conteneur #n : objet #m (pain) sans place ou sans définition, conservé à part`. La miche n'est pas dans la besace ; sa ligne est toujours en base. |
| 4 | Console : `set vava_env dev`, `restart vava_example_items`. A : `I`. | La miche est revenue à sa place, sans reconnexion (`… pile(s) de 'pain' replacée(s)`). |
| 5 | Console : `set vava_env prod` (sans redémarrer `vava_example_items`), puis `restart vava_inventory`. | Console : `[vava_example_items] objets non redéclarés : mode développement absent …` ; les objets d'exemple ne reviennent pas au catalogue. Remettre `set vava_env dev`, `restart vava_example_items`. |

## 5. Arrêt de l'outil d'animation

| # | Faire | Attendu |
|---|---|---|
| 1 | A : `/epee`, puis console `stop vava_anim_test`. | L'animation s'arrête, l'accessoire éventuel (`/animprop`) disparaît. |
| 2 | A : `/aterre` (outil de `vava_dev_characters`), puis console `ensure vava_anim_test` et `stop vava_anim_test`. | A reste couché : l'arrêt de l'outil ne coupe pas une animation qu'il n'a pas jouée. Se relever ensuite. |

## 6. Exemple de l'Atelier (`vava_example_atelier` 1.1.0, T-100 et T-101)

Procédure complète de l'Atelier : [atelier.md](atelier.md). Ici, la seule garde de l'exemple.

| # | Faire | Attendu |
|---|---|---|
| 1 | Sans `vava_env` (§ 1) : `ensure vava_atelier`, `ensure vava_example_atelier`. | Console : `module 'vava_example_atelier' v1.1.0 refusé : … mode développement absent (convar vava_env ≠ dev) : aucun atelier d'exemple déclaré`. A : `F9` : aucune carte « Panneaux du bourg (exemple) » ni « Proclamations (exemple) ». `/atelier_exemple journal panneaux essai` : commande inconnue. |
| 2 | `set vava_env dev`, `restart vava_example_atelier`. | Console : `atelier 'vava_example_atelier:panneaux' déclaré par vava_example_atelier (droit metiers, gardé)`, la même pour `proclamations` (droit `staff`), leurs synchronisations (`… fiches en base …`), puis l'avertissement `mode développement : ateliers d'exemple déclarés et /atelier_exemple ouverte — jamais sur un serveur ouvert au public`. |
| 3 | **(2 joueurs)** B (hors du Conseil) : `/atelier_exemple journal panneaux essai`. | « refusé : cet atelier ne vous est pas ouvert. » ; aucune ligne au journal du Conseil. |
| 4 | Console : `set vava_env prod` (sans redémarrer). A : `/atelier_exemple journal panneaux essai`. | « outil inactif sur ce serveur (mode développement absent). » : la convar est relue à chaque appel. Les ateliers d'exemple restent déclarés jusqu'au redémarrage de la ressource. Remettre `set vava_env dev`. |
| 5 | B (hors du Conseil), près du « Panneau de la place » : `/atelier_exemple lire`, deux fois de suite. | Le titre et le texte du panneau ; la seconde fois : « Doucement : patientez un instant. ». Loin de tout panneau : « Aucun panneau à portée de lecture. » |
| 6 | Console : `set vava_example_refuse 1` avec `vava_env prod`, puis publier un panneau (A, Atelier). | Le refus d'essai n'agit qu'en mode développement : la publication passe. Remettre `set vava_example_refuse 0` et `set vava_env dev`. |

## 6 bis. Essai de la chaîne de dégâts (`vava_example_combat` 1.0.0, T-110)

Procédure complète de la chaîne : [combat.md](combat.md) § 1. Ici, la seule garde de l'essai.

| # | Faire | Attendu |
|---|---|---|
| 1 | Sans `vava_env` (§ 1) : `ensure vava_example_combat`. | Console : `module 'vava_example_combat' v1.0.0 refusé : … mode développement absent (convar vava_env ≠ dev) : rien n'est offert`. `/frapper`, `/chaine` : commandes inconnues ; aucun modificateur `vava_example_combat:…` déclaré. |
| 2 | `set vava_env dev`, `restart vava_example_combat`. | Console : trois lignes « modificateur 'vava_example_combat:…' déclaré », puis l'avertissement `mode développement : /frapper, /esquive, /bouclier, /resistance, /chaine et les modificateurs d'essai ouverts au droit « staff » et à l'ACE « vava.dev » — à ne jamais laisser sur un serveur ouvert au public`. |
| 3 | **(2 joueurs)** C, sans droit ni ACE : `/frapper <A> 10`, `/arme pistolet`, `/tricher`. | « refusé : outil d'essai réservé… » pour la première ; « refusé (not_allowed). » pour les deux autres ; rien ne change chez A ni chez C. |
| 4 | A : `/frapper <B> 5` ; Registre → Journal. | Ligne « Essai de combat : coup porté » (cible, points, type, résultat). |
| 5 | Console : `set vava_env prod` (sans redémarrer). A : `/frapper <B> 5`, `/arme couteau`. | Refusés : la convar est relue à chaque appel. Les modificateurs restent déclarés jusqu'au redémarrage de la ressource (et ne sont plus redéclarés au redémarrage de `vava_health`). Remettre `set vava_env dev`. |

## 7. Fin du test

Retirer `set vava_env dev` s'il a été posé pour l'occasion, `remove_ace` pour B s'il reste, et arrêter les ressources
de `[vava-dev]` si le serveur doit servir à autre chose.
