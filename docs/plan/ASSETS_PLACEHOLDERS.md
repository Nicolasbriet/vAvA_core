# Assets manquants : travailler sans eux, les brancher sans réécrire

Carte, montures, vêtements et armes définitifs n'existent pas encore. Les systèmes se développent quand même, avec
des remplaçants vanilla déclarés **uniquement en config** et marqués `-- PLACEHOLDER`. Quand un asset arrive, on
remplace la valeur dans la config, on teste, c'est tout. `grep -rn PLACEHOLDER modules/` donne la liste de ce qui
reste à remplacer.

| Domaine | Ce qui se développe maintenant | Remplaçant vanilla | Branché plus tard |
|---|---|---|---|
| Carte et lieux | Zones de récolte, parcelles, stations, puits, portes, maisons, points d'arrivée : tous par coordonnées en config | Une région rurale de GTA (nord du comté : Paleto, Grapeseed, Mont Chiliad) plutôt que la ville, déjà proche d'une ambiance de campagne ; `vava_world` coupe déjà PNJ et sons urbains | Coordonnées de la map médiévale |
| Armes | Système de combat au corps à corps : objets d'inventaire liés à une arme, dégâts, solidité, qualité de forge | `WEAPON_MACHETE` (épée), `WEAPON_HATCHET` (hache), `WEAPON_BAT` ou `WEAPON_HAMMER` (masse), `WEAPON_KNIFE` (dague), `WEAPON_DAGGER` ; armes à feu retirées | Modèles d'armes médiévales, animations (`vava_anim_test` montre déjà le chargement d'une animation `.ycd`) |
| Vêtements | Équipement porté : objet d'inventaire → composants du ped via `vava_appearance` | Composants vanilla les plus sobres (chemises, pantalons de travail, bottes) | Vêtements médiévaux en streaming |
| Montures | Écurie, propriété, nourriture, santé, appel, persistance | Pas de cheval dans GTA V : animal de remplacement qui suit le joueur, la monte n'arrive qu'avec l'asset | Modèle de cheval et animations de monte |
| Props | Stations, nœuds de récolte, cultures | Props vanilla (déjà utilisés par les modules métiers) | Props médiévaux |

Règles pour les agents :
1. Toute table de correspondance a la forme `{ id_du_jeu = { model = '…', -- PLACEHOLDER … } }` dans `config.lua`
   (dans `config_client.lua` si le client lit le modèle, ce qui est le cas des props et accessoires ; T-132).
2. Le code ne teste jamais un nom de modèle : il lit la config.
3. Un asset absent ne doit jamais faire planter un module : modèle introuvable → message de log, repli sur le
   remplaçant.
4. Chaque README de module liste ses `PLACEHOLDER` dans une section « Assets à brancher ».
