--[[
    vava_magic/server/casting.lua
    Rôle : incantation commune à tous les sorts, décidée par le serveur.
      - Début (RPC du sort) : fiche chargée, mage, sort connu, une seule incantation à la fois, pas à terre ni en
        véhicule, empêchements des autres fichiers (état « chancelant »…), délai global entre deux sorts, temps de
        recharge du sort, hook `vava_magic:castStarting` (annulable), validation propre au sort, mana. Position et vie
        du lanceur notées (lues côté serveur) ; state bag « incantation » (sort et niveau) sur son ped ; le sort est
        prévenu que l'incantation est acceptée (`started` : frisson de la cible verrouillée…).
      - Fin (RPC du sort) : durée écoulée, déplacement (positions serveur) et vie (une blessure interrompt les sorts
        qui le disent, `interruptOnHurt`) revérifiés.
        La mana est réservée avant l'effet du sort : rendue en entier s'il refuse, en partie s'il le dit (échec
        partiel) ; temps de recharge et délai global posés ; XP accordée (moitié pour un échec).
      - Interruption (chute, blessure, déplacement, touche) : aucune mana consommée ; incantation sans fin
        abandonnée après sa durée et une marge.
    Les temps de recharge sont tenus par personnage : se reconnecter ne les efface pas.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/world.lua, server/sheets.lua,
                  server/mana.lua, server/progression.lua, server/spells.lua
]]

local type, pcall, tostring, ipairs, pairs = type, pcall, tostring, ipairs, pairs
local ceil, floor, mathType = math.ceil, math.floor, math.type
local unpack = table.unpack
local GetGameTimer, SetTimeout, TriggerClientEvent = GetGameTimer, SetTimeout, TriggerClientEvent

local core = VavaMagic.core
local bridge = VavaMagic.bridge
local world = VavaMagic.world
local sheets = VavaMagic.sheets
local mana = VavaMagic.mana
local experience = VavaMagic.experience
local spells = VavaMagic.spells
local progression = VavaMagic.progression
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config.casting
local limits = VavaMagic.config.rateLimits
local EVENTS = VavaMagic.EVENTS
local STATES = VavaMagic.STATES
local HOOKS = VavaMagic.HOOKS
local BEGIN_PREFIX, FINISH_PREFIX = VavaMagic.BEGIN_PREFIX, VavaMagic.FINISH_PREFIX

local CAST_ID = { type = 'integer', min = 1, max = 0x7FFFFFFF }
local MS_PER_SECOND = 1000

local casting = {}
VavaMagic.casting = casting

---@class vAvA.MagicCast
---@field id integer
---@field spell string
---@field level integer
---@field cost integer
---@field characterId integer
---@field startedAt integer
---@field durationMs integer
---@field origin table
---@field health integer
---@field maxMove number
---@field data any       préparé par le sort au début, rendu à sa fin
---@field finishing boolean

---@type table<integer, vAvA.MagicCast>
local casts = {}
---@type table<integer, table<string, integer>>  personnage → sort → fin du temps de recharge
local cooldowns = {}
---@type table<integer, integer>  personnage → fin du délai global entre deux sorts
local globals = {}
---@type (fun(src: integer): string|nil)[]  empêchements d'incanter (renvoient un code de refus)
local blockers = {}
---@type table<string, boolean>  sorts dont les RPC sont ouvertes
local exposed = {}
local nextId = 0

--- Appelle une fonction d'un sort (peut venir d'un autre module) : une erreur est journalisée, jamais propagée.
local function invoke(fn, ...)
    local results = table.pack(pcall(fn, ...))
    if not results[1] then
        VavaMagic.log.error('sort en erreur : %s', tostring(results[2]))
        return false, 'server_error'
    end
    return unpack(results, 2, results.n)
end

---@param characterId integer
---@param spell string
---@return integer  millisecondes restantes
function casting.cooldownLeft(characterId, spell)
    local entries = cooldowns[characterId]
    local untilMs = entries and entries[spell]
    if not untilMs then return 0 end
    local left = untilMs - GetGameTimer()
    if left <= 0 then
        entries[spell] = nil
        return 0
    end
    return left
end

---@param characterId integer
---@return integer  millisecondes restantes du délai global
function casting.globalLeft(characterId)
    local untilMs = globals[characterId]
    if not untilMs then return 0 end
    local left = untilMs - GetGameTimer()
    if left <= 0 then
        globals[characterId] = nil
        return 0
    end
    return left
end

--- Efface les temps de recharge d'un personnage (Conseil).
---@param characterId integer
function casting.resetCooldowns(characterId)
    cooldowns[characterId] = nil
    globals[characterId] = nil
end

--- Empêchement d'incanter tenu par un autre fichier : `check(source)` renvoie un code de refus, ou nil.
---@param check fun(src: integer): string|nil
function casting.addBlocker(check)
    blockers[#blockers + 1] = check
end

---@param src integer
---@return string|nil
local function blocked(src)
    for _, check in ipairs(blockers) do
        local ok, code = pcall(check, src)
        if ok and type(code) == 'string' then return code end
    end
    return nil
end

---@param characterId integer
---@param spell string
---@param ms integer
function casting.setCooldown(characterId, spell, ms)
    if ms <= 0 then return end
    local entries = cooldowns[characterId]
    if not entries then
        entries = {}
        cooldowns[characterId] = entries
    end
    entries[spell] = GetGameTimer() + ms
end

--- Incantation en cours du joueur (nil s'il n'en a pas).
---@param src integer
---@return vAvA.MagicCast|nil
function casting.current(src)
    return casts[src]
end

--- Contexte passé aux fonctions du sort.
---@param src integer
---@param cast vAvA.MagicCast
---@return table
local function contextOf(src, cast)
    return {
        source = src, characterId = cast.characterId, spell = cast.spell, level = cast.level, cost = cast.cost,
        castId = cast.id, origin = cast.origin, data = cast.data,
    }
end

--- Arrête une incantation sans rien consommer ; `tell` prévient le client du lanceur.
---@param src integer
---@param code string
---@param tell? boolean
function casting.abort(src, code, tell)
    local cast = casts[src]
    if not cast then return end
    casts[src] = nil
    world.setState(src, STATES.CASTING, nil)
    local def = spells.get(cast.spell)
    if def and def.cancel then invoke(def.cancel, contextOf(src, cast), code) end
    if tell then TriggerClientEvent(EVENTS.CAST_ABORT, src, cast.id, code) end
end

--- Début d'une incantation. Renvoie true, { id, ms, move } ou false, code[, secondes de recharge].
---@param src integer
---@param name string
---@return boolean ok
---@return any info
---@return any extra
function casting.begin(src, name, ...)
    local def = spells.get(name)
    local sheet = sheets.get(src)
    if not def then return false, 'unknown_spell' end
    if not sheet then return false, 'not_ready' end
    if not sheet.isMage then return false, 'not_mage' end
    local entry = sheet.spells[name]
    if not entry then return false, 'unknown_spell' end
    if casts[src] then return false, 'busy' end
    if bridge.IsDowned(src) then return false, 'downed' end
    if world.inVehicle(src) then return false, 'in_vehicle' end
    local blocker = blocked(src)
    if blocker then return false, blocker end
    if casting.globalLeft(sheet.characterId) > 0 then return false, 'global_cooldown' end
    local left = casting.cooldownLeft(sheet.characterId, name)
    if left > 0 then return false, 'cooldown', ceil(left / MS_PER_SECOND) end
    local origin = world.position(src)
    local health = world.health(src)
    if not origin or not health then return false, 'no_position' end

    local level = progression.levelOf(entry.xp)
    local allowed, reason = core.hooks.runBefore(HOOKS.CASTING, { source = src, characterId = sheet.characterId, spell = name, level = level })
    if not allowed then return false, (type(reason) == 'string' and reason ~= 'hook_error') and reason or 'refused' end

    local ctx = { source = src, characterId = sheet.characterId, spell = name, level = level, origin = origin, cost = progression.cost(def.config, level) }
    local ok, data, cost = invoke(def.begin, ctx, ...)
    if ok ~= true then return false, type(data) == 'string' and data or 'refused' end
    cost = (mathType(cost) == 'integer' and cost >= 0) and cost or ctx.cost
    if mana.current(src) < cost then return false, 'no_mana' end

    local levelCfg = def.config.levels[level]
    local duration = levelCfg.castMs
    local maxMove = cfg.maxMove
    if def.config.moveSpeed then maxMove = maxMove + def.config.moveSpeed * duration / MS_PER_SECOND end
    nextId = nextId % CAST_ID.max + 1
    local cast = {
        id = nextId, spell = name, level = level, cost = cost, characterId = sheet.characterId,
        startedAt = GetGameTimer(), durationMs = duration, origin = origin, health = health, maxMove = maxMove,
        data = data, finishing = false,
    }
    casts[src] = cast
    world.setState(src, STATES.CASTING, { spell = name, level = level })
    -- incantation acceptée (mana, recharges, contrôles passés) : ce que le sort annonce seulement maintenant
    if def.started then invoke(def.started, contextOf(src, cast)) end
    SetTimeout(duration + cfg.graceMs, function()
        if casts[src] == cast and not cast.finishing then casting.abort(src, 'expired', true) end
    end)
    return true, { id = cast.id, ms = duration, move = maxMove }
end

--- Fin d'une incantation. Renvoie true, { success, cooldownMs, result } ou false, code.
---@param src integer
---@param name string
---@param castId integer
---@return boolean ok
---@return any info
function casting.finish(src, name, castId, ...)
    local cast = casts[src]
    if not cast or cast.id ~= castId or cast.spell ~= name or cast.finishing then return false, 'no_cast' end
    local def = spells.get(name)
    if not def then
        casting.abort(src, 'unknown_spell')
        return false, 'unknown_spell'
    end
    if GetGameTimer() - cast.startedAt < cast.durationMs - cfg.finishToleranceMs then
        casting.abort(src, 'too_soon')
        return false, 'too_soon'
    end
    local position = world.position(src)
    local health = world.health(src)
    local code = nil
    if not position or not health then
        code = 'no_position'
    elseif geometry.distance(cast.origin, position) > cast.maxMove + cfg.moveMargin then
        code = 'moved'
    elseif health < cast.health and def.config.interruptOnHurt ~= false then
        code = 'hurt'
    elseif bridge.IsDowned(src) then
        code = 'downed'
    end
    if code then
        casting.abort(src, code)
        return false, code
    end

    -- la mana est réservée : rien d'autre ne peut la dépenser pendant l'effet du sort
    if not mana.spend(src, cast.cost) then
        casting.abort(src, 'no_mana')
        return false, 'no_mana'
    end
    cast.finishing = true
    world.setState(src, STATES.CASTING, nil)
    local outcome, refusal = invoke(def.finish, contextOf(src, cast), ...)
    if casts[src] == cast then casts[src] = nil end
    if type(outcome) ~= 'table' then
        mana.give(src, cast.cost)
        return false, type(refusal) == 'string' and refusal or 'refused'
    end
    local refund = type(outcome.refund) == 'number' and outcome.refund or 0
    if refund > 0 then mana.give(src, floor(cast.cost * (refund > 1 and 1 or refund) + 0.5)) end
    local cooldownMs = def.config.levels[cast.level].cooldownMs
    casting.setCooldown(cast.characterId, name, cooldownMs)
    globals[cast.characterId] = GetGameTimer() + cfg.globalCooldownMs
    local success = outcome.success ~= false
    local gained = experience.grant(src, name, success)
    -- un sort qui touche plus tard (projectile) ne rapporte son bonus que si le lancer a rapporté de l'XP
    if type(outcome.rewarded) == 'function' then outcome.rewarded(gained > 0) end
    core.hooks.runAfter(HOOKS.CAST, { source = src, characterId = cast.characterId, spell = name, level = cast.level, success = success })
    return true, { success = success, cooldownMs = cooldownMs, globalMs = cfg.globalCooldownMs, result = outcome.result }
end

--- Interruption demandée par le client (rien n'est consommé).
---@param src integer
---@param castId integer
function casting.cancel(src, castId)
    local cast = casts[src]
    if cast and cast.id == castId and not cast.finishing then casting.abort(src, 'cancelled') end
end

--- Départ du joueur : son incantation est perdue.
---@param src integer
function casting.forget(src)
    casting.abort(src, 'left')
end

--- Ouvre les RPC (début et fin) d'un sort déclaré.
---@param name string
---@return boolean ok
---@return string|nil err
function casting.expose(name)
    local def = spells.get(name)
    if not def or exposed[name] then return true end
    local ok, err = core.rpc.register(BEGIN_PREFIX .. name, { args = def.beginArgs, rateLimit = limits.cast }, function(src, ...)
        return casting.begin(src, name, ...)
    end)
    if not ok then return false, err end
    local finishArgs = { CAST_ID }
    for _, schema in ipairs(def.finishArgs) do finishArgs[#finishArgs + 1] = schema end
    ok, err = core.rpc.register(FINISH_PREFIX .. name, { args = finishArgs, rateLimit = limits.cast }, function(src, castId, ...)
        return casting.finish(src, name, castId, ...)
    end)
    if not ok then
        core.rpc.unregister(BEGIN_PREFIX .. name)
        return false, err
    end
    exposed[name] = true
    return true
end

--- Ferme les RPC d'un sort retiré et annule ses incantations en cours.
---@param name string
function casting.hide(name)
    if not exposed[name] then return end
    core.rpc.unregister(BEGIN_PREFIX .. name)
    core.rpc.unregister(FINISH_PREFIX .. name)
    exposed[name] = nil
    for src, cast in pairs(casts) do
        if cast.spell == name then casting.abort(src, 'unknown_spell', true) end
    end
end
