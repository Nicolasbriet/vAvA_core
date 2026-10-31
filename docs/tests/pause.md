# La bannière du royaume — procédure de test en jeu

Procédure pour vérifier en jeu `vava_pause` 1.0.0 (menu pause d'Eldoria, T-145) et ce qu'il demande aux autres modules :
`vava_codex` 1.6.0 (Codex en panneau), `vava_admin` 1.9.0 (demandes au Conseil), `vava_hud` 1.5.0 et `vava_voice` 1.4.0
(réglages). Elle suit la spec `docs/plan/specs/T-145.md` § 11.2, avec les décisions du porteur du projet du 31 octobre
2026 (bannière réduite à terre ; auteur d'un signalement visible du Conseil ; combat 10 s). Comptez une heure ; les
tests à plusieurs sont marqués **(2 joueurs)** ou **(3 joueurs)**. Un test se cite « pause 3-2 ». Préparation commune,
mesure du resmon et remontée des écarts : [LISEZMOI.md](LISEZMOI.md).

## 0. Préparation

1. **Ordre de démarrage** : celui du `README.md` racine, `vava_pause` juste après `vava_codex` et avant `vava_arrival`
   (la Chancellerie l'écrit seule). Console : `module 'vava_pause' v1.0.0 prêt`.
2. **Compte du Souverain** (`vava_conseil <compte> souverain`) ; un second joueur **B** pour les tests à deux, un
   troisième **C** pour 7-6.
3. `vava_admin` 1.9.0 avec `requests.callers = { 'vava_pause' }` (défaut). Un `config.lua` d'avant (gardé par une
   mise à jour) écrit au démarrage « config.lua sans « requests » » : la bannière ne peut alors pas écrire au Conseil.

## 1. Ouvrir et fermer

| # | Faire | Attendu |
|---|---|---|
| 1-1 | En jeu, appuyer sur Échap. | La bannière se déroule en ≈ 0,3 s ; le menu de GTA n'apparaît jamais, même une image. Le HUD (jauges) disparaît, les notifications restent. |
| 1-2 | Appuyer sur P ; puis Start à la manette. | Même bannière. |
| 1-3 | Échap ; rouvrir, cliquer « Reprendre » ; rouvrir, B à la manette. | La bannière se replie, la main revient au jeu, le HUD revient. |
| 1-4 | À l'écran de sélection du personnage, Échap. | Le menu de GTA s'ouvre (la bannière n'existe qu'en jeu). |
| 1-5 | Ouvrir l'inventaire, le fermer par Échap ; idem Codex (F1) et livre des compétences (K). | L'interface se ferme ; la bannière ne s'ouvre pas dans la foulée. |
| 1-6 | `resmon 1`, personnage immobile, bannière fermée, 30 s. | `vava_pause` ≤ 0,02 ms. Bannière ouverte : ≤ 0,15 ms. |
| 1-7 | `restart vava_pause` bannière ouverte. | Souris et clavier rendus ; HUD réaffiché ; Échap rouvre la bannière. |

## 2. Quand la bannière ne s'ouvre pas, ou se réduit

| # | Faire | Attendu |
|---|---|---|
| 2-1 | Se mettre à terre (chute d'une hauteur, ou `/aterre` de `vava_dev_characters` sur un serveur de test), attendre 10 s, Échap. | La bannière **réduite** se déroule : Reprendre, Paramètres du jeu, Quitter Eldoria seulement (les autres rubriques absentes). Quitter fonctionne (9-2). |
| 2-2 | **(2 joueurs)** B frappe A (arme ou sort) ; A appuie sur Échap aussitôt, puis 11 s après. Pareil pour B, qui a frappé. | D'abord « Pas de répit au cœur d'un combat : la bannière attendra. » ; ensuite la bannière s'ouvre. |
| 2-3 | **(2 joueurs)** A ouvre la bannière ; B le frappe. | La bannière de A se replie : « Vous êtes pris à partie : la bannière se replie. » |
| 2-4 | `devCuffCommand = 'essai_ligote'` (config_client.lua), `restart vava_pause`, `/essai_ligote`, Échap ; `/essai_ligote` de nouveau ; remettre `''` ensuite. | « Les mains liées, vous ne pouvez déployer la bannière. » ; une fois déliée, la bannière s'ouvre. Ligoté bannière ouverte : elle se replie avec le même message. |
| 2-5 | Une chute n'est pas un combat : sauter d'un muret (perte de vie native, sans tomber à terre), Échap aussitôt. | La bannière s'ouvre. |
| 2-6 | Spammer Échap pendant un refus (combat). | Le message ne revient pas plus d'une fois toutes les 3 s. |

## 3. Personnage

| # | Faire | Attendu |
|---|---|---|
| 3-1 | Rubrique Personnage ; comparer avec `/metiers voir <vous>`. | Nom, savoir-faire, rangs et niveaux identiques ; santé, faim, soif comme le HUD. |
| 3-2 | « voir les treize savoir-faire ». | Les treize lignes, défilantes. |
| 3-3 | « ouvrir la fiche complète ». | La bannière se ferme, le livre des compétences s'ouvre. |
| 3-4 | `stop vava_skills` ; rubrique Personnage ; `ensure vava_skills`. | Aucun savoir-faire, bouton de la fiche masqué ; tout revient à l'ouverture suivante. |

## 4. Codex en panneau

| # | Faire | Attendu |
|---|---|---|
| 4-1 | Rubrique Codex. | Le livre s'ouvre à droite de la bannière, bannière visible ; recherche, chapitres, lecture fonctionnent au clavier. |
| 4-2 | Échap dans le Codex (jusqu'à le fermer). | Retour à la bannière, focus repris, rubrique d'avant. |
| 4-3 | Depuis le Codex en panneau, lancer une commande qui ouvre une interface (`/conseil`, Souverain). | Codex et bannière fermés, l'interface lancée a la main. |
| 4-4 | `stop vava_codex` ; rubrique Codex ; `ensure vava_codex`. | « Le Codex est fermé pour l'instant. » ; puis il revient. |
| 4-5 | Codex en panneau ouvert : B à la manette ; Start. | B referme le livre (retour à la bannière) ; Start replie tout. |
| 4-6 | `restart vava_pause` Codex en panneau ouvert. | Livre et bannière fermés, souris et clavier rendus. |

## 5. Carte et paramètres du jeu

| # | Faire | Attendu |
|---|---|---|
| 5-1 | Rubrique Carte → « ouvrir la carte (provisoire) ». | Carte de GTA ; Échap la ferme et la bannière revient sur Carte. |
| 5-2 | Paramètres du jeu. | Les paramètres de GTA ; à leur fermeture, retour à la bannière. |
| 5-3 | Réglages → Touches → « changer une touche ». | Les raccourcis de FiveM (ou, si le nom du menu ne répond pas, les paramètres du jeu après 1,5 s) ; retour à la bannière. |

## 6. Réglages

| # | Faire | Attendu |
|---|---|---|
| 6-1 | Réglages → Interface → 115 %. | Bannière et HUD grandissent aussitôt. |
| 6-2 | Durée des notifications : Longue ; se faire notifier (manger). | Message visible ≈ 7 s au lieu de 4,5. |
| 6-3 | Voix → Cercle de portée : Désactivé ; changer de portée. | Aucun cercle au sol ; la portée change quand même. Réactivé : le cercle revient. |
| 6-4 | Se déconnecter, revenir (autre personnage aussi). | Réglages gardés. |
| 6-5 | « revenir aux valeurs par défaut ». | 100 %, Normale, cercle activé. |
| 6-6 | Touches : changer la touche du livre (K → L) dans les raccourcis FiveM ; rouvrir la bannière. | Touches montre L. |
| 6-7 | `/vava_reseau ressource vava_pause` après deux ouvertures. | `rpc vava_pause:open` : ≈ 3,4 Ko puis ≈ 1 Ko. |
| 6-8 | `stop vava_hud` ; rouvrir la bannière. | Les deux réglages d'Interface propres au HUD (durée) disparaissent ; la taille reste (elle sert aussi à la bannière). |

## 7. Le Conseil

| # | Faire | Attendu |
|---|---|---|
| 7-1 | Le Conseil → Une question, 20 mots → Sceller et envoyer. | Encart « entre les mains du Conseil » ; le Souverain reçoit l'alerte « Question n° N de … » ; le Registre montre la nature et la position jointe. |
| 7-2 | Envoyer « aide ». | « Quelques mots de plus, s'il vous plaît. » |
| 7-3 | Renvoyer une demande 10 s après. | « Patientez encore 50 s… » |
| 7-4 | **(2 joueurs)** Le membre prend la demande en charge ; A rouvre la bannière. | Encart vert « prise en charge » ; notification sans nom du membre. |
| 7-5 | Clore la demande ; A rouvre (avant 15 min, puis après). | Encart « close », puis plus d'encart. |
| 7-6 | **(3 joueurs)** B (Gardien) et C (Gardien) ; A signale un joueur à 5 m de B, C loin. | B et C reçoivent l'alerte (décision 3 : aucun membre n'est écarté) ; au Registre, la demande « Signalement » nomme A et liste B parmi les témoins ; le journal de prise en charge nomme A. Aucun joueur hors du Conseil ne reçoit rien (A seul, à la prise en charge et à la clôture). |
| 7-7 | `/signaler texte` (ancienne voie). | Demande « Autre » au Registre ; notification « transmis ». |
| 7-8 | Trois demandes de suite (en attendant 60 s entre chaque), aucune prise en charge. | La troisième : « Deux demandes attendent déjà le Conseil. » |
| 7-9 | `stop vava_admin` ; rubrique Le Conseil. | « Le Conseil ne siège pas en ce moment… », envoi désactivé. |

## 8. Quitter

| # | Faire | Attendu |
|---|---|---|
| 8-1 | Quitter Eldoria → Rester à Eldoria ; Échap dans le dialogue. | Le dialogue se ferme, la bannière reste. |
| 8-2 | Se déconnecter ; revenir. | Message « Vous avez quitté Eldoria. Le royaume garde votre place. » ; retour au même endroit, même besace. |
| 8-3 | Quitter le jeu. | Le jeu se ferme (ou, à défaut, après 1,5 s, déconnexion avec « Vous avez quitté Eldoria : vous pouvez fermer le jeu. »). |
| 8-4 | **(2 joueurs)** A à terre se déconnecte par la bannière réduite ; revient. | A est encore à terre (garantie de `vava_health`). |

## 9. Bannière, plaque, réseau

| # | Faire | Attendu |
|---|---|---|
| 9-1 | Sans `vava_guilds`. | Bannière royale (garance, champ bleu, croix de laiton), titre « Eldoria ». |
| 9-2 | Comparer la plaque avec `/date` et l'heure du jeu. | Même moment du jour, même saison. |
| 9-3 | **(2 joueurs)** B se connecte, A rouvre la bannière 10 s après. | « 2 habitants présents ». |
| 9-4 | **(2 joueurs, proches)** A ouvre et ferme sa bannière dix fois ; `/vava_reseau joueur <B>`. | B n'a rien reçu de `vava_pause`. |
| 9-5 | Spammer Échap (ouvrir / fermer vite). | Après 4 ouvertures, la bannière s'ouvre encore (instantané repris pendant 60 s) ; aucune erreur en F8. |
