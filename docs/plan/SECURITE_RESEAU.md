# Sécurité, optimisation et bande passante

Document de référence des agents `vava-securite` et `vava-reseau-perf`. Les règles courtes sont dans `CLAUDE.md` ;
ici, le pourquoi, les seuils et l'état des lieux.

## Objectifs chiffrés (à mesurer en phase 1, à tenir ensuite)

| Mesure | Cible |
|---|---|
| resmon de chaque ressource client au repos (personnage debout, rien d'ouvert) | ≤ 0,02 ms |
| resmon pendant une action (récolte, incantation, interface ouverte) | ≤ 0,15 ms |
| Évènements serveur → client reçus par un joueur immobile seul dans une zone calme | ≈ 0 par minute hors besoins/HUD |
| Données téléchargées à la première connexion (hors oxmysql) | à mesurer, puis − 30 % après mutualisation |
| Écran de chargement (tous fichiers) | ≤ 1,5 Mo |
| Temps d'un RPC courant côté serveur | ≤ 2 ms ; requêtes SQL ≤ `slowQueryMs` |

## Modèle de menace

Un joueur malveillant contrôle entièrement son client : il exécute du Lua arbitraire, appelle n'importe quel RPC
avec n'importe quels arguments, rejoue des requêtes, ment sur sa position et sur ce qu'il voit, ouvre les outils de
développement de la NUI. Il ne contrôle pas le serveur ni la base. Tout ce qui a de la valeur (objets, XP, santé,
droits, positions de stockage) est donc décidé et vérifié côté serveur.

Scénarios à fermer pour chaque fonctionnalité : duplication par requêtes simultanées ; action à distance ; action
en étant mort, ligoté ou en échange ; spam ; arguments hors bornes (négatifs, NaN, chaînes géantes, tables
imbriquées) ; déconnexion au milieu d'un échange ; injection HTML dans les noms affichés ; contournement d'un droit
du Conseil par appel direct du RPC.

## Bande passante : règles détaillées

1. **Ciblage.** Un évènement a un destinataire calculé par le serveur : le joueur concerné, les participants d'une
   interaction, ou les joueurs dans un rayon (portée de vue ou d'ouïe définie en config). Jamais `-1`.
2. **GlobalState.** Toute écriture est envoyée à **tous** les joueurs connectés. Acceptable : heure du royaume,
   saison, météo, quelques drapeaux. Non acceptable : l'état de chaque nœud de récolte, parcelle ou station quand il
   y en a des dizaines et qu'il change à chaque action.
3. **Données de zone.** Modèle en place depuis le core 0.11.0 (`core.zones`, T-014, décision du porteur du projet du
   30 octobre 2026) : **le serveur décide seul** qui suit une zone. À chaque passage (1 s, réglable), il lit la position
   de chaque personnage apparu (une lecture par joueur, gardée 50 ms), cherche dans une grille les zones proches et
   abonne ceux qui entrent dans le cercle d'intérêt (rayon + marge, distance au sol, instance de la zone) → il leur
   envoie l'état entier et sa révision → ensuite seulement les différences, regroupées par tour, toujours fiables →
   il les désabonne au-delà de rayon + marge + 25 m (hystérésis : pas d'aller-retour en bordure), à la sélection, au
   déchargement ou au départ. **Aucun RPC d'abonnement** : un client ne demande jamais d'entrer dans une zone (il
   devrait sinon connaître toutes les zones, un annuaire envoyé à tous) ; son seul RPC (`core:zones:resync`, limité)
   redemande l'état d'une zone **qu'il suit déjà**, quand une révision manque (le client applique la révision
   attendue + 1, ignore les anciennes, garde les plus récentes en attendant un état entier). L'état vit dans le core :
   une seule sérialisation pour tous les entrants d'un passage, rien de gros ne traverse un export. Bornes : 32 Ko par
   état, 8 Mo en tout, 2 048 zones, 256 zones suivies par joueur, 32 Ko d'états entiers par joueur et par passage.
   **Limite à connaître** : sous OneSync, la position du ped que lit le serveur est **déclarée par son client**. Un
   client modifié peut se dire n'importe où et recevoir l'état de n'importe quelle zone : l'abonnement économise la
   bande passante, il ne protège rien. L'état d'une zone est donc **public pour quiconque peut s'y rendre** : on n'y
   met rien de secret (récompense cachée, qualité d'une récolte à venir, contenu d'un grenier) ; chaque action d'un
   module revérifie côté serveur, au moment de l'action, la distance réelle, la possession, le droit et le délai, sans
   se fier à l'abonnement (contrôle de vitesse plausible si un module en a besoin).
4. **Différences.** On envoie `{ id, champ = nouvelle valeur }`, pas l'objet complet.
5. **Gros volumes** (catalogue, journal, liste de recettes) : envoyés une fois à la demande, mis en cache côté
   client avec une version, renvoyés seulement si la version change ; `TriggerLatentClientEvent` au-delà de
   quelques Ko.
6. **Fichiers web.** Une ressource commune (`vava_ui`) porte polices, textures et icônes partagées, référencées par
   `nui://vava_ui/…` ; chaque module ne garde que ses propres fichiers.
7. **Fichiers Lua servis.** Un joueur ne télécharge que ce que son client lit : `config.lua` et la logique réservée au
   serveur sont en `server_scripts` ; `config_client.lua`, `shared/constants.lua` et la logique dont un fichier
   client se sert en `shared_scripts` (T-132 ; `scripts/audit-reseau.sh` et `tests/spec/config_split_spec.lua` ;
   mesure : `scripts/poids-client.sh`). Un réglage du serveur retouché ne fait plus retélécharger la ressource.

## État des lieux (lecture du dépôt, octobre 2026)

Points solides déjà en place :
- Une seule porte d'entrée réseau : `server/core/rpc.lua` (seul `RegisterNetEvent` serveur du core), avec schémas
  bornés obligatoires, limites de débit par joueur dont les clés sont choisies par le serveur, plafond de requêtes
  simultanées.
- SQL centralisé dans `server/core/database.lua`, paramétré, requêtes lentes signalées. Aucune requête concaténée
  avec une valeur trouvée.
- Un seul `TriggerClientEvent(…, -1, …)` : l'annonce du Conseil (`vava_admin/server/requests.lua`), rare et
  réservée à un droit, inscrite dans `scripts/audit-exceptions.txt` ; les évènements de magie sont ciblés.
- Modules isolés par leur `bridge/` : un module absent ne fait pas tomber les autres.

Points à traiter (tâches de la phase 1) :
- **GlobalState pour des états locaux** : `vava_gathering` (zones et nœuds), `vava_farming` (parcelles),
  `vava_crafting` (stations). Chaque changement part chez tous les joueurs. Coût faible à 10 joueurs, à mesurer et à
  passer au modèle « abonnement de zone » avant d'ouvrir (service en place depuis T-014 ; bascules : T-015, T-016,
  T-017, plan dans `docs/plan/specs/T-014.md` § 13).
- **13 fichiers clients contiennent `Wait(0)`** (`vava_magic` en majorité, `vava_voice`, `vava_chat/overhead`,
  `vava_admin/tools`, `client/players/spawn.lua`) : vérifier que chaque boucle ne tourne que pendant un état actif.
- **Environ 3 Mo de fichiers web dupliqués** : 50 polices WOFF2 (1,8 Mo) et les textures `grain.png`/`paper.png`
  (1,1 Mo) copiées dans une quinzaine de ressources, téléchargées autant de fois à la première connexion.
- **Boucles `GetPlayers()`** dans 13 fichiers serveur : vérifier celles qui envoient des évènements.
- `vava_chat/server/compat.lua` enregistre un évènement réseau hors RPC (repli de commande) : vérifier sa limite
  de débit et ses bornes.
- La magie n'a jamais été jouée en vrai (README de `vava_magic`) : c'est le module le plus risqué en performance
  (projectiles, effets, zones).
- **≈ 190 Ko de Lua servis pour rien** (configs et logique du serveur en `shared_scripts`) : T-132 (règle, outillage,
  lot 1 : `vava_atelier`, `vava_arrival`, `vava_chancellerie`, ≈ 41,7 Ko en moins), puis T-141, T-142, T-143 (lots
  2 à 4, exceptions transitoires dans `scripts/audit-exceptions.txt`).
- Pas de tests ni de lint avant ce kit : base de départ de **14 avertissements luacheck mineurs** (relevés le 29 octobre 2026).
