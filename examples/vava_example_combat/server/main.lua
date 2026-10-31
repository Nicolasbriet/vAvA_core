--[[
    vava_example_combat/server/main.lua
    Rôle : essai de la chaîne de dégâts côté serveur, offert seulement en mode développement et à qui y a droit :
      - garde       : `setup` refuse sans `set vava_env dev` (aucune commande, aucun modificateur) ; chaque commande
                      revérifie l'accès (droit vava_admin `staff` ou ACE `vava.dev`, config `access`) et un délai par
                      joueur (`cooldownMs`) ;
      - /frapper <n°> <points> [type] [partie] : coup par exports.vava_health:hit (source : le lanceur), résultat au
                      seul lanceur ;
      - modificateurs d'essai (registre vava_health:modifiers), réserves en mémoire par joueur :
                      vava_example_combat:esquive (étape esquive : fenêtre de /esquive, coups `melee` non `undodgeable`),
                      vava_example_combat:bouclier (étape bouclier : réserve de /bouclier ; `erreur` le fait lever une
                      erreur, essai d'isolement), vava_example_combat:resistance (étape resistance : /resistance <type>
                      <pour cent>, négatif = faiblesse) ; déclarés au setup si le registre existe, puis à chaque
                      démarrage de vava_health (hook core:module:ready) ; un modificateur ne cède jamais la main ;
      - /chaine     : modificateurs déclarés, dans l'ordre d'appel (export modifiers), et ses propres réserves ;
      - /frapper_arme <n°> [multiplicateur] [technique] (1.1.0, T-111) : coup de l'arme tenue en main par
                      exports.vava_combat:strike (appel isolé ; vava_combat facultatif), résultat et solidité au seul
                      lanceur ;
      - RPC vava_example_combat:access : accord demandé par le client avant /arme, /explosion, /tricher.
      Chaque coup et chaque protection posée est inscrit au journal du Registre (vava_admin:log), ou à la console du
      serveur sans lui. Rien n'est écrit en base. Mode développement relu faux pendant un coup : toutes les réserves
      sont vidées. Réponses au seul joueur par core.net.send (vava_example_combat:message, comptées).
    Dépendances : vAvA_core (API v1, core ≥ 0.10.0), config.lua, shared/guard.lua ; vava_health ≥ 1.3.0 (export hit,
                  modifiers, registre) ; facultatifs : vava_admin (droit et journal), vava_combat ≥ 1.0.0 (exports
                  strike et weapon, /frapper_arme)
]]

local RESOURCE = GetCurrentResourceName()
local cfg = VavaExampleCombat.config
local guard = VavaExampleCombat.guard

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

local pcall, pairs, ipairs, next, tostring, tonumber, type, error = pcall, pairs, ipairs, next, tostring, tonumber,
    type, error
local min, floor, tointeger = math.min, math.floor, math.tointeger
local concat, sort = table.concat, table.sort
local format = string.format
local GetConvar, GetResourceState, IsPlayerAceAllowed = GetConvar, GetResourceState, IsPlayerAceAllowed
local GetGameTimer, RegisterCommand = GetGameTimer, RegisterCommand

local ADMIN = 'vava_admin'
local HEALTH = 'vava_health'
local COMBAT = 'vava_combat'
local REGISTRY = 'vava_health:modifiers'
local COMMANDS = 'core:commands'
local RPC_ACCESS = RESOURCE .. ':access'
-- message au seul joueur, compté par core.net (le client l'affiche dans son chat)
local MESSAGE_EVENT = RESOURCE .. ':message'
local C = cfg.commands
local PERCENT = 100

-- Réserves en mémoire, par joueur : fin de l'esquive (GetGameTimer), bouclier { reserve, failing }, résistance
-- { kind, percent }. Retirées au départ du joueur.
local dodges, shields, resistances = {}, {}, {}
local lastCommand = {}

-- Accès et journal ------------------------------------------------------------------------------------------------

--- Mode développement relu à chaque appel, puis droit vava_admin (appel isolé) ou ACE.
---@param source integer
---@return boolean
local function allowed(source)
    local adminStarted = GetResourceState(ADMIN) == 'started'
    local adminCalled, adminCan = false, nil
    if adminStarted then
        adminCalled, adminCan = pcall(function() return exports[ADMIN]:can(source, cfg.access.permission) end)
    end
    return guard.allowed({
        devMode = guard.isDevMode(GetConvar(guard.CONVAR, guard.FALLBACK)),
        adminStarted = adminStarted,
        adminCalled = adminCalled,
        adminCan = adminCan,
        ace = IsPlayerAceAllowed(source, cfg.access.ace) == true,
    })
end

--- Journal du Registre (appel isolé) ; refusé (Registre absent, joueur qui n'a que l'ACE) : console du serveur.
---@param source integer
---@param label string
---@param details table  { clé = texte ou nombre }, 8 au plus
local function journal(source, label, details)
    local called, ok, err = false, nil, nil
    if GetResourceState(ADMIN) == 'started' then
        called, ok, err = pcall(function() return exports[ADMIN]:log(source, label, details) end)
    end
    if called and ok == true then return end
    local keys = {}
    for key in pairs(details) do keys[#keys + 1] = key end
    sort(keys)
    local parts = {}
    for i, key in ipairs(keys) do parts[i] = key .. ' : ' .. tostring(details[key]) end
    core.log.info('%s (joueur %d) — %s%s', label, source, concat(parts, ' ; '),
        called and (' (journal du Registre : ' .. tostring(err or ok) .. ')') or '')
end

--- Réponse au seul lanceur (chat), ou à la console.
---@param source integer
---@param message string
local function reply(source, message, ...)
    local text = format(message, ...)
    if source == 0 then
        print(('[%s] %s'):format(RESOURCE, text))
    else
        core.net.send(source, MESSAGE_EVENT, text)
    end
end

--- Accès, mode développement et délai entre deux commandes. Console : seulement si `console` est permis.
---@param source integer
---@param console boolean
---@return boolean
local function admitted(source, console)
    if source == 0 then
        if console and guard.isDevMode(GetConvar(guard.CONVAR, guard.FALLBACK)) then return true end
        reply(source, 'commande réservée à un joueur en jeu, en mode développement.')
        return false
    end
    if not allowed(source) then
        reply(source, 'refusé : outil d\'essai réservé (mode développement, droit staff ou ACE vava.dev).')
        return false
    end
    local now = GetGameTimer()
    if lastCommand[source] and now - lastCommand[source] < cfg.cooldownMs then
        reply(source, 'doucement…')
        return false
    end
    lastCommand[source] = now
    return true
end

---@param value number
---@return string
local function number(value)
    local rounded = floor(value * 10 + 0.5) / 10
    if rounded == floor(rounded) then return tostring(floor(rounded)) end
    return (tostring(rounded):gsub('%.', ','))
end

local function invokeHealth(fn, ...)
    local target = exports[HEALTH]
    return target[fn](target, ...)
end

--- Export de vava_health, isolé : vrai (appel abouti) puis ses valeurs.
---@param fn string
---@return boolean called
local function health(fn, ...)
    if GetResourceState(HEALTH) ~= 'started' then return false end
    return pcall(invokeHealth, fn, ...)
end

local function invokeCombat(fn, ...)
    local target = exports[COMBAT]
    return target[fn](target, ...)
end

--- Export de vava_combat, isolé : vrai (appel abouti) puis ses valeurs.
---@param fn string
---@return boolean called
local function combat(fn, ...)
    if GetResourceState(COMBAT) ~= 'started' then return false end
    return pcall(invokeCombat, fn, ...)
end

-- Modificateurs d'essai --------------------------------------------------------------------------------------------
-- Appelés par vava_health pendant un coup : ils lisent leurs réserves, rendent un résultat, ne cèdent jamais la main.

--- Mode développement relu : faux, toutes les réserves sont vidées (plus rien ne protège personne).
---@return boolean
local function stillDev()
    if guard.isDevMode(GetConvar(guard.CONVAR, guard.FALLBACK)) then return true end
    if next(dodges) or next(shields) or next(resistances) then
        dodges, shields, resistances = {}, {}, {}
        core.log.warn('mode développement absent : réserves d\'essai vidées')
    end
    return false
end

local function dodgeModifier(ctx)
    if not stillDev() then return nil end
    local untilAt = dodges[ctx.target]
    if untilAt and GetGameTimer() < untilAt and ctx.tags.melee and not ctx.tags.undodgeable then
        return { cancel = 'esquive' }
    end
    return nil
end

local function shieldModifier(ctx)
    if not stillDev() then return nil end
    local shield = shields[ctx.target]
    if not shield then return nil end
    if shield.failing then error('bouclier d\'essai en panne (voulu : essai d\'isolement)') end
    local taken = min(shield.reserve, ctx.amount)
    if taken <= 0 then return nil end
    shield.reserve = shield.reserve - taken
    if shield.reserve <= 0 then
        shields[ctx.target] = nil
        reply(ctx.target, 'bouclier brisé.')
    end
    return { absorbed = taken }
end

local function resistanceModifier(ctx)
    if not stillDev() then return nil end
    local resistance = resistances[ctx.target]
    if not resistance or resistance.kind ~= ctx.kind then return nil end
    if resistance.percent >= 0 then return { resisted = ctx.amount * resistance.percent / PERCENT } end
    return { added = ctx.amount * -resistance.percent / PERCENT }
end

local MODIFIERS = {
    [RESOURCE .. ':esquive'] = { stage = 'esquive', label = 'Esquive d\'essai', apply = dodgeModifier },
    [RESOURCE .. ':bouclier'] = { stage = 'bouclier', label = 'Bouclier d\'essai', apply = shieldModifier },
    [RESOURCE .. ':resistance'] = { stage = 'resistance', label = 'Résistance d\'essai', apply = resistanceModifier },
}

--- Déclare les trois modificateurs si le registre existe (au setup, et à chaque démarrage de vava_health).
local function declare()
    -- mode développement relu à chaque appel : `set vava_env prod` puis `restart vava_health` ne redéclare rien
    if not guard.isDevMode(GetConvar(guard.CONVAR, guard.FALLBACK)) then
        core.log.warn('mode développement absent : modificateurs d\'essai non déclarés')
        return
    end
    if not core.registry.exists(REGISTRY) then return end
    for key, def in pairs(MODIFIERS) do
        if not core.registry.has(REGISTRY, key) then
            local ok, err = core.registry.add(REGISTRY, key, def)
            if ok then
                core.log.info("modificateur '%s' déclaré", key)
            else
                core.log.error("modificateur '%s' refusé : %s", key, tostring(err))
            end
        end
    end
end

-- Commandes ------------------------------------------------------------------------------------------------------

--- Texte d'un résultat de hit.
---@param result table
---@return string
local function describe(result)
    if result.cancelled then
        return 'annulé : ' .. (cfg.reasons[result.cancelled] or result.cancelled)
    end
    return format('appliqué %s, bloqué %s, absorbé %s, résisté %s, ajouté %s — vie %d %%', number(result.applied),
        number(result.blocked), number(result.absorbed), number(result.resisted), number(result.added),
        floor(result.health * PERCENT + 0.5))
end

--- /frapper <n°> <points> [type] [partie]
local function hitCommand(source, args)
    if not admitted(source, true) then return end
    local target = tointeger(tonumber(args[1]))
    local points = tonumber(args[2])
    if not target or not points then
        reply(source, 'usage : /%s <n° du joueur> <points> [type] [partie]', C.hit)
        return
    end
    local packet = {
        amount = points, kind = args[3] or cfg.defaultKind, part = args[4],
        source = source ~= 0 and source or nil, tags = { melee = true, parryable = true },
    }
    local called, result, code = health('hit', target, packet)
    if not called then
        reply(source, 'vava_health ne répond pas.')
        return
    end
    if not result then
        reply(source, 'refusé : %s', tostring(code))
        return
    end
    local text = describe(result)
    reply(source, '%s', text)
    journal(source, cfg.journal.hit, { cible = target, points = points, type = packet.kind, resultat = text })
end

--- /frapper_arme <n°> [multiplicateur] [technique] : coup de l'arme tenue en main (vava_combat:strike). Le
--- multiplicateur et la technique sont revérifiés par vava_combat (invalid_options).
local function weaponHitCommand(source, args)
    if not admitted(source, false) then return end
    local target = tointeger(tonumber(args[1]))
    local multiplier = args[2] == nil and 1 or tonumber(args[2])
    if not target or not multiplier then
        reply(source, 'usage : /%s <n° du joueur> [multiplicateur 0,1 à 3] [technique]', C.weaponHit)
        return
    end
    local called, result, code = combat('strike', source, target,
        { damage = multiplier, technique = args[3], tags = { parryable = true } })
    if not called then
        reply(source, 'vava_combat ne répond pas.')
        return
    end
    if not result then
        reply(source, 'refusé : %s', cfg.reasons[code] or tostring(code))
        return
    end
    local weapon = type(result.weapon) == 'table' and result.weapon or {}
    local labelCalled, def = combat('weapon', weapon.item)
    local label = labelCalled and type(def) == 'table' and def.label or tostring(weapon.item)
    local function whole(value) return type(value) == 'number' and tointeger(value) or 0 end
    local text = format('%s — %s, solidité %d / %d%s', describe(result), label, whole(weapon.durability),
        whole(weapon.maxDurability), weapon.dull and ', émoussée' or '')
    reply(source, '%s', text)
    journal(source, cfg.journal.weaponHit, { cible = target, arme = tostring(weapon.item), multiplicateur = multiplier,
        resultat = text })
end

--- /esquive
local function dodgeCommand(source)
    if not admitted(source, false) then return end
    dodges[source] = GetGameTimer() + cfg.dodgeMs
    reply(source, 'esquive ouverte %s s.', number(cfg.dodgeMs / 1000))
    journal(source, cfg.journal.modifier, { protection = 'esquive', duree_ms = cfg.dodgeMs })
end

--- /bouclier <points> | erreur | non
local function shieldCommand(source, args)
    if not admitted(source, false) then return end
    local value = args[1]
    if value == 'non' then
        shields[source] = nil
        reply(source, 'bouclier retiré.')
        return
    end
    if value == 'erreur' then
        shields[source] = { reserve = 0, failing = true }
        reply(source, 'bouclier en panne : il lèvera une erreur à chaque coup (essai d\'isolement).')
        journal(source, cfg.journal.modifier, { protection = 'bouclier', reserve = 'erreur' })
        return
    end
    local points = tonumber(value)
    if not points or points <= 0 or points > 200 then
        reply(source, 'usage : /%s <points 1 à 200> | erreur | non', C.shield)
        return
    end
    shields[source] = { reserve = points, failing = false }
    reply(source, 'bouclier de %s points.', number(points))
    journal(source, cfg.journal.modifier, { protection = 'bouclier', reserve = points })
end

--- /resistance <type> <pour cent> | non
local function resistanceCommand(source, args)
    if not admitted(source, false) then return end
    if args[1] == 'non' then
        resistances[source] = nil
        reply(source, 'résistance retirée.')
        return
    end
    local kind, percent = args[1], tointeger(tonumber(args[2]))
    if type(kind) ~= 'string' or #kind > 16 or not kind:find('^[a-z]+$') or not percent or percent < -100
        or percent > 100 or percent == 0 then
        reply(source, 'usage : /%s <type> <pour cent, -100 à 100, négatif : faiblesse> | non', C.resistance)
        return
    end
    resistances[source] = { kind = kind, percent = percent }
    reply(source, percent > 0 and 'résistance au %s : %d %%.' or 'faiblesse au %s : %d %%.', kind,
        percent > 0 and percent or -percent)
    journal(source, cfg.journal.modifier, { protection = 'resistance', type = kind, pour_cent = percent })
end

--- /chaine
local function chainCommand(source)
    if not admitted(source, true) then return end
    local called, list = health('modifiers')
    if not called or type(list) ~= 'table' then
        reply(source, 'vava_health ne répond pas.')
        return
    end
    if #list == 0 then reply(source, 'aucun modificateur déclaré.') end
    for i, entry in ipairs(list) do
        local kinds = type(entry.kinds) == 'table' and (' [' .. concat(entry.kinds, ', ') .. ']') or ''
        reply(source, '%d. %s (%d) — %s — %s%s', i, entry.stage, entry.priority, entry.key, entry.label, kinds)
    end
    if source == 0 then return end
    local now = GetGameTimer()
    local dodge = dodges[source] and dodges[source] > now and (number((dodges[source] - now) / 1000) .. ' s') or 'fermée'
    local shield = shields[source]
    local shieldText = shield and (shield.failing and 'en panne' or number(shield.reserve)) or 'aucun'
    local resistance = resistances[source]
    local resistanceText = resistance and format('%s %d %%', resistance.kind, resistance.percent) or 'aucune'
    reply(source, 'vous : esquive %s · bouclier %s · résistance %s', dodge, shieldText, resistanceText)
end

local function declareCommands()
    if not core.registry.exists(COMMANDS) then return true end
    local base = { kind = 'command', scope = 'admin', permission = cfg.access.permission, ace = cfg.access.ace,
        module = RESOURCE, chapter = cfg.chapter }
    local defs = {
        [C.hit] = { label = 'Frapper un joueur (essai)', description = 'Coup passé par la chaîne de dégâts.', args = {
            { name = 'joueur', type = 'player' },
            { name = 'points', type = 'number', min = 0.5, max = 200 },
            { name = 'type', type = 'text', optional = true, hint = 'tranchant, contondant, percant, feu, eau…' },
            { name = 'partie', type = 'text', optional = true, hint = 'tete, torse, bras, jambes' },
        } },
        [C.dodge] = { label = 'Ouvrir une esquive (essai)' },
        [C.shield] = { label = 'Poser un bouclier (essai)', args = {
            { name = 'réserve', type = 'text', hint = 'points (1 à 200), erreur ou non' },
        } },
        [C.resistance] = { label = 'Poser une résistance (essai)', args = {
            { name = 'type', type = 'text', hint = 'feu, eau, tranchant… ou non' },
            { name = 'pour cent', type = 'integer', min = -100, max = 100, optional = true },
        } },
        [C.chain] = { label = 'Voir la chaîne de dégâts (essai)' },
        [C.weapon] = { label = 'Prendre une arme vanilla (essai)', args = {
            { name = 'arme', type = 'choice', choices = { 'pistolet', 'couteau', 'non' } },
        } },
        [C.explosion] = { label = 'Explosion vanilla devant soi (essai)' },
        [C.cheat] = { label = 'Remettre sa vie GTA au maximum (essai)' },
        [C.weaponHit] = { label = 'Frapper avec l\'arme en main (essai)',
            description = 'Coup de l\'arme tenue, par vava_combat : qualité, usure, chaîne de dégâts.', args = {
            { name = 'joueur', type = 'player' },
            { name = 'multiplicateur', type = 'number', min = 0.1, max = 3, optional = true },
            { name = 'technique', type = 'text', optional = true, hint = 'identifiant, par exemple taille_descendante' },
        } },
    }
    for name, def in pairs(defs) do
        for key, value in pairs(base) do def[key] = value end
        local ok, err = core.registry.add(COMMANDS, name, def)
        if not ok then return false, name .. ' : ' .. tostring(err) end
    end
    return true
end

local function onDropped(payload)
    local source = payload.source
    if not source then return end
    dodges[source], shields[source], resistances[source], lastCommand[source] = nil, nil, nil, nil
end

local function onModuleReady(payload)
    if payload.name == HEALTH then declare() end
end

local function setup()
    if not guard.isDevMode(GetConvar(guard.CONVAR, guard.FALLBACK)) then return false, guard.REFUSAL end
    -- T-132 : un config.lua d'avant 1.2.0 (gardé par une mise à jour) remplace la table de config_client.lua
    if cfg.clientFile ~= true then
        core.log.warn('config.lua garde la forme d\'avant 1.2.0 (il remplace la table de config_client.lua) : les '
            .. 'réglages lus par les joueurs sont dans config_client.lua ; reportez vos changements d\'après '
            .. 'config.lua.nouveau')
    end
    for _, hook in ipairs({ { 'core:module:ready', onModuleReady }, { 'core:player:dropped', onDropped } }) do
        local id, err = core.hooks.after(hook[1], hook[2])
        if not id then return false, hook[1] .. ' : ' .. tostring(err) end
    end
    local ok, err = declareCommands()
    if not ok then return false, 'commandes : ' .. tostring(err) end
    ok, err = core.rpc.register(RPC_ACCESS, { args = {}, rateLimit = cfg.accessRateLimit }, function(source)
        if not allowed(source) then return false, 'not_allowed' end
        return true
    end)
    if not ok then return false, err end
    RegisterCommand(C.hit, hitCommand, false)
    RegisterCommand(C.dodge, dodgeCommand, false)
    RegisterCommand(C.shield, shieldCommand, false)
    RegisterCommand(C.resistance, resistanceCommand, false)
    RegisterCommand(C.chain, chainCommand, false)
    RegisterCommand(C.weaponHit, weaponHitCommand, false)
    declare()
    core.log.warn('mode développement : /%s, /%s, /%s, /%s, /%s, /%s et les modificateurs d\'essai ouverts au droit'
        .. ' « %s » et à l\'ACE « %s » — à ne jamais laisser sur un serveur ouvert au public', C.hit, C.dodge, C.shield,
        C.resistance, C.chain, C.weaponHit, cfg.access.permission, cfg.access.ace)
    return true
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(RESOURCE, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
