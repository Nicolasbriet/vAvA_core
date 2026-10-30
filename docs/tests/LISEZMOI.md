# Procédures de test en jeu

Les agents ne peuvent pas lancer GTA : tout ce qui se voit, s'entend ou se joue à plusieurs se vérifie ici, à la
main. Chaque procédure dit quoi faire et ce qui doit se passer ; les tests à deux joueurs sont marqués
**(2 joueurs)**. Un test se cite par son fichier, sa section et son numéro : « inventaire 3-4 ».

## Les procédures

| Fichier | Ce qu'elle couvre | Modules |
|---|---|---|
| [personnage.md](personnage.md) | Connexion, création, sélection, suppression, reconnexion, position | `vAvA_core`, `vava_characters_ui`, `vava_appearance` |
| [inventaire.md](inventaire.md) | Besace, ceinture, mains, sol, conteneurs, à deux | `vava_inventory` |
| [besoins.md](besoins.md) | Faim, soif | `vava_needs` |
| [sante.md](sante.md) | Blessure, mise à terre, aide, réveil | `vava_health` |
| [chat.md](chat.md) | Chat de proximité, commandes, suggestions | `vava_chat` |
| [voix.md](voix.md) | Chat vocal, portée, zones de voix | `vava_voice` |
| [registre.md](registre.md) | Registre du Conseil : droits, joueurs, signalements, bans | `vava_admin` |
| [codex.md](codex.md) | Toutes les commandes et touches | `vava_codex` |
| [metiers.md](metiers.md) | Compétences, récolte, artisanat, agriculture | `vava_skills`, `vava_gathering`, `vava_crafting`, `vava_farming` |
| [magie.md](magie.md) | Les onze sorts, états, zones, combinaisons | `vava_magic` |
| [temps.md](temps.md) | Heure du royaume, saisons de quatorze jours, ciel, nuits de gel, Conseil en jeu et depuis la Chancellerie, effets sur les métiers | `vava_time`, `vava_farming`, `vava_gathering`, `vava_chancellerie` |
| [chancellerie.md](chancellerie.md) | Clé du pont hors de la ligne de commande, rangs des seuls comptes vus reliés en jeu | Chancellerie, `vava_chancellerie` |
| [interfaces.md](interfaces.md) | Polices, textures et ornements communs servis par `vava_ui` : § 0 pilote du HUD, puis § 1 à 6 les quinze interfaces (après la fusion de la suite), rendu, CORS, WebP | `vava_ui`, `vava_hud`, puis toutes les interfaces |
| [reseau.md](reseau.md) | Compteur réseau du Conseil (`/vava_reseau`), gros envois en latent, essai du réseau depuis la console, plus d'envoi à tous par le chat | `vAvA_core`, `vava_chat` |
| [developpement.md](developpement.md) | Outils de développement : rien sans `vava_env`, réservés et journalisés avec | `vava_dev_characters`, `vava_example`, `vava_example_items`, `vava_anim_test` |

Ordre conseillé : interfaces (§ 0, pilote du HUD ; § 1 à 6 une fois la suite de T-012 fusionnée), personnage,
inventaire, besoins, santé, chat, voix, registre, Codex, réseau, métiers, temps, magie. Chaque procédure s'appuie sur
ce que les précédentes ont validé.

## Préparation commune

1. **Ordre de démarrage** (`server.cfg`, ou la Chancellerie qui le fait seule), après `oxmysql` : `vAvA_core`, `vava_ui`,
   `vava_chat`, `vava_world`, `vava_time`, `vava_appearance`, `vava_characters_ui`, `vava_hud`, `vava_inventory`, `vava_needs`,
   `vava_health`, `vava_admin`, `vava_voice`, `vava_cameras`, `vava_magic`, `vava_skills`, `vava_gathering`,
   `vava_crafting`, `vava_farming`, `vava_codex`, `vava_chancellerie`.
2. **Démarrage** : dans la console du serveur, chaque module affiche `module 'xxx' vY prêt` ; les migrations partent
   seules. Un module refusé affiche la raison : c'est le premier retour à noter.
3. **Compte du Conseil** : console du serveur → `vava_conseil <compte> souverain`. Le numéro de compte se lit dans la
   Chancellerie (Joueurs → fiche, ligne « Compte »), ou dans la console du serveur à la toute première connexion
   seulement (`nouveau compte #n`) ; le joueur ne le voit pas en jeu. Le Souverain a tous les droits, dont
   `metiers`, `tools` et `staff`.
4. **Objets** : `/catalogue` ouvre le catalogue de développement (actif sur ce dépôt) ; sinon Registre du Conseil
   (`F10`) → Joueurs → vous → Donner.
5. **Deux joueurs** : deux clients FiveM sur deux machines, chacun avec son compte. Le second n'a pas besoin d'être
   du Conseil, sauf mention contraire.
6. **Outils de développement** (`/objet`, `/vie`, `/aterre`, `/besoins`, `/perso`, `/respawn`, objets d'exemple) :
   seulement avec `set vava_env dev` au `server.cfg` du serveur de test, et réservés au Souverain ou à l'ACE
   `vava.dev` (second joueur : `add_ace identifier.license:<licence> vava.dev allow` en console). Sans la convar, ils
   n'offrent rien : voir [developpement.md](developpement.md) et le README racine.
7. **Consoles** : celle du serveur, et celle du client (`F8`). Les lignes qui commencent par le nom du module
   (`[vava_inventory]`…) sont les plus parlantes.

## Mesurer le resmon

Console du client (`F8`) → `resmon 1`. Noter, pour chaque ressource, la valeur **au repos** (personnage debout, rien
d'ouvert, personne autour) et **pendant l'action** décrite par la procédure. Cibles de
`docs/plan/SECURITE_RESEAU.md` : 0,02 ms au plus au repos, 0,15 ms au plus pendant une action.

## Remonter un problème

Pour chaque écart : le test (« sante 2-3 »), ce qui s'est passé, les lignes des consoles serveur et client au même
moment, et si possible l'état en base. Chaque écart devient une tâche de correction de la phase 0 dans
`docs/plan/BACKLOG.md` (porte T-009).
