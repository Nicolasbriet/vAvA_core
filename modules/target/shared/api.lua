-- ============================================
-- vAvA Target - Shared API
-- Fonctions et utilitaires partagés
-- ============================================

TargetAPI = {}

-- ============================================
-- VALIDATION D'OPTIONS
-- ============================================

function TargetAPI.ValidateOption(option)
    if type(option) ~= 'table' then
        return false, 'Option must be a table'
    end
    
    if not option.label then
        return false, 'Option must have a label'
    end
    
    -- Vérifier qu'au moins une action est définie
    if not option.event and not option.export and not option.command and not option.action then
        return false, 'Option must have at least one action (event, export, command, or action)'
    end
    
    return true
end

-- ============================================
-- VALIDATION DE ZONE
-- ============================================

function TargetAPI.ValidateZone(zone)
    if type(zone) ~= 'table' then
        return false, 'Zone must be a table'
    end
    
    if not zone.name or type(zone.name) ~= 'string' then
        return false, 'Zone must have a name (string)'
    end
    
    if not zone.type or type(zone.type) ~= 'string' then
        return false, 'Zone must have a type (string)'
    end
    
    if not zone.coords then
        return false, 'Zone must have coords'
    end
    
    -- Validation spécifique par type
    if zone.type == 'sphere' then
        if not zone.radius or type(zone.radius) ~= 'number' then
            return false, 'Sphere zone must have a radius (number)'
        end
    elseif zone.type == 'box' then
        if not zone.size then
            return false, 'Box zone must have a size (vector3)'
        end
    elseif zone.type == 'cylinder' then
        if not zone.radius or type(zone.radius) ~= 'number' then
            return false, 'Cylinder zone must have a radius (number)'
        end
        if not zone.height or type(zone.height) ~= 'number' then
            return false, 'Cylinder zone must have a height (number)'
        end
    elseif zone.type == 'poly' then
        if not zone.points or type(zone.points) ~= 'table' or #zone.points < 3 then
            return false, 'Poly zone must have at least 3 points'
        end
    else
        return false, 'Invalid zone type: ' .. zone.type
    end
    
    return true
end

-- ============================================
-- CONVERSION MODÈLE
-- ============================================

function TargetAPI.ModelToHash(model)
    if type(model) == 'string' then
        return GetHashKey(model)
    elseif type(model) == 'number' then
        return model
    end
    
    return nil
end

-- ============================================
-- VÉRIFICATION PERMISSIONS
-- ============================================

function TargetAPI.CheckPermissions(option, playerData)
    -- Job
    if option.job then
        if type(option.job) == 'string' then
            if not playerData.job or playerData.job ~= option.job then
                return false, 'Invalid job'
            end
        elseif type(option.job) == 'table' then
            local hasJob = false
            for _, job in ipairs(option.job) do
                if playerData.job == job then
                    hasJob = true
                    break
                end
            end
            if not hasJob then
                return false, 'Invalid job'
            end
        end
    end
    
    -- Grade
    if option.grade then
        if not playerData.grade or playerData.grade < option.grade then
            return false, 'Insufficient grade'
        end
    end
    
    -- Item
    if option.item then
        if type(option.item) == 'string' then
            if not playerData.items or not playerData.items[option.item] then
                return false, 'Missing item: ' .. option.item
            end
        elseif type(option.item) == 'table' then
            for _, item in ipairs(option.item) do
                if not playerData.items or not playerData.items[item] then
                    return false, 'Missing item: ' .. item
                end
            end
        end
    end
    
    -- Money
    if option.money then
        if not playerData.money or playerData.money < option.money then
            return false, 'Insufficient money'
        end
    end
    
    -- Groups (admin)
    if option.groups then
        if type(option.groups) == 'string' then
            if not playerData.groups or not playerData.groups[option.groups] then
                return false, 'Invalid group'
            end
        elseif type(option.groups) == 'table' then
            local hasGroup = false
            for _, group in ipairs(option.groups) do
                if playerData.groups and playerData.groups[group] then
                    hasGroup = true
                    break
                end
            end
            if not hasGroup then
                return false, 'Invalid group'
            end
        end
    end
    
    return true
end

-- ============================================
-- DISTANCE ENTRE DEUX POINTS
-- ============================================

function TargetAPI.GetDistance(coords1, coords2)
    if type(coords1) == 'vector3' and type(coords2) == 'vector3' then
        return #(coords1 - coords2)
    elseif type(coords1) == 'table' and type(coords2) == 'table' then
        local dx = coords1.x - coords2.x
        local dy = coords1.y - coords2.y
        local dz = coords1.z - coords2.z
        return math.sqrt(dx * dx + dy * dy + dz * dz)
    end
    
    return 999999
end

-- ============================================
-- CALCUL DISTANCE 2D
-- ============================================

function TargetAPI.GetDistance2D(coords1, coords2)
    if type(coords1) == 'vector3' and type(coords2) == 'vector3' then
        return #(vector2(coords1.x, coords1.y) - vector2(coords2.x, coords2.y))
    elseif type(coords1) == 'table' and type(coords2) == 'table' then
        local dx = coords1.x - coords2.x
        local dy = coords1.y - coords2.y
        return math.sqrt(dx * dx + dy * dy)
    end
    
    return 999999
end

-- ============================================
-- FORMATAGE DISTANCE
-- ============================================

function TargetAPI.FormatDistance(distance)
    if distance < 1 then
        return string.format('%.1fcm', distance * 100)
    else
        return string.format('%.1fm', distance)
    end
end

-- ============================================
-- DEEP COPY TABLE
-- ============================================

function TargetAPI.DeepCopy(original)
    local copy
    
    if type(original) == 'table' then
        copy = {}
        for k, v in next, original, nil do
            copy[TargetAPI.DeepCopy(k)] = TargetAPI.DeepCopy(v)
        end
        setmetatable(copy, TargetAPI.DeepCopy(getmetatable(original)))
    else
        copy = original
    end
    
    return copy
end

-- ============================================
-- MERGE TABLES
-- ============================================

function TargetAPI.MergeTables(t1, t2)
    local result = {}
    
    for k, v in pairs(t1) do
        result[k] = v
    end
    
    for k, v in pairs(t2) do
        if type(v) == 'table' and type(result[k]) == 'table' then
            result[k] = TargetAPI.MergeTables(result[k], v)
        else
            result[k] = v
        end
    end
    
    return result
end

-- ============================================
-- GÉNÉRER UUID
-- ============================================

function TargetAPI.GenerateUUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

-- ============================================
-- EXPORTS
-- ============================================

return TargetAPI
