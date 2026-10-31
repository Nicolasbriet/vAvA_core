--[[
    vava_gathering/client/blips.lua
    Rôle : les zones de récolte sur la carte, vues du joueur : un blip par zone (icône et couleur selon le genre, nommé
           comme elle, à courte portée) et le cercle translucide de son rayon, créés depuis la config partagée à
           l'entrée en jeu et retirés à la sélection, au déchargement et à l'arrêt du module ; repère de la carte posé
           sur une zone à la demande du panneau. Aucune boucle, rien ne circule : la config suffit.
    Dépendances : config_client.lua, client/core.lua, client/props.lua
]]

local ipairs = ipairs
local AddBlipForCoord, AddBlipForRadius, RemoveBlip, DoesBlipExist = AddBlipForCoord, AddBlipForRadius, RemoveBlip, DoesBlipExist
local SetBlipSprite, SetBlipColour, SetBlipScale, SetBlipAlpha, SetBlipAsShortRange =
    SetBlipSprite, SetBlipColour, SetBlipScale, SetBlipAlpha, SetBlipAsShortRange
local BeginTextCommandSetBlipName, AddTextComponentSubstringPlayerName, EndTextCommandSetBlipName =
    BeginTextCommandSetBlipName, AddTextComponentSubstringPlayerName, EndTextCommandSetBlipName
local SetNewWaypoint, AddEventHandler = SetNewWaypoint, AddEventHandler

local core = VavaGathering.core
if not core then return end

local cfg = VavaGathering.config
local mapCfg = cfg.map
local props = VavaGathering.props
local RESOURCE = VavaGathering.resource
local NAME_TEXT = 'STRING'

local blips = {}
VavaGathering.blips = blips

-- blips posés (zones et cercles), dans l'ordre de création
local handles = {}
local shown = false

---@param kind string
---@return { sprite: integer, colour: integer }
local function lookOf(kind)
    return mapCfg.kinds[kind] or mapCfg.default
end

---@param blip integer
---@param label string
local function name(blip, label)
    BeginTextCommandSetBlipName(NAME_TEXT)
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
end

--- Pose les blips de toutes les zones, une seule fois : les apparitions suivantes ne les doublent pas.
function blips.show()
    if shown or not mapCfg.blips then return end
    shown = true
    for _, zone in ipairs(cfg.zones) do
        local look = lookOf(zone.kind)
        local blip = AddBlipForCoord(zone.x, zone.y, zone.z)
        SetBlipSprite(blip, look.sprite)
        SetBlipColour(blip, look.colour)
        SetBlipScale(blip, mapCfg.scale)
        SetBlipAsShortRange(blip, true)
        name(blip, zone.label)
        handles[#handles + 1] = blip
        if mapCfg.ring.show then
            local ring = AddBlipForRadius(zone.x, zone.y, zone.z, zone.radius)
            SetBlipColour(ring, look.colour)
            SetBlipAlpha(ring, mapCfg.ring.alpha)
            handles[#handles + 1] = ring
        end
    end
end

--- Retire tous les blips du module.
function blips.hide()
    shown = false
    for i = #handles, 1, -1 do
        if DoesBlipExist(handles[i]) then RemoveBlip(handles[i]) end
        handles[i] = nil
    end
end

--- Repère de la carte posé au centre d'une zone (panneau des zones).
---@param zoneId string
---@return boolean  faux si la zone est inconnue
function blips.waypoint(zoneId)
    local zone = props.zone(zoneId)
    if not zone then return false end
    SetNewWaypoint(zone.x, zone.y)
    return true
end

--- Suit l'entrée et la sortie du jeu. Appelé par client/main.lua.
function blips.start()
    core.hooks.after('core:character:spawning', blips.show)
    core.hooks.after('core:character:selection', blips.hide)
    core.hooks.after('core:character:unloaded', blips.hide)
    if core.characters.current() and not core.characters.awaitingSelection() then blips.show() end
end

-- arrêt du module : aucun blip ne doit rester sur la carte
AddEventHandler('onResourceStop', function(resource)
    if resource == RESOURCE then blips.hide() end
end)
