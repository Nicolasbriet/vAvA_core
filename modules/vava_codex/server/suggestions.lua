--[[
    vava_codex/server/suggestions.lua
    Rôle : suggestions du chat tirées du registre pour un joueur (export `suggestions(src)`) : une par commande qu'il
           peut taper, une par sous-commande (« metiers niveau »), avec une aide et ses paramètres nommés ; les
           touches et les commandes de console n'y sont pas. vava_chat les demande avec le profil du joueur.
    Dépendances : shared/constants.lua, server/core.lua, server/catalog.lua
]]

local ipairs, tostring = ipairs, tostring
local concat = table.concat
local format = string.format

local catalog = VavaCodex.catalog

local suggestions = {}
VavaCodex.suggestions = suggestions

-- aide d'un paramètre selon son type, à défaut d'une indication déclarée
local TYPE_HELP = {
    player = 'numéro du joueur', account = 'numéro de compte', text = '', registry = 'au choix dans la liste', list = 'au choix dans la liste',
}

---@param arg table
---@return string
local function argHelp(arg)
    local help
    if arg.hint then
        help = arg.hint
    elseif arg.type == 'choice' then
        help = concat(arg.choices or {}, ' | ')
    elseif arg.type == 'integer' or arg.type == 'number' then
        help = (arg.min ~= nil and arg.max ~= nil) and format('de %s à %s', tostring(arg.min), tostring(arg.max)) or 'nombre'
    else
        help = TYPE_HELP[arg.type] or ''
    end
    if arg.optional then help = help ~= '' and ('facultatif : ' .. help) or 'facultatif' end
    return help
end

---@param args table[]|nil
---@return { name: string, help: string }[]
local function params(args)
    local list = {}
    for i, arg in ipairs(args or {}) do list[i] = { name = arg.name, help = argHelp(arg) } end
    return list
end

--- Suggestions d'un joueur : { { name, help, params = { { name, help } } } }, dans l'ordre des entrées visibles.
---@param src integer
---@return table[]
function suggestions.forPlayer(src)
    local out = {}
    local entries = catalog.visible(src)
    for _, entry in ipairs(entries) do
        if entry.kind == 'command' and entry.scope ~= 'console' then
            if entry.actions then
                local ids, bare = {}, nil
                for _, action in ipairs(entry.actions) do
                    if action.id then ids[#ids + 1] = action.id else bare = action end
                end
                out[#out + 1] = {
                    name = entry.name,
                    help = #ids > 0 and format('%s — %s', entry.label, concat(ids, ' | ')) or entry.label,
                    params = bare and params(bare.args) or { { name = 'sous-commande', help = concat(ids, ' | ') } },
                }
                for _, action in ipairs(entry.actions) do
                    if action.id then
                        out[#out + 1] = { name = entry.name .. ' ' .. action.id, help = action.label, params = params(action.args) }
                    end
                end
            else
                out[#out + 1] = { name = entry.name, help = entry.label, params = params(entry.args) }
            end
        end
    end
    return out
end

exports('suggestions', function(src)
    return suggestions.forPlayer(src)
end)
