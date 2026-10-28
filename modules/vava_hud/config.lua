--[[
    vava_hud/config.lua
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

    -- Le jeu ne signale ni l'ouverture du menu pause, ni les fondus au noir, ni le retour de son interface :
    -- vérification à cet intervalle.
    pollMs = 250,

    -- Bornes d'une déclaration de jauge.
    maxGauges = 12,
    maxIdLength = 64,
    maxLabelLength = 32,
    maxIconLength = 200,
    maxOrder = 1000,
}
