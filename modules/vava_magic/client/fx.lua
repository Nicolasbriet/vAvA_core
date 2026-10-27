--[[
    vava_magic/client/fx.lua
    Rôle : gestion commune des effets, pour que plusieurs mages restent fluides :
      - lots de particules et dictionnaires d'animation chargés à la demande (attente bornée), libérés quand plus
        rien ne s'en sert depuis `effects.releaseMs` (le lot « core » de GTA reste toujours chargé) ;
      - plafond de lumières dynamiques dessinées par image, et de particules en boucle actives ;
      - niveau de détail selon la distance à la caméra : complet, simplifié, ou rien.
    Dépendances : config.lua, shared/geometry.lua
]]

local pairs, next = pairs, next
local CreateThread, Wait, GetGameTimer, GetFrameCount, GetFinalRenderedCamCoord =
    CreateThread, Wait, GetGameTimer, GetFrameCount, GetFinalRenderedCamCoord
local RequestNamedPtfxAsset, HasNamedPtfxAssetLoaded, RemoveNamedPtfxAsset, UseParticleFxAsset, StopParticleFxLooped =
    RequestNamedPtfxAsset, HasNamedPtfxAssetLoaded, RemoveNamedPtfxAsset, UseParticleFxAsset, StopParticleFxLooped
local RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict = RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict
local DrawLightWithRange = DrawLightWithRange

local geometry = VavaMagic.geometry
local cfg = VavaMagic.config.effects
-- lot de particules de base de GTA : jamais libéré (d'autres ressources s'en servent)
local BASE_ASSET = 'core'
local LOAD_POLL_MS = 10

local fx = {}
VavaMagic.fx = fx

fx.FULL, fx.REDUCED = 'full', 'reduced'

---@type table<string, { lastUse: integer, handles: integer }>
local assets = {}
---@type table<string, { lastUse: integer, users: integer }>
local dicts = {}
---@type table<integer, string>  particule en boucle → son lot
local looped = {}
local loopedCount = 0
local lightFrame, lightCount = -1, 0
local releasing = false

local function startRelease()
    if releasing then return end
    releasing = true
    CreateThread(function()
        while next(assets) or next(dicts) do
            Wait(cfg.releaseMs)
            local now = GetGameTimer()
            for asset, entry in pairs(assets) do
                if entry.handles <= 0 and now - entry.lastUse >= cfg.releaseMs then
                    if asset ~= BASE_ASSET then RemoveNamedPtfxAsset(asset) end
                    assets[asset] = nil
                end
            end
            for dict, entry in pairs(dicts) do
                if entry.users <= 0 and now - entry.lastUse >= cfg.releaseMs then
                    RemoveAnimDict(dict)
                    dicts[dict] = nil
                end
            end
        end
        releasing = false
    end)
end

---@param asset string
---@return table
local function assetEntry(asset)
    local entry = assets[asset]
    if not entry then
        entry = { lastUse = GetGameTimer(), handles = 0 }
        assets[asset] = entry
        startRelease()
    end
    entry.lastUse = GetGameTimer()
    return entry
end

--- Lot de particules prêt ? Sinon sa demande part, sans attendre (à rappeler à l'image suivante).
---@param asset string
---@return boolean
function fx.ptfxReady(asset)
    assetEntry(asset)
    if HasNamedPtfxAssetLoaded(asset) then return true end
    RequestNamedPtfxAsset(asset)
    return false
end

--- Charge un lot de particules en attendant (au plus `effects.assetLoadMs`). Bloque le thread appelant.
---@param asset string
---@return boolean
function fx.loadPtfx(asset)
    if fx.ptfxReady(asset) then return true end
    local deadline = GetGameTimer() + cfg.assetLoadMs
    while not HasNamedPtfxAssetLoaded(asset) do
        if GetGameTimer() > deadline then return false end
        Wait(LOAD_POLL_MS)
    end
    return true
end

--- Démarre une particule en boucle si le plafond le permet : `start()` la crée (le lot est déjà choisi). Renvoie
--- son numéro, ou nil.
---@param asset string
---@param start fun(): integer
---@return integer|nil
function fx.startLooped(asset, start)
    if loopedCount >= cfg.maxLooped or not fx.ptfxReady(asset) then return nil end
    UseParticleFxAsset(asset)
    local handle = start()
    if not handle or handle == 0 then return nil end
    looped[handle] = asset
    loopedCount = loopedCount + 1
    assetEntry(asset).handles = assetEntry(asset).handles + 1
    return handle
end

---@param handle integer|nil
function fx.stopLooped(handle)
    if not handle then return end
    local asset = looped[handle]
    StopParticleFxLooped(handle, false)
    if not asset then return end
    looped[handle] = nil
    loopedCount = loopedCount - 1
    local entry = assets[asset]
    if entry then
        entry.handles = entry.handles - 1
        entry.lastUse = GetGameTimer()
    end
end

--- Particule ponctuelle (impact…) : `play()` la lance si son lot est prêt.
---@param asset string
---@param play fun()
---@return boolean
function fx.oneShot(asset, play)
    if not fx.ptfxReady(asset) then return false end
    UseParticleFxAsset(asset)
    play()
    return true
end

--- Lumière dynamique pour cette image, si le plafond n'est pas atteint.
---@return boolean drawn
function fx.light(x, y, z, r, g, b, range, intensity)
    local frame = GetFrameCount()
    if frame ~= lightFrame then lightFrame, lightCount = frame, 0 end
    if lightCount >= cfg.maxLights then return false end
    lightCount = lightCount + 1
    DrawLightWithRange(x, y, z, r, g, b, range, intensity)
    return true
end

--- Niveau de détail d'un effet à cette position : fx.FULL, fx.REDUCED, ou nil (trop loin : rien à dessiner).
---@param position table
---@return string|nil
function fx.detail(position)
    local distance = geometry.distance(GetFinalRenderedCamCoord(), position)
    if distance <= cfg.fullDistance then return fx.FULL end
    if distance <= cfg.maxDistance then return fx.REDUCED end
    return nil
end

--- Charge un dictionnaire d'animation (attente bornée) et le garde tant qu'il sert. Bloque le thread appelant.
---@param dict string
---@return boolean
function fx.useAnim(dict)
    local entry = dicts[dict]
    if not entry then
        entry = { lastUse = GetGameTimer(), users = 0 }
        dicts[dict] = entry
        startRelease()
    end
    entry.users = entry.users + 1
    entry.lastUse = GetGameTimer()
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + cfg.assetLoadMs
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then
            entry.users = entry.users - 1
            return false
        end
        Wait(LOAD_POLL_MS)
    end
    return true
end

--- Le dictionnaire ne sert plus à cet appelant (libéré plus tard s'il ne sert à personne).
---@param dict string
function fx.releaseAnim(dict)
    local entry = dicts[dict]
    if not entry then return end
    entry.users = entry.users > 0 and entry.users - 1 or 0
    entry.lastUse = GetGameTimer()
end

--- Arrêt du module : toutes les particules en boucle s'éteignent.
function fx.stop()
    for handle in pairs(looped) do StopParticleFxLooped(handle, false) end
    looped, loopedCount = {}, 0
end

