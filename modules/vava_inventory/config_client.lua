--[[
    vava_inventory/config_client.lua
    Rôle : réglages de l'inventaire que lit le client : sacs au sol vus du client (distance d'interaction, attente de
           l'entité), objet tenu en main (cadences du client), raccourcis, touches. Téléchargé par chaque joueur ; le
           serveur le lit aussi. Tout le reste (grille du personnage, sacs au sol, bornes des objets, métadonnées,
           ancrages, garde de la main, journal, catalogue, objets de départ, débits) est dans config.lua, servi au
           seul serveur (T-132).
    Dépendances : shared/constants.lua
]]

VavaInventory.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.9.0)

    -- Sacs au sol, vus du client. Le reste des sacs (grille, modèle, durée, plafonds) est dans config.lua.
    drop = {
        interactDistance = 2.5,    -- distance maximale (m), vérifiée côté serveur à chaque opération
        stateWaitMs = 2000,        -- client : attente maximale de l'entité locale d'un sac signalé par statebag
        statePollMs = 100,
    },

    -- Objet tenu en main (objets déclarant `held = { model, bone?, offset?, rotation? }`), cadences du client. Os par
    -- défaut et garde du statebag par le serveur : config.lua.
    hands = {
        pollMs = 1000,             -- client : cadence de la boucle lente, active seulement tant qu'un accessoire est affiché
        modelTimeoutMs = 5000,     -- client : attente maximale du chargement d'un modèle d'accessoire
        awaitPedMs = 10000,        -- client : attente maximale du ped d'une main reçue avant lui (puis oubliée)
    },
    hotbarSize = 5,

    -- Touches par défaut, modifiables par chaque joueur (Paramètres > Raccourcis > FiveM). `open` est citée par l'écran
    -- de chargement : la changer oblige à retoucher le conseil de modules/vava_loading/web/js/strings.js.
    keys = { open = 'I', hotbar = { '1', '2', '3', '4', '5' } },
    labels = { open = 'Ouvrir l\'inventaire', slot = 'Raccourci d\'inventaire %d' },
}
