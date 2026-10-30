# Interfaces et fichiers web communs (`vava_ui`) — procédure de test en jeu

Procédure pour vérifier que les interfaces prennent leurs polices, textures et ornements dans la ressource commune
`vava_ui` (T-012) au lieu d'en livrer chacune une copie. Rien ne doit changer à l'écran : le seul gain est un premier
téléchargement plus léger. Le point que le dépôt n'a jamais vu en jeu est le **chargement d'une police depuis une autre
ressource** (`nui://vava_ui/…`, règle CORS du navigateur du jeu) : c'est le premier test.

T-012 se fait en deux temps. **D'abord le pilote** (§ 0, sur `main`) : seul `vava_hud` 1.4.0 a basculé ; les autres
interfaces gardent leurs copies et ne doivent pas avoir bougé. **Ensuite** (§ 1 à 6) : les quatorze autres ont basculé
sur la branche `agents/T-012-suite`, **fusionnée seulement après un § 0 réussi** — `vava_health` 1.2.0,
`vava_characters_ui` 1.1.0, `vava_inventory` 1.8.0, `vava_codex` 1.3.0, `vava_chat` 1.3.0, `vava_skills` 1.2.0,
`vava_gathering` 1.5.0, `vava_crafting` 1.4.0, `vava_farming` 1.6.0, `vava_time` 1.3.0, `vava_voice` 1.3.0,
`vava_cameras` 1.4.0, `vava_admin` 1.8.0, `vava_magic` 2.8.0.
Les tests à deux joueurs sont marqués **(2 joueurs)**. Pour chaque écart : le test (« interfaces 0-3 »), ce que vous
avez vu, les lignes de la console du client (`F8`) et de l'onglet Console des outils de la page.

## 0. Pilote : `vava_hud` 1.4.0

Préparation : serveur de test à jour (Chancellerie 1.6.2, `vava_ui` 1.0.0, `vava_hud` 1.4.0). Pour comparer, gardez
sous la main les captures du rapport `docs/plan/rapports/T-012.md` (HUD avant / après, hors jeu) ou une capture
d'écran du HUD prise avant la mise à jour.

| # | Faire | Attendu |
|---|---|---|
| 1 | Chancellerie → Ressources. | `vava_ui` listée avec « Polices, textures et ornements communs des interfaces (aucun script) ». Une fois cochée et le `server.cfg` enregistré, sa ligne `ensure vava_ui` est juste après `ensure vAvA_core`. |
| 2 | Démarrer le serveur. | Console : `Started resource vava_ui` avant `vava_chat` et avant `vava_hud` ; `module 'vava_hud'…` sans erreur ; aucune ligne `Couldn't start resource` ni `dependency`. |
| 3 | `vava_ui` **décochée** (aucune ligne `ensure vava_ui`) : redémarrer le serveur. | `vava_ui` démarre quand même, juste avant `vava_hud` (dépendance déclarée) ; le HUD s'affiche normalement en jeu. Recocher ensuite `vava_ui`. |
| 4 | En jeu, console du client (`F8`) → `resmon 1`. | `vava_ui` absent de la liste ou à 0,00 ms (aucun script). `vava_hud` comme avant. |
| 5 | Personnage en jeu, rien d'ouvert : regarder les médaillons (santé, faim, soif, voix) en bas à gauche. | Cuir **grainé** (fin grain irrégulier, pas un dégradé lisse), lunette de laiton, anneaux comme avant. |
| 6 | Provoquer une notification (boire, ou `/besoins` sur le serveur de test) : carte en haut à droite. | Texte en **EB Garamond** : lettres fines et serrées, petites minuscules ; **pas** la police large et ronde de Georgia (à texte égal, Georgia prend nettement plus de largeur). Carte grainée, liseré coloré à gauche. Même allure que les notifications d'avant. |
| 7 | Lancer une action longue (couper un arbre, `vava_gathering`). | Barre au centre bas : libellé en **capitales Cinzel** (empattements fins, « VOUS ABATTEZ UN CHÊNE »), indice « Peut être interrompue » en **italique** EB Garamond distinct du droit. |
| 8 | `F8` → `nui_devtools` ; dans la fenêtre des outils, choisir le cadre de `vava_hud` (menu des contextes en haut de l'onglet Console, ou cadre `cfx-nui-vava_hud` dans Éléments). Onglet **Réseau**, cocher « Désactiver le cache », puis recharger la page du HUD (`Ctrl+R` dans les outils, ou `restart vava_hud` en console serveur). Relancer une notification et une action longue. | Requêtes **toutes servies** (statut 200, aucune ligne rouge) : `vava_ui.css`, `eb_garamond.woff2`, `grain.webp` ; `cinzel.woff2` et `eb_garamond_italic.woff2` dès que la barre de progression s'affiche (une police n'est demandée que quand un texte l'emploie). Leur adresse commence par `nui://vava_ui/web/` (ou `https://cfx-nui-vava_ui/web/`). **Aucune** requête vers `devmock.js` ni `/dev/`. |
| 9 | Même fenêtre, onglet **Console** du cadre `vava_hud`. | **Aucune** erreur contenant `CORS`, `Access-Control-Allow-Origin`, `blocked` ou `Failed to decode downloaded font`. |
| 10 | Onglet **Éléments** : sélectionner une notification (`.toast`), puis Calculé (Computed) → tout en bas « Polices rendues » (Rendered Fonts). | `EB Garamond` — « Network resource » (ou « ressource réseau »), **pas** `Georgia` ni `Palatino Linotype`. Même contrôle sur `.progress-label` pendant une action : `Cinzel`. |
| 11 | Ouvrir une autre interface, encore sur ses propres copies (inventaire `I`, Codex `F1`, chat `T`). | Inchangée : mêmes polices et textures qu'avant la mise à jour. |
| 12 | **(2 joueurs)** Second client : vider le cache de FiveM (dossier `FiveM.app/data/cache`), se connecter pendant que le premier est en jeu. | HUD juste dès la première connexion (tests 5 à 7). |
| 13 | Serveur de test seulement : `stop vava_ui` en console serveur. | FXServer arrête aussi `vava_hud` (il en dépend) : le HUD disparaît. Si `vava_hud` reste démarré, noter ce qui s'affiche (attendu : polices de repli, cuir sans grain, tout lisible). **Redémarrer le serveur** pour revenir à l'état normal (jamais sur un serveur ouvert). |

**Si le test 8, 9 ou 10 échoue** (polices refusées, erreur CORS) : noter le message exact et l'adresse de la requête.
Le HUD reste lisible (police de repli). La suite de T-012 attend : la correction essaiera d'abord l'adresse
`https://cfx-nui-vava_ui/…` (une chaîne à changer par page et dans `vava_ui.css`), puis, avec votre accord, une feuille
de polices intégrée (`data:`, environ 50 Ko de plus). Si **seules** les polices échouent et que `grain.webp` est servi,
le dire : c'est le cas attendu d'un refus CORS.

## 1. Démarrage (après la bascule des 15 interfaces)

Préparation : § 0 réussi, branche de la suite fusionnée, serveur de test à jour (versions ci-dessus). Gardez une capture
d'écran de chaque interface prise **avant** la mise à jour (ou les captures « avant » du rapport) pour comparer.

| # | Faire | Attendu |
|---|---|---|
| 1 | Démarrer le serveur (Chancellerie, `server.cfg` régénéré). | Console : `Started resource vava_ui` juste après `vAvA_core`, avant `vava_chat` ; chaque module affiche `module 'xxx' vY prêt` avec les versions ci-dessus ; aucune ligne `Couldn't start resource` ni `dependency`. |
| 2 | Serveur existant mis à jour, **sans** ligne `ensure vava_ui` : redémarrer. | `vava_ui` démarre quand même, avant `vava_chat` (dépendance de quinze ressources) ; Chancellerie → Ressources : `vava_ui` listée avec sa description, placée après `vAvA_core` quand on la coche. |
| 3 | `resmon 1` au repos. | `vava_ui` n'apparaît pas (ou 0,00 ms) : aucun script. Les quinze modules à page comme avant. |

## 2. Rendu de chaque interface

Pour chacune : titres en Cinzel (capitales à empattements fins, pas les capitales de Georgia), texte en EB Garamond
(italique distinct du droit), grain sur le cuir, papier sur les parchemins qui en avaient, coins de laiton aux cadres ;
allure identique à la capture d'avant la mise à jour (hors jeu, les 101 vues des pages ont été comparées pixel par
pixel : aucune différence hormis les animations et les heures affichées, voir le rapport).

| # | Faire | Attendu |
|---|---|---|
| 1 | Se connecter : écran de sélection, puis « Créer » et parcourir les sept onglets de l'éditeur. | `vava_characters_ui` comme avant : cuir grainé, coins de laiton du cadre, losanges des cartes, blason, filets. |
| 2 | En jeu : regarder le HUD ; lancer une action longue (récolte). | Médaillons au grain fin, barre de progression en Cinzel. |
| 3 | Inventaire (`I`), puis jeter un objet pour voir le sac au sol. | Cuir grainé, coins de laiton, filet et losange des titres ; cases et balance du module inchangées. |
| 4 | Codex (`F1`) ; chat (`T`) avec quelques messages et une suggestion de commande. | Codex : livre, coins, deux filets, losange. Chat : fenêtre de cuir à coins de laiton, bande de parchemin **au papier** sous la saisie, suggestions. |
| 5 | Compétences (`K`), les quatre onglets. | Livre de cuir grainé, pages au papier, coins de laiton. |
| 6 | Récolte : invite près d'un arbre ; pêche jusqu'à la barre de tension ; panneau des zones. | Invite à plaque de laiton, barre de tension, panneau de parchemin au papier : rien de changé. |
| 7 | Forge : invite, menu (Recettes, Réparation, Poinçon) ; façonner un chef-d'œuvre jusqu'à la boîte de baptême. Champ : invite et menu d'un emplacement. | Parchemins au papier, coins de laiton (deux cadres à la forge), rien de changé. |
| 8 | `/aterre` (outil de développement `vava_dev_characters`), puis se faire relever par un autre joueur **(2 joueurs)**. | Écran à terre : filet et losange au-dessus du titre ; bandeau du relevage grainé. |
| 9 | Conseil : Registre (`F10`), chaque signet, dialogue de bannissement, proclamation. | Couverture grainée, pages au papier, coins ; grands titres en **Cinzel Decorative** comme avant. |
| 10 | Outil « Ciel et heure » (Registre → Outils, ou `/ciel`). | Reliure de cuir grainé, coins de laiton, feuillet clair. |
| 11 | Éditeur des zones de voix (`/zonesvoix`), ouvrir une zone ; mur des caméras (`/cameras`). | Titres « Zones de voix » et « Mur des caméras » en Cinzel Decorative **grasse**, comme avant (pas plus fins) ; lettrines de la voix ; papier de l'éditeur ; filet sous le bandeau du mur. |
| 12 | Magie : roue (`Tab`), barre d'incantation, grimoire, registre des murmures. | Cinzel Decorative 400 et 700, papier, runes, écriture, cadres de laiton. |

## 3. Outils de développement de la NUI

| # | Faire | Attendu |
|---|---|---|
| 1 | `F8` → `nui_devtools`, cadre de `vava_hud`, onglet Réseau, puis recharger la page (ou `restart vava_hud`). | `vava_ui.css`, `eb_garamond.woff2`, `cinzel.woff2`, `grain.webp` : tous servis (200) ; **aucune** erreur CORS ni requête en rouge ; aucune requête vers `devmock.js` ni `/dev/`. |
| 2 | Même chose dans le cadre de `vava_crafting` (menu ouvert). | `paper.webp`, `frame.svg` servis ; Éléments → texte → « Rendered Fonts » : `EB Garamond`, pas `Georgia`. |
| 3 | Cadre de `vava_voice` (éditeur ouvert) ou de `vava_cameras` (mur ouvert) : Éléments → titre → « Rendered Fonts ». | `Cinzel Decorative` (Bold), pas `Cinzel` ni `Georgia`. |
| 4 | Dans trois ou quatre autres cadres (inventaire, chat, Registre, magie), onglet Réseau après avoir ouvert l'interface. | Aucune requête en rouge (404) : en particulier rien vers `web/fonts/`, `img/grain.png`, `img/paper.png`, `img/frame.svg` du module, ni vers `devmock.js` ou `/dev/`. |

## 4. Première connexion **(2 joueurs)**

| # | Faire | Attendu |
|---|---|---|
| 1 | Second client : vider le cache de FiveM, se connecter pendant que le premier est en jeu. | Écran de sélection et toutes les interfaces justes dès la première connexion. Noter le volume téléchargé si le client l'affiche (attendu : environ 2,9 Mo de moins qu'avant T-012 ; repris à T-019). |

## 5. Arrêt de `vava_ui` (serveur de test seulement)

| # | Faire | Attendu |
|---|---|---|
| 1 | `stop vava_ui` en console. | FXServer arrête aussi les quinze modules qui en dépendent, et par ricochet ceux qui dépendent d'eux (console). Redémarrer le serveur pour revenir à l'état normal. Si des modules restent démarrés, noter ce qui s'affiche (attendu : polices de repli, dégradés sans grain ni coins, tout reste lisible). |

## 6. Textures WebP

| # | Faire | Attendu |
|---|---|---|
| 1 | Registre (`F10`) en grand, panneaux de cuir les plus larges. | Grain régulier, **aucune ligne ni raccord** visible entre les tuiles. |
| 2 | Menu d'une forge, compétences : parchemin. | Papier identique à avant (comparer à une capture d'écran prise avant la mise à jour). |
