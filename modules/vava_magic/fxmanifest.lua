--[[
    vava_magic/fxmanifest.lua
    Rôle : magie du royaume : fiche magie par personnage (mage ou non, sorts et leur XP, sort prêt dans les mains,
           sigils), mana et sa barre, progression sur 5 niveaux, incantation commune, roue des sorts (Tab) et mode
           magie à la souris (viser, lancer, verrouiller une cible), états élémentaires (brûlure, mouillé, ralenti,
           chancelant, renversé, gelé ; immunité aux contrôles durs), zones au sol, sorts de feu (Boule de feu, Mur de
           flammes, Nova ardente), Lueur (lumière) et Murmure (messages), grimoire et registre des murmures (objets),
           commandes du Conseil. Le serveur décide de tout ; les effets visibles passent par des state bags posés par le
           serveur et des évènements ciblés, reçus des seuls joueurs proches.
    Dépendances : vAvA_core ≥ 0.5.0 ; facultatives : vava_inventory ≥ 1.3.0 (grimoire et registre), vava_hud
                  (notifications), vava_health (dégâts, à terre), vava_admin (droits et journal du Conseil), vava_chat
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_magic'
description 'Magie vAvA : mana, progression, Murmure, Lueur, Boule de feu, grimoire et registre'
version '2.1.0'

dependency 'vAvA_core'

vava_migration 'sql/0001_magic.sql'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/fonts/*.woff2',
    'web/img/*',
    'web/img/spells/*.svg',
    'web/img/elements/*.svg',
    'web/img/states/*.svg',
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
    'server/states.lua',
    'server/zones.lua',
    'server/registers.lua',
    'server/sigils.lua',
    'server/casting.lua',
    'server/spells/murmure.lua',
    'server/spells/lueur.lua',
    'server/spells/boule_de_feu.lua',
    'server/spells/mur_de_flammes.lua',
    'server/spells/nova_ardente.lua',
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
    'client/fx.lua',
    'client/hud.lua',
    'client/keys.lua',
    'client/aim.lua',
    'client/targeting.lua',
    'client/casting.lua',
    'client/controls.lua',
    'client/wheel.lua',
    'client/states.lua',
    'client/ambient.lua',
    'client/zones.lua',
    'client/spells/murmure.lua',
    'client/spells/lueur.lua',
    'client/spells/boule_de_feu.lua',
    'client/spells/mur_de_flammes.lua',
    'client/spells/nova_ardente.lua',
    'client/sigils.lua',
    'client/grimoire.lua',
    'client/register.lua',
    'client/main.lua',
}
