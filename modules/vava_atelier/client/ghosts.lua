--[[
    vava_atelier/client/ghosts.lua
    Rôle : objets fantômes de l'outil de placement (§ 8.3 de la spec T-102) : objets LOCAUX (jamais réseau : personne
           d'autre ne les voit), translucides, sans collision, figés, pour les enfants qui n'existent pas encore en jeu
           (`new`, ou brouillon déplacé) à portée (`placement.ghosts.distance`, 12 au plus) et pour le candidat de la
           visée (repositionné à chaque image). Modèle chargé dans un fil avec une attente bornée (`loadTimeoutMs`) ;
           un modèle inconnu laisse le chevron (client/drawing.lua). Tous retirés en quittant la fiche, à la fermeture
           de l'Atelier, au déchargement et à l'arrêt de la ressource.
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua
]]

local pairs, type = pairs, type
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local GetHashKey, IsModelValid, RequestModel, HasModelLoaded, SetModelAsNoLongerNeeded =
    GetHashKey, IsModelValid, RequestModel, HasModelLoaded, SetModelAsNoLongerNeeded
local CreateObjectNoOffset, DoesEntityExist, DeleteObject = CreateObjectNoOffset, DoesEntityExist, DeleteObject
local SetEntityAlpha, SetEntityCollision, FreezeEntityPosition, SetEntityHeading, SetEntityCoordsNoOffset =
    SetEntityAlpha, SetEntityCollision, FreezeEntityPosition, SetEntityHeading, SetEntityCoordsNoOffset

local placement = VavaAtelier.config.placement
local settings = placement.ghosts
local LOAD_POLL_MS = 50

local ghosts = {}
VavaAtelier.ghosts = ghosts

-- fantômes posés : clé ('type|id') → { model, entity?, loading, failed, x, y, z, h }
local shown = {}
-- fantôme du candidat de la visée : { model, entity?, loading, failed }
local candidate = nil

---@param entry table|nil
local function drop(entry)
    if entry and entry.entity and DoesEntityExist(entry.entity) then DeleteObject(entry.entity) end
    if entry then entry.entity, entry.gone = nil, true end
end

--- Crée l'objet d'un fantôme (modèle chargé dans un fil, attente bornée) ; `entry.failed` si le modèle est inconnu.
---@param entry table
local function spawn(entry)
    entry.loading = true
    CreateThread(function()
        local hash = GetHashKey(entry.model)
        if not IsModelValid(hash) then
            entry.loading, entry.failed = false, true
            return
        end
        RequestModel(hash)
        local deadline = GetGameTimer() + settings.loadTimeoutMs
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(LOAD_POLL_MS) end
        if entry.gone or not HasModelLoaded(hash) then
            entry.loading, entry.failed = false, not entry.gone
            SetModelAsNoLongerNeeded(hash)
            return
        end
        local entity = CreateObjectNoOffset(hash, entry.x, entry.y, entry.z, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        entry.loading = false
        if entity == 0 then
            entry.failed = true
            return
        end
        SetEntityAlpha(entity, settings.alpha, false)
        SetEntityCollision(entity, false, false)
        FreezeEntityPosition(entity, true)
        SetEntityHeading(entity, entry.h or 0.0)
        entry.entity = entity
    end)
end

---@param entry table
local function move(entry, x, y, z, h)
    entry.x, entry.y, entry.z, entry.h = x, y, z, h
    if entry.entity then
        SetEntityCoordsNoOffset(entry.entity, x, y, z, false, false, false)
        SetEntityHeading(entry.entity, h or 0.0)
    end
end

--- Fantômes voulus (12 au plus, déjà choisis par l'appelant) : { { key, model, x, y, z, h } }. Les autres sont retirés,
--- ceux qui ont bougé repositionnés, ceux d'un autre modèle recréés.
---@param list table[]
function ghosts.sync(list)
    local wanted = {}
    for i = 1, math.min(#list, settings.max) do wanted[list[i].key] = list[i] end
    for key, entry in pairs(shown) do
        local want = wanted[key]
        if not want or want.model ~= entry.model then
            drop(entry)
            shown[key] = nil
        end
    end
    for key, want in pairs(wanted) do
        local entry = shown[key]
        if entry then
            if entry.x ~= want.x or entry.y ~= want.y or entry.z ~= want.z or entry.h ~= want.h then
                move(entry, want.x, want.y, want.z, want.h)
            end
        else
            entry = { model = want.model, x = want.x, y = want.y, z = want.z, h = want.h }
            shown[key] = entry
            spawn(entry)
        end
    end
end

--- Un fantôme posé et visible pour cette clé ? (sinon la visée dessine un chevron)
---@param key string
---@return boolean
function ghosts.has(key)
    local entry = shown[key]
    return entry ~= nil and (entry.entity ~= nil or entry.loading == true)
end

--- Fantôme du candidat : `model` nil le retire ; sinon créé (ou recréé s'il change de modèle) et placé.
---@param model string|nil
---@return boolean visible  faux : modèle inconnu ou en chargement (chevron)
function ghosts.candidate(model, x, y, z, h)
    if candidate and candidate.model ~= model then
        drop(candidate)
        candidate = nil
    end
    if type(model) ~= 'string' then return false end
    if not candidate then
        candidate = { model = model, x = x, y = y, z = z, h = h }
        spawn(candidate)
        return false
    end
    move(candidate, x, y, z, h)
    return candidate.entity ~= nil
end

--- Tous les fantômes retirés (fiche quittée, Atelier fermé, déchargement, arrêt de la ressource).
function ghosts.clear()
    for key, entry in pairs(shown) do
        drop(entry)
        shown[key] = nil
    end
    drop(candidate)
    candidate = nil
end
