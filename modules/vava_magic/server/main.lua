--[[
    vava_magic/server/main.lua
    Rôle : déclaration du module auprès du core : champ de fiche, catalogue des sorts et leurs RPC, objets (grimoire,
           registre), arrivée et départ des personnages (fiche chargée, mana pleine pour un mage ; tout est écrit et
           nettoyé au départ), intentions du client en RPC à schéma strict et à débit limité (dont le sort choisi dans
           la roue), écritures régulières, commandes du Conseil.
    Dépendances : tous les fichiers server/ du module
]]

local ipairs, pairs, tonumber, tostring = ipairs, pairs, tonumber, tostring
local AddEventHandler, GetPlayers, TriggerClientEvent = AddEventHandler, GetPlayers, TriggerClientEvent

local core = VavaMagic.core
if not core then return end

local bridge = VavaMagic.bridge
local world = VavaMagic.world
local sheets = VavaMagic.sheets
local mana = VavaMagic.mana
local experience = VavaMagic.experience
local spells = VavaMagic.spells
local casting = VavaMagic.casting
local sigils = VavaMagic.sigils
local registers = VavaMagic.registers
local combat = VavaMagic.combat
local states = VavaMagic.states
local admin = VavaMagic.admin
local cfg = VavaMagic.config
local limits = cfg.rateLimits
local RPC = VavaMagic.RPC
local EVENTS = VavaMagic.EVENTS

local ID = { type = 'integer', min = 1, max = 0x7FFFFFFF }
local PAGE_ID = { type = 'integer', min = 1, max = 2 ^ 53 }
local INDEX = { type = 'integer', min = 1, max = sheets.SIGILS_MAX }
local NAME = { type = 'string', max = cfg.sigils.nameMax * 4 }
-- sort prêt dans les mains : un nom de sort, ou '' pour aucun
local SELECTED = { type = 'string', max = 32, pattern = '^[%w_]*$' }
local BOOL = { type = 'boolean' }

--- Personnage arrivé : fiche chargée (bloque le thread du core le temps de lire son sigil), mana pleine s'il est mage.
---@param src integer
---@param characterId integer
local function arrive(src, characterId)
    if not sheets.load(src, characterId) then
        VavaMagic.log.error('fiche magie du personnage %d non chargée', characterId)
        return
    end
    if sheets.get(src).isMage then mana.start(src) end
end

--- Départ du personnage : tout ce qui le concerne est arrêté, sa fiche écrite.
---@param src integer
local function leave(src)
    casting.forget(src)
    states.clear(src)
    sigils.forgetPlayer(src)
    spells.leave(src)
    world.clearStates(src)
    mana.stop(src)
    experience.forget(src)
    sheets.unload(src)
end

--- Vue de la fiche à l'apparition : { view, catalog (sorts d'autres modules), admin }. Renvoie aussi la mana.
local function sheetRequest(src)
    local view = sheets.view(src)
    if not view then return false, 'not_ready' end
    mana.push(src)
    return true, { view = view, catalog = spells.catalog(), admin = bridge.IsAdmin(src) }
end

local function setup()
    local declared, declareErr = VavaMagic.commands.declare()
    if not declared then return false, 'commandes : ' .. tostring(declareErr) end
    local ok, err = bridge.DefineSheet(sheets.SCHEMA)
    if not ok then return false, 'champ de fiche : ' .. tostring(err) end
    ok, err = spells.start()
    if not ok then return false, err end
    for name in pairs(spells.all()) do
        ok, err = casting.expose(name)
        if not ok then return false, err end
    end
    for _, def in ipairs({
        { RPC.SHEET, {}, limits.sheet, sheetRequest },
        { RPC.SELECT, { SELECTED }, limits.select, sheets.select },
        { RPC.CANCEL, { ID }, limits.cancel, function(src, castId) casting.cancel(src, castId) end },
        { RPC.SIGILS, {}, limits.sigils, function(src)
            local list = sigils.list(src)
            if not list then return false, 'not_ready' end
            return true, list
        end },
        { RPC.SIGIL_OFFER, {}, limits.offer, sigils.offer },
        { RPC.SIGIL_ANSWER, { ID, BOOL, NAME, BOOL }, limits.answer, sigils.answer },
        { RPC.SIGIL_NAME, { ID, BOOL, NAME }, limits.answer, sigils.nameBack },
        { RPC.SIGIL_RENAME, { INDEX, NAME }, limits.edit, sigils.rename },
        { RPC.SIGIL_FORGET, { INDEX }, limits.edit, sigils.forget },
        { RPC.SIGIL_SCRAMBLE, {}, limits.scramble, sigils.scramble },
        { RPC.REGISTER_TEAR, { ID, PAGE_ID }, limits.register, registers.tear },
    }) do
        ok, err = core.rpc.register(def[1], { args = def[2], rateLimit = def[3] }, def[4])
        if not ok then return false, err end
    end
    for _, def in ipairs({
        { 'core:character:loaded', function(payload) arrive(payload.source, payload.characterId) end },
        { 'core:character:unloading', function(payload) leave(payload.source) end },
        { 'core:player:dropped', function(payload) leave(payload.source) end },
        { 'core:character:deleted', function(payload) sheets.forgetCharacter(payload.characterId) end },
    }) do
        local id, hookErr = core.hooks.after(def[1], def[2])
        if not id then return false, hookErr end
    end
    VavaMagic.ready = true
    ok, err = bridge.start()
    if not ok then return false, err end
    sheets.start()
    combat.start()
    states.start()
    admin.start()
    -- module (re)démarré en cours de partie : fiches des personnages déjà en jeu
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local characterId = src and bridge.GetCharacterId(src)
        if characterId then arrive(src, characterId) end
    end
    return true
end

-- utiliser le grimoire l'ouvre (le client le lit d'après sa vue de la fiche)
bridge.RegisterUsableItem(cfg.items.grimoire.name, cfg.items.grimoire, function(src)
    TriggerClientEvent(EVENTS.GRIMOIRE, src)
end)

-- arrêt du module : fiches écrites, effets retirés des peds, orbes supprimés, journal des dégâts vidé
AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaMagic.resource or not VavaMagic.ready then return end
    for src in pairs(sheets.all()) do
        sheets.save(src)
        world.clearStates(src)
    end
    -- un joueur gelé est libéré
    states.clearAll()
    spells.stop()
    combat.flush()
end)

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaMagic.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
