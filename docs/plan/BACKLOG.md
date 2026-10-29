# Backlog d'Eldoria

## Règles (lues par chaque agent avant de choisir)

**Statuts** : `à faire` · `en cours` · `à tester en jeu` · `validée` · `bloquée`. Seul un humain met `validée`.

Une tâche est **éligible** si :
1. son statut est `à faire` ;
2. elle n'est pas marquée **HUMAIN** ;
3. chacune de ses dépendances est `à tester en jeu` ou `validée` ;
4. toutes les **portes de phase** des phases précédentes sont `validée`.

On prend la première tâche éligible dans l'ordre du fichier. On passe son statut à `en cours` au début, à
`à tester en jeu` à la fin (ou `bloquée` avec une ligne `Blocage :` qui dit pourquoi). Un problème trouvé hors
périmètre devient une **nouvelle tâche** ajoutée à la fin de la phase concernée (numéro libre suivant), jamais une
correction sauvage. Un problème **BLOQUANT** remonté par un audit devient une tâche placée en tête de sa phase.

---

## Phase 0 — Socle

### T-001 — Lint propre et CI
- Agent : vava-dev-lua · Dépend de : — · Statut : à tester en jeu
- Corriger les 14 avertissements luacheck relevés le 29 octobre 2026 (variables inutilisées, masquages, branche
  vide, affectation écrasée) sans changer le comportement. Vérifier que `.github/workflows/verifier.yml` passe.
- Critères : `luacheck .` sans avertissement ; versions des modules touchés montées en correctif.

### T-002 — Tests unitaires du core
- Agent : vava-testeur · Dépend de : — · Statut : à tester en jeu
- Tester `shared/lib/schema.lua` en priorité (c'est la barrière de sécurité de chaque RPC : bornes, NaN, ±inf,
  tables imbriquées, clés inconnues, chaînes trop longues, entrée réseau vs locale), puis `string.lua`, `table.lua`,
  `pending.lua`, `hooks.lua`.
- Critères : chaque règle du tableau « Schémas » de `docs/api.md` a au moins un test positif et un négatif.

### T-003 — Tests unitaires des modules métiers et magie
- Agent : vava-testeur · Dépend de : T-002 · Statut : à faire
- Logique pure de `vava_crafting/shared/quality.lua`, `vava_farming/shared/growth.lua` et `geometry.lua`,
  `vava_gathering/shared/geometry.lua`, `vava_skills/shared/progression.lua` (compléter), `vava_magic/shared/*`,
  `vava_inventory/shared/grid.lua`. Vérifier les valeurs documentées dans chaque README.

### T-004 — Procédures de test en jeu manquantes
- Agent : vava-testeur · Dépend de : — · Statut : à tester en jeu
- Écrire `docs/tests/` pour : connexion et personnage (création, sélection, suppression, reconnexion, position),
  inventaire (y compris 2 joueurs et conteneurs), besoins, santé (mort, aide, réveil), chat, voix, magie (reprendre
  la section « Tests à faire en jeu » de son README), Registre du Conseil, Codex. Déplacer `docs/tests-metiers.md`
  dans `docs/tests/metiers.md` (en laissant un renvoi).

Les tâches T-005 à T-008 corrigent les anomalies relevées par T-004 (détail, fichiers et lignes dans
`docs/plan/rapports/T-004.md`) avant la session de test T-009. Chacune met aussi à jour les attendus des procédures
de `docs/tests/` qui décrivaient le défaut, et les README ou `docs/api.md` qui contredisaient le code. Les points
marqués « décision » attendent le porteur du projet : ne pas les coder sans sa réponse.

### T-005 — Inventaire : redémarrage, affichage et messages
- Agents : vava-dev-lua + vava-dev-nui · Dépend de : — · Statut : à faire
- I1 : après `restart vava_inventory`, les objets d'autres modules mis de côté au chargement des besaces sont
  replacés dès que leur définition revient, main comprise, sans jamais perdre ni recouvrir une pile.
- Interface : un refus du serveur n'efface pas les changements arrivés entre-temps (geste d'un autre joueur).
- Messages : « Cet objet n'est plus là. » quand un autre l'a pris ; refus d'un objet tenable par la ceinture
  notifié ; la touche de fermeture suit celle que le joueur a choisie pour l'ouverture.
- Critères : test du replacement (logique pure ou harnais) ; `restart vava_inventory` à 2 joueurs sans objet perdu
  dans la procédure ; versions montées.

### T-006 — À terre, santé, besoins et magie
- Agent : vava-dev-lua · Dépend de : — · Statut : à faire
- S1 : la mise à terre couche le ped même quand sa vie GTA vaut exactement 100 (faim, soif, sort, `/vie 0`).
- S2 : aucune action de récolte, d'artisanat ou d'agriculture à terre, refusée par le serveur avec l'export
  existant `vava_health:isDowned` (pas de copie de la règle) ; `E` ne fait plus que rendre l'âme à terre.
- M1 : un joueur à terre n'est plus mouillé, poussé ni renversé par la magie (Vague, sol mouillé, brume, boue).
- M2 : la fin d'un Gel ne libère pas un joueur immobilisé par le Registre.
- Santé : médaillon rendu après un redémarrage à terre ; l'écran affiche la touche du joueur.
- Magie : verrou de cible à la portée du sort prêt ; `/lancer` refusé arme en main ; `/sort` chez un non-mage ne dit
  plus « Sort prêt » ; journal des dégâts entièrement écrit à l'arrêt ; messages du Conseil et `/lueur couleur`
  en français.
- README à écrire : `vava_needs`, `vava_health` ; README de `vava_magic` à remettre d'accord avec le code.
- Décisions : délai entre deux soins ; objets consommés quand `vava_needs` ou `vava_health` est arrêté ; membre du
  Conseil à terre qui se relève lui-même ; Brume et Rempart en zone protégée.

### T-007 — Codex, Registre et personnage
- Agents : vava-dev-lua + vava-dev-nui · Dépend de : — · Statut : à faire
- C1 : un nombre obligatoire du Codex doit être choisi (pas de 0 d'office) ; valeur bornée et arrondie.
- Codex : un maximum de favoris ou de dernières pages abaissé tronque au lieu de bloquer « Lancer » ; `recent.max`
  lu au lieu de 12 ; main rendue à l'arrêt ; suggestions du chat à jour après un changement de rang.
- Registre : outil des caméras visible avec le droit `watch` ; état « immobilisé » cohérent après un redémarrage ;
  identifiants (license, discord, steam) plus envoyés à l'interface ; observateur qui part : jamais rendu sous terre.
- Personnage : règles de nom de l'interface tirées de la config du serveur (peut toucher le core : cette tâche
  l'autorise) ; nettoyage à l'arrêt de `vava_characters_ui` ; scène de création distincte du point d'apparition
  (`-- PLACEHOLDER`).
- README à écrire : `vava_appearance`, `vava_characters_ui` ; README de `vava_codex` (test 4) corrigé.
- Décisions : `core:characters:create` ouvert aux clients ; revenir à la sélection sans se reconnecter.

### T-008 — Voix, chat et Chancellerie
- Agents : vava-dev-lua + vava-dev-nui · Dépend de : — · Statut : à tester en jeu
- V1 : le `server.cfg` écrit par la Chancellerie contient `setr voice_useNativeAudio true` et
  `setr voice_useSendingRangeOnly true` (cette tâche autorise à toucher `chancellerie/`).
- Voix : nom de zone borné de façon cohérente entre le champ (signes) et le schéma (octets) ; pas de double envoi
  par `Entrée` ; focus rendu à l'arrêt ; zones et limite « à terre » redemandées après un redémarrage ; personne en
  sélection ne s'entend pendant un `restart`.
- Chat : README remis d'accord (test 9, `recipients`) ; `/staff` suggéré au seul Conseil.
- Chat (repris de T-007) : suggestions du chat à jour après un changement de rang du Conseil, sans reconnexion.
- README à écrire : `vava_voice`, `vava_cameras`, `vava_chancellerie`.
- `docs/api.md` : ordre de démarrage complet, refus des besoins « dès 95 », actions non protégées par le rang.

### T-009 — PORTE : première session de test complète — **HUMAIN**
- Dépend de : T-001, T-004, T-005 à T-008 · Statut : à faire
- Dérouler toutes les procédures de `docs/tests/`, noter chaque écart en tâche de correction (phase 0), mesurer le
  resmon de chaque ressource au repos et en action, noter le poids téléchargé à la première connexion.

## Phase 1 — Sécurité, performance, réseau

### T-010 — Audit sécurité de tout le dépôt
- Agent : vava-securite · Dépend de : — · Statut : à faire
- Un rapport par module dans `docs/audits/securite-<module>.md` (le core compris). Chaque BLOQUANT ou IMPORTANT
  devient une tâche de correction en tête de phase 1. (Exception à la lecture seule : l'agent écrit ses rapports et
  ses tâches.)

### T-011 — Audit réseau et performance de tout le dépôt
- Agent : vava-reseau-perf · Dépend de : — · Statut : à faire
- Un rapport par module dans `docs/audits/reseau-<module>.md` : chaque évènement serveur→client (cible, taille,
  fréquence), chaque écriture de GlobalState et de state bag, chaque boucle client et sa fréquence, poids des
  fichiers web. Partir de l'état des lieux de `SECURITE_RESEAU.md`. Mêmes règles pour les tâches de correction.

### T-012 — Ressource web commune `vava_ui`
- Agents : vava-architecte → vava-dev-nui · Dépend de : — · Statut : à faire
- Polices, textures (grain, papier, cadres, séparateurs) et icônes communes dans une ressource unique, référencées
  par `nui://vava_ui/…` ; retirer les copies des autres modules. Démarre juste après `vAvA_core`.
- Critères : aucune police ni texture commune dupliquée ; poids total des dossiers `web/` mesuré avant/après dans le
  rapport ; toutes les interfaces s'affichent (devmock).

### T-013 — Compteur réseau `core.net`
- Agents : vava-architecte → vava-dev-lua · Dépend de : — · Statut : à faire
- API du core pour envoyer à un joueur ou à une liste (`core.net.send`, `sendNear(coords, rayon, …)`) qui compte
  par ressource et par évènement le nombre d'envois et une estimation de taille ; commande du Conseil
  `/vava_reseau` (top des évènements de la dernière minute) et affichage dans la Chancellerie si simple.
- Critères : tests unitaires de l'agrégation ; documenté dans `docs/api.md`.

### T-014 — Abonnements de zone dans le core
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-013 · Statut : à faire
- Service générique : un module déclare des zones (centre, rayon) ; le serveur tient la liste des joueurs abonnés
  à chaque zone (entrée demandée par le client, sortie vérifiée côté serveur, nettoyage à la déconnexion) ;
  `publish(zone, différence)` n'envoie qu'aux abonnés. Voir le modèle de `SECURITE_RESEAU.md`.

### T-015 — Récolte : GlobalState → abonnements de zone
- Agent : vava-dev-lua · Dépend de : T-014 · Statut : à faire
- `vava_gathering` (zones et nœuds) n'écrit plus dans GlobalState. Même comportement en jeu.

### T-016 — Agriculture : GlobalState → abonnements de zone
- Agent : vava-dev-lua · Dépend de : T-014 · Statut : à faire

### T-017 — Artisanat : GlobalState → abonnements de zone
- Agent : vava-dev-lua · Dépend de : T-014 · Statut : à faire

### T-018 — Revue des boucles client
- Agent : vava-dev-lua (avec vava-reseau-perf) · Dépend de : T-011 · Statut : à faire
- Chacun des 13 fichiers avec `Wait(0)` : la boucle ne tourne que pendant un état actif, sinon intervalle adaptatif.
  Même revue pour toutes les boucles signalées par T-011.

### T-019 — PORTE : mesure après optimisation — **HUMAIN**
- Dépend de : T-010 à T-018 et leurs corrections · Statut : à faire
- Refaire les mesures de T-009 (resmon, poids, `/vava_reseau` à 2 joueurs éloignés puis proches). Comparer aux
  objectifs de `SECURITE_RESEAU.md`.

## Phase 2 — Arrivée

### T-020 — Écran de chargement `vava_loading`
- Agents : vava-architecte → vava-dev-nui · Dépend de : T-012 · Statut : à faire
- Ressource dédiée : `loadscreen` + `loadscreen_manual_shutdown 'yes'`, fermée par le client quand la sélection de
  personnage est prête (coordination avec `vava_characters_ui`). Progression réelle (messages `loadProgress`),
  extraits du lore en rotation, conseils, nom du serveur ; musique facultative coupable, désactivée par défaut.
  Identité visuelle des autres interfaces. Aucune ressource externe.
- Critères : poids total ≤ 1,5 Mo (contrôlé par `scripts/audit-reseau.sh`) ; ouvrable hors jeu avec un devmock qui
  simule la progression ; aucun écran noir entre le chargement et la sélection.

### T-021 — Textes de l'écran de chargement et du premier pas
- Agent : vava-gardien-lore · Dépend de : T-020 · Statut : à faire
- 20 à 30 extraits courts du lore, 15 conseils de jeu, textes d'accueil.

### T-022 — Arrivée d'un nouveau personnage
- Agents : vava-architecte → vava-dev-lua · Dépend de : — · Statut : à faire
- Point d'arrivée en config (PLACEHOLDER), dotation de départ minimale en config (besace, vêtements simples, pain,
  eau), message d'accueil, ouverture du Codex au chapitre « Premiers pas » à la première connexion. Rien de plus :
  le reste s'obtient auprès des autres joueurs.

### T-023 — Codex : chapitre « Premiers pas » et guide des métiers
- Agents : vava-dev-lua + vava-gardien-lore · Dépend de : T-022 · Statut : à faire
- Pages de lecture dans le Codex (pas seulement les commandes) : vivre à Eldoria, troquer, apprendre un métier,
  la magie, le Conseil.

## Phase 3 — L'Atelier : socle et créateurs du monde

Référence : `docs/plan/ATELIER.md` et les maquettes `docs/maquettes/`. Les écrans réalisés doivent ressembler aux
maquettes.

### T-100 — Ressource `vava_atelier` : cadre, accueil, droits
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-012 · Statut : à faire
- Interface NUI unique (accueil selon la maquette `Main` : familles, recherche, brouillons, journal), ouverture par
  touche et commande déclarées au registre `core:commands`, registre `vava_atelier:editors`, droits par éditeur via
  `vava_admin`, journal du Conseil. Formulaire générique piloté par schéma (widgets `slider`, `segmented`, `select`,
  `toggle`, `text`, `duration`, `item`, `model`).
- Critères : un éditeur d'exemple (module `examples/`) s'affiche sans code d'interface propre ; devmock de chaque
  écran ; relectures sécurité et réseau OK.

### T-101 — Définitions : stockage, versions, cycle de vie
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-100, T-014 · Statut : à faire
- Table `vava_atelier_definitions` (une ligne par version), statuts brouillon / essai / publié / archivé, import
  de la config comme version 1 au premier démarrage (la base fait foi ensuite), réimport explicite par commande,
  retour à une version, export et import JSON, rechargement à chaud chez le module (`apply`), diffusion aux joueurs
  concernés seulement.
- Critères : tests unitaires du cycle de vie et de la validation ; publier puis revenir en arrière en jeu sans
  redémarrage.

### T-102 — Outil de placement et créateur de récolte
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-101, T-015 · Statut : à faire
- Outil de placement commun (point, point orienté avec modèle, cercle, polygone ; aperçu vert/rouge ; molette,
  `Maj`, clic droit, `Ctrl+Z`, `Échap` ; barre des touches) sur le modèle de l'éditeur de `vava_voice`.
- `vava_gathering` déclare ses éditeurs zone et point (maquette `Recolte`) ; « Tester la récolte » en essai.
- Critères : créer une zone et 5 points en jeu, publier, un autre joueur proche les voit apparaître sans
  redémarrage, un joueur loin ne reçoit rien (vérifié avec `/vava_reseau`).

### T-103 — Créateur d'agriculture
- Agent : vava-dev-lua (+ vava-dev-nui si widget) · Dépend de : T-102, T-016 · Statut : à faire
- Parcelles en polygone (communale ou privée), emplacements, puits, greniers, composteurs.

### T-104 — Créateur d'artisanat
- Agent : vava-dev-lua · Dépend de : T-102, T-017 · Statut : à faire
- Stations (type, qualité, combustible, recettes disponibles, publique ou privée).

### T-105 — Confréries et leur créateur `vava_guilds` (remplace l'ancienne T-042)
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-102 · Statut : à faire
- L'équivalent des « jobs » du RP classique, sans salaire. Créateur selon la maquette `Confrerie` : nom, blason,
  type (rôle de la cité nommé par le Conseil, ou confrérie libre validée par le Conseil), grades ordonnés, grille
  grades × droits, lieux posés en jeu (coffre = conteneur ancré de `vava_inventory`, vestiaire, point de service),
  tenue (PLACEHOLDER). Côté joueurs : recruter, promouvoir, renvoyer, quitter ; registre des membres ; coffre
  journalisé. Droits fournis par les autres modules au registre (`lier`, `fouiller`, `cachot`, `coffre`…) pour que
  la grille s'enrichisse sans toucher à `vava_guilds`.
- Critères : créer la Garde et les Guérisseurs en jeu, recruter un second joueur, vérifier qu'un droit décoché est
  refusé par le serveur même en appelant le RPC directement.

### T-106 — Portes, serrures, clés et leur créateur `vava_doors` (remplace l'ancienne T-035)
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-102 · Statut : à faire
- Viser une porte du décor pour la déclarer ; verrouillée ou non ; état décidé par le serveur, envoyé aux joueurs
  proches seulement ; clés = objets avec métadonnées ; copie de clé chez un artisan (recette) ; crochetage lié à une
  compétence ; une porte peut appartenir à une confrérie (droit) ou à un logis.

### T-109 — PORTE : l'Atelier du monde en jeu — **HUMAIN**
- Dépend de : T-100 à T-106 · Statut : à faire
- Avec un second membre du staff qui ne connaît pas l'Atelier : lui faire créer une zone de récolte, une forge et
  une confrérie **sans explication**. Noter chaque hésitation : ce sont des tâches de correction d'interface.

## Phase 4 — Combat v1

Référence : `docs/plan/COMBAT_V1.md`. Ordre à respecter : chaîne de dégâts, moteur, défense, réglages, puis
seulement l'éditeur (phase 6).

### T-110 — Chaîne de dégâts commune
- Agents : vava-architecte → vava-dev-lua · Dépend de : — · Statut : à faire
- Export serveur `vava_health:hit(target, paquet)`, registre de modificateurs ordonnés, hooks `vava_health:hit` ;
  annulation des dégâts natifs de GTA entre joueurs.
- Critères : tests unitaires de l'ordre des modificateurs ; aucun dégât entre joueurs possible hors de la chaîne.

### T-111 — Armes de corps à corps
- Agent : vava-dev-lua · Dépend de : T-110 · Statut : à faire
- Objets armes (catégories, dégâts de base, qualité de forge, usure), correspondance vers modèles vanilla
  (PLACEHOLDER), bouclier accroché, contrôles natifs du corps à corps et armes à feu coupés. Recettes de forge
  ajoutées à `vava_crafting`.

### T-112 — Moteur de techniques `vava_combat`
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-111 · Statut : à faire
- Techniques en données (format de `COMBAT_V1.md`), 4 techniques d'épée en config, RPC `vava_combat:use`, fenêtre
  de frappe tenue par le serveur, positions serveur et tolérances, enchaînement, réactions envoyées aux proches
  seulement ; verrouillage de cible repris de `vava_magic`.
- Critères : tests unitaires de la géométrie ; impossible de toucher hors portée ou à travers le délai ; resmon au
  repos inchangé.

### T-113 — Blocage, parade, esquive
- Agent : vava-dev-lua · Dépend de : T-112 · Statut : à faire

### T-114 — Endurance et HUD
- Agents : vava-dev-lua + vava-dev-nui · Dépend de : T-112 · Statut : à faire

### T-115 — Styles, compétences de combat, XP
- Agent : vava-dev-lua · Dépend de : T-113, T-114 · Statut : à faire
- Styles par catégorie d'arme, compétences de combat dans `vava_skills`, déblocage par rang, XP sur vraie cible,
  mentorat du maître d'armes ; techniques de hache, masse, dague, bâton et bouclier en config.

### T-116 — La magie sur la chaîne de dégâts
- Agent : vava-dev-lua · Dépend de : T-110 · Statut : à faire
- Les dégâts de `vava_magic` passent par `hit` ; les boucliers et résistances deviennent des modificateurs ; même
  comportement en jeu pour les 11 sorts.

### T-119 — PORTE : sensations du combat — **HUMAIN**
- Dépend de : T-110 à T-116 · Statut : à faire
- Au moins 4 joueurs, latences différentes. Régler les tolérances et fenêtres en config jusqu'à ce que les coups
  « portent ». Chaque réglage retenu est noté dans `COMBAT_V1.md`.

## Phase 5 — Interactions RP

### T-030 — Troc face à face `vava_trade`
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-014 · Statut : à faire
- Proposer un échange à un joueur proche ; fenêtre partagée où chacun dépose des objets de sa besace ; toute
  modification annule les validations ; double validation ; exécution **atomique** par `vava_inventory` (tout ou
  rien, place vérifiée des deux côtés) ; annulation si l'un s'éloigne, meurt, se déconnecte ; journal du Conseil.
  Fiche d'objet visible (qualité, provenance, artisan) pour juger la valeur.
- Critères : impossible de dupliquer (tests à 2 joueurs avec spam, déconnexion pendant la validation, objet déplacé
  pendant l'échange) ; verdicts sécurité et réseau OK.

### T-031 — Donner un objet de la main à la main
- Agent : vava-dev-lua · Dépend de : T-030 · Statut : à faire
- Glisser un objet vers un joueur proche → il accepte ou refuse ; animation de don.

### T-032 — Interactions physiques `vava_interact`
- Agents : vava-architecte → vava-dev-lua · Dépend de : — · Statut : à faire
- Menu d'interaction sur un joueur proche : lier et délier les mains (objet corde), escorter, porter, fouiller
  (consentement, ou personne liée ou à terre), aider à se relever (réutiliser `vava_health`). Chaque état est décidé
  par le serveur et bloque les actions incompatibles dans les autres modules (hook).

### T-034 — Parchemins et lettres
- Agent : vava-dev-lua + vava-dev-nui · Dépend de : — · Statut : à faire
- Objet parchemin qu'on écrit (texte borné en métadonnées, signé du personnage, scellable), qu'on lit, qu'on donne.
  Interface de lecture/écriture. Texte inséré avec `textContent` uniquement.

### T-036 — Se présenter
- Agents : vava-architecte → vava-dev-lua · Dépend de : — · Statut : à faire
- On ne connaît pas le nom des inconnus : description courte affichée à la place, « se présenter » révèle son nom à
  un joueur proche (mémorisé par personnage). Utilisé par le chat de proximité et l'affichage au-dessus des têtes.

### T-039 — PORTE : soirée RP de test — **HUMAIN**
- Dépend de : phase 5 · Statut : à faire
- 4 à 8 joueurs, une soirée : arrivée, présentations, troc, apprentissage, interactions. Noter les manques.

## Phase 6 — Les arts de l'Atelier

### T-120 — Atelier des gestes
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-101 · Statut : à faire
- Recherche d'animations côté serveur (liste de GTA + dictionnaires `.ycd` diffusés), aperçu sur soi ou sur un
  mannequin, options en cases à cocher (boucle, haut du corps, garder la main, figer), accessoires placés avec
  l'outil de placement, enchaînement de clips, gestes à deux (position du partenaire), catégories (émote, métier,
  incantation, combat). Les métiers peuvent référencer un geste par son id. Dépôt d'un `.ycd` par la Chancellerie
  (compte maître seulement, fichier vérifié) : tâche séparée si nécessaire.

### T-033 — Émotes et animations partagées `vava_emotes`
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-120 · Statut : à faire
- Menu d'animations RP : les gestes publiés dans l'Atelier des gestes (catégorie « émote »), raccourcis, animations à deux avec consentement (poignée de main,
  accolade, révérence). Synchronisation sans broadcast (les autres voient l'animation par le moteur).

### T-121 — Éditeur de techniques de combat
- Agents : vava-dev-lua + vava-dev-nui · Dépend de : T-120, T-119 · Statut : à faire
- Maquette `Combat` : frise des phases réglable à la souris, aperçu au ralenti, zone touchée dessinée au sol,
  essai contre un mannequin ; les techniques de la config sont importées comme version 1.

### T-122 — Atelier des effets
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-101 · Statut : à faire
- Calques (particules du catalogue de GTA, taille, couleur quand la particule le permet, lumière, son, attache à un
  os, durée) ; aperçu en direct ; le niveau de détail et les plafonds de `vava_magic/client/fx.lua` s'appliquent.

### T-123 — Atelier des sorts
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-122, T-120, T-116 · Statut : à faire
- Maquettes `Sort` et `Protection` : forme, cibles, élément, geste, valeurs, liste d'effets de jeu avec conditions
  (familles de `ATELIER.md`), effets visibles par moment (lancement, trajet, impact, sur la cible, rupture, fin),
  règle de cumul des protections, comparaison avec un sort existant, essai par le seul créateur, versions.
  Moteur générique qui réutilise les noyaux de `vava_magic` ; les 11 sorts existants gardent leur code.

### T-124 — Invocations
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-123 · Statut : à faire
- Créatures créées par le serveur (exception contrôlée au monde sans PNJ de `vava_world`), modèles provisoires,
  comportements simples (suivre, défendre, attaquer), durée, plafonds par mage et par serveur, disparition si le mage
  s'éloigne, tombe ou se déconnecte.

### T-125 — Transformations
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-123, T-036 · Statut : à faire
- Forme animale (modèles de GTA), déguisement qui rend **méconnaissable** (jamais l'apparence d'un autre joueur ;
  nom remplacé par une description d'inconnu, voir T-036), taille ; durée ; restauration exacte de l'apparence ;
  actions impossibles sous forme animale bloquées côté serveur ; déconnexion pendant une transformation gérée.

### T-129 — PORTE : les arts en jeu — **HUMAIN**
- Dépend de : T-120 à T-125, T-033 · Statut : à faire

## Phase 7 — Société

### T-041 — Équipement porté `vava_equipment`
- Agents : vava-architecte → vava-dev-lua · Dépend de : — · Statut : à faire
- Emplacements d'équipement (tête, torse, jambes, pieds, mains, cape) ; un vêtement est un objet qui applique des
  composants via `vava_appearance` (PLACEHOLDER) ; armures avec protection et solidité.

### T-043 — Habitat `vava_housing`
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-106 · Statut : à faire
- Logis attribués par le Conseil (pas achetés : pas de monnaie), coffre privé (conteneur ancré), clés partagées.

### T-044 — Cachot et registre des sentences
- Agent : vava-dev-lua · Dépend de : T-105, T-032 · Statut : à faire
- La Garde peut enfermer une personne liée dans une cellule (zone) pour une durée bornée ; registre consultable.

## Phase 8 — Monde

### T-050 — Temps, saisons, météo `vava_time`
- Agents : vava-architecte → vava-dev-lua · Dépend de : — · Statut : à faire
- Heure du royaume et calendrier (GlobalState : usage légitime), saisons qui modulent la croissance de
  `vava_farming` et les ressources de `vava_gathering` (hooks), météo cohérente avec la saison.

### T-051 — Montures, squelette `vava_mounts`
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-043 · Statut : à faire
- Écurie (lieux posés avec l'outil de placement de l'Atelier), propriété, nom, nourriture, santé, appel, persistance ; animal de remplacement ; la monte attend l'asset.

### T-052 — Région de remplacement
- Agent : vava-dev-lua · Dépend de : T-022 · Statut : à faire
- Déplacer tous les lieux d'exemple (autour de −269, −955, en ville) vers une région rurale choisie, uniquement en
  config. **Décision à confirmer** par le porteur du projet avant de commencer.

### T-059 — PORTE : test du monde — **HUMAIN**
- Dépend de : phases 7 et 8 · Statut : à faire

## Phase 9 — Version jouable

### T-060 — Session de charge — **HUMAIN**
- Dépend de : T-059 · Statut : à faire
- Le plus de joueurs possible (objectif 32) pendant une heure ; mesures resmon, `/vava_reseau`, requêtes lentes,
  temps de tick serveur ; chaque problème devient une tâche.

### T-061 — Liste de mise en ligne
- Agent : vava-testeur · Dépend de : T-060 · Statut : à faire
- `docs/mise-en-ligne.md` : sauvegardes de la base, Chancellerie, liste blanche, règlement (journaux gardés),
  ordre de démarrage final, inventaire des PLACEHOLDER restants.

### T-062 — PORTE : 1.0.0-alpha — **HUMAIN**
- Dépend de : T-061 · Statut : à faire
