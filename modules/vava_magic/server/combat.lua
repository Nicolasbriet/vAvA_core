--[[
    vava_magic/server/combat.lua
    Rôle : blessures infligées par les sorts, décidées par le serveur et portées par la chaîne de dégâts commune de
           vava_health (T-116) : chaque coup part par `exports.vava_health:hit` (bridge) avec le lanceur pour source,
           son personnage, le type de l'élément du sort, le sort et des étiquettes selon sa nature (impact, zone, zone
           qui dure, brûlure : règles pures de shared/harm.lua) ; il respecte donc l'interrupteur des combats entre
           joueurs de la chaîne, son débit par paire et le lanceur à terre, et passe par les modificateurs (zones de
           paix, boucliers et résistances de la magie, parades du combat…). Un coup déjà lancé (projectile, éclats,
           présage de la Secousse) porte l'instant de son lancement (`launchedAt`, vava_health ≥ 1.4.0) : il blesse
           encore si le lanceur tombe à terre avant l'impact. Avant la chaîne, la magie garde ses propres filtres :
           `combat.pvp`, cible en jeu, hors zone protégée, lanceur qui joue toujours le même personnage (sinon le coup
           est refusé : il échapperait à `chain.pvp` et au journal). La victime réagit (son élément, ou le champ
           `reaction` du sort : geste, effet d'écran), et l'appelant pose brûlure, états et XP, seulement si le coup a
           retiré de la vie (`applied > 0`) ; une brûlure qui dure ne fait pas réagir à chaque morsure. Un sort
           offensif sans dégâts (recul, état) demande d'abord si la cible peut être touchée (`combat.affects` : jamais
           un joueur à terre, rien quand `combat.pvp` ou `chain.pvp` de vava_health est coupé).
           Sans vava_health (arrêté ou en erreur), aucun sort ne blesse personne : une ligne de console par minute, un
           message au lanceur au plus une fois par minute. Le journal des coups est celui de vava_health
           (`vava_health_hits`) : `vava_magic_damage_log` n'est plus écrit, ses lignes anciennes sont encore retirées au
           démarrage puis chaque jour (`combat.log.retentionDays`), par lots bornés.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/world.lua, server/spells.lua
]]

local type, tostring, tonumber, floor = type, tostring, tonumber, math.floor
local time = os.time
local SetTimeout, CreateThread, Wait, TriggerClientEvent, GetGameTimer =
    SetTimeout, CreateThread, Wait, TriggerClientEvent, GetGameTimer

local bridge = VavaMagic.bridge
local world = VavaMagic.world
local geometry = VavaMagic.geometry
local harm = VavaMagic.harm
local cfg = VavaMagic.config.combat
local notify = VavaMagic.config.texts.notify
local EVENTS = VavaMagic.EVENTS
-- purge des lignes anciennes du journal d'avant la chaîne : par lots bornés (index sur `at`), une courte pause entre
-- deux lots, une fois par jour
local PURGE = 'DELETE FROM `vava_magic_damage_log` WHERE `at` < ? LIMIT ?'
local PURGE_BATCH = 5000
local PURGE_PAUSE_MS = 1000
local SECONDS_PER_DAY = 86400
local DAY_MS = SECONDS_PER_DAY * 1000
-- au plus une ligne de console par code et par minute ; au plus un message par lanceur et par minute
local NOTICE_MS = 60000
local UNAVAILABLE = 'health_unavailable'

local combat = {}
VavaMagic.combat = combat

combat.KIND = { IMPACT = harm.NATURE.IMPACT, ZONE = harm.NATURE.ZONE, AURA = harm.NATURE.AURA, BURN = harm.NATURE.BURN }

---@type table<string, integer>  code refusé par la chaîne → dernière ligne de console
local logged = {}
---@type table<integer, integer>  lanceur → dernier message « vos sorts ne blessent personne »
local told = {}

--- Point dans une zone protégée ?
---@param point table
---@return boolean
function combat.protected(point)
    return geometry.protectedZone(point) ~= nil
end

--- Un sort offensif peut-il toucher ce joueur ? (dégâts entre joueurs activés, personnage en jeu, hors zone
--- protégée, pas à terre : un corps au sol n'est ni mouillé, ni poussé, ni renversé) Avec le lanceur (autre que la
--- cible), mêmes refus qu'un coup de la chaîne : lanceur qui joue désormais un autre personnage que
--- `casterCharacter`, ou posté dans une zone de paix. Renvoie la position de la cible lue côté serveur, ou nil.
---@param target integer
---@param caster? integer
---@param casterCharacter? integer  personnage du lanceur au moment du sort (zone, projectile)
---@return table|nil
function combat.affects(target, caster, casterCharacter)
    if not cfg.pvp or not bridge.ChainPvp() or not bridge.GetCharacterId(target) then return nil end
    if type(caster) == 'number' and caster > 0 and caster ~= target then
        local current = bridge.GetCharacterId(caster)
        if current and type(casterCharacter) == 'number' and casterCharacter > 0 and current ~= casterCharacter then
            return nil
        end
        local from = world.position(caster)
        if from and combat.protected(from) then return nil end
    end
    local position = world.position(target)
    if not position or combat.protected(position) then return nil end
    -- en dernier : un appel à vava_health, seulement pour qui serait touché
    if bridge.IsDowned(target) then return nil end
    return position
end

--- La victime d'un sort réagit : geste bref et effet d'écran selon le sort (son élément, ou son champ `reaction`).
---@param target integer
---@param spell string
function combat.react(target, spell)
    local def = VavaMagic.spells.get(spell)
    if def then TriggerClientEvent(EVENTS.HIT, target, def.config.reaction or def.config.element) end
end

--- Ligne de console au plus une fois par minute et par clé.
---@param key string
---@return boolean
local function due(key)
    local now = GetGameTimer()
    if logged[key] and now - logged[key] < NOTICE_MS then return false end
    logged[key] = now
    return true
end

--- vava_health absent : le sort ne blesse personne ; console, et le lanceur en jeu le sait (une fois par minute).
---@param caster integer
local function unharmed(caster)
    if due(UNAVAILABLE) then
        VavaMagic.log.warn('vava_health ne répond pas (arrêté, en erreur, ou sans chaîne de dégâts : 1.3.0 au '
            .. 'moins) : les sorts ne blessent personne (aucun repli chez le client)')
    end
    if type(caster) ~= 'number' or caster <= 0 or not bridge.GetCharacterId(caster) then return end
    local now = GetGameTimer()
    if told[caster] and now - told[caster] < NOTICE_MS then return end
    told[caster] = now
    bridge.Notify(caster, notify.noHarm, 'warning')
end

--- Élément d'un coup : celui donné (projectile qui emporte le feu, zone née d'une combinaison), sinon celui du sort.
---@param spell string
---@param element? string
---@return string|nil
local function elementOf(spell, element)
    if element then return element end
    local def = VavaMagic.spells.get(spell)
    return def and def.config.element or nil
end

--- Blesse un joueur au nom d'un sort, par la chaîne de dégâts de vava_health. Renvoie vrai si le coup a retiré de la
--- vie (`applied > 0`) : l'appelant ne pose brûlure, états et bonus d'XP qu'alors.
---@param caster integer   source du lanceur (0 : aucun)
---@param target integer   source de la cible
---@param spell string     sort (ou combinaison) à l'origine
---@param points number    points de vie retirés avant modificateurs (sur `combat.healthPoints`)
---@param kind string      nature du coup : combat.KIND
---@param casterCharacter? integer  personnage du lanceur, quand il a pu partir depuis (zone, brûlure)
---@param element? string  élément du coup s'il n'est pas celui du sort (roche ardente : feu ; vapeur : eau)
---@param launchedAt? integer  instant du lancement (GetGameTimer) d'un coup déjà lancé : projectile, éclats, présage
---@return boolean
function combat.damage(caster, target, spell, points, kind, casterCharacter, element, launchedAt)
    if not cfg.pvp then return false end
    local amount = harm.amount(points, cfg.healthPoints, bridge.ChainHealthPoints())
    if not amount then return false end
    local position = world.position(target)
    if not position or combat.protected(position) then return false end
    if not bridge.GetCharacterId(target) then return false end
    local current = type(caster) == 'number' and caster > 0 and bridge.GetCharacterId(caster) or nil
    local source, sourceCharacter = harm.source(caster, casterCharacter, current)
    -- lanceur qui joue désormais un autre personnage : son mur, sa vapeur ou sa secousse ne blessent plus personne
    -- (un coup sans source échapperait à chain.pvp, au débit par paire et au journal)
    if not source and type(caster) == 'number' and caster > 0 then return false end
    local result, code = bridge.Hit(target, harm.packet({
        amount = amount, kind = harm.kindOf(elementOf(spell, element), cfg.kinds), nature = kind,
        source = source, sourceCharacter = sourceCharacter, spell = spell,
        -- coup déjà lancé : seulement si la chaîne connaît l'étiquette (vava_health ≥ 1.4.0, sinon invalid_tags)
        launchedAt = launchedAt and bridge.ChainKnowsLaunched() and launchedAt or nil,
    }))
    if not result then
        if code == UNAVAILABLE then
            unharmed(caster)
        elseif due(tostring(code)) then
            VavaMagic.log.warn("coup du sort '%s' refusé par vava_health : %s", tostring(spell), tostring(code))
        end
        return false
    end
    if result.cancelled or type(result.applied) ~= 'number' or result.applied <= 0 then return false end
    if kind ~= combat.KIND.BURN then combat.react(target, spell) end
    return true
end

--- Retire du journal d'avant la chaîne les lignes plus anciennes que `log.retentionDays` jours, par lots bornés.
--- Bloque le thread appelant (base de données). Renvoie le nombre de lignes retirées.
---@return integer
function combat.purge()
    local days = cfg.log.retentionDays
    if not days or days <= 0 then return 0 end
    local cutoff = time() - floor(days * SECONDS_PER_DAY)
    local removed = 0
    while true do
        local affected, err = bridge.db.update(PURGE, { cutoff, PURGE_BATCH })
        if err then
            VavaMagic.log.warn('journal des dégâts non purgé : %s', tostring(err))
            break
        end
        affected = tonumber(affected) or 0
        removed = removed + affected
        -- lot incomplet : plus rien d'aussi ancien
        if affected < PURGE_BATCH then break end
        Wait(PURGE_PAUSE_MS)
    end
    if removed > 0 then VavaMagic.log.info('journal des dégâts : %d ligne(s) de plus de %d jours retirée(s)', removed, days) end
    return removed
end

--- Purge du journal d'avant la chaîne au démarrage, puis une fois par jour. Appelé pendant le setup du module.
function combat.start()
    local function daily()
        combat.purge()
        SetTimeout(DAY_MS, daily)
    end
    -- dans son propre thread : le setup n'attend pas la base
    CreateThread(daily)
end

-- départ d'un joueur : son dernier message est oublié
VavaMagic.spells.onLeave(function(src)
    told[src] = nil
end)
