--[[
    vava_magic/fxmanifest.lua
    Rôle : magie du royaume : fiche magie par personnage (mage ou non, sorts et leur XP, sigils), mana, progression
           sur 5 niveaux, incantation commune, sorts Murmure (messages), Lueur (lumière) et Boule de feu (offensif),
           grimoire et registre des murmures (objets), commandes du Conseil. Le serveur décide de tout ; les effets
           visibles passent par des state bags posés par le serveur, reçus des seuls joueurs proches.
    Dépendances : vAvA_core ≥ 0.5.0 ; facultatives : vava_inventory ≥ 1.3.0 (grimoire et registre), vava_hud (mana,
                  notifications), vava_health (dégâts, à terre), vava_admin (droits et journal du Conseil), chat
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_magic'
description 'Magie vAvA : mana, progression, Murmure, Lueur, Boule de feu, grimoire et registre'
version '1.0.0'

dependency 'vAvA_core'

vava_migration 'sql/0001_magic.sql'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/fonts/*.woff2',
    'web/img/*',
    'web/items/*.svg',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui. Un nouveau sort : ses deux fichiers
-- spells/<nom>.lua (serveur et client) à la suite des autres, et sa config dans config.lua.
shared_scripts {
    'shared/constants.lua',
    'config.lua',
    'shared/text.lua',
    'shared/progression.lua',
    'shared/geometry.lua',
}

server_scripts {
    'server/core.lua',
    'bridge/server.lua',
    'server/world.lua',
    'server/sheets.lua',
    'server/mana.lua',
    'server/spells.lua',
    'server/progression.lua',
    'server/combat.lua',
    'server/registers.lua',
    'server/sigils.lua',
    'server/casting.lua',
    'server/spells/murmure.lua',
    'server/spells/lueur.lua',
    'server/spells/boule_de_feu.lua',
    'server/admin.lua',
    'server/api.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'bridge/client.lua',
    'client/nui.lua',
    'client/state.lua',
    'client/messages.lua',
    'client/mana.lua',
    'client/keys.lua',
    'client/aim.lua',
    'client/casting.lua',
    'client/ambient.lua',
    'client/spells/murmure.lua',
    'client/spells/lueur.lua',
    'client/spells/boule_de_feu.lua',
    'client/sigils.lua',
    'client/grimoire.lua',
    'client/register.lua',
    'client/main.lua',
}
