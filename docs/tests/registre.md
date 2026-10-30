# Registre du Conseil — procédure de test en jeu

Procédure pour vérifier en jeu `vava_admin` 1.7.1 (avec le core 0.9.1, `vava_cameras` 1.3.0 et le pont
`vava_chancellerie` 1.5.1) : le Conseil et ses trois rangs, le Registre du Conseil (`F10` ou `/conseil`), les
signalements, les bans et le journal. Le point capital est la section 3 : **un droit refusé l'est par le serveur**, pas
seulement par l'interface. Comptez une heure et demie ; presque tout se joue à deux, marqué **(2 joueurs)**. Un test se cite « registre 3-4 ». Préparation commune, mesure du resmon et remontée des écarts :
[LISEZMOI.md](LISEZMOI.md).

## 0. Préparation

1. **Deux joueurs** : **A** (vous, Souverain par la préparation commune) et **B** (second client, hors du Conseil au
   départ). Notez leurs numéros de compte (`compte #n` à la connexion, ou « Compte n° n » dans la fiche du Registre),
   écrits ici `<A>` et `<B>`, et le numéro de session de B (« n° » en tête de sa ligne dans Joueurs), écrit `<idB>`.
2. **La console du serveur à portée de main** : plusieurs tests changent un rang pendant que le Registre reste ouvert.
   Chaque commande y répond par une ligne du module (`compte n° 2 : gardien`…).
3. **Modules liés démarrés** : `vava_health` (Soigner, « À terre »), `vava_needs` (Nourrir), `vava_inventory` (Fouiller,
   Donner), `vava_hud` (notifications), `vava_cameras` et `vava_voice` (outils des modules). Sans l'un d'eux, l'action
   correspondante répond « Module indisponible. ».
4. **Réglages pour aller vite** (facultatif, `modules/vava_admin/config.lua` puis `restart vava_admin`, à remettre
   après) : `reportCooldownMs = 10000` (défaut `60000`) et `rateLimits.report.refillPerSecond = 0.5` (défaut `0.05`)
   pour un signalement toutes les 10 s au lieu d'une minute. Les bans durent au moins une heure (`banDurations`) : pour
   en voir un expirer sans attendre, en base `UPDATE vava_admin_bans SET expires_at = NOW() WHERE id = <n° du ban>;`.
5. **Objets** : aucun ; le test « Donner » utilise `charbon`.

Le Registre se ferme par `Échap` (un dialogue ouvert se ferme d'abord), par `F10` ou par le bouton « Fermer le
registre ». Les réponses du serveur s'affichent dans un mot éphémère en bas du livre (3 s environ).

## 1. Nommer et révoquer en console

| # | Faire | Attendu |
|---|---|---|
| 1 | Console : `vava_conseil` sans argument. | `usage : vava_conseil <compte> <rang\|aucun>`. |
| 2 | `vava_conseil <B> chevalier`. | `Conseil : refusé (unknown_rank)`. |
| 3 | `vava_conseil <B> aucun` (B hors du Conseil). | `Conseil : refusé (not_staff)`. |
| 4 | **(2 joueurs)** `vava_conseil <B> gardien`, puis B appuie sur `F10` sans se reconnecter. | Console : `compte n° <B> : gardien`. Le Registre s'ouvre chez B, sceau « Gardien ». `vava_admin_staff` : ligne `<B>`, `gardien`, `granted_by` = 0 (la console). |
| 5 | `vava_conseil <B> senechal`, puis `vava_conseil <B> souverain`. | Le rang change chaque fois ; une seule ligne pour `<B>` en base (mise à jour, `granted_at` renouvelé). Seule la console nomme un Souverain. |
| 6 | `vava_conseil <B> aucun` ; B appuie sur `F10`. | `compte n° <B> : révoqué` ; rien ne s'ouvre chez B ; ligne supprimée de `vava_admin_staff`. |
| 7 | A : Registre → Journal. | Lignes « Console · a nommé · compte n° <B> · rang : gardien », … « a révoqué ». |
| 8 | B (hors du Conseil) tape `/vava_conseil <B> souverain` dans le chat, puis `vava_conseil <B> souverain` dans `F8`. | Rien chez B ; il n'est pas nommé (`F10` ne fait toujours rien). Ces commandes n'agissent que depuis la console du serveur. |

## 2. Ce que chaque rang voit

Rangs cumulatifs (`config.lua` → `ranks`) : Gardien `view`, `teleport`, `freeze`, `heal`, `message`, `warn`, `kick`,
`reports`, `watch` ; Sénéchal en plus `ban` (168 h au plus), `inventory`, `give`, `announce`, `tools`, `spectate`,
`logs`, `bans`, `metiers` ; Souverain en plus `unban`, `staff` et les bans sans limite.

| # | Faire | Attendu |
|---|---|---|
| 1 | **(2 joueurs)** B hors du Conseil : `F10`, `/conseil`, `F2`. | Rien ne s'ouvre, aucun message. |
| 2 | `vava_conseil <B> gardien` ; B : `F10`. | Sceau « Gardien » ; onglets **Joueurs**, **Signalements** et **Outils** — ce dernier avec le seul « Mur des caméras » (`vava_cameras` démarré, droit `watch`), sans leviers ni repère ni position (droit `tools`). Sans `vava_cameras` : Joueurs et Signalements seulement. |
| 3 | B Gardien : fiche de A. | Déplacements : Rejoindre, Amener, Renvoyer, Immobiliser ; Soins : Soigner, Nourrir ; Paroles : Écrire, Avertir ; Justice : Expulser. Ni Observer, ni Fouiller, ni Donner, ni Bannir, ni groupe Conseil. Sur sa propre fiche : Renvoyer, Soigner, Nourrir seulement. |
| 4 | `vava_conseil <B> senechal` ; B ferme et rouvre le Registre. | Onglets Joueurs, Signalements, Sanctions, Journal, Outils, Proclamation. Fiche de A : en plus Observer, Fouiller, Donner, Bannir. « Bannir » propose 1 heure, 6 heures, 1 jour, 3 jours, 7 jours (1 heure présélectionnée). |
| 5 | A (Souverain) : `F10`, fiche de B. | Les sept onglets, dans l'ordre Joueurs, Signalements, Sanctions, Journal, Conseil, Outils, Proclamation. « Bannir » propose en plus 30 jours et Définitif. Groupe « Conseil » : « Rang au Conseil » (Aucun rang, Gardien, Sénéchal ; jamais Souverain) et « Nommer ». |
| 6 | Fermer sur un onglet, rouvrir. | Le Registre rouvre sur le même onglet. |

`vava_conseil <B> aucun` avant la suite.

## 3. Les refus viennent du serveur (2 joueurs)

L'interface n'affiche que ce que le rang permet ; ce n'est qu'un confort. Pour prouver que le serveur refuse de
lui-même, on change un rang **en console pendant que le Registre reste ouvert** : la page garde les boutons de
l'ancien rang (elle ne lit les droits qu'à l'ouverture), alors que le serveur relit le rang à chaque demande. Ne fermez
pas le Registre entre le changement de rang et le clic.

| # | Faire | Attendu |
|---|---|---|
| 1 | `vava_conseil <B> senechal` ; B : `F10` → Proclamation, écrit « essai ». Console : `vava_conseil <B> gardien`. B clique « Proclamer ». | Chez B : « Votre rang ne le permet pas. ». Aucune proclamation chez A ; aucune ligne « a proclamé » au Journal. |
| 2 | Toujours le même Registre chez B : Outils → levier « Vol libre ». | « Votre rang ne le permet pas. » ; le levier reste « Inactif » ; B ne vole pas. |
| 3 | B clique l'onglet Journal. | « Votre rang ne le permet pas. » et « Le journal est vierge. » : rien n'a été envoyé. |
| 4 | B ferme le Registre et appuie sur `F2`. | Rien : ni vol libre ni notification. La touche existe chez tout le monde ; le serveur refuse faute du droit `tools`. Pas de « a utilisé un outil » au Journal. |
| 5 | Console : `vava_conseil <A> aucun` (A devient la cible), `vava_conseil <B> senechal`. B : `F10` → fiche de A → « Bannir », 1 heure, motif « essai » (ne pas encore valider). Console : `vava_conseil <B> gardien`. B : « Sceller le ban ». | « Votre rang ne le permet pas. » ; A reste connecté ; `vava_admin_bans` inchangé. Remettre `vava_conseil <A> souverain` (si A a été banni : `vava_unban <A>` en console, et c'est un écart majeur). |
| 6 | `vava_conseil <B> aucun`. A : `F10` → fiche de B → « Bannir ». Console : `vava_conseil <A> senechal`. A choisit « 30 jours », motif « essai », « Sceller le ban ». | « Durée au-delà de ce que permet votre rang. » ; B reste connecté ; rien en base. |
| 7 | Même Registre : « Bannir » à nouveau (les durées du Souverain y sont encore), « Définitif ». | Même refus. |
| 8 | Même Registre : « Bannir », « 7 jours » (168 h, la borne du Sénéchal). | Accepté : B est expulsé, l'écran de connexion indique « Jusqu'au <date dans 7 jours> » ; Journal « duree : 168 h ». Puis `vava_conseil <A> souverain` et `vava_unban <B>` ; B se reconnecte. |
| 9 | `vava_conseil <B> gardien`. B : `F10` → fiche de A (Souverain) → Immobiliser, Amener, Renvoyer, puis Avertir et Expulser avec un motif. | Chaque fois : « Son rang est égal ou supérieur au vôtre. » ; A n'est ni immobilisé, ni déplacé, ni averti, ni expulsé ; aucune ligne au Journal. |
| 10 | B Gardien, fiche de A : Rejoindre, Soigner, Nourrir, Écrire. | Permis par le code (ces quatre gestes ne sont pas soumis au rang) : B rejoint A, A est soigné et nourri, A lit « Message du Conseil : … » ; une ligne de Journal pour chacun. |
| 11 | `vava_conseil <B> souverain`. A : fiche de B → Avertir (motif) ; puis « Rang au Conseil » → Gardien → « Nommer » ; puis onglet Conseil. | « Son rang est égal ou supérieur au vôtre. » pour l'avertissement comme pour la nomination ; dans l'onglet Conseil, pas de « Révoquer » en face de B. |
| 12 | `vava_conseil <B> gardien` ; B ouvre le Registre sur Joueurs et le laisse ouvert. A : onglet Conseil → « Révoquer » en face de B → « Retirer <B> du Conseil ? » → « Révoquer ». B clique une fiche. | Chez A : « C'est fait. » ; chez B : « Votre rang ne le permet pas. ». `F10` ne rouvre plus rien chez B. |

## 4. Joueurs : liste et fiche

| # | Faire | Attendu |
|---|---|---|
| 1 | A : `F10` → Joueurs. | « Âmes présentes », « 2 âmes ». Chaque ligne : « n° <session> », nom du personnage (« En sélection de personnage » s'il n'en a pas), « <nom FiveM> · Compte n° <n> · <temps de jeu> », étiquettes « Vous », rang, « À terre », « Immobilisé ». |
| 2 | Chercher une partie du nom de B, puis son numéro de session, puis son numéro de compte. | La liste filtre à chaque lettre ; sans correspondance : « Personne ne correspond. ». |
| 3 | Cliquer B. | Fiche : nom et étiquettes ; Nom FiveM ; Compte « n° <B> » ; Session « n° <idB> · <ping> ms » ; Temps de jeu (« 48 min », « 1 h 05 ») ; Position x, y, z à une décimale ; jauges Vie, Faim, Soif en % ; actions par groupe ; « Avertissements » : « Aucun avertissement. ». Aucun identifiant (license, Discord, Steam…) : ils ne partent qu'à la Chancellerie, qui les affiche (facultatif : outils de développement de la page, `nui_devtools` dans `F8`, onglet Réseau, réponse de `request` : pas de champ `identifiers`). |
| 4 | Fermer, rouvrir. | B reste choisi et sa fiche est relue. |

## 5. Déplacer et immobiliser (2 joueurs)

| # | Faire | Attendu |
|---|---|---|
| 1 | A loin de B : fiche de B → « Rejoindre ». | Le Registre se ferme ; A apparaît à 1,2 m de B (`teleportOffset`). Journal « a rejoint ». |
| 2 | A : `F10`, sa propre fiche → « Renvoyer ». | A revient où il était avant de rejoindre ; Journal « a renvoyé ». Second clic : « Aucune position où le renvoyer. ». |
| 3 | Fiche de B → « Amener ». | « C'est fait. » ; B apparaît à 1,2 m de A ; Journal « a amené ». |
| 4 | Fiche de B → « Renvoyer », deux fois. | B retourne à sa place d'avant ; au second clic : « Aucune position où le renvoyer. ». |
| 5 | « Immobiliser ». | B lit « Le Conseil vous a immobilisé. » et ne peut plus se déplacer ; étiquette « Immobilisé » ; le bouton devient « Libérer ». Journal « a immobilisé », « etat : immobilisé ». |
| 6 | « Libérer ». | B lit « Vous pouvez de nouveau bouger. » et repart ; Journal « a immobilisé », « etat : libéré » (même libellé dans les deux sens, le détail tranche). |

## 6. Soigner, écrire, avertir, fouiller, donner (2 joueurs)

| # | Faire | Attendu |
|---|---|---|
| 1 | B tombe à terre (`vava_health`), A ouvre sa fiche. | Étiquette « À terre » ; jauge Vie à 0 %. |
| 2 | « Soigner ». | B se relève ; Journal « a soigné », « releve : oui ». |
| 3 | B blessé mais debout : « Soigner ». | Vie pleine ; « releve : non ». |
| 4 | « Nourrir ». | Faim et Soif à 100 % dans la fiche relue ; Journal « a nourri ». |
| 5 | « Écrire » → texte → « Envoyer ». Puis « Écrire » avec un texte vide. | B lit « Message du Conseil : <texte> » ; Journal « a écrit à », « message : … ». Texte vide : le dialogue ne se valide pas. |
| 6 | « Avertir » → motif « langage » → « Avertir ». | B lit « Avertissement du Conseil : langage » ; la fiche liste l'avertissement (date, motif, « Souverain <nom de A> ») ; `vava_admin_warnings` ; Journal « a averti ». Seuls les 10 derniers sont montrés. |
| 7 | « Fouiller ». | Le Registre se ferme ; l'inventaire de A s'ouvre avec la besace de B à côté de la sienne, quelle que soit la distance. Journal « a fouillé ». |
| 8 | « Donner » : objet `charbon`, quantité 10. | « C'est fait. » ; 10 charbons dans la besace de B ; Journal « a donné à », « objet : charbon ; quantite : 10 ». « Donner » existe aussi sur sa propre fiche. |
| 9 | « Donner » : `objet_inconnu`, 1. | Refus, rien donné : « Action impossible. » (à confirmer : code de l'inventaire sans texte dans le Registre). |
| 10 | « Donner » : `charbon` avec 5000 tapé au clavier ; puis `charbon fer` (avec une espace). | « Saisie refusée. » dans les deux cas (schéma du serveur : quantité 1 à 1000, nom sans espace). |

## 7. Expulser, bannir, lever un ban (2 joueurs)

| # | Faire | Attendu |
|---|---|---|
| 1 | Fiche de B → « Expulser », motif « essai ». | B quitte le serveur sur « Expulsé par le Conseil. / Motif : essai ». Journal « a expulsé », « motif : essai ». |
| 2 | B revenu : « Bannir », « 1 heure », motif « essai » → « Sceller le ban ». | B est expulsé sur « Vous êtes banni de ce royaume. / Motif : essai / Jusqu'au <jj/mm/aaaa hh:mm>. / Ban n° <n> » (heure de la base). `vava_admin_bans` : `expires_at` une heure plus tard. Journal « a banni », « ban : <n> ; duree : 1 h ; motif : essai ». |
| 3 | B se reconnecte. | Refusé à la connexion avec le même texte, avant la sélection de personnage : le ban vaut pour le compte et tous ses personnages. |
| 4 | A : Sanctions. | « Bans en cours » : N°, Banni (nom du personnage · Compte n° <B>), Motif, Prononcé, Fin, Par (« Souverain <nom de A> »), bouton « Lever ». |
| 5 | « Lever » → « Lever tous les bans de <nom> ? » → « Lever ». | « C'est fait. » ; la ligne disparaît ; en base `revoked_at` et `revoked_by` (« Souverain <nom de A> ») remplis ; Journal « a levé le ban de · compte n° <B> ». B se reconnecte. |
| 6 | Bannir B « Définitif ». Puis le lever. | Fin « Définitif » ; chez B « Ban définitif. » à la place de la date ; `expires_at` vide. |
| 7 | **Compte déconnecté** : B quitte. Console : `vava_ban <B> 2 absent`. | `ban n° <n> prononcé contre le compte n° <B>` ; Sanctions : Banni « compte n° <B> », Par « Console », Fin dans 2 h. B est refusé à la connexion. |
| 8 | Console : `vava_unban <B>`, deux fois. | `bans du compte n° <B> levés`, puis `aucun ban actif pour le compte n° <B>`. B se reconnecte. |
| 9 | Bannir B 1 heure, puis en base `UPDATE vava_admin_bans SET expires_at = NOW() WHERE id = <n>;`. B se reconnecte. | Accepté ; le ban n'est plus dans Sanctions (seuls les bans en cours y sont). |
| 10 | Console : `vava_ban <B> -1 essai`, `vava_ban <B> 1.5 essai`, `vava_ban <B> 2` (sans motif). | Chaque fois `usage : vava_ban <compte> <heures\|0> <motif>`, rien en base. |
| 11 | Console : `vava_kick <idB> essai`, puis `vava_kick 999 essai`. | B expulsé sur « Expulsé par le Conseil. / Motif : essai » et `joueur <idB> expulsé` ; puis `joueur 999 introuvable`. |
| 12 | `vava_conseil <A> senechal`, A rouvre le Registre → Sanctions. Remettre `souverain`. | La liste s'affiche, sans bouton « Lever » (droit `unban` du Souverain). |
| 13 | **Ban pendant le chargement** (1.7.1) : B quitte, puis se reconnecte ; dès l'écran de chargement du jeu (après « Vérification de votre compte… »), console : `vava_ban <B> 1 essai`. | Console : `ban n° <n> prononcé contre le compte n° <B>` ; B termine son chargement, puis est expulsé dès son arrivée (avant de choisir un personnage) sur « Vous êtes banni de ce royaume. / Motif : essai / … / Ban n° <n> ». Console : `compte n° <B> banni (ban n° <n>) expulsé à son arrivée`. Journal : « Banni écarté par le Registre », Auteur « Console », Cible « compte n° <B> », « ban : <n> ; moment : à son arrivée ». Puis `vava_unban <B>`. |
| 14 | **Bans illisibles à la connexion** (1.7.1) : B quitte. En base : `RENAME TABLE vava_admin_bans TO vava_admin_bans_essai;`. B se reconnecte. | Refusé avant la sélection de personnage sur « Le registre des bans ne peut être consulté pour l'instant : réessayez dans une minute. » ; console : `connexion du compte n° <B> refusée : vérification de ban impossible (…)`. Aucun personnage chargé. A (déjà en jeu) n'est pas touché. |
| 15 | **Bans illisibles à l'arrivée** : table toujours renommée, B quitte. En base `RENAME TABLE vava_admin_bans_essai TO vava_admin_bans;`, B se reconnecte et, pendant l'écran de chargement du jeu, `RENAME TABLE vava_admin_bans TO vava_admin_bans_essai;`. | B entre (vérification à la connexion réussie) et **reste en jeu** (`banRecheck.onError = 'keep'`, défaut) ; environ 5 s après son arrivée (seconde lecture, `banRecheck.retryMs`), console : `compte n° <B> à son arrivée : bans illisibles, joueur gardé (…)`. Rien au Journal (même base). Recommencer en remettant la table **pendant ces 5 s** : rien à la console. Avec `onError = 'kick'` (config, `restart vava_admin`) : B est expulsé avec le même message qu'en 14, console `compte n° <B> expulsé à son arrivée : bans illisibles (…)`. **Remettre** `RENAME TABLE vava_admin_bans_essai TO vava_admin_bans;` et `onError = 'keep'` ; B se reconnecte normalement. |
| 16 | **Base arrêtée** (core 0.9.1) : arrêter le service MariaDB (ou MySQL) ; B se connecte. Relancer le service ; B se reconnecte. | Refusé sur « Le serveur est momentanément indisponible, réessayez dans un instant. » ; console : `connexion refusée : compte de la license introuvable, base indisponible (…)`. Aucun compte créé. Base relancée : B entre normalement (à confirmer : délai de la réponse d'oxmysql quand la base est arrêtée). |
| 17 | **Registre en échec : porte fermée** (core 0.9.1) : B quitte. En base `RENAME TABLE vava_admin_bans TO vava_admin_bans_essai;`, console `restart vava_admin` ; B se connecte. Puis remettre la table (`RENAME TABLE vava_admin_bans_essai TO vava_admin_bans;`), `restart vava_admin`, B se connecte. | Au redémarrage : le module échoue (`table des bans illisible : …`). B est refusé sur « Le royaume s'éveille : réessayez dans un instant. » ; console : `connexion refusée : le garde de connexion 'vava_admin' n'est pas prêt (ressource started, module failed)`. A, déjà en jeu, n'est pas touché. Table remise et module prêt : B entre. |
| 18 | **Registre en redémarrage** : console `restart vava_admin` et, aussitôt, B se connecte (au besoin plusieurs fois de suite). | Pendant le démarrage du module : même refus qu'en 17 (« module starting » ou « non déclaré » à la console) ; une fois `module 'vava_admin' v1.7.1 prêt`, B entre. |
| 19 | **Registre arrêté : porte fermée, banni en jeu relu au retour** : B en jeu. Console `stop vava_admin`. Un troisième joueur C (ou B après avoir quitté) essaie de se connecter. En base : `INSERT INTO vava_admin_bans (account_id, target_label, reason, actor_label) VALUES (<B>, 'essai', 'essai', 'Console');`. Console `ensure vava_admin`. | Registre arrêté : C refusé sur « Le royaume s'éveille : réessayez dans un instant. » ; console `connexion refusée : le garde de connexion 'vava_admin' n'est pas prêt (ressource stopped, module non déclaré : ensure vava_admin, ou retirez-le de players.connectionGuards si le serveur n'a pas de Registre)`. Au démarrage du module : B expulsé sur le texte du ban, console `compte n° <B> banni (ban n° <n>) expulsé au démarrage du Registre`, Journal « Banni écarté par le Registre », « moment : au démarrage du Registre » ; C entre. Puis `vava_unban <B>`. |
| 20 | **Redémarrage du core** : B banni par la console (`vava_ban <B> 1 essai`) puis déconnecté ; console `restart vAvA_core` (FiveM arrête `vava_admin`, qui en dépend, sans le relancer : voir `personnage.md`). B essaie de se connecter. Console `ensure vava_admin` (et les autres modules arrêtés), puis B réessaie. Enfin `vava_unban <B>`. | Tant que `vava_admin` n'est pas relancé : B refusé sur « Le royaume s'éveille… », console avec l'indication `ensure vava_admin` ; jamais admis sans vérification. Après `ensure vava_admin` : B refusé sur le texte de son ban ; A, resté en jeu, est relu au démarrage du Registre sans être touché. Après `vava_unban <B>` : B entre. |
| 21 | **Ressource absente** (réglage, à remettre) : dans `config/server.lua`, `connectionGuards = { 'vava_admin_absent' }`, `restart vAvA_core` puis `ensure` des modules ; B se connecte. Puis `connectionGuards = { 'vava_admin', 42 }`, même redémarrage, B se connecte. | Nom absent : B entre, console `connexion accordée sans le garde 'vava_admin_absent' (ressource missing) : ce qu'il vérifie ne l'est pas` (c'est ce qui arriverait en renommant la ressource sans mettre la liste à jour). Entrée `42` : une erreur `players.connectionGuards[2] (42) n'est pas un nom de ressource : ignoré` à la première connexion, B entre normalement. Remettre `{ 'vava_admin' }`. |

## 8. Signalements (2 joueurs)

| # | Faire | Attendu |
|---|---|---|
| 1 | B : `/signaler` sans texte. | « usage : /signaler <message> ». |
| 2 | A ouvre le Registre sur Signalements. B : `/signaler Un voleur au marché`. | B : « Votre signalement a été transmis au Conseil. ». A : notification « Signalement n° 1 de <nom de B>. » et la liste se met à jour seule. |
| 3 | B : `/signaler encore` aussitôt, puis trois fois de suite. | La deuxième : « Patientez avant d'envoyer un nouveau signalement. » ; les suivantes : rien du tout (débit du serveur : deux demandes, puis une toutes les 20 s). Aucun nouveau signalement chez A. Une minute après le premier (`reportCooldownMs`) : accepté. |
| 4 | A : le signalement. | Ligne « n° 1 », nom de B, « il y a un instant », étiquette « En attente ». Détail : « De <nom de B> », le message, « En attente », boutons Prendre en charge, Rejoindre, Voir la fiche, Clore. |
| 5 | « Prendre en charge ». | B : « Un membre du Conseil prend en charge votre signalement. ». Détail : « Pris en charge par Souverain <nom de A> », étiquette ✓, bouton disparu. Journal « a pris en charge », « signalement : 1 ». |
| 6 | « Voir la fiche », puis revenir et « Rejoindre ». | La fiche de B s'ouvre dans Joueurs ; « Rejoindre » ferme le Registre et pose A près de B. |
| 7 | B se déconnecte ; A rouvre Signalements. | « Le joueur a quitté le royaume. » ; plus de Rejoindre ni de Voir la fiche ; Prendre en charge et Clore restent. |
| 8 | B revenu dans la minute : `/signaler encore`. | « Patientez avant d'envoyer un nouveau signalement. » : le délai suit le compte, pas la session. |
| 9 | Un signalement en cours, B connecté : « Clore ». | B : « Votre signalement a été clos. » ; « Aucun signalement en attente. » ; Journal « a clos le signalement de ». |
| 10 | `vava_conseil <B> gardien` ; A : `/signaler essai` (un membre du Conseil peut signaler aussi). | B (Gardien) reçoit l'alerte et voit le signalement dans son Registre : tout le Conseil a `reports`. |

## 9. Outils et vol libre

Sénéchal et au-dessus (droit `tools`).

| # | Faire | Attendu |
|---|---|---|
| 1 | A : Outils. | Vol libre, Invisibilité, Invulnérabilité (leviers « Actif » / « Inactif »), Rejoindre le repère, Copier ma position, puis « Outils des modules » : « Mur des caméras », « Zones de voix ». Aide du vol libre : « Raccourci F2 (réglable). Invisible pendant le vol. ZQSD pour se déplacer, Espace et Ctrl pour monter et descendre, Maj pour accélérer. ». |
| 2 | Registre fermé : `F2`. | « Vol libre : vous êtes invisible. ». ZQSD dans l'axe de la caméra, Espace monte, Ctrl gauche descend, Maj gauche × 4, Alt gauche × 0,25 (`noclip`) ; on traverse les murs. **(2 joueurs)** B ne voit plus A ; A se voit. Journal « a utilisé un outil », « actif : oui ; outil : noclip ». |
| 3 | `F2` à nouveau. | « Vol libre terminé. » ; A redevient visible et retombe ; Journal « actif : non ». |
| 4 | Levier « Vol libre » dans Outils. | Même effet que `F2` ; le levier passe à « Actif ». |
| 5 | **(2 joueurs)** Levier « Invisibilité ». | B ne voit plus A ; « Inactif » le rend visible. |
| 6 | **(2 joueurs)** Levier « Invulnérabilité » ; B frappe A. | A ne perd pas de vie (à confirmer avec `vava_health`, qui lit la vie du ped) ; « Inactif » rend A vulnérable. |
| 7 | « Rejoindre le repère » sans repère sur la carte. | « Aucun repère sur la carte. ». |
| 8 | Poser un repère (menu pause → carte), « Rejoindre le repère ». | « C'est fait. » ; A posé sur le sol à l'emplacement du repère. |
| 9 | « Copier ma position », puis coller dans le chat (`Ctrl+V`). | « Position copiée : x, y, z » ; le collage donne les mêmes nombres. |
| 10 | « Mur des caméras » → « Ouvrir ». | Le Registre se ferme, le mur s'ouvre (`vava_cameras`). |
| 11 | « Zones de voix » → « Ouvrir ». | Le Registre se ferme, l'éditeur des zones de voix s'ouvre (`vava_voice`). |
| 12 | Registre ouvert sur Outils : `stop vava_voice` en console, puis « Ouvrir » sur « Zones de voix ». `start vava_voice`, rouvrir le Registre. | « Cet outil n'est plus disponible (son module est arrêté). » ; après le redémarrage, l'outil est de nouveau listé. |

## 10. Observer, écran des joueurs (2 joueurs)

| # | Faire | Attendu |
|---|---|---|
| 1 | A (Sénéchal ou plus) : fiche de B → « Observer ». | Le Registre se ferme ; bandeau « Vous observez <nom de B> » avec la touche `F10` ; la caméra suit B ; B ne voit pas A. Journal « a observé ». |
| 2 | B court au loin. | La vue suit (recalage toutes les secondes, `spectate.anchorMs`). |
| 3 | A : `F2`. | Rien : le vol libre est bloqué pendant l'observation. |
| 4 | A : `F10`. | L'observation cesse : A revient à sa place et à son orientation, visible ; bandeau disparu ; le Registre ne s'ouvre pas (un second `F10` l'ouvre). |
| 5 | Observer B, puis B se déconnecte. | Dans la seconde, l'observation cesse d'elle-même et A revient à sa place. |
| 6 | Écran des joueurs (droit `watch`, tout le Conseil, sans règle de rang) : `vava_conseil <B> gardien` ; B : `/cameras`. | Le mur s'ouvre (joueurs connectés, B exclu, disposition 3 × 3 par défaut) ; B peut regarder l'écran de A bien que A soit Souverain. Journal « Mur des caméras ouvert ». |
| 7 | B Gardien : `F10` → Outils → « Mur des caméras » → « Ouvrir ». | L'onglet Outils ne montre que cet outil (pas de titre « Outils des modules », aucun levier) ; le Registre se ferme et le mur s'ouvre, comme par `/cameras`. |
| 8 | `vava_conseil <B> aucun` ; B : `/cameras`. | Rien. |
| 9 | **Une offre par caméra** (`vava_cameras` 1.2.0) : A ouvre le mur en 4 × 4 avec B dedans, puis ouvre B en grand, revient au mur, change de page et revient. | Chaque case et la vue en grand montrent l'image de B comme avant : une seule offre suffit à chaque caméra. Console du serveur : aucune erreur `already_offered`. (Un client qui renverrait l'offre en boucle est couvert par les tests unitaires, `tests/spec/cameras_wall_spec.lua`.) |
| 10 | **Mur fermé puis rouvert** : A ferme le mur (`Échap`), le rouvre (`/cameras`). | Deux lignes « Mur des caméras ouvert » au Journal ; les cases reviennent à la réouverture. |
| 11 | **Droit retiré puis rendu, mur ouvert** : B Gardien, mur ouvert sur A. Console : `vava_conseil <B> aucun`, puis `vava_conseil <B> gardien` sans que B ferme son mur ; un troisième joueur (ou A revenu de la sélection) apparaît dans le mur de B. | Au retrait, « Droit refusé » sur chaque case. Rang rendu, mur toujours affiché : une case nouvelle affiche « Mur à rouvrir » (le serveur a levé le mur au retrait) et n'est pas retentée toutes les 10 s ; changer de page ou de disposition : toutes les cases disent « Mur à rouvrir » d'un coup, sans attente. B ferme et rouvre le mur : nouvelle ligne « Mur des caméras ouvert », les cases reviennent, une à une (150 ms d'écart, visible sur un mur 4 × 4). |
| 12 | **Retour à la sélection** : B, mur ouvert, revient à la sélection de personnage, rejoue, puis `/cameras`. | Le mur se ferme à la sélection ; à la réouverture, une ligne « Mur des caméras ouvert » et les cases fonctionnent. Aucune case n'est jamais vue sans une ligne d'ouverture au Journal juste avant. |
| 13 | **Depuis la Chancellerie** (compte du panneau Gardien, au moins deux joueurs en jeu) : page Caméras en 1 × 1 ; puis, page toujours ouverte, console : `restart vava_chancellerie` ; dans la page, passer à la page suivante du mur, puis en 2 × 2. | À l'ouverture de la page : « Mur des caméras ouvert » au nom de « Chancellerie : <compte> », pas de « Cases du mur regardées ». Après le redémarrage, le pont ne sait plus qu'un mur est ouvert : à la première case ouverte ensuite, une ligne « Cases du mur regardées » (« numero : <n° du joueur> »), une seule pour toutes les cases suivantes. Recharger la page : seulement « Mur des caméras ouvert ». (Caméras déjà ouvertes avant le redémarrage : gardées ou éteintes, à noter ; ce test ne dépend pas de leur sort.) |
| 14 | **Mur trop ancien** : `wall.maxOpenMs = 60000` dans `modules/vava_cameras/config.lua`, `restart vava_cameras`. A ouvre le mur, attend plus d'une minute, puis change de page. | Les cases de la nouvelle page disent « Mur à rouvrir » ; fermer et rouvrir le mur : nouvelle ligne au Journal, les cases reviennent. Remettre `2 * 60 * 60 * 1000`. |

**Débit montant du joueur filmé** (`vava_cameras` 1.3.0, tests 15 à 19). Il faut **B** filmé et plusieurs membres qui le
regardent : A en jeu, et des onglets de la page Caméras de la Chancellerie (chaque onglet ouvert compte pour un
spectateur ; un compte du panneau Gardien suffit). Chez B : `F8` → `cl_drawfps 1` (images par seconde) et
`netgraph 1` (ping) ; dans Windows, Gestionnaire des tâches → Performances → la carte réseau : « Envoi » (tout ce que
B envoie, image comprise). Dans un onglet de la Chancellerie, `edge://webrtc-internals` (ou `chrome://…`) montre le
débit reçu de chaque caméra. Noter chaque mesure dans le compte rendu ; si possible, faire 15 à 17 une fois sur
`vava_cameras` 1.2.0 (avant T-047) pour comparer.

| # | Faire | Attendu |
|---|---|---|
| 15 | **Référence** : personne ne regarde B ; B court en ville 30 s. | Noter images/s, ping, « Envoi » de B : c'est la référence (le jeu et la voix seuls). |
| 16 | **1 membre** : A ouvre B en grand, B court 30 s. | Image nette et fluide chez A. « Envoi » de B : référence + 1,2 Mbit/s au plus. Images/s et ping de B notés, proches de la référence. |
| 17 | **3 membres** : A garde B en grand ; deux onglets de la Chancellerie, mur en 1 × 1 sur B (case). | « Envoi » de B : référence + 1,5 Mbit/s au plus (1 200 pour la vue en grand, 150 par case). `webrtc-internals` d'un onglet : environ 150 kbit/s. Images/s et ping de B notés. |
| 18 | **6 membres** : A garde B en grand ; cinq onglets en case sur B. Puis fermer trois onglets. | « Envoi » de B : jamais plus de référence + 1,5 Mbit/s ; la vue en grand de A reste à 20 images/s, un peu moins nette (900 kbit/s), les cases à 120 kbit/s. Images/s et ping de B notés (à comparer avec 7,2 Mbit/s avant T-047). Trois onglets fermés : dans les secondes qui suivent, la vue de A redevient aussi nette qu'au test 16, sans coupure ni nouvelle connexion (aucune ligne au Journal, aucune image noire). |
| 19 | **Une seule vue en grand** : A garde B en grand. Un onglet de la Chancellerie : fiche de B → « Regarder l'écran » ; un second membre en jeu C (ou A depuis un second client) : `/cameras`, clic sur B. Puis A revient à son mur (`Échap`). | Chancellerie : « Le débit de ce joueur est déjà pris (une seule vue en grand à la fois, et un plafond pour toutes ses caméras) : réessayez dans un instant. » ; mur de C : « Débit du joueur déjà pris, nouvel essai bientôt ». Aucune ligne « Écran regardé » au Journal pour ces vues refusées, même après plusieurs essais. A revenu au mur : la vue de C (ou de l'onglet) s'ouvre d'elle-même dans les 15 s, avec sa ligne « Écran regardé ». |

## 11. Proclamation, journal, Conseil

| # | Faire | Attendu |
|---|---|---|
| 1 | Proclamation : taper un texte. | L'aperçu suit la frappe, signé du rang (« Souverain ») ; 500 caractères au plus. |
| 2 | « Proclamer ». | « Proclamation envoyée. » ; chez tous (**(2 joueurs)** B compris) : bandeau en haut « Proclamation du Conseil », le texte, « Souverain », pendant 9 s (`announcementMs`). Journal « a proclamé », « message : … ». Texte vide : rien ne part. |
| 3 | Journal. | « Journal du Conseil » : Date, Auteur, Action, Cible, Détails ; plus récent en tête ; 50 lignes par page (`pageSize`), « Page suivante » à partir de 50. Les actions des modules s'y lisent en clair (« Vitalité fixée », « Mur des caméras ouvert »…). |
| 4 | Conseil. | « Membres du Conseil » : nom du personnage (ou « Compte n° »), « Compte n° · Session n° » ou « Absent », rang ; « Révoquer » seulement en face d'un rang inférieur au vôtre, jamais en face de vous ; aide « Nommez un joueur depuis sa fiche, dans l'onglet Joueurs. ». |
| 5 | **(2 joueurs)** Fiche de B → « Rang au Conseil » : Gardien → « Nommer ». B : `F10`. | « C'est fait. » ; étiquette « Gardien » sur la fiche ; le Registre s'ouvre chez B ; Journal « a nommé », « rang : gardien ». |
| 6 | Fiche de B : « Aucun rang » → « Nommer », deux fois. | Première fois : B révoqué, Journal « a révoqué ». Seconde : « Ce compte ne siège pas au Conseil. ». |

## 12. Déconnexion au milieu d'une action (2 joueurs)

| # | Faire | Attendu |
|---|---|---|
| 1 | Dialogue « Avertir » ouvert pour B ; B quitte ; valider. | « Ce joueur n'est plus là. » ; rien en base. |
| 2 | B immobilisé quitte puis revient. | B bouge librement ; plus d'étiquette « Immobilisé » (à confirmer : nouveau personnage, nouveau ped non figé). |
| 3 | A note sa position (Registre → sa fiche), observe B, quitte le jeu pendant l'observation (`F8` → `disconnect`) ; revient et « Jouer ». | Après l'apparition, un second fondu replace A à la position notée (à 1 m près), au sol, avec son orientation ; jamais sous terre ni près de B. Console : `personnage n° <M> replacé là où il a commencé une observation`. En base, avant le retour : clé `vava_admin:spectateReturn` de `vava_characters.data` remplie, avec `"departed": true` ; après : vide (`{}` ou `[]`). Entre les deux fondus, A peut entrevoir un instant l'endroit relevé sous B (à confirmer). |
| 3b | A observe B, termine par `F10`, puis quitte et revient. | A réapparaît simplement à sa dernière position, sans second fondu : la place gardée a été effacée à la fin de l'observation. |
| 3c | A observe B ; `/perso quitter` (outil de développement, § 0 de `personnage.md`) pendant l'observation ; rejouer le même personnage. | Comme 3 : replacé à sa position d'avant l'observation. |
| 3d | A note sa position ; fiche de B → **double clic** (ou clics rapides) sur « Observer » ; puis quitter le jeu pendant l'observation ; revenir et « Jouer ». | Le bouton se grise dès le premier clic : une seule observation, une seule ligne « a observé » au Journal. Au retour, comme 3 : A est replacé à la position notée, jamais sous B ni sous terre. |
| 3e | A observe B ; `/perso quitter`, puis choisir **un autre** personnage du même compte (sans « Jouer » le premier entre-temps). | Le second personnage apparaît à sa propre place, sans second fondu ; en rejouant ensuite le premier, il est replacé à sa position d'avant l'observation. |
| 4 | A en vol libre haut dans le ciel quitte ; revient. | Le vol libre est coupé ; A réapparaît à sa dernière position relevée (à confirmer : en l'air, il tombe). |
| 5 | Pendant que A observe B, console : `vava_ban <B> 1 essai` (le Registre ne s'ouvre pas pendant une observation) ; puis `vava_unban <B>`. | B expulsé ; l'observation de A cesse et A revient à sa place. |

## 13. Redémarrage du module

| # | Faire | Attendu |
|---|---|---|
| 1 | A en vol libre avec le Registre ouvert, B immobilisé, un signalement ouvert. Console : `restart vava_admin`. | Console : `arrêt : 1 joueur(s) immobilisé(s) libéré(s)` puis `module 'vava_admin' v1.7.1 prêt`. Chez A : Registre fermé, souris rendue au jeu, vol libre coupé (A visible, retombe). Chez B : il peut de nouveau bouger, avec « Vous pouvez de nouveau bouger. » (à confirmer : le message part pendant l'arrêt du module chez B ; s'il manque, seul le mouvement compte). |
| 2 | A : `F10`, `F2` sans se reconnecter. | Tous deux fonctionnent. Rangs, bans, avertissements et journal intacts (base). |
| 3 | Signalements. | Vide : les signalements vivent en mémoire ; le suivant repart au n° 1 et le délai d'une minute de B est remis à zéro. |
| 4 | Fiche de B (immobilisé avant le redémarrage). | B est libre et la fiche le dit : pas d'étiquette « Immobilisé », bouton « Immobiliser ». État cohérent ; à immobiliser de nouveau si besoin. |
| 5 | « Renvoyer » sur B déplacé avant le redémarrage. | « Aucune position où le renvoyer. ». |
| 6 | Outils. | « Mur des caméras » et « Zones de voix » sont revenus (les modules se réinscrivent). |
| 7 | A observe B ; `restart vava_admin`. Puis A quitte et revient. | L'observation cesse ; A revient à sa place, visible. Au retour, aucun second fondu : la place gardée de A a été effacée au redémarrage du module. |
| 8 | `stop vava_admin` avec B immobilisé, attendre, `start vava_admin`. | B libéré dès l'arrêt ; personne ne reste figé pendant que le Registre est absent. |
| 9 | **(2 joueurs)** A en vol libre (`F2`), en l'air au-dessus d'un toit, outils Invisibilité et Invulnérabilité **inactifs** ; console : `restart vava_admin`. Puis A essaie de traverser un mur ; B frappe A. Recommencer à bord d'un véhicule. | Aussitôt l'arrêt : A retombe (plus figé), ne traverse plus les murs, B le voit de nouveau, et A perd de la vie quand B le frappe ; à bord, le véhicule redevient visible et solide. Rien n'attend la fin du fil du vol, qui ne tourne plus. |
| 10 | A en vol libre avec Invisibilité **active** ; `restart vava_admin`. | Le vol est défait (A retombe, solide) ; l'invisibilité est coupée aussi par l'arrêt : A redevient visible pour B. |

## 14. Tentatives de triche simples

| # | Faire | Attendu |
|---|---|---|
| 1 | **(2 joueurs)** B hors du Conseil : `F10`, `/conseil`, `F2`, `/cameras`, `/vava_conseil <B> souverain` dans le chat et `vava_conseil <B> souverain` dans `F8`. | Rien, nulle part ; B reste hors du Conseil. |
| 2 | A : « Nourrir » sur B, quinze clics en trois secondes. | Une dizaine de réussites puis « Doucement… » (10 demandes d'affilée, puis 2 par seconde : `rateLimits.action`). |
| 3 | `F2` vingt fois très vite. | Bascule à chaque appui accordé, puis ne répond plus un instant ; une ligne de Journal par bascule accordée, pas davantage. |
| 4 | `F10` vingt fois très vite (ouvrir, fermer). | Au-delà d'une dizaine d'ouvertures rapprochées, `F10` n'ouvre plus rien pendant un instant (`rateLimits.read`), puis de nouveau. |
| 5 | B : `/signaler` en rafale | Voir 8-3. |
| 6 | Saisies hors bornes dans « Donner » | Voir 6-10. |
| 7 | A (Conseil) à terre : `F10`, sa fiche → « Soigner ». | Le code le permet : A se relève et le Journal l'inscrit (« a soigné », « releve : oui ») (à confirmer : `F10` répond à terre). À trancher : voir le compte rendu. |

## 15. Resmon

| Situation | Attendu (`resmon 1`, ligne `vava_admin`) |
|---|---|
| Au repos, Registre fermé | 0,02 ms au plus : aucune boucle (la page reste chargée pour les proclamations). |
| Registre ouvert, navigation | 0,02 ms au plus : rien ne tourne en continu. |
| Vol libre | 0,15 ms au plus : seule boucle par image du module, active pendant le vol seulement. |
| Observation | 0,02 ms au plus : un recalage par seconde. |

## 16. Ce qu'il faut regarder dans la base

- `vava_admin_staff` : `account_id`, `rank`, `granted_by` (0 = la console), `granted_at`.
- `vava_admin_bans` : `expires_at` vide = définitif ; `revoked_at`, `revoked_by` à la levée ; `actor_account_id` 0 pour
  la console ou un module.
- `vava_admin_warnings` : un avertissement par ligne, `actor_label` = « <Rang> <Prénom Nom> ».
- `vava_admin_logs` : `action` (code : `reach`, `ban`, `staffGrant`… ou libellé d'un module), `target_label`, `details`
  (« clé : valeur ; … ») ; écrit aussitôt, sans regroupement. Purgé au démarrage au-delà de 90 jours
  (`logRetentionDays`). Exemple : `SELECT created_at, actor_label, action, target_label, details FROM vava_admin_logs
  ORDER BY id DESC LIMIT 20;`
- Les signalements ne sont pas en base (mémoire) : seules leur prise en charge et leur clôture laissent une trace au
  journal ; l'état « immobilisé » non plus (libéré à l'arrêt du module).
- `vava_characters.data`, clé `vava_admin:spectateReturn` : vide hors observation ; pendant une observation,
  `{ x, y, z, heading }` de la place d'où le membre est parti ; après un départ en pleine observation, la même place
  avec `departed = true`, jusqu'au replacement réussi à son retour.
  `SELECT id, JSON_EXTRACT(data, '$."vava_admin:spectateReturn"') FROM vava_characters WHERE id = <M>;`

## 17. Ce que je ne peux pas avoir vérifié hors jeu

- Le rendu du livre dans CEF (sceaux, cachets des durées, bandeaux) : `web/index.html?tab=players` (ou `reports`,
  `bans`, `logs`, `staff`, `tools`, `announce`), avec `&dialog=ban`, `&proclaim=1` ou `&watch=1`, dans un navigateur ;
  `&rank=gardien` montre le Registre d'un Gardien (Outils avec le seul mur des caméras).
- Le retour d'un observateur parti (12-3) : second fondu juste après l'apparition, et ce qu'on voit entre les deux.
- Le message « Vous pouvez de nouveau bouger. » envoyé pendant l'arrêt du module (13-1).
- Les natives serveur sur le ped d'un autre joueur (`SetEntityCoords`, `FreezeEntityPosition`) sous OneSync.
- L'invisibilité vue des autres pendant le vol libre (`SetEntityVisible` + `SetEntityLocallyVisible`) et le mode
  spectateur (`NetworkSetInSpectatorMode`, attente de 3 s que le joueur observé soit transmis).
- La recherche du sol au repère (`GetGroundZFor_3dCoord` à onze hauteurs) et la copie dans le presse-papiers depuis CEF.
- La mise en page du texte de refus sur l'écran de connexion de FiveM (retours à la ligne du message de ban).
- Le second contrôle des bans à l'arrivée et au démarrage (7-13, 7-15, 7-19, 7-20) et la base arrêtée (7-16) : couverts
  hors jeu par `tests/spec/admin_bans_spec.lua` (verdict, lecture d'essai, connexion, seconde lecture, `keep` par
  défaut et `kick`, relecture des joueurs en jeu, joueur pas encore repris par le core, joueur parti ou numéro repris),
  pas sur un vrai FXServer ; le délai d'oxmysql quand MariaDB est arrêtée n'est pas connu.
- La porte gardée (7-17 à 7-21) : `tests/spec/core_accounts_gate_spec.lua` vérifie le verdict (`stopped` et
  `uninitialized` ferment, `missing` seul laisse passer), le garde nommé, l'indication `ensure` et les entrées
  invalides ; les états réels de `GetResourceState` pendant un `restart` et après un `restart vAvA_core` restent à
  observer en jeu (porte fermée dans tous les cas, sauf `missing`).
- L'offre unique et le mur exigé pour une case (10-9 à 10-14) : `tests/spec/cameras_wall_spec.lua` vérifie les règles
  du serveur et du pont ; un client qui renverrait l'offre en boucle ne se teste qu'avec un client modifié. L'arrêt
  des demandes au premier « Mur à rouvrir » et l'écart de 150 ms entre les cases ont été vérifiés sous jsdom (vrai
  `wall.js`), pas dans le CEF du jeu.
- Le débit montant du joueur filmé (10-15 à 10-19) : `tests/spec/cameras_budget_spec.lua` vérifie la règle (tableau du
  README, jamais plus que le budget, une seule vue en grand), le refus `budget` et son ordre, les parts annoncées au
  seul joueur filmé, et `cameras_wall_spec.lua` le pont qui n'inscrit rien pour une vue refusée ; l'application des parts par `setParameters`
  (une à la fois, la dernière gagne, part arrivée avant la description locale) a été vérifiée sur le vrai
  `capture.js` avec un WebRTC simulé. Que le CEF du jeu respecte réellement `maxBitrate` changé en cours de route,
  l'effet sur les images par seconde et le ping, et l'arrivée de l'offre en envoi latent (`TriggerLatentClientEvent`)
  ne se voient qu'en jeu.
