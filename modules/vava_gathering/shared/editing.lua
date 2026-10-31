--[[
    vava_gathering/shared/editing.lua
    Rôle : logique pure de l'atelier « Récolte » de l'Atelier du Conseil (T-102), servie au seul serveur :
             - déclaration (sans ses fonctions) : types `zone` (cercle) et `node` (« point », orienté, enfant d'une zone),
               formulaires, règles de placement, modèle du prochain point, titre donné tout seul, fantôme par ressource ;
             - conversions graine ⇄ data ⇄ définition (aller-retour exact) : zone { id, label, kind, x, y, z, radius,
               cost, regenPerHour, scarHours } ⇄ data { nom, genre, fatigue, repos, cicatrice } + lieu { x, y, z, r } ;
               nœud { id, label, zone, resource, x, y, z, heading, charges, regenMs } ⇄ data { nom, ressource, charges,
               repousse } + lieu { x, y, z, h } + parent ;
             - règles du module : `validate` d'une zone (nom unique, type connu, lieu exigé à l'essai et à la
               publication, rayon, chevauchement d'une autre zone) et d'un point (ressource connue, poisson ⇔ eau, lieu
               exigé, dedans sa zone si elle n'est pas dans le lot), `validateLot` (la zone après le lot : nombre de
               points, chacun dedans le cercle neuf, écart, cercle englobant), `placeCheck` (chevauchement, nombre de
               zones, nombre de points d'une zone) ;
             - liste de la carte (zones arrondies au mètre) et son empreinte (stable quel que soit l'ordre).
           `view` : ce que le serveur sait en ce moment (zones publiées, leurs nœuds, ressources, genres d'eau, réglages
           `editor` de config.lua). Testée : tests/spec/gathering_editing_spec.lua.
    Dépendances : shared/constants.lua
]]

local type, ipairs, pairs, tostring = type, ipairs, pairs, tostring
local floor, ceil, sqrt, max = math.floor, math.ceil, math.sqrt, math.max
local format, gsub, byte = string.format, string.gsub, string.byte
local concat, sort = table.concat, table.sort
local tointeger = math.tointeger

local editing = {}
VavaGathering.editing = editing

local HOUR, DAY = 3600, 86400
-- erreurs d'un lot gardées au plus (l'Atelier en montre 16)
local MAX_ERRORS = 8

-- Déclaration ----------------------------------------------------------------------------------------------------------

--- Formulaires et types de l'atelier, tirés de la config (une fois au démarrage).
---@param cfg table  VavaGathering.config
---@return table declaration  sans fonctions ni `right` effectif (le module les ajoute)
function editing.declaration(cfg)
    local e = cfg.editor
    local T = e.texts
    local d = e.defaults
    local models = {}
    for id, resource in pairs(cfg.resources) do
        local look = cfg.looks and cfg.looks[id] or {}
        models[id] = { model = resource.prop.model, label = look.label, provisional = look.provisional == true or nil }
    end
    local zone = {
        id = 'zone', noun = 'zone', nounPlural = 'zones', article = 'la', newLabel = 'Nouvelle zone', layout = 'side',
        creatable = true, steps = { 'La zone', 'Les points', 'Publier' }, placement = 'circle',
        rules = { radius = { min = e.zoneRadius.min, max = e.zoneRadius.max, default = e.zoneRadius.default } },
        form = {
            titleField = 'nom',
            groups = {
                { id = 'zone', label = 'La zone' },
                { id = 'terre', label = 'Réglages de la zone', folded = true,
                    help = 'Type, rayon, vitesse à laquelle la terre se repose, durée d\'une cicatrice.' },
            },
            fields = {
                { id = 'nom', widget = 'text', charset = 'name', min = 3, max = 40, group = 'zone',
                    label = 'Nom de la zone',
                    help = 'Le nom que verront les récoltants sur la carte et dans le panneau des zones.' },
                { id = 'genre', widget = 'segmented', options = e.zoneKinds, default = e.zoneKinds[1].value,
                    group = 'terre', label = 'Type de lieu',
                    help = 'Donne l\'icône de la carte ; dans une zone d\'eau, on pêche et la terre devient l\'eau.' },
                { id = 'fatigue', widget = 'slider', min = 0.5, max = 10, step = 0.5, decimals = 1, unit = 'pts',
                    default = d.cost, group = 'terre', label = 'Fatigue par récolte',
                    help = 'Vitalité (sur 100) que perd la zone à chaque récolte réussie : plus elle est haute, plus la '
                        .. 'terre s\'épuise vite.' },
                { id = 'repos', widget = 'slider', min = 0.5, max = 24, step = 0.5, decimals = 1, unit = 'pts/h',
                    default = d.regenPerHour, group = 'terre', label = 'Repos de la terre',
                    help = 'Vitalité que la terre regagne chaque heure quand on la laisse en paix.' },
                { id = 'cicatrice', widget = 'duration', min = HOUR, max = 30 * DAY, units = { 'h', 'j' },
                    default = d.scarHours * HOUR, group = 'terre', label = 'Durée d\'une cicatrice',
                    help = 'Une zone épuisée jusqu\'à zéro se remet bien plus lentement pendant ce temps.' },
            },
        },
    }
    local node = {
        id = 'node', noun = 'point', nounPlural = 'points', article = 'le', newLabel = 'Nouveau point', layout = 'side',
        creatable = false, parent = 'zone', placement = 'oriented',
        rules = { inside = { slack = e.nodeSlack }, spacing = e.spacing },
        template = { 'ressource', 'charges', 'repousse' }, autoTitle = 'ressource', hintField = 'charges',
        hintFormat = '%s récoltes', ghost = { field = 'ressource', models = models },
        form = {
            titleField = 'nom',
            fields = {
                { id = 'nom', widget = 'text', charset = 'name', min = 1, max = 40, label = 'Nom du point',
                    help = 'Pour le retrouver dans la liste ; donné tout seul à la pose (« Chêne 4 »).' },
                { id = 'ressource', widget = 'select', source = 'ressources', label = 'Ressource',
                    help = 'Ce que l\'on récolte ici : elle fixe l\'outil, l\'apparence et le savoir-faire.' },
                { id = 'charges', widget = 'slider', integer = true, min = 1, max = 20, step = 1, default = d.charges,
                    label = 'Récoltes avant repos', help = 'Combien de récoltes ce point donne avant de devoir repousser.' },
                { id = 'repousse', widget = 'duration', min = 60, max = DAY, units = { 'min', 'h' },
                    default = d.regenMs // 1000, label = 'Repousse d\'une récolte',
                    help = 'Temps pour qu\'une récolte revienne ; la saison l\'accélère ou la ralentit.' },
            },
        },
    }
    return {
        family = 'monde', label = T.label, description = T.description, icon = 'recolte', right = e.right, format = 1,
        trialPlay = true,
        texts = { trial = T.trial, publish = T.publish, publishHint = T.publishHint, trialLine = T.trialLine },
        kinds = { zone, node },
    }
end

--- Choix de la source `ressources` (« Ressource » d'un point) : { { value, label } }, triés par libellé.
---@param resources table<string, { label: string }>
---@return { value: string, label: string }[]
function editing.resourceOptions(resources)
    local out = {}
    for id, resource in pairs(resources) do out[#out + 1] = { value = id, label = resource.label or id } end
    sort(out, function(a, b)
        if a.label ~= b.label then return a.label < b.label end
        return a.value < b.value
    end)
    return out
end

-- Conversions ----------------------------------------------------------------------------------------------------------

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

--- Identifiant d'une ressource (définition du catalogue ou identifiant).
local function resourceId(resource)
    return type(resource) == 'table' and resource.id or resource
end

--- Zone → data et lieu (lecture par l'Atelier : graine et rapprochement).
---@param zone table
---@return table data
---@return table place
function editing.zoneData(zone)
    return {
        nom = zone.label, genre = zone.kind, fatigue = zone.cost, repos = zone.regenPerHour,
        cicatrice = tointeger(floor(zone.scarHours * HOUR + 0.5)) or floor(zone.scarHours * HOUR + 0.5),
    }, { x = zone.x, y = zone.y, z = zone.z, r = zone.radius }
end

--- Nœud → data, lieu et parent.
---@param node table
---@return table data
---@return table place
---@return string parent
function editing.nodeData(node)
    local zoneId = type(node.zone) == 'table' and node.zone.id or node.zone
    return {
        nom = node.label or node.id, ressource = resourceId(node.resource), charges = node.charges,
        repousse = tointeger(node.regenMs // 1000) or node.regenMs // 1000,
    }, { x = node.x, y = node.y, z = node.z, h = node.heading or 0.0 }, zoneId
end

--- Définition rendue par l'Atelier (`apply`) → zone ; nil et une raison si elle n'a pas de lieu ou des valeurs fausses.
---@param def table  data + id, place
---@return table|nil
---@return string|nil err
function editing.zoneOf(def)
    local place = def.place
    if type(place) ~= 'table' or not finite(place.x) or not finite(place.y) or not finite(place.z)
        or not finite(place.r) then
        return nil, 'no_place'
    end
    if type(def.nom) ~= 'string' or type(def.genre) ~= 'string' or not finite(def.fatigue) or not finite(def.repos)
        or not finite(def.cicatrice) then
        return nil, 'bad_data'
    end
    return {
        id = def.id, label = def.nom, kind = def.genre, x = place.x, y = place.y, z = place.z, radius = place.r,
        cost = def.fatigue, regenPerHour = def.repos, scarHours = def.cicatrice / HOUR,
    }
end

--- Définition rendue par l'Atelier → nœud { id, label, zone, resource, x, y, z, heading, charges, regenMs } ; nil et une
--- raison sans lieu, sans parent ou à valeurs fausses.
---@param def table
---@return table|nil
---@return string|nil err
function editing.nodeOf(def)
    local place = def.place
    if type(place) ~= 'table' or not finite(place.x) or not finite(place.y) or not finite(place.z) then
        return nil, 'no_place'
    end
    if type(def.parent) ~= 'string' then return nil, 'no_zone' end
    local charges = tointeger(def.charges)
    if type(def.ressource) ~= 'string' or not charges or charges < 1 or not finite(def.repousse) then
        return nil, 'bad_data'
    end
    return {
        id = def.id, label = def.nom, zone = def.parent, resource = def.ressource, x = place.x, y = place.y,
        z = place.z, heading = finite(place.h) and place.h or 0.0, charges = charges,
        regenMs = tointeger(def.repousse * 1000) or floor(def.repousse * 1000),
    }
end

-- Règles -------------------------------------------------------------------------------------------------------------

-- lettres accentuées ramenées à leur base (comparaison des noms sans accents ni casse)
local FOLD = {}
do
    local groups = {
        a = 'àáâãäåÀÁÂÃÄÅ', c = 'çÇ', e = 'èéêëÈÉÊË', i = 'ìíîïÌÍÎÏ', n = 'ñÑ', o = 'òóôõöÒÓÔÕÖ', u = 'ùúûüÙÚÛÜ',
        y = 'ýÿÝŸ', oe = 'œŒ', ae = 'æÆ',
    }
    for base, chars in pairs(groups) do
        for _, code in utf8.codes(chars) do FOLD[utf8.char(code)] = base end
    end
    for code = 65, 90 do FOLD[string.char(code)] = string.char(code + 32) end
end

--- Clé d'un nom : sans accents ni casse, espaces de bord retirés et réduits (« Forêt de  Brume » = « foret de brume »).
---@param name any
---@return string
function editing.nameKey(name)
    if type(name) ~= 'string' then return '' end
    local value = gsub(name, '[\xC2-\xF4][\x80-\xBF]*', FOLD)
    value = gsub(value, '[A-Z]', FOLD)
    value = gsub(gsub(value, '[ \t]+', ' '), '^ ', '')
    return (gsub(value, ' $', ''))
end

local function ground(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return sqrt(dx * dx + dy * dy)
end

--- Retraits de zones d'un lot (références de `ctx.bundle` ou lot de `validateLot`) : identifiant → vrai.
local function removedZones(lot)
    local out = {}
    for _, ref in ipairs(type(lot) == 'table' and lot or {}) do
        if ref.kind == 'zone' and ref.removal then out[ref.id] = true end
    end
    return out
end

--- Chevauchement le plus profond d'un cercle avec les autres zones publiées : zone, mètres (0 sans chevauchement).
---@param circle { x: number, y: number, r: number }
---@param selfId string|nil
---@param zones table[]
---@param skip table<string, boolean>
---@return table|nil zone
---@return number depth
function editing.overlap(circle, selfId, zones, skip)
    local worst, depth = nil, 0
    for _, zone in ipairs(zones) do
        if zone.id ~= selfId and not (skip and skip[zone.id]) then
            local d = (circle.r + zone.radius) - ground(circle.x, circle.y, zone.x, zone.y)
            if d > depth then worst, depth = zone, d end
        end
    end
    return worst, depth
end

local function push(errors, item)
    if #errors < MAX_ERRORS then errors[#errors + 1] = item end
end

local function verdict(errors)
    if #errors == 0 then return true end
    return false, errors
end

---@class vAvA.GatheringEditingView
---@field zones table[]                         zones publiées (catalogue)
---@field zone fun(id: string): table|nil
---@field nodesOf fun(zoneId: string): table[]  nœuds publiés d'une zone
---@field resources table<string, { label: string, fishing: boolean }>
---@field water table<string, boolean>          genres de zone d'eau
---@field kinds table<string, boolean>          types de lieu permis
---@field settings table                        config.editor

--- `validate` d'une zone (data du formulaire, `ctx` de l'Atelier). true, ou false et les erreurs.
---@param data table
---@param ctx table  { id?, action, place?, bundle? }
---@param view vAvA.GatheringEditingView
function editing.validateZone(data, ctx, view)
    ctx = ctx or {}
    if ctx.action == 'remove' then return true end
    local s = view.settings
    local T = s.texts
    local errors = {}
    local key = editing.nameKey(data.nom)
    for _, zone in ipairs(view.zones) do
        if zone.id ~= ctx.id and editing.nameKey(zone.label) == key then
            push(errors, { field = 'nom', text = T.name })
            break
        end
    end
    if not view.kinds[data.genre] then push(errors, { field = 'genre', text = T.kind }) end
    local place = ctx.place
    if type(place) ~= 'table' then
        if ctx.action == 'trial' or ctx.action == 'publish' then push(errors, { text = T.noPlaceZone }) end
        return verdict(errors)
    end
    local bounds = s.zoneRadius
    if not finite(place.r) or place.r < bounds.min or place.r > bounds.max then
        push(errors, { text = format(T.radius, floor(bounds.min), floor(bounds.max)) })
    end
    local other, depth = editing.overlap(place, ctx.id, view.zones, removedZones(ctx.bundle))
    if other and depth > s.overlapTolerance then push(errors, { text = format(T.overlap, other.label, ceil(depth)) }) end
    return verdict(errors)
end

--- La zone (nouvelle data et lieu d'un lot, ou publiée) est-elle dans le lot ?
local function zoneInLot(lot, zoneId)
    for _, ref in ipairs(type(lot) == 'table' and lot or {}) do
        if ref.kind == 'zone' and ref.id == zoneId and not ref.removal then return true end
    end
    return false
end

--- Ressource ⇔ type de lieu : un poisson dans l'eau, rien d'autre dans l'eau. Texte du refus, ou nil.
local function waterRule(resource, kind, view)
    local water = view.water[kind] == true
    local T = view.settings.texts
    if resource.fishing and not water then return T.waterOnly end
    if water and not resource.fishing then return T.fishOnly end
    return nil
end

--- `validate` d'un point. Sa zone n'est jugée ici que si elle n'est pas dans le lot (`ctx.bundle`) : sinon
--- `validateLot` juge avec le cercle neuf.
---@param data table
---@param ctx table  { id?, action, place?, parent?, bundle? }
---@param view vAvA.GatheringEditingView
function editing.validateNode(data, ctx, view)
    ctx = ctx or {}
    if ctx.action == 'remove' then return true end
    local T = view.settings.texts
    local errors = {}
    local resource = view.resources[data.ressource]
    if not resource then push(errors, { field = 'ressource', text = T.resource }) end
    local place = ctx.place
    local judged = ctx.action == 'trial' or ctx.action == 'publish'
    if type(place) ~= 'table' and judged then push(errors, { text = T.noPlaceNode }) end
    if ctx.parent and not zoneInLot(ctx.bundle, ctx.parent) then
        local zone = view.zone(ctx.parent)
        if zone then
            local why = resource and waterRule(resource, zone.kind, view)
            if why then push(errors, { field = 'ressource', text = why }) end
            if type(place) == 'table'
                and ground(place.x, place.y, zone.x, zone.y) > zone.radius + view.settings.nodeSlack + 1e-9 then
                push(errors, { text = format(T.outside, zone.label) })
            end
        elseif judged then
            push(errors, { text = T.noZone })
        end
    end
    return verdict(errors)
end

--- `validateLot` : chaque zone touchée par le lot, telle qu'elle serait après lui (cercle neuf, points publiés moins
--- les retraits, points du lot) : nombre de points, chacun dedans le cercle (+ nodeSlack), poisson ⇔ eau, écart entre
--- tous, cercle englobant du core (500 m). true, ou false et les erreurs.
---@param lot table[]  { { kind, id, data, parent?, place?, removal } }
---@param view vAvA.GatheringEditingView
function editing.validateLot(lot, view)
    local s = view.settings
    local T = s.texts
    local errors = {}
    local zonesOfLot, touched, order = {}, {}, {}
    local function touch(id)
        if id and not touched[id] then
            touched[id] = true
            order[#order + 1] = id
        end
    end
    for _, item in ipairs(lot) do
        if item.kind == 'zone' then
            zonesOfLot[item.id] = item
            touch(item.id)
        elseif item.kind == 'node' then
            touch(item.parent)
        end
    end
    for _, zoneId in ipairs(order) do
        local item = zonesOfLot[zoneId]
        local zone
        if item then
            if not item.removal and type(item.place) == 'table' then
                zone = { id = zoneId, label = item.data.nom, kind = item.data.genre, x = item.place.x,
                    y = item.place.y, radius = item.place.r }
            end
        else
            zone = view.zone(zoneId)
        end
        if zone then
            local final, list = {}, {}
            for _, node in ipairs(view.nodesOf(zoneId)) do
                final[node.id] = { id = node.id, title = node.label or node.id, resource = resourceId(node.resource),
                    x = node.x, y = node.y }
            end
            for _, entry in ipairs(lot) do
                if entry.kind == 'node' and entry.parent == zoneId then
                    if entry.removal then
                        final[entry.id] = nil
                    elseif type(entry.place) == 'table' then
                        final[entry.id] = { id = entry.id, title = entry.data.nom or entry.id,
                            resource = entry.data.ressource, x = entry.place.x, y = entry.place.y }
                    end
                end
            end
            for _, node in pairs(final) do list[#list + 1] = node end
            sort(list, function(a, b) return a.id < b.id end)
            if #list > s.maxNodesPerZone then push(errors, { text = format(T.tooMany, #list, s.maxNodesPerZone) }) end
            local widest = zone.radius
            for i, node in ipairs(list) do
                local d = ground(node.x, node.y, zone.x, zone.y)
                if d > widest then widest = d end
                if d > zone.radius + s.nodeSlack + 1e-9 then push(errors, { text = format(T.outside, zone.label) }) end
                local resource = view.resources[node.resource]
                local why = resource and waterRule(resource, zone.kind, view)
                if why then push(errors, { text = why }) end
                for j = i + 1, #list do
                    local other = list[j]
                    local gap = ground(node.x, node.y, other.x, other.y)
                    if gap < s.spacing - 1e-9 then
                        push(errors, { text = format(T.tooClose, other.title,
                            (gsub(format('%.1f', gap), '%.', ','))) })
                    end
                end
            end
            if widest > VavaGathering.ZONE_MAX_RADIUS then
                push(errors, { text = format(T.tooWide, zone.label, ceil(widest), floor(VavaGathering.ZONE_MAX_RADIUS)) })
            end
        end
    end
    return verdict(errors)
end

--- `placeCheck` : ce que les règles déclarées ne savent pas dire. Zone : chevauchement d'une autre zone publiée,
--- nombre de zones ; point : nombre de points de sa zone après ce placement (`ctx.siblings`). true, ou false et le
--- texte du refus.
---@param kind string
---@param place table
---@param ctx table  { id, siblings }
---@param view vAvA.GatheringEditingView
function editing.placeCheck(kind, place, ctx, view)
    local s = view.settings
    local T = s.texts
    if kind == 'zone' then
        local other, depth = editing.overlap(place, ctx.id ~= '' and ctx.id or nil, view.zones, nil)
        if other and depth > s.overlapTolerance then return false, format(T.overlap, other.label, ceil(depth)) end
        if (ctx.id == nil or ctx.id == '') and #view.zones >= s.maxZones then
            return false, format(T.tooManyZones, #view.zones)
        end
        return true
    end
    if kind == 'node' and type(ctx.siblings) == 'number' and ctx.siblings > s.maxNodesPerZone then
        return false, format(T.tooMany, ctx.siblings, s.maxNodesPerZone)
    end
    return true
end

--- « Pour comparer » d'une zone : la première autre zone publiée du même type de lieu. { title, text }, ou nil.
---@param data table
---@param view vAvA.GatheringEditingView
function editing.compare(data, view)
    local T = view.settings.texts
    local key = editing.nameKey(data.nom)
    for _, zone in ipairs(view.zones) do
        if zone.kind == data.genre and editing.nameKey(zone.label) ~= key then
            local function number(value) return (gsub(format('%.1f', value), '%.0$', ''):gsub('%.', ',')) end
            return { title = T.compareTitle, text = format(T.compare, zone.label, number(zone.cost),
                number(zone.regenPerHour)) }
        end
    end
    return nil
end

-- Carte ----------------------------------------------------------------------------------------------------------------

local function metre(value)
    return floor(value + 0.5)
end

--- Liste de la carte : { { i, l, k, x, y, r } } triée par identifiant, coordonnées et rayon au mètre.
---@param zones table[]
---@return table[]
function editing.mapList(zones)
    local out = {}
    for _, zone in ipairs(zones) do
        out[#out + 1] = { i = zone.id, l = zone.label, k = zone.kind, x = metre(zone.x), y = metre(zone.y),
            r = max(1, metre(zone.radius)) }
    end
    sort(out, function(a, b) return a.i < b.i end)
    return out
end

--- Empreinte (FNV-1a 64 bits, 16 hexadécimaux) d'une liste de la carte : la même pour les mêmes zones, quel que soit
--- l'ordre où elles arrivent.
---@param list table[]  liste de editing.mapList (triée)
---@return string
function editing.mapVersion(list)
    local lines = {}
    for i, zone in ipairs(list) do
        lines[i] = concat({ zone.i, zone.l, zone.k, tostring(zone.x), tostring(zone.y), tostring(zone.r) }, '|')
    end
    sort(lines)
    local text = concat(lines, '\n')
    local hash = -3750763034362895579   -- 0xcbf29ce484222325
    for i = 1, #text do
        hash = (hash ~ byte(text, i)) * 1099511628211
    end
    return format('%016x', hash)
end
