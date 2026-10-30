--[[
    vava_atelier/server/core.lua
    Rôle : accès à l'API serveur du core, partagé par les fichiers du module ; table des points d'extension que T-101
           remplacera (brouillons, étiquettes, source des listes et des fiches, état et pied d'une fiche).
    Dépendances : vAvA_core (API v1), shared/constants.lua
]]

local RESOURCE = GetCurrentResourceName()

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

VavaAtelier.core = core
VavaAtelier.log = core.log
VavaAtelier.resource = RESOURCE

-- Points d'extension (remplis par server/entries.lua et server/home.lua ; T-101 les remplace sans toucher aux RPC) :
--   drafts(source, visibleEditorIds) → liste ≤ 5     tag(editorId) → texte | nil
--   index(editor, kind) → liste brute                 read(editor, kind, id) → data | nil
--   state(editor, kind, id) → { label, tone }         footer(editor, kind, id) → { { id, label, primary? } }
VavaAtelier.providers = {}
