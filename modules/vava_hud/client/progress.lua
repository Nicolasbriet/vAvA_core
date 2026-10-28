--[[
    vava_hud/client/progress.lua
    Rôle : barre de progression d'une action longue (récolte, artisanat, arrosage, réparation, leçon…), partagée par
           tous les modules : une seule à la fois, identifiant préfixé par la ressource appelante, qui seule peut
           l'interrompre. Purement visuelle : le serveur reste maître du temps et revérifie la durée à la fin de
           l'action. Le HUD n'écoute aucune touche : interrompre (touche, déplacement) est l'affaire du module, qui
           appelle cancelProgress. Fin et interruption sont annoncées par les hooks client vava_hud:progressDone et
           vava_hud:progressCancelled. Aucune boucle : la fin est programmée une fois, l'interface anime seule.
    Dépendances : config.lua, client/core.lua, client/nui.lua
]]

local type = type
local mathType, tointeger = math.type, math.tointeger
local find, sub = string.find, string.sub
local GetGameTimer, SetTimeout = GetGameTimer, SetTimeout

local core = VavaHud.core
local cfg = VavaHud.config.progress
local maxIdLength = VavaHud.config.maxIdLength
local nui = VavaHud.nui

local ID_PATTERN = '^[%w_%-%.]+:[%w_%-%.]+$'
local HOOK_DONE = 'vava_hud:progressDone'
local HOOK_CANCELLED = 'vava_hud:progressCancelled'

local progress = {}
VavaHud.progress = progress

---@class vAvA.Progress
---@field id string
---@field owner string
---@field label string
---@field durationMs integer
---@field startedAt integer   GetGameTimer au départ
---@field endsAt integer
---@field cancelable boolean  indice « peut être interrompue » affiché

---@type vAvA.Progress|nil
local current = nil

---@param owner string
---@param id any
---@return boolean
local function owns(owner, id)
    return type(id) == 'string' and #id <= maxIdLength and find(id, ID_PATTERN) ~= nil
        and sub(id, 1, #owner + 1) == owner .. ':'
end

--- Durée en millisecondes entières dans les bornes de la config ; un flottant de valeur entière est accepté.
---@param value any
---@return integer|nil
local function duration(value)
    if type(value) ~= 'number' or value ~= value then return nil end
    if mathType(value) == 'float' then
        if value % 1 ~= 0 then return nil end
        value = tointeger(value)
    end
    if not value or value < cfg.minDurationMs or value > cfg.maxDurationMs then return nil end
    return value
end

---@param entry vAvA.Progress
---@param elapsedMs integer
---@return table
local function wire(entry, elapsedMs)
    return {
        id = entry.id, label = entry.label, durationMs = entry.durationMs, elapsedMs = elapsedMs,
        cancelable = entry.cancelable, hint = cfg.cancelHint,
    }
end

--- Termine la progression en cours : interface prévenue, hook déclenché.
---@param done boolean
---@param reason? 'module'|'hidden'  cause de l'interruption
local function finish(done, reason)
    local entry = current
    if not entry then return end
    current = nil
    nui.send('progressEnd', { id = entry.id, done = done })
    if done then
        core.hooks.runAfter(HOOK_DONE, { id = entry.id })
    else
        core.hooks.runAfter(HOOK_CANCELLED, { id = entry.id, reason = reason })
    end
end

--- Lance une progression. Une seule à la fois : la suivante attend la fin ou l'interruption de la précédente.
---@param owner string
---@param id any
---@param options any  { label, durationMs, cancelable? }
---@return boolean ok
---@return string|nil code  invalid_id, invalid_options, busy
function progress.start(owner, id, options)
    if not owns(owner, id) then return false, 'invalid_id' end
    if type(options) ~= 'table' then return false, 'invalid_options' end
    local label, durationMs, cancelable = options.label, duration(options.durationMs), options.cancelable
    if type(label) ~= 'string' or #label == 0 or #label > cfg.maxLabelLength then return false, 'invalid_options' end
    if not durationMs then return false, 'invalid_options' end
    if cancelable ~= nil and type(cancelable) ~= 'boolean' then return false, 'invalid_options' end
    if current then return false, 'busy' end

    local now = GetGameTimer()
    local entry = {
        id = id, owner = owner, label = label, durationMs = durationMs,
        startedAt = now, endsAt = now + durationMs, cancelable = cancelable == true,
    }
    current = entry
    nui.send('progress', wire(entry, 0))
    -- fin programmée une fois ; une progression interrompue puis remplacée n'est pas terminée par erreur
    SetTimeout(durationMs, function()
        if current == entry then finish(true) end
    end)
    return true
end

--- Interrompt la progression en cours. Seule la ressource qui l'a lancée le peut.
---@param owner string
---@param id any
---@return boolean ok
---@return string|nil code  not_found, not_owner
function progress.cancel(owner, id)
    local entry = current
    if not entry or entry.id ~= id then return false, 'not_found' end
    if entry.owner ~= owner then return false, 'not_owner' end
    finish(false, 'module')
    return true
end

--- Progression en cours, ou nil.
---@return { id: string, label: string, endsAt: integer }|nil
function progress.current()
    local entry = current
    if not entry then return nil end
    return { id = entry.id, label = entry.label, endsAt = entry.endsAt }
end

--- Le personnage quitte le jeu (sélection, déchargement) : l'action n'a plus de sens.
function progress.hide()
    if current then finish(false, 'hidden') end
end

--- Arrêt d'une ressource : sa progression disparaît.
---@param owner string
function progress.purgeOwner(owner)
    if current and current.owner == owner then finish(false, 'module') end
end

--- État pour l'interface (page prête ou rechargée en cours d'action) : elle reprend à la bonne avancée.
---@return table|nil
function progress.snapshot()
    local entry = current
    if not entry then return nil end
    return wire(entry, GetGameTimer() - entry.startedAt)
end
