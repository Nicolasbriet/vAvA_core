# Accueil des nouveaux venus — procédure de test en jeu

Procédure pour vérifier en jeu l'arrivée d'un nouveau personnage (`vava_arrival` 1.0.0) et l'ouverture du Codex à un
chapitre (`vava_codex` 1.4.0). Comptez une heure ; les tests à deux joueurs sont marqués **(2 joueurs)**. Chaque test
dit quoi faire et ce qui doit se passer ; si ce n'est pas le cas, notez l'étape, ce que vous avez vu, et la ligne de
console correspondante.

## 0. Préparation

1. **Ordre de démarrage** (`server.cfg`, ou la Chancellerie qui le fait seule), après `oxmysql` : `vAvA_core`,
   `vava_ui`, `vava_chat`, `vava_world`, `vava_time`, `vava_appearance`, `vava_characters_ui`, `vava_hud`,
   `vava_inventory`, `vava_needs`, `vava_health`, `vava_admin`, `vava_voice`, `vava_cameras`, `vava_magic`,
   `vava_skills`, `vava_gathering`, `vava_crafting`, `vava_farming`, `vava_codex`, `vava_arrival`, `vava_chancellerie`.
2. **Rôles** : A est Sénéchal (console : `vava_conseil <compte de A> senechal`) ; B n'a aucun rang.
3. **Outils de développement** (`/respawn`, `/perso`) : `set vava_env dev` au `server.cfg` du serveur de test, et
   `vava_dev_characters` démarré ; réservés au Souverain ou à l'ACE `vava.dev` (B : `add_ace identifier.license:<licence>
   vava.dev allow` en console).
4. **Consoles** : celle du serveur et celle du client (`F8`) ouvertes.
5. **Chapitre d'essai** : pour voir le Codex s'ouvrir à un chapitre **avant T-023**, mettre provisoirement
   `codex.chapter = 'vava_inventory'` dans `modules/vava_arrival/config.lua`, puis `restart vava_arrival` (remis au
   test 20).
6. **Base** : un client SQL ouvert sur la base du serveur, pour les tables `vava_arrival` et `vava_arrival_log`.

## 1. Arrivée d'un nouveau personnage

| # | Faire | Attendu |
|---|---|---|
| 1 | Démarrer le serveur. | Console : migration `0001_arrival.sql` appliquée, `module 'vava_arrival' v1.0.0 prêt`, `module 'vava_codex' v1.4.0 prêt`. Aucun avertissement. |
| 2 | B crée un personnage et le joue. | Apparition au point d'arrivée (`spawn.defaultPoint`). Environ 4 s après la fin du fondu : notification d'accueil, puis celle de la besace ; le Codex s'ouvre (au chapitre Inventaire avec le réglage d'essai, à son index sinon), clavier et souris pris ; `Échap` le ferme. Besace (`I`) : 2 Miche de pain, 2 Outre d'eau. |
| 3 | B ferme le Codex, puis `/respawn` (ou se fait mettre à terre et rend l'âme). | Aucune notification, aucun objet de plus. |
| 4 | B se déconnecte et revient sur le même personnage. | Apparition à sa dernière position ; ni accueil ni objet. |
| 5 | B joue un personnage créé avant `vava_arrival` (temps de jeu non nul). | Rien. `SELECT * FROM vava_arrival WHERE character_id = <id>` : aucune ligne. |

## 2. Attente d'un écran calme

| # | Faire | Attendu |
|---|---|---|
| 6 | B crée un personnage et appuie sur `F1` dès la fin du fondu, puis ferme le Codex au bout de 10 s. | L'accueil attend ; dans la seconde qui suit la fermeture : notifications, puis le Codex s'ouvre au chapitre. |
| 7 | B crée un personnage, ouvre le Codex dès la fin du fondu et le laisse ouvert 40 s. | À 34 s environ : notifications d'accueil, de la besace et rappel du Codex (`codexHint`) ; le Codex ouvert n'est pas touché. |
| 8 | B crée un personnage et quitte le jeu (`quit` en F8) dans les 3 s qui suivent l'apparition, puis revient. | Au retour : accueil affiché (pas encore vu), **pas** de seconde dotation (besace : 2 pains, 2 outres, ou rien si le serveur n'avait pas encore écrit la besace : voir 15). |

## 3. Dotation refusée, limite du compte

| # | Faire | Attendu |
|---|---|---|
| 9 | Console : `stop vava_inventory` ; B crée un personnage. Puis `ensure vava_inventory`. | Accueil sans la ligne de la besace ; console : dotation non donnée (`inventory_unavailable`). Après `ensure` : en quelques secondes, les objets sont dans la besace, sans nouvel accueil. `vava_arrival` : `kit = 'given'`. À confirmer : FXServer peut arrêter `vava_arrival` avec l'inventaire (il déclare `dependency 'vava_inventory'`) ; si `stop` l'arrête, noter que ce test ne s'applique pas. |
| 10 | Sur un même compte, en moins de 30 jours : créer un personnage, le jouer, le supprimer ; recommencer jusqu'au 4e personnage. | Les trois premiers reçoivent la dotation ; le 4e est accueilli sans la ligne de la besace ; `vava_arrival_log` : `kit_withheld` (`count` 3, `max` 3). |

## 4. Conseil

| # | Faire | Attendu |
|---|---|---|
| 11 | **(2 joueurs)** A : `/accueil etat <B>`. | Une ligne dans le chat de A seul : nom, numéro, « dotation donnée le … ; accueil vu le … ». Rien chez B. |
| 12 | **(2 joueurs)** A : `/accueil redoter <B>`. | B reçoit 2 pains et 2 outres (sans notification) ; chat de A : « Dotation redonnée à … » ; Registre (`F10`) → Journal : « Dotation redonnée » (joueur, personnage) ; `vava_arrival_log` : `admin_regive`. |
| 13 | **(2 joueurs)** A : `/accueil rejouer <B>` ; B ferme puis attend. | Chez B : notification d'accueil et Codex au chapitre ; Registre : « Accueil rejoué ». |
| 14 | **(2 joueurs)** B (sans rang) : `/accueil etat <A>` ; `F1`. | Rien ne se passe ; le Codex de B ne montre pas `/accueil`. Celui de A le montre au chapitre Accueil, avec ses trois actions. |
| 15 | Créer un personnage C ; **dans la seconde** qui suit l'apparition de la besace garnie, tuer FXServer (gestionnaire des tâches). Relancer, revenir sur C. | Pas de seconde dotation. Si la ligne était restée « réservée » : console « dotation incertaine », `vava_arrival_log` `kit_uncertain`, `/accueil etat` dit « incertaine » ; la besace est vide ou garnie selon ce que l'inventaire avait écrit ; `/accueil redoter` répare. |
| 16 | **(2 joueurs)** A se tient au point d'arrivée quand B arrive. A : `/vava_reseau joueur <A>` puis `/vava_reseau joueur <B>`. | Chez A : aucune ligne `vava_arrival`. Chez B : `vava_arrival:welcome` une fois (~25 o), `rpc vava_arrival:welcomed`, `rpc vava_codex:open`. |
| 17 | `resmon` client de B au repos, puis pendant les 4 s d'attente de l'accueil. | `vava_arrival` à 0,00 ms au repos ; au plus 0,01 ms pendant l'attente. |
| 18 | Console du serveur : `accueil etat <n° de B>`, puis `accueil redoter <n° de B>`. | La ligne d'état s'écrit dans la console ; la dotation part, `vava_arrival_log` : `admin_regive` avec `actor_account_id` vide. |
| 19 | B en jeu : `restart vava_arrival`. | Aucun accueil, aucun objet ; `/accueil etat <B>` fonctionne aussitôt après `prêt`. |
| 20 | Remettre `codex.chapter = 'premiers_pas'`, `restart vava_arrival`, créer un personnage. | Le Codex s'ouvre à son index (le chapitre n'existe pas avant T-023), sans erreur en F8. |

## 5. Ce qui reste à confirmer (README de `vava_arrival`)

- `IsScreenFadedIn()` est vrai assez tôt après l'apparition (sinon l'accueil attendrait 30 s : test 2).
- Le Codex ouvert par `openAt` reçoit bien clavier et souris et `Échap` le ferme (test 2).
- `IsNuiFocused()` voit le Codex et l'inventaire ouverts (tests 6 et 7).
- Les valeurs vides des requêtes (`kit_at` effacé au retour « à donner », compte de la console au journal) arrivent en
  `NULL` (tests 9 et 18).
