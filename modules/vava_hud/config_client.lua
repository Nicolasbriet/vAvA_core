--[[
    vava_hud/config_client.lua
    Rôle : table du module (seule globale de la ressource) et configuration de l'affichage.
    Dépendances : aucune
]]

VavaHud = {}

VavaHud.config = {
    -- Position des jauges (unités CSS) : coin inférieur gauche (la minimap GTA est retirée).
    position = { left = '1.5vw', bottom = '3vh' },

    -- Interface native de GTA retirée : minimap (et ses barres de vie), HUD (argent, noms de rue et de véhicule,
    -- munitions, notifications…). Le menu pause reste. Réappliqué si le jeu les réaffiche.
    native = { hideRadar = true, hideHud = true },

    -- Notifications (remplacent celles de GTA) : durée d'affichage, nombre à l'écran, longueur d'un message.
    notifications = { durationMs = 4500, maxVisible = 4, maxLength = 200, kinds = { info = true, warning = true, danger = true } },

    -- Barre de progression d'une action longue (récolte, artisanat, réparation, leçon…), une seule à la fois :
    -- bornes de la durée (ms), longueur du libellé, indice affiché quand l'action peut être interrompue.
    -- Purement visuelle : le serveur reste maître du temps.
    progress = { minDurationMs = 250, maxDurationMs = 120000, maxLabelLength = 60, cancelHint = 'Peut être interrompue' },

    -- Bannière du royaume (vava_pause, 1.6.0) : HUD masqué pendant qu'elle est déployée (jauges et barre de
    -- progression masquées, jamais interrompues ; notifications visibles), et des réglages du joueur lus chez elle :
    -- taille de l'interface (choix 90, 100 ou 115 → échelle de la page) et durée des notifications (multiplicateur de
    -- notifications.durationMs). Sans vava_pause : échelle 1, durée de base.
    pauseResource = 'vava_pause',
    scales = { [90] = 0.9, [100] = 1.0, [115] = 1.15 },
    notifyDurations = { courte = 0.6, normale = 1.0, longue = 1.6 },

    -- Chiffres des coups (T-155) : montant d'un coup, ou mot d'une issue sans dégâts, au-dessus de la cible. Envoyés par
    -- les modules qui frappent (vava_combat, vava_magic) aux seuls attaquant et cible ; ce HUD ne fait que les montrer.
    -- Réglage du joueur `combat.numbers` de la bannière (vava_pause) ; sans elle, `defaultMode`.
    numbers = {
        enabled = true,           -- false : aucun chiffre (l'export rend 'off')
        defaultMode = 'tous',     -- sans vava_pause : 'tous' | 'infliges' | 'aucun'
        durationMs = 900,         -- vie d'un chiffre (montée, effacement) ; 400 à 3 000
        riseVh = 5.0,             -- montée totale, en hauteur d'écran (vh) ; 0 à 20
        maxAlive = 10,            -- chiffres à l'écran au plus (le plus ancien laisse la place) ; 1 à 30
        maxPerSecond = 16,        -- chiffres créés par seconde au plus (au-delà : ignorés) ; 1 à 60
        followMs = 100,           -- suivi de la cible tant qu'un chiffre vit ; 50 à 500 (jamais à chaque image)
        followEpsilon = 0.004,    -- déplacement à l'écran (part de la largeur ou de la hauteur) sous lequel rien n'est envoyé
        stackMs = 350,            -- un coup qui suit le précédent sur la même cible de moins que cela se décale…
        stackMax = 4,             -- … d'un cran, jusqu'à 4 crans, puis on revient au premier
        stackStepVh = 3.4,        -- hauteur d'un cran (un chiffre et son mot dessous ne chevauchent pas le suivant)
        stackStepVw = 1.2,        -- décalage de côté d'un cran (alterné gauche, droite)
        jitterVw = 0.6,           -- petit écart de côté au hasard, pour que deux chiffres ne se recouvrent jamais exactement
        maxDistance = 60.0,       -- au-delà (mètres entre la caméra et la cible), rien n'est montré
        headBone = 31086,         -- os de la tête (SKEL_Head) ; ancre = os + headOffset en hauteur
        headOffset = 0.45,
        takenFallback = { x = 0.5, y = 0.58 },  -- chiffre reçu quand sa propre tête est hors de l'écran (vue subjective)
        decimals = 0,             -- 0 : entier (au moins 1 si le coup a porté) ; 1 : un chiffre après la virgule
        words = {
            block = 'Bloqué', parry = 'Paré', dodge = 'Esquivé', absorb = 'Absorbé', ['break'] = 'Garde brisée',
            stagger = 'Chancelle', down = 'À terre', none = 'Sans effet',
        },
    },

    -- Le jeu ne signale ni l'ouverture du menu pause, ni les fondus au noir, ni le retour de son interface :
    -- vérification à cet intervalle.
    pollMs = 250,

    -- Remontée d'une jauge que la page anime seule (1.8.0, T-114 : endurance) : part de la jauge par seconde (0 exclu à
    -- maxPerSecond) et attente avant de remonter (0 à maxDelayMs ms) ; au-delà, setGauge rend 'invalid_refill'.
    refill = { maxPerSecond = 10, maxDelayMs = 60000 },

    -- Bornes d'une déclaration de jauge.
    maxGauges = 12,
    maxIdLength = 64,
    maxLabelLength = 32,
    maxIconLength = 200,
    maxOrder = 1000,
}
