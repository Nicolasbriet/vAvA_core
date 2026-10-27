--[[
    vava_world/server/api.lua
    Rôle : exports serveur pour les autres modules : préparer une instance (routing bucket) qu'ils créent, pour
           qu'elle suive les règles du monde (sans population).
    Dépendances : shared/constants.lua, server/population.lua
]]

local mathType = math.type

local population = VavaWorld.population
-- bornes des routing buckets de FXServer
local MAX_BUCKET = 0x7FFFFFFF

exports('prepareBucket', function(bucket)
    if not VavaWorld.ready then return false, 'not_ready' end
    if mathType(bucket) ~= 'integer' or bucket < 0 or bucket > MAX_BUCKET then return false, 'invalid_args' end
    population.prepare(bucket)
    return true
end)
