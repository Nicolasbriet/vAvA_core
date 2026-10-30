# vava_arrival — l'arrivée d'un nouveau personnage

Un nouveau personnage apparaît au point d'arrivée du royaume, une besace sur l'épaule avec deux miches de pain et deux
outres d'eau : de quoi tenir sa première soirée, pas davantage. Un mot d'accueil lui dit qu'ici rien ne s'achète et
qu'il trouvera son chemin auprès des autres, puis son Codex s'ouvre à la page de ses premiers pas. Le reste (outils,
vêtements, toit, savoir) s'obtient en allant vers les gens d'Eldoria.

Le serveur décide de tout : la nouveauté est lue sur le temps de jeu **mesuré par le core** et sur la base, la dotation
part **au plus une fois** (réservation conditionnelle en base, échange atomique de l'inventaire), et le client ne fait
qu'afficher l'accueil puis accuser lecture. Aucun envoi aux autres joueurs, aucune boucle.

Ordre de démarrage : après `vAvA_core` (≥ 0.10.0), `vava_inventory` (≥ 1.4.0) et `vava_codex`, avant
`vava_chancellerie`. Facultatifs : `vava_codex` ≥ 1.4.0 (Codex ouvert au chapitre), `vava_hud` (notifications ; sans
lui, celles du jeu), `vava_admin` (droit `give`, journal du Registre ; sans lui, ACE `vava_arrival.admin`), `vava_chat`
(réponses de `/accueil` ; sans lui, une notification au seul membre).

## Règles (config.lua)

| Règle | Défaut | Clé |
|---|---|---|
| Point d'arrivée | `spawn.defaultPoint` de `config/server.lua` (core), `-- PLACEHOLDER` jusqu'à la carte du royaume (T-052) | aucune ici |
| Dotation de départ | 2 `pain`, 2 `eau` ; liste pure, 8 entrées au plus, quantités 1 à 100, un objet une fois ; `{}` : aucune dotation | `kit.items` |
| Limite par compte | 3 dotations sur 30 jours glissants (réservées, données ou incertaines, personnages supprimés compris) ; au-delà, accueil sans dotation ; `max = 0` : aucune limite | `kit.perAccount` |
| Objets déclarés s'ils manquent | `pain` (faim + 35), `eau` (soif + 40), dessins `web/items/*.svg` | `items` |
| Attente de l'accueil | 4 s après la réception, puis un essai par seconde, 30 s au plus | `welcome.delayMs`, `retryMs`, `maxWaitMs` |
| Envois de l'accueil sans accusé | 3 au plus, un par session | `welcome.maxSends` |
| Chapitre du Codex | `premiers_pas` : le Codex (1.5.0, T-023) s'ouvre sur l'onglet Lecture, chapitre « Premiers pas », page « Vivre à Eldoria » ; un chapitre de commandes (`vava_inventory`) ou une page de lecture sont aussi acceptés | `codex.chapter` |
| Commande du Conseil | `/accueil`, droit `give` (Sénéchal et au-dessus), ACE `vava_arrival.admin`, 2 s entre deux | `admin` |
| Accusé de lecture | 2 d'avance, puis 1 par 20 s | `rateLimits.welcomed` |
| Journal | 90 jours | `logRetentionDays` |
| Textes | relus avec l'écran de chargement (T-021) ; notifications de 200 octets au plus, libellés du journal de 32 octets au plus ; `codexHint` cite la touche par défaut du Codex (F1) | `messages` |

`startingItems` de `vava_inventory` reste vide : le remplir en même temps donnerait deux dotations.

Ce que la dotation **n'est pas** : ni vêtements (la tenue est celle choisie à la création, `vava_appearance`), ni
besace en objet (la besace **est** l'inventaire du personnage), ni toit, ni outil. Deux pains et deux outres
repoussent la faim d'environ 2 h 50 et la soif d'environ 2 h 25 chez un personnage qui part de 100 : la première soirée, pas la
première semaine.

## L'arrivée, pas à pas

1. **Chargement** (hook `core:character:loaded`, avant l'apparition) : une lecture par clé primaire. Aucune ligne et
   temps de jeu nul → ligne « à donner » (`INSERT IGNORE`) ; aucune ligne et temps de jeu non nul → personnage ancien,
   rien (jamais suivi) ; ligne → reprise ; ligne « réservée » → « incertaine » (serveur tombé pendant une remise :
   console, journal, jamais redonnée d'office), sauf si une remise de ce personnage est en cours dans ce serveur
   (personnage déchargé puis rechargé pendant qu'elle se fait : reprise « réservée », la remise écrit son issue).
   Lecture ou écriture en échec : rien cette session.
2. **Apparition** (hook `core:character:spawned`, chaque apparition) : dans un thread, une seule arrivée à la fois par
   personnage :
   - dotation « à donner » : objets connus de l'inventaire (sinon rien n'est réservé, une ligne de console par objet et
     par 10 min) ; limite du compte (« retenue ») ; **réservation** `WHERE kit = 'due'` (la base arbitre) ; limite
     **recomptée** aussitôt après (atteinte : « retenue », rien donné) ; entrée de cette arrivée (personnage ni
     déchargé ni rechargé entre-temps) et personnage actif relus juste avant l'échange, sans céder la main ; **un**
     `exchange` tout ou rien ; « donnée », ou retour à « à donner » (besace pleine, inventaire absent, personnage
     changé ou rechargé) pour un nouvel essai à l'apparition suivante ;
   - accueil jamais vu, envoyé moins de 3 fois et pas encore pendant cette session : `vava_arrival:welcome` au seul
     joueur ; au premier envoi, hook `vava_arrival:arrived`.
3. **Retour de l'inventaire** (`core:module:ready`) : objets redéclarés, dotations dues reprises pour les personnages
   apparus, sans second accueil.
4. **Client** : attente d'un écran calme (fondu fini, ni menu pause, ni interface au focus), mot d'accueil et ligne de
   la besace en notifications, Codex ouvert au chapitre (sinon rappel de sa touche), puis accusé
   `vava_arrival:welcomed`. Un nouvel accueil ou le retour à la sélection annule l'attente.

États de la dotation : `due` (à donner), `claimed` (réservée, échange en cours), `given` (donnée), `withheld`
(retenue, limite du compte), `uncertain` (à vérifier par le Conseil), `none` (personnage d'avant l'accueil, ligne créée
par `/accueil rejouer`).

## Base de données (sql/0001_arrival.sql)

- `vava_arrival` : une ligne par personnage accueilli (`kit`, `kit_at`, `welcomed_at`, `welcome_sends`), **jamais
  supprimée** : elle compte dans la limite du compte, même après la suppression du personnage. Toutes les transitions
  sont conditionnelles (`WHERE kit = ?`, `WHERE welcomed_at IS NULL`).
- `vava_arrival_log` : `kit_given`, `kit_withheld`, `kit_uncertain`, `admin_regive`, `admin_replay` (détails en JSON),
  purgé au démarrage au-delà de `logRetentionDays`.

## Réseau

| Quoi | Cible | Taille | Fréquence |
|---|---|---|---|
| `vava_arrival:welcome` (`kitGiven`) | le seul nouveau venu (ou le joueur visé par `/accueil rejouer`) | ~25 o | 3 fois au plus dans la vie d'un personnage, plus les rejouées du Conseil |
| RPC `vava_arrival:welcomed` | — | ~40 o aller-retour | une fois par accueil montré |
| `vava_arrival:notify` (texte) | le seul membre du Conseil qui a tapé `/accueil`, sans `vava_chat` | 60 à 200 o | à la demande |

Rien pour les joueurs anciens, rien pour les autres joueurs ; ni GlobalState, ni state bag. La dotation ne coûte rien
de plus : l'inventaire n'envoie un conteneur qu'à qui l'a ouvert. Côté client : aucune boucle au repos (0,00 ms), un
thread borné par accueil reçu.

## Conseil (droit `give`)

`/accueil etat <n°>` : état de la dotation et de l'accueil du personnage en jeu (lecture seule). `/accueil redoter <n°>` :
redonne la dotation par un échange atomique, quels que soient l'état et la limite du compte (journal du module et du
Registre, « Dotation redonnée ») ; refusée pendant une remise en cours (« en cours ») ; un personnage d'avant
l'accueil redoté n'aura pas d'accueil ensuite.
`/accueil rejouer <n°>` : renvoie l'accueil (sans la ligne de la dotation) et le compte comme un envoi (« Accueil
rejoué »). Console du serveur : `accueil etat <n°>`. Sans droit : rien, aucune réponse.

## Installation

`ensure vava_arrival` après `ensure vava_codex` (la Chancellerie le place seule). La migration crée les deux tables au
premier démarrage. Le chapitre « Premiers pas » existe depuis `vava_codex` 1.5.0 (T-023) ; avec un Codex plus
ancien, le livre s'ouvre à son index, sans erreur. Pour essayer un chapitre de commandes : `codex.chapter =
'vava_inventory'`, puis `restart vava_arrival` (à remettre ensuite).

**Personnages anciens jamais joués.** La première venue se lit sur le temps de jeu mesuré par le core : un personnage
créé avant la migration `0003_play_seconds.sql` du core (0.6.0) et jamais joué depuis est resté à `play_seconds = 0`
et, s'il n'a pas de ligne dans `vava_arrival`, sera accueilli et doté comme un nouveau venu à sa prochaine venue (une
fois, dans la limite du compte). Les repérer avant d'installer le module : ``SELECT `id` FROM `vava_characters` WHERE
`play_seconds` = 0``. Quand l'un d'eux revient, `/accueil etat <n° du joueur>` dit ce qu'il a reçu (« donnée le … ») ;
la règle ne change pas, le Conseil juge au cas par cas (rien à reprendre : deux pains et deux outres).

Assets à brancher : aucun dans le module. Le point d'arrivée définitif se règle dans `config/server.lua`
(`spawn.defaultPoint`) ; les dessins `web/items/pain.svg` et `eau.svg` sont ceux de `vava_example_items`.

## Tests

Hors jeu : `tests/spec/arrival_rules_spec.lua` (règles pures et config), `tests/spec/arrival_kit_spec.lua` (chargement,
dotation, accueil, accusé, `/accueil` avec des doublures de la base et de l'inventaire). En jeu :
`docs/tests/accueil.md`.

## À vérifier en jeu

- Les deux notifications (4,5 s chacune dans `vava_hud`) restent visibles et lisibles par-dessus le Codex qui s'ouvre
  aussitôt après : c'est le seul message qui dit « allez vers les autres » (accueil 2). Sinon, prévoir une attente
  réglable avant l'ouverture du Codex.
- `IsScreenFadedIn()` est vrai assez tôt après l'apparition (sinon l'accueil attendrait 30 s : accueil 2).
- Le Codex ouvert par `openAt` reçoit bien clavier et souris, et `Échap` le ferme (accueil 2).
- `IsNuiFocused()` voit le Codex et l'inventaire ouverts (accueil 6 et 7).
- Un personnage d'avant la mesure du temps de jeu du core resté à `play_seconds = 0` est pris pour un nouveau venu
  (voir « Installation ») : le vérifier avec `/accueil etat` sur la base de test.
- Les paramètres `nil` des requêtes (`kit_at` remis à vide, compte de la console au journal) arrivent en `NULL` (accueil
  9 et 18).
