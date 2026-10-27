--[[
    vava_needs/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole.
    Dépendances : aucune
]]

VavaNeeds = {}

-- Champ de personnage : { [besoin] = valeur } (visibilité owner : envoyé au seul joueur du personnage).
VavaNeeds.FIELD = 'vava_needs:state'
-- Valeur d'un besoin pleinement satisfait (0 = épuisé).
VavaNeeds.MAX = 100

-- Événements serveur → client (toujours vers le seul joueur concerné).
VavaNeeds.EVENTS = {
    CONSUME = 'vava_needs:consume',   -- geste de consommation à jouer (nom du geste)
    STARVE = 'vava_needs:starve',     -- points de vie perdus à cause d'un besoin épuisé
}

-- Hooks déclenchés par le module.
VavaNeeds.HOOKS = {
    DECAY = 'vava_needs:decay',       -- before, annulable : suspend la baisse d'un personnage (prison, zone protégée…)
    CHANGED = 'vava_needs:changed',   -- after : valeurs d'un personnage modifiées
}

-- Hook de l'inventaire écouté pour manger et boire (l'inventaire reste facultatif).
VavaNeeds.INVENTORY_USE = 'vava_inventory:use'
-- Préfixe des jauges déclarées auprès de vava_hud.
VavaNeeds.GAUGE_PREFIX = 'vava_needs:'
