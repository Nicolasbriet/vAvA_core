# vAvA_core — Eldoria (RP médiéval fantastique, FiveM)

Ce fichier est lu par Claude Code et par chaque agent avant toute tâche. Il prime sur les habitudes générales.
Le lore complet est dans `docs/lore/ELDORIA.md`, le plan dans `docs/plan/ROADMAP.md`, les tâches dans
`docs/plan/BACKLOG.md`, les règles de sécurité et de réseau détaillées dans `docs/plan/SECURITE_RESEAU.md`.

## L'esprit du serveur

Eldoria est une cité sans monnaie : la richesse circule par le **troc**, les **services rendus** et les **réserves
communes**. Le savoir se **transmet** (mentorat, leçons), personne ne sait tout faire, la terre se **fatigue** si on
l'épuise, la **magie a un coût** et des conséquences. Le jeu est du **GTA RP classique** : l'interaction entre joueurs
et l'évolution du personnage passent avant tout. Aucune mécanique ne doit rendre un joueur autosuffisant au point de
ne plus avoir besoin des autres. **Aucune monnaie, aucun « argent », aucune boutique à prix fixe** sans validation
explicite du porteur du projet.

## Socle technique (non négociable)

- Lua 5.4, OneSync, FXServer récent. `oxmysql` est la **seule** dépendance externe. Ni ESX, ni QBCore, ni Qbox,
  ni ox_lib, ni ox_core, ni bibliothèque JS chargée depuis un CDN.
- Tout passe par l'API du core documentée dans `docs/api.md` : `core.rpc`, `core.db`, `core.hooks`,
  `core.registry`, `core.characters`, migrations SQL.
- Textes visibles par les joueurs **en français**, ton du royaume (voir les modules existants).

## Structure d'un module (copier un module existant, par ex. `modules/vava_skills`)

```
modules/vava_xxx/
  fxmanifest.lua        version semver, dépendances, ordre des fichiers
  config.lua            TOUT ce qui est réglable : durées, bornes, modèles, coordonnées, textes
  shared/constants.lua  table du module (SEULE globale : VavaXxx), noms d'évènements et de RPC
  bridge/server.lua     SEUL point de contact avec le core et les autres modules, chaque appel isolé (pcall)
  server/*.lua          logique, un fichier par responsabilité ; server/main.lua déclare le module et ses RPC
  client/*.lua          affichage et demandes ; client/nui.lua seul à parler à l'interface
  web/                  interface NUI (HTML/CSS/JS sans framework) ; polices, textures et ornements communs pris
                        dans `vava_ui` (`nui://vava_ui/…`, `dependency 'vava_ui'`), jamais recopiés ;
                        web/dev/devmock.js pour la tester hors jeu, jamais livré (hors des `files`)
  sql/0001_xxx.sql      migrations, jamais modifiées une fois publiées (on ajoute 0002_…)
  README.md             règles (tableau config), installation, dépendances, « À vérifier en jeu »
```

Conventions observées dans tout le dépôt, à respecter :
- En-tête de chaque fichier : `--[[ chemin / Rôle : … / Dépendances : … ]]`.
- Natives et fonctions standard mises en `local` en haut du fichier.
- Aucune fonction d'API ne lève d'erreur : retour `valeur` ou `false/nil, err`.
- Hooks, RPC, registres préfixés par le nom de la ressource (`vava_xxx:…`). `core:` est réservé au core.
- Les tables qui traversent un export ne sont jamais mixtes (liste + clés nommées).
- Commandes et touches déclarées au registre `core:commands` (elles apparaissent dans le Codex).
- Versions : chaque changement monte la version du module dans son `fxmanifest.lua` (semver).
- Messages de commit : `vava_xxx 1.2.0 : ce qui change` (voir `git log`).

## Sécurité : le serveur décide de tout

1. Le client **affiche et demande**, le serveur **vérifie et décide**. Aucun résultat (objet gagné, dégât, XP,
   réussite) n'est calculé côté client.
2. Toute entrée réseau passe par `core.rpc.register` avec un schéma `args` complet et borné (`max` sur chaque
   chaîne et liste, `pattern` ancré, `enum`) et une `rateLimit` adaptée. **Jamais** de `RegisterNetEvent` serveur
   brut dans un module.
3. Le serveur revérifie tout ce qui dépend du monde : distance réelle (`GetEntityCoords(GetPlayerPed(src))`),
   personnage chargé, objet réellement possédé, droit du Conseil, délai entre deux actions.
4. Ce que renvoie `callClient` n'est jamais une source de vérité (toujours `returns`).
5. SQL : uniquement via `core.db`, toujours paramétré (`?`). Jamais de concaténation de valeur.
6. Toute action sensible (échange, don, retrait d'un grenier, action du Conseil) est journalisée.
7. Échanges d'objets : uniquement par les opérations atomiques « tout ou rien » de `vava_inventory`.
8. Aucun secret dans le dépôt, ne jamais lire ni écrire `server.cfg`.

## Performance client

- `Wait(0)` interdit, sauf pendant un état actif qui dessine ou lit des contrôles à chaque image (visée, roue,
  incantation) et qui se termine. Sinon : intervalle adaptatif selon la distance (500 ms loin, 100 ms près…).
- Pas de recherche dans tout le monde à chaque tour (`GetGamePool` en boucle) ; garder des listes locales.
- Les props et effets ne sont créés qu'à portée (streaming par distance, comme `vava_gathering`), et supprimés
  quand on s'éloigne ou que la ressource s'arrête.
- NUI : jamais de `SendNUIMessage` à chaque image ; n'envoyer que les changements.

## Bande passante : ne rien envoyer à qui n'en a pas besoin

- `TriggerClientEvent(nom, -1, …)` **interdit**. On cible : le joueur concerné, ou les joueurs à portée calculée
  côté serveur.
- `GlobalState` est réservé à de **petites** valeurs **rares** utiles à **tout le monde**. Un état local (zone,
  parcelle, station, nœud de récolte) est envoyé aux joueurs proches ou demandé par le client quand il arrive à
  portée.
- State bags d'entité : répliqués seulement si les autres joueurs doivent les voir ; valeurs courtes.
- On envoie des **différences**, pas des instantanés complets ; les gros envois passent par
  `TriggerLatentClientEvent` avec un débit borné.
- Fichiers web : polices, textures et images communes ne sont pas dupliquées dans chaque ressource ; images en
  SVG ou WebP légères ; aucune ressource externe. Écran de chargement : poids total maîtrisé (voir le backlog).

## Assets manquants (cartes, montures, vêtements, armes)

Les assets définitifs n'existent pas encore. **Aucun modèle, coordonnée, composant de vêtement ou arme n'est écrit
en dur** : tout passe par `config.lua` avec une valeur de remplacement vanilla et un commentaire `-- PLACEHOLDER`.
Le jour où l'asset arrive, on ne change que la config. Voir `docs/plan/ASSETS_PLACEHOLDERS.md`.

## L'Atelier et le combat

- Tout ce que le staff doit pouvoir créer ou régler en jeu (zones, points, stations, parcelles, portes,
  confréries, gestes, techniques, effets, sorts) est une **définition** gérée par `vava_atelier` : la config est
  la graine, la base fait foi, chaque version est gardée. Un module déclare ses éditeurs au registre
  `vava_atelier:editors` et reste seul juge de la validité de ses données. Voir `docs/plan/ATELIER.md`.
- Les interfaces de l'Atelier suivent les maquettes de `docs/maquettes/` : mots du jeu, une phrase d'aide par
  réglage, essai avant publication, modèles provisoires signalés.
- **Tous les dégâts** du jeu passent par `vava_health:hit` et ses modificateurs ; aucun module n'appelle
  `damage` directement pour un coup ou un sort. Voir `docs/plan/COMBAT_V1.md`.
- Une technique de combat, un geste, un effet ou un sort est une **donnée** au format fixé par sa référence ; le
  code est un moteur générique qui lit ces données.

## Décisions déjà prises (ne pas les remettre en cause)

Choix tranchés par le porteur du projet : un agent ne les signale pas comme des problèmes et ne les re-propose pas.

- **Catalogue de développement actif** : `catalog.enabled = true` dans `modules/vava_inventory/config.lua` est
  voulu (il sert aux tests en jeu). Ni le désactiver, ni le signaler comme une faille.
- **Interfaces claires** (parchemin, livre, fiche) : jamais de `grain.png` sur un fond clair, un dégradé éclairé en
  haut suffit ; encre `#241b12`, atténuée `#56442f`, effacée `#7a6750`, filets `rgba(70,48,24,.3)` ; champs sur
  fond crème avec un filet de laiton. Le grain et les gris pâles restent réservés aux fonds de cuir sombre
  (inventaire, HUD). La Cinzel est une police de capitales réservée aux titres ; les commandes s'écrivent en
  bas-de-casse, en EB Garamond gras.
- **Un écran par module métier** : chaque module a sa propre NUI, dans le même style (pas de livre unique).
  L'Atelier est l'exception voulue : une interface pour tous les éditeurs.
- **Droits du Conseil** : `metiers` (Sénéchal et au-dessus) pour les zones, nœuds, stations et corrections de
  compétence ; les fondateurs sont réservés à `staff` (Souverain) et à la console.
- **Règles des métiers** (palier choisi par ingrédient, mentorat, pénurie, récolte communale dans la besace…) :
  décrites dans les README de `vava_skills`, `vava_gathering`, `vava_crafting` et `vava_farming`.
- **Compteur réseau** (`core.net`) : **tous les joueurs connectés sont suivis d'office**, évènement par évènement
  (les plus lourds de chacun, mémoire bornée), sans `/vava_reseau joueur` préalable ; la page Réseau de la
  Chancellerie les liste avec le nom de leur personnage. Consulter le détail d'un joueur reste inscrit au journal.
- **Coup déjà lancé** : un sort (projectile, éclats, présage de la Secousse) lancé debout porte encore si son
  lanceur tombe à terre avant l'impact ; la chaîne de dégâts ne le refuse pas pour `source_downed` (étiquette posée
  par le serveur, bornée dans le temps). Un coup lancé à terre reste refusé.
- **Mains vides pour incanter** : on ne lance pas un sort avec une arme ou un bouclier en main (le mage a besoin d'un
  garde, le guerrier d'un mage) ; vérifié par le serveur (`vava_combat:armed`). Un focaliseur viendra plus tard.
- **Commits** : un commit par chantier, au format du dépôt, jamais un commit fourre-tout.

## Façon de travailler

1. Lire `docs/plan/BACKLOG.md`, prendre **une seule** tâche éligible (voir les règles en tête du backlog).
2. Lire les fichiers du module visé, `docs/api.md` et les modules dont il dépend avant d'écrire.
3. Pour une tâche de création de module ou de système : faire écrire la spec par l'agent `vava-architecte`
   (`docs/plan/specs/T-xxx.md`) avant de coder.
4. Coder petit : une tâche = un changement cohérent. Pas de refonte non demandée, pas de fichier touché hors du
   périmètre de la tâche.
5. Lancer `./scripts/verifier.sh` jusqu'à ce qu'il passe.
6. Faire relire par `vava-securite` et `vava-reseau-perf` (obligatoire dès qu'un RPC, un évènement, un state bag,
   une boucle client ou une interface est ajouté ou modifié), puis par `vava-gardien-lore` si des règles de jeu ou
   des textes changent. Corriger ce qu'ils remontent.
7. Mettre à jour : `docs/api.md` (si l'API change), le README du module, la procédure de test en jeu
   (`docs/tests/`), la version dans `fxmanifest.lua`, l'ordre de démarrage dans le `README.md` racine si besoin.
8. Passer la tâche à **« à tester en jeu »** dans le backlog (jamais « validée » : seul un humain valide).
9. Commit au format du dépôt.

## Définition de « terminé » pour un agent

- `./scripts/verifier.sh` passe (lint des fichiers modifiés, tests unitaires, audit réseau).
- La logique pure nouvelle (formules, validations) a des tests dans `tests/spec/`.
- Les relectures sécurité / réseau sont faites et leurs points bloquants corrigés.
- Une procédure de test en jeu existe, au format de `docs/tests/metiers.md` : quoi faire, ce qui doit se passer.
- La doc est à jour, la version est montée, le backlog est à jour.

## Interdits

- Pousser ou fusionner sur `main`. Réécrire l'historique. Supprimer ou affaiblir un test pour le faire passer.
- Ajouter une dépendance (Lua, npm, CDN).
- Modifier `chancellerie/` ou le core (`server/`, `client/`, `shared/` racine) hors d'une tâche qui le demande.
- Modifier une migration SQL déjà publiée.
- Inventer une mécanique qui contredit le lore (monnaie, autosuffisance, magie sans coût).
