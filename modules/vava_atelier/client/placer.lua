--[[
    vava_atelier/client/placer.lua
    Rôle : l'outil de placement côté membre (§ 8 de la spec T-102). États : repos → visée → repos. Entrée par le retour
           de page `placeStart` (refus sur place : pas de séance, page mise de côté, personnage non apparu, en véhicule
           ou à cheval, porte) ; à l'entrée, le jeu reprend clavier et souris (la page reste affichée), la bannière de
           vava_pause est bloquée (appel isolé), la page reçoit `placing` et la barre des touches du mode.
           LA boucle par image de l'outil ne vit que pendant la visée : contrôles neutralisés, visée par un lancer de
           rayon asynchrone (un seul en vol), candidat (shared/aim.lua), règles (shared/placerules.lua, les mêmes que
           le serveur) au plus toutes les `refreshMs` ou dès que le candidat bouge, éléments proches triés toutes les
           `sortMs`, dessin (client/drawing.lua, fantômes : client/ghosts.lua), commandes (clic, molette, Maj, clic
           droit, Ctrl+Z, Entrée, Échap). Un seul envoi au serveur à la fois ; un refus s'affiche 3 s et part à la page
           (`placeRefused`). Rien n'est envoyé à chaque image, ni à la page ni au serveur : le serveur ne reçoit que
           des intentions (`place`, `discard`), qu'il revérifie toutes.
           Garde aussi la dernière réponse `children` (lieux de la fiche, de son parent, des enfants) pour dessiner,
           juger et poser les fantômes des enfants pas encore publiés.
    Dépendances : shared/constants.lua, config_client.lua, shared/placerules.lua, shared/aim.lua, client/core.lua,
                  client/nui.lua, client/session.lua, client/drawing.lua, client/ghosts.lua
]]

local type, ipairs, tostring, tonumber, pcall = type, ipairs, tostring, tonumber, pcall
local find, format = string.find, string.format
local tointeger, huge = math.tointeger, math.huge
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local PlayerPedId, GetEntityCoords, IsPedInAnyVehicle, IsPedOnMount = PlayerPedId, GetEntityCoords, IsPedInAnyVehicle,
    IsPedOnMount
local GetGameplayCamCoord, GetGameplayCamRot = GetGameplayCamCoord, GetGameplayCamRot
local StartShapeTestLosProbe, GetShapeTestResult = StartShapeTestLosProbe, GetShapeTestResult
local DisableControlAction, IsDisabledControlJustPressed, IsDisabledControlPressed, IsControlJustPressed =
    DisableControlAction, IsDisabledControlJustPressed, IsDisabledControlPressed, IsControlJustPressed
local GetResourceState = GetResourceState

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local placement = cfg.placement
local placeTexts = placement.texts
local colors = placement.colors
local controls = placement.controls
local RPC, HOOKS = VavaAtelier.RPC, VavaAtelier.HOOKS
local nui, session, drawing, ghosts = VavaAtelier.nui, VavaAtelier.session, VavaAtelier.drawing, VavaAtelier.ghosts
local placerules, aim = VavaAtelier.placerules, VavaAtelier.aim

local PAUSE = 'vava_pause'
local BLOCK_ID = 'placement'
local FLASH_MS = 3000
local SHAPES = { point = true, oriented = true, circle = true, polygon = true }
local TONES = { live = true, draft = true, new = true, removal = true, other = true }
local MODES = { self = true, children = true }
local MAX_TITLE, MAX_HINT, MAX_LABEL = 64, 60, 40
local MAX_XY, MAX_Z, MAX_R = 50000, 5000, 500
local LIMITS = { reach = placement.reach, polygonFactor = placement.polygonFactor }

local placer = {}
VavaAtelier.placer = placer

-- visée en cours (nil au repos)
local state = nil
-- dernière réponse `children` gardée : { editor, kind, id, self = { place? }, parent?, rows }
local kept = nil
-- valeurs du modèle (« Prochain point à poser ») et fantôme du candidat, gardés entre deux visées
local template, templateGhost, templateLabel = {}, nil, nil

-- Valeurs reçues (page, serveur) ---------------------------------------------------------------------------------------

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

local function isId(value, pattern, max)
    return type(value) == 'string' and #value <= max and find(value, pattern) ~= nil
end

local function str(value, max)
    if type(value) ~= 'string' then return nil end
    if #value > max then return nil end
    return value
end

local function within(value, limit)
    return finite(value) and value >= -limit and value <= limit
end

--- Lieu reçu, borné (nombres finis, 32 sommets au plus), ou nil.
local function cleanPlace(value)
    if type(value) ~= 'table' then return nil end
    if type(value.points) == 'table' then
        if not within(value.z, MAX_Z) or #value.points > VavaAtelier.MAX_VERTICES then return nil end
        local points = {}
        for i, point in ipairs(value.points) do
            if type(point) ~= 'table' or not within(point.x, MAX_XY) or not within(point.y, MAX_XY) then return nil end
            points[i] = { x = point.x, y = point.y }
        end
        return { z = value.z, points = points }
    end
    if not within(value.x, MAX_XY) or not within(value.y, MAX_XY) or not within(value.z, MAX_Z) then return nil end
    local out = { x = value.x, y = value.y, z = value.z }
    if value.h ~= nil then out.h = finite(value.h) and value.h or 0.0 end
    if value.r ~= nil then
        if not finite(value.r) or value.r <= 0 or value.r > MAX_R then return nil end
        out.r = value.r
    end
    return out
end

--- Modèle d'un fantôme reçu : { model, label?, provisional? }, ou nil.
local function cleanLook(value)
    if type(value) ~= 'table' or not isId(value.model, VavaAtelier.MODEL_PATTERN, VavaAtelier.MAX_MODEL) then
        return nil
    end
    return { model = value.model, label = str(value.label, MAX_LABEL), provisional = value.provisional == true }
end

--- Ligne `children` reçue, bornée, ou nil.
local function cleanRow(row)
    if type(row) ~= 'table' or not isId(row.kind, VavaAtelier.KEY_PATTERN, VavaAtelier.MAX_KEY)
        or not isId(row.id, VavaAtelier.ENTRY_PATTERN, VavaAtelier.MAX_ENTRY) or not TONES[row.tone] then
        return nil
    end
    local where = cleanPlace(row.place)
    if not where then return nil end
    local center = placerules.center(where)
    return {
        kind = row.kind, id = row.id, title = str(row.title, MAX_TITLE) or row.id, hint = str(row.hint, MAX_HINT),
        tone = row.tone, place = where, look = cleanLook(row.look), rev = tointeger(tonumber(row.rev)) or 0,
        x = center.x, y = center.y, z = center.z,
    }
end

--- Valeurs d'une fiche reçues de la page : les trois cartes seulement, telles quelles (le serveur revérifie tout).
local function cards(values)
    local out = {}
    if type(values) ~= 'table' then return out end
    for _, card in ipairs({ 'n', 's', 'b' }) do
        if type(values[card]) == 'table' then out[card] = values[card] end
    end
    return out
end

-- Réponse `children` gardée ----------------------------------------------------------------------------------------

local function pedCoords()
    local coords = GetEntityCoords(PlayerPedId())
    return { x = coords.x, y = coords.y, z = coords.z }
end

--- Fantômes voulus près d'un point : les lignes pas encore publiées qui ont un modèle (hors élément choisi).
local function ghostList(origin, skip)
    local candidates = {}
    for _, row in ipairs(kept and kept.rows or {}) do
        if row.look and (row.tone == 'new' or row.tone == 'draft') and row.id ~= skip then
            candidates[#candidates + 1] = row
        end
    end
    local list = {}
    local settings = placement.ghosts
    for i, row in ipairs(aim.nearest(candidates, origin.x, origin.y, origin.z, settings.max, settings.distance)) do
        list[i] = { key = row.kind .. '|' .. row.id, model = row.look.model, x = row.place.x, y = row.place.y,
            z = row.place.z, h = row.place.h or 0.0 }
    end
    return list
end

--- Garde une réponse `children` reçue par la page (relais) et pose les fantômes proches.
---@param editorId string
---@param kindId string
---@param id string
---@param data any
function placer.absorb(editorId, kindId, id, data)
    if type(data) ~= 'table' then return end
    local rows = {}
    for _, raw in ipairs(type(data.rows) == 'table' and data.rows or {}) do
        if #rows >= VavaAtelier.MAX_ROWS then break end
        local row = cleanRow(raw)
        if row then rows[#rows + 1] = row end
    end
    local parent = nil
    if type(data.parent) == 'table' and isId(data.parent.id, VavaAtelier.ENTRY_PATTERN, VavaAtelier.MAX_ENTRY) then
        parent = { id = data.parent.id, title = str(data.parent.title, MAX_TITLE) or data.parent.id,
            place = cleanPlace(data.parent.place) }
    end
    kept = { editor = editorId, kind = kindId, id = id, rows = rows, parent = parent,
        self = { place = type(data.self) == 'table' and cleanPlace(data.self.place) or nil } }
    -- distance du bloc « Lieu » (« Posée à 32 m de vous »), calculée ici : la page la lit dans `self.distance`
    if type(data.self) == 'table' then data.self.distance = placer.distance(kept.self.place) end
    if not state then ghosts.sync(ghostList(pedCoords(), nil)) end
end

--- La page quitte la fiche (accueil, liste, autre atelier, fermeture) : réponse oubliée, fantômes retirés.
function placer.leave()
    if state then placer.stop() end
    kept = nil
    ghosts.clear()
end

--- Mètres (entiers) entre le personnage et le centre d'un lieu, ou nil (bloc « Lieu » du volet).
---@param where any
---@return integer|nil
function placer.distance(where)
    local center = placerules.center(where)
    if not center then return nil end
    return math.floor(placerules.distance(center, pedCoords()) + 0.5)
end

-- Visée --------------------------------------------------------------------------------------------------------------

local function now()
    return GetGameTimer()
end

---@param current table
---@param line string
---@param tone string  valid | refused
local function flash(current, line, tone)
    current.flash = { text = line, color = tone == 'valid' and colors.valid or colors.refused, until_ = now() + FLASH_MS }
end

--- Barre des touches du mode courant, à la page.
local function sendKeys(current)
    nui.send('placing', {
        on = true, mode = current.mode, shape = current.shape,
        keys = aim.keys(current.mode, current.shape, current.picked ~= nil, placement.keybar),
    })
end

--- Blocage de la bannière du royaume (vava_pause), par appel isolé : sans elle, rien.
local function pauseBlock(on)
    if GetResourceState(PAUSE) ~= 'started' then return end
    local called, err = pcall(function() return exports[PAUSE]:block(BLOCK_ID, on, 'other') end)
    if not called then core.log.warn('%s.block en erreur : %s', PAUSE, tostring(err)) end
end

--- Lieu du parent dessiné et jugé (`inside`) : en mode « points », la fiche elle-même ; sinon le parent de la fiche.
local function parentArea(current)
    if not kept then return nil end
    local where, title
    if current.mode == 'children' then
        where, title = kept.self and kept.self.place, current.title
    elseif kept.parent then
        where, title = kept.parent.place, kept.parent.title
    end
    if not where then return nil end
    return { title = title, shape = where.points and 'polygon' or 'circle', place = where }
end

--- Frères pour la règle d'écart : lignes du type posé (le serveur relit les siens).
local function siblings(current)
    local list = {}
    for _, row in ipairs(kept and kept.rows or {}) do
        if row.kind == current.kind then
            list[#list + 1] = { id = row.id, title = row.title, x = row.x, y = row.y, removal = row.tone == 'removal' }
        end
    end
    return list
end

--- Titre du candidat (« Chêne 4 ») : titre donné tout seul d'un enfant nouveau, sinon celui de la fiche.
local function candidateTitle(current)
    if current.mode == 'children' then
        if current.picked then return current.picked.title end
        if templateLabel then
            local titles = {}
            for _, row in ipairs(kept and kept.rows or {}) do
                if row.kind == current.kind then titles[#titles + 1] = row.title end
            end
            return placerules.autoTitle(templateLabel, titles)
        end
        return templateGhost and templateGhost.label or current.title
    end
    return current.title
end

--- Règles réévaluées pour le candidat (les mêmes que le serveur ; le serveur décide).
local function evaluate(current)
    local candidate = current.candidate
    current.lastCandidate = candidate
    if not candidate then
        current.verdict = { code = 'ground', args = {} }
        return
    end
    local selfId = current.mode == 'self' and current.id or (current.picked and current.picked.id) or nil
    current.verdict = placerules.check(current.rules, current.shape, candidate, {
        origin = pedCoords(), reach = LIMITS.reach, polygonFactor = LIMITS.polygonFactor,
        open = current.shape == 'polygon' and not current.closing, parent = parentArea(current),
        siblings = siblings(current), self = selfId,
    })
end

--- Lancer de rayon depuis la caméra : résultat de la trame d'avant, puis un nouveau lancer (un seul en vol).
local function probe(current)
    if current.probe then
        local status, hit, coords = GetShapeTestResult(current.probe)
        if status == 2 then
            current.probe = nil
            if hit == true or hit == 1 then
                current.hit = { x = coords.x, y = coords.y, z = coords.z }
            else
                current.hit = nil
            end
        elseif status == 0 then
            current.probe = nil
        end
    end
    if not current.probe then
        local from = GetGameplayCamCoord()
        local rotation = GetGameplayCamRot(2)
        local dx, dy, dz = aim.direction(rotation.x, rotation.z)
        local reach = placement.aim.distance
        current.probe = StartShapeTestLosProbe(from.x, from.y, from.z, from.x + dx * reach, from.y + dy * reach,
            from.z + dz * reach, placement.aim.flags, PlayerPedId(), 7)
    end
end

--- Éléments proches triés (étiquettes et fantômes), toutes les `sortMs`.
local function sortNear(current)
    local origin = pedCoords()
    local labels = placement.labels
    local skip = current.picked and current.picked.id or nil
    local list = {}
    for _, row in ipairs(kept and kept.rows or {}) do
        if row.id ~= skip then list[#list + 1] = row end
    end
    current.near = aim.nearest(list, origin.x, origin.y, origin.z, labels.max, labels.distance)
    ghosts.sync(ghostList(origin, skip))
end

--- Dessin d'un lieu de zone (anneau, ou tracé fermé) dans une teinte.
local function drawArea(where, color)
    if where.points then
        local points = where.points
        for i = 1, #points do
            local a, b = points[i], points[i % #points + 1]
            drawing.segment(a.x, a.y, b.x, b.y, where.z, color)
            drawing.post(a.x, a.y, where.z, color)
        end
    elseif where.r then
        drawing.ring(where.x, where.y, where.z, where.r, color)
    end
end

--- Dessin d'une image : zone parente, candidat, étiquettes proches, message du moment.
local function draw(current, at)
    local area = parentArea(current)
    if area then drawArea(area.place, colors.area) end
    local candidate, verdict = current.candidate, current.verdict
    local color = verdict and colors.refused or colors.valid
    local title = candidateTitle(current)
    local line = verdict and format(placeTexts.refused, title, placerules.text(verdict, placeTexts))
        or format(placeTexts.valid, title)
    if candidate then
        if current.shape == 'circle' then
            drawing.ring(candidate.x, candidate.y, candidate.z, candidate.r, color)
            local areaLine = format(placeTexts.area, title, placerules.number(candidate.r))
            drawing.label(candidate.x, candidate.y, candidate.z, verdict and line or areaLine, color)
        elseif current.shape == 'polygon' then
            local points = candidate.points
            for i = 1, #points - 1 do
                drawing.segment(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y, candidate.z, color)
            end
            for _, point in ipairs(points) do drawing.post(point.x, point.y, candidate.z, color) end
            local last = points[#points]
            local traceLine = format(placeTexts.trace, #current.vertices)
            drawing.label(last.x, last.y, candidate.z, verdict and line or traceLine, color)
        else
            local model = current.mode == 'children' and not current.picked and templateGhost and templateGhost.model
                or (current.picked and current.picked.look and current.picked.look.model)
                or (current.mode == 'self' and current.ghost and current.ghost.model) or nil
            if not ghosts.candidate(model, candidate.x, candidate.y, candidate.z, candidate.h or 0.0) then
                drawing.chevron(candidate.x, candidate.y, candidate.z, candidate.h, color)
            end
            drawing.label(candidate.x, candidate.y, candidate.z, line, color)
        end
    else
        ghosts.candidate(nil)
        drawing.screen(placerules.text({ code = 'ground', args = {} }, placeTexts), colors.refused)
    end
    for _, row in ipairs(current.near or {}) do
        local rowColor, suffix = colors.child, nil
        if row.tone == 'new' then rowColor, suffix = colors.valid, placeTexts.new
        elseif row.tone == 'removal' then rowColor, suffix = colors.refused, placeTexts.removal end
        local label = row.title
        if row.hint then label = label .. ' · ' .. row.hint end
        if suffix then label = label .. ' (' .. suffix .. ')' end
        if (row.tone == 'new' or row.tone == 'draft') and not ghosts.has(row.kind .. '|' .. row.id) and not row.place.r
            and not row.place.points then
            drawing.chevron(row.x, row.y, row.z, row.place.h, rowColor)
        end
        drawing.label(row.x, row.y, row.z, label, rowColor)
    end
    if current.picked then
        drawing.label(current.picked.x, current.picked.y, current.picked.z,
            format(placeTexts.picked, current.picked.title), colors.picked)
    end
    local message = current.flash
    if message then
        if at > message.until_ then current.flash = nil else drawing.screen(message.text, message.color) end
    end
end

-- Envois ---------------------------------------------------------------------------------------------------------------

--- Ligne gardée d'une fiche (mise à jour, ou ajoutée), depuis la ligne rendue par le serveur.
local function keepRow(raw)
    local row = cleanRow(raw)
    if not row or not kept then return nil end
    for i, known in ipairs(kept.rows) do
        if known.kind == row.kind and known.id == row.id then
            kept.rows[i] = row
            return row
        end
    end
    if #kept.rows < VavaAtelier.MAX_ROWS then kept.rows[#kept.rows + 1] = row end
    return row
end

local function forgetRow(kindId, id)
    if not kept then return end
    for i = #kept.rows, 1, -1 do
        local row = kept.rows[i]
        if row.kind == kindId and row.id == id then table.remove(kept.rows, i) end
    end
end

local function rowOf(kindId, id)
    for _, row in ipairs(kept and kept.rows or {}) do
        if row.kind == kindId and row.id == id then return row end
    end
    return nil
end

--- Refus du serveur (code ou texte) : 3 s sous le candidat, et à la page.
local function refused(current, why)
    local line = type(why) == 'string' and why or session.refusal(why)
    if current then flash(current, line, 'refused') end
    nui.send('placeRefused', { text = line })
end

--- Réponse d'un RPC : true, réponse ; ou false, texte du refus.
local function outcome(ok, success, answer)
    if not ok then return false, session.refusal(success) end
    if not success then return false, session.refusal(answer) end
    if type(answer) ~= 'table' then return false, session.refusal('unavailable') end
    if answer.done == false then
        local first = type(answer.errors) == 'table' and answer.errors[1]
        return false, type(first) == 'table' and type(first.text) == 'string' and first.text
            or session.refusal('unavailable')
    end
    return true, answer
end

--- Pose envoyée au serveur (un envoi à la fois) ; la visée continue en mode « points », se ferme sinon.
local function send(current, where)
    if current.busy then
        flash(current, placeTexts.busy, 'refused')
        return
    end
    current.busy = true
    local picked = current.picked
    local entryKind, entryId, rev, parent, values = current.kind, current.id, current.rev, '', {}
    if current.mode == 'children' then
        parent = current.parentId
        if picked then
            entryId, rev = picked.id, picked.rev
        else
            entryId, rev, values = '', 0, cards(template)
        end
    end
    local before = picked and picked.place or (current.mode == 'self' and current.place) or nil
    CreateThread(function()
        local good, answer = outcome(core.rpc.call(RPC.PLACE, current.editor, entryKind, entryId, rev, where, parent,
            values))
        current.busy = false
        if state ~= current then return end
        if not good then
            refused(current, answer)
            return
        end
        local row = keepRow(answer.row)
        if answer.parent and type(answer.parent.rev) == 'number' then current.parentRev = answer.parent.rev end
        if current.mode == 'children' then
            if entryId == '' then
                aim.push(current.stack, { kind = 'create', entryKind = entryKind, id = answer.id })
            else
                aim.push(current.stack, { kind = 'move', entryKind = entryKind, id = answer.id, before = before })
                current.picked = nil
                sendKeys(current)
            end
        else
            current.rev = tointeger(tonumber(answer.rev)) or current.rev
            current.place = cleanPlace(answer.place) or current.place
            aim.push(current.stack, { kind = 'move', entryKind = entryKind, id = answer.id, before = before })
        end
        nui.send('placed', { kind = entryKind, id = answer.id, rev = answer.rev, title = answer.title,
            state = answer.state, footer = answer.footer, place = answer.place,
            distance = placer.distance(cleanPlace(answer.place)), row = row and {
                kind = row.kind, id = row.id, title = row.title, hint = row.hint, tone = row.tone, place = row.place,
                look = row.look, rev = row.rev,
            } or nil, parent = answer.parent })
        sortNear(current)
        -- la fiche seule (zone, point déplacé depuis sa fiche) : retour au volet après une pose réussie
        if current.mode == 'self' then placer.stop() end
    end)
end

--- Annule le dernier geste de la visée (Ctrl+Z).
local function undo(current)
    local gesture = aim.pop(current.stack)
    if not gesture then
        flash(current, placeTexts.undoNone, 'refused')
        return
    end
    local plan = aim.undoPlan(gesture)
    if not plan then return end
    if plan.action == 'vertex' then
        if gesture.index and gesture.before then
            current.vertices[gesture.index] = gesture.before
        else
            table.remove(current.vertices)
        end
        current.lastCandidate = nil
        return
    end
    if current.busy then
        aim.push(current.stack, gesture)
        flash(current, placeTexts.busy, 'refused')
        return
    end
    current.busy = true
    CreateThread(function()
        local row = rowOf(plan.entryKind, plan.id)
        local rev = current.mode == 'self' and current.rev or (row and row.rev or 0)
        local good, answer
        if plan.action == 'discard' then
            good, answer = outcome(core.rpc.call(RPC.DISCARD, current.editor, plan.entryKind, plan.id, rev))
        else
            local parent = current.mode == 'children' and current.parentId or ''
            good, answer = outcome(core.rpc.call(RPC.PLACE, current.editor, plan.entryKind, plan.id, rev, plan.place,
                parent, {}))
        end
        current.busy = false
        if state ~= current then return end
        if not good then
            aim.forget(current.stack, plan.id)
            flash(current, placeTexts.undoFailed, 'refused')
            return
        end
        if plan.action == 'discard' then
            forgetRow(plan.entryKind, plan.id)
            nui.send('undone', { kind = plan.entryKind, id = plan.id, gone = answer.gone == true or nil })
        else
            keepRow(answer.row)
            if current.mode == 'self' then
                current.rev = tointeger(tonumber(answer.rev)) or current.rev
                current.place = cleanPlace(answer.place) or current.place
            end
            nui.send('undone', { kind = plan.entryKind, id = plan.id, rev = answer.rev,
                place = cleanPlace(answer.place) })
        end
        sortNear(current)
    end)
end

-- Commandes ------------------------------------------------------------------------------------------------------------

--- Clic : poser ici (si vert), ou ajouter un sommet (tracé), ou déplacer le sommet choisi.
local function click(current)
    local candidate = current.candidate
    if current.shape == 'polygon' then
        if not current.hit then return end
        if current.pickedVertex then
            local index = current.pickedVertex
            aim.push(current.stack, { kind = 'vertex', index = index, before = current.vertices[index] })
            current.vertices[index] = current.hit
            current.pickedVertex = nil
        elseif current.verdict == nil and #current.vertices < VavaAtelier.MAX_VERTICES then
            current.vertices[#current.vertices + 1] = current.hit
            aim.push(current.stack, { kind = 'vertex' })
        end
        current.lastCandidate = nil
        return
    end
    if not candidate or current.verdict ~= nil then return end
    send(current, candidate)
end

--- Molette : tourner (orienté) ou changer le rayon (cercle), pas fin avec Maj.
local function wheel(current, direction, fine)
    if current.shape == 'oriented' then
        current.heading = aim.turn(current.heading, direction, fine, placement.steps)
    elseif current.shape == 'circle' then
        local bounds = type(current.rules.radius) == 'table' and current.rules.radius or { min = 1, max = MAX_R }
        current.radius = aim.resize(current.radius, direction, fine, placement.steps, bounds)
    end
end

--- Clic droit : choisir l'élément le plus proche du point visé (point de la fiche, ou sommet du tracé), ou le lâcher.
local function pick(current)
    if current.picked or current.pickedVertex then
        current.picked, current.pickedVertex = nil, nil
        sendKeys(current)
        return
    end
    local hit = current.hit
    if not hit then return end
    if current.shape == 'polygon' then
        local items = {}
        for i, vertex in ipairs(current.vertices) do items[i] = { x = vertex.x, y = vertex.y, index = i } end
        local found = aim.pick(items, hit.x, hit.y, placement.pickRadius)
        current.pickedVertex = found and found.index or nil
        return
    end
    if current.mode ~= 'children' then return end
    local items = {}
    for _, row in ipairs(kept and kept.rows or {}) do
        if row.kind == current.kind and row.tone ~= 'removal' and row.tone ~= 'other' then items[#items + 1] = row end
    end
    local found = aim.pick(items, hit.x, hit.y, placement.pickRadius)
    if not found then return end
    current.picked = found
    if found.place.h then current.heading = found.place.h end
    sendKeys(current)
end

--- Échap : quitter la visée ; tracé commencé : un second appui sous `quitConfirmMs`.
local function quit(current, at)
    if current.shape == 'polygon' and #current.vertices > 0
        and not (current.quitAt and at - current.quitAt <= placement.quitConfirmMs) then
        current.quitAt = at
        flash(current, placeTexts.quitTrace, 'refused')
        return
    end
    placer.stop()
end

--- Entrée : fermer le tracé et l'envoyer (règles d'un tracé fermé).
local function closeTrace(current)
    if current.shape ~= 'polygon' then return end
    local vertices = current.vertices
    local points = {}
    for i, vertex in ipairs(vertices) do points[i] = { x = vertex.x, y = vertex.y } end
    local where = { z = vertices[1] and vertices[1].z or 0.0, points = points }
    local found = placerules.check(current.rules, 'polygon', where, {
        origin = pedCoords(), reach = LIMITS.reach, polygonFactor = LIMITS.polygonFactor, parent = parentArea(current),
    })
    if #vertices < (type(current.rules.vertices) == 'table' and current.rules.vertices.min or 3) then
        found = found or { code = 'vertices', args = { current.rules.vertices and current.rules.vertices.min or 3,
            current.rules.vertices and current.rules.vertices.max or VavaAtelier.MAX_VERTICES } }
    end
    if found then
        flash(current, placerules.text(found, placeTexts), 'refused')
        return
    end
    send(current, where)
end

--- Contrôles lus à chaque image de la visée.
local function readControls(current, at)
    if IsDisabledControlJustPressed(0, controls.quit) then return quit(current, at) end
    if IsControlJustPressed(0, controls.close) or IsDisabledControlJustPressed(0, controls.close) then
        closeTrace(current)
    end
    local fine = IsDisabledControlPressed(0, controls.fine)
    if IsDisabledControlJustPressed(0, controls.wheelUp) then
        wheel(current, 1, fine)
    elseif IsDisabledControlJustPressed(0, controls.wheelDown) then
        wheel(current, -1, fine)
    end
    if IsDisabledControlJustPressed(0, controls.pick) then pick(current) end
    if IsDisabledControlJustPressed(0, controls.place) then click(current) end
end

--- LA boucle par image de l'outil : seulement pendant la visée, chez le seul membre qui place.
local function loop(current)
    local nextEval, nextSort = 0, 0
    local disabled = placement.disabled
    while state == current do
        local at = now()
        for _, control in ipairs(disabled) do DisableControlAction(0, control, true) end
        probe(current)
        current.candidate = aim.candidate(current.shape, current.hit, current)
        if at >= nextEval or aim.moved(current.lastCandidate, current.candidate) then
            evaluate(current)
            nextEval = at + placement.refreshMs
        end
        if at >= nextSort then
            sortNear(current)
            nextSort = at + placement.sortMs
        end
        draw(current, at)
        readControls(current, at)
        Wait(0) -- audit: ok (état actif qui dessine et lit les contrôles à chaque image : la visée, finie par Échap, la fermeture, le déchargement ou l'arrêt)
    end
end

-- Entrée et sortie ---------------------------------------------------------------------------------------------------

---@return boolean
function placer.isAiming()
    return state ~= nil
end

--- Refus de démarrer : { ok = false, error, text }.
local function refuse(code, line)
    return { ok = false, error = code, text = line or session.refusal(code) }
end

--- Demande `children` au serveur si la réponse gardée n'est pas celle de la fiche (relais absent ou autre fiche).
local function ensureKept(editorId, kindId, id)
    if kept and kept.editor == editorId and kept.kind == kindId and kept.id == id then return true end
    local ok, success, answer = core.rpc.call(RPC.CHILDREN, editorId, kindId, id)
    if not ok or not success then return false, ok and answer or success end
    placer.absorb(editorId, kindId, id, answer)
    return true
end

--- Retour de page `placeStart { editor, kind, id, rev, mode, shape, rules, ghost?, template?, parent?, parentKind?,
--- parentRev?, label?, title }` : la visée commence. Chaque valeur est bornée ici ; le serveur revérifie tout.
---@param d table
---@return table
function placer.start(d)
    if state then placer.stop() end
    if not session.isOpen() then return refuse('not_open') end
    if session.isSuspended() then return refuse('not_open') end
    if not core.characters.current() then return refuse('no_character') end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsPedOnMount(ped) then return refuse('vehicle', placeTexts.vehicle) end
    local mode = MODES[d.mode] and d.mode or 'self'
    local shape = d.shape
    if not SHAPES[shape] then return refuse('not_placeable') end
    local editorId, kindId = d.editor, d.kind
    if not isId(editorId, VavaAtelier.EDITOR_PATTERN, VavaAtelier.MAX_EDITOR)
        or not isId(kindId, VavaAtelier.KEY_PATTERN, VavaAtelier.MAX_KEY) then
        return refuse('bad_request')
    end
    -- mode « points » : `kind` est le type des enfants, `parent` (ou `id`) la fiche parent ouverte
    local id = d.id
    local parentId = mode == 'children' and (d.parent or d.id) or nil
    if mode == 'children' then
        if not isId(parentId, VavaAtelier.ENTRY_PATTERN, VavaAtelier.MAX_ENTRY) then return refuse('bad_request') end
        -- lieux de la fiche parent : ceux que la page a demandés (`children`), sinon redemandés si elle nomme son type
        if not (kept and kept.editor == editorId and kept.id == parentId) then
            local parentKind = isId(d.parentKind, VavaAtelier.KEY_PATTERN, VavaAtelier.MAX_KEY) and d.parentKind or nil
            if not parentKind then return refuse('stale') end
            local fetched, code = ensureKept(editorId, parentKind, parentId)
            if not fetched then return refuse(code) end
        end
    elseif not isId(id, VavaAtelier.ENTRY_PATTERN, VavaAtelier.MAX_ENTRY) then
        return refuse('bad_request')
    else
        local fetched, code = ensureKept(editorId, kindId, id)
        if not fetched then return refuse(code) end
    end
    -- règles du type : bornes connues seulement (le serveur juge avec les siennes)
    local rules = {}
    if type(d.rules) == 'table' then
        local r = d.rules
        if type(r.radius) == 'table' and finite(r.radius.min) and finite(r.radius.max) and finite(r.radius.default) then
            rules.radius = { min = r.radius.min, max = r.radius.max, default = r.radius.default }
        end
        if type(r.vertices) == 'table' and finite(r.vertices.min) and finite(r.vertices.max) then
            rules.vertices = { min = r.vertices.min, max = r.vertices.max }
        end
        if type(r.inside) == 'table' then rules.inside = { slack = finite(r.inside.slack) and r.inside.slack or 0 } end
        if finite(r.spacing) then rules.spacing = r.spacing end
    end
    if mode == 'children' then
        if type(d.template) == 'table' then template = d.template end
        if d.ghost ~= nil then templateGhost = cleanLook(d.ghost) end
        if d.label ~= nil then templateLabel = str(d.label, MAX_LABEL) end
    end
    local selfPlace = mode == 'self' and kept and kept.self and kept.self.place or nil
    local current = {
        editor = editorId, kind = kindId, id = mode == 'self' and id or nil, parentId = parentId,
        rev = tointeger(tonumber(d.rev)) or 0, parentRev = tointeger(tonumber(d.parentRev)) or 0, mode = mode,
        shape = shape, rules = rules, title = str(d.title, MAX_TITLE) or '',
        ghost = mode == 'self' and cleanLook(d.ghost) or nil, place = selfPlace,
        heading = selfPlace and selfPlace.h or 0.0,
        radius = selfPlace and selfPlace.r or (rules.radius and rules.radius.default) or placement.steps.radius,
        vertices = {}, stack = aim.stack(placement.undoMax), busy = false, near = {},
    }
    state = current
    nui.setFocus(false)
    pauseBlock(true)
    -- la ligne du bandeau pendant la visée (« Mode édition : les cercles… ») est un texte de la page : aucun `mode`
    sendKeys(current)
    core.hooks.runAfter(HOOKS.STATE, { open = true, placing = true, suspended = false })
    CreateThread(function() loop(current) end)
    return { ok = true }
end

--- Fin de la visée (Échap, page, pose d'une fiche seule, fermeture, déchargement, essai joué) : boucle arrêtée, fantôme
--- du candidat retiré, blocage levé, focus rendu à la page.
---@param silent? boolean  la page est fermée ou cachée : ni focus ni message
function placer.stop(silent)
    local current = state
    if not current then return end
    state = nil
    ghosts.candidate(nil)
    pauseBlock(false)
    if not silent and session.isOpen() and not session.isSuspended() then
        nui.send('placing', { on = false })
        nui.setFocus(true)
        core.hooks.runAfter(HOOKS.STATE, { open = true, placing = false, suspended = false })
    end
    if kept and not silent then ghosts.sync(ghostList(pedCoords(), nil)) end
end

--- Retour de page `templateChanged { values, ghost?, label? }` : valeurs du prochain enfant (aucun RPC).
---@param d table
function placer.templateChanged(d)
    if type(d.values) == 'table' then template = d.values end
    if d.ghost ~= nil then templateGhost = cleanLook(d.ghost) end
    if d.label ~= nil then templateLabel = str(d.label, MAX_LABEL) end
    if state then state.lastCandidate = nil end
end

--- Ctrl+Z (commande-touche Z, Ctrl tenu) : hors visée, rien.
function placer.undo()
    local current = state
    if not current or not IsDisabledControlPressed(0, controls.ctrl) then return end
    undo(current)
end

--- Arrêt de la ressource, déchargement : tout ce que l'outil a posé disparaît, sans message.
function placer.release()
    placer.stop(true)
    kept = nil
    ghosts.clear()
end
