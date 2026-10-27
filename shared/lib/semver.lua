--[[
    shared/lib/semver.lua
    Rôle : lecture et comparaison de versions sémantiques MAJEUR.MINEUR.CORRECTIF.
    Dépendances : shared/init.lua
]]

local type, tonumber = type, tonumber
local match = string.match
local tointeger = math.tointeger

local semver = {}
vAvA.lib.semver = semver

---@class vAvA.Version
---@field major integer
---@field minor integer
---@field patch integer

---@param digits string
---@return integer|nil
local function toPart(digits)
    return tointeger(tonumber(digits))
end

--- Analyse une version ; nil si elle n'est pas au format MAJEUR.MINEUR.CORRECTIF.
---@param version any
---@return vAvA.Version|nil
function semver.parse(version)
    if type(version) ~= 'string' then return nil end
    local major, minor, patch = match(version, '^(%d+)%.(%d+)%.(%d+)$')
    if not major then return nil end
    major, minor, patch = toPart(major), toPart(minor), toPart(patch)
    -- un nombre trop grand pour un entier devient un flottant : rejeté
    if not (major and minor and patch) then return nil end
    return { major = major, minor = minor, patch = patch }
end

--- Compare deux versions : -1 si a < b, 0 si égales, 1 si a > b ; nil si l'une est invalide.
---@param a string
---@param b string
---@return integer|nil
function semver.compare(a, b)
    local va, vb = semver.parse(a), semver.parse(b)
    if not va or not vb then return nil end
    if va.major ~= vb.major then return va.major < vb.major and -1 or 1 end
    if va.minor ~= vb.minor then return va.minor < vb.minor and -1 or 1 end
    if va.patch ~= vb.patch then return va.patch < vb.patch and -1 or 1 end
    return 0
end

--- Vrai si `version` est supérieure ou égale à `minimum`.
---@param version string
---@param minimum string
---@return boolean
function semver.satisfiesMin(version, minimum)
    local result = semver.compare(version, minimum)
    return result ~= nil and result >= 0
end
