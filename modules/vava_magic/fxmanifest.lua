--[[
    vava_magic/fxmanifest.lua
    Rôle : magie du royaume : fiche magie par personnage (mage ou non, sorts et leur XP, sort prêt dans les mains,
           sigils), mana et sa barre, progression sur 5 niveaux, incantation commune, roue des sorts (Tab) et mode
           magie à la souris (viser, lancer, verrouiller une cible), états élémentaires (brûlure, mouillé, ralenti,
           chancelant, renversé, gelé ; immunité aux contrôles durs), zones au sol, projectiles et obstacles, blessures
           portées par la chaîne de dégâts de vava_health (boucliers, résistances et zones de paix en modificateurs),
           sorts de feu (Boule de feu, Mur de flammes, Nova ardente), d'eau (Trait de glace, Vague, Brume) et de terre (Projectile de
           roche, Secousse, Rempart), combinaisons entre éléments (vapeur, boue, gel…), Lueur (lumière) et Murmure
           (messages), grimoire (avec ses combinaisons découvertes) et registre des murmures (objets),
           commandes du Conseil. Le serveur décide de tout ; les effets visibles passent par des state bags posés par le
           serveur et des évènements ciblés, reçus des seuls joueurs proches.
    Dépendances : vAvA_core ≥ 0.5.0 ; vava_ui ≥ 1.0.0 (polices, grain, papier et coins de la page, par
                  nui://vava_ui/…) ; facultatives : vava_inventory ≥ 1.3.0 (grimoire et registre), vava_hud
                  (notifications), vava_health ≥ 1.3.0 (chaîne de dégâts : sans lui, aucun sort ne blesse ; à terre),
                  vava_admin (droits et journal du Conseil), vava_chat
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_magic'
description 'Magie vAvA : mana, progression, roue des sorts, états, sorts de feu, eau et terre, Murmure, Lueur, grimoire et registre'
version '2.9.0'

dependency 'vAvA_core'
dependency 'vava_ui'

vava_migration 'sql/0001_magic.sql'

ui_page 'web/index.html'

-- polices, grain, papier et coins : vava_ui (runes, écriture, sorts, éléments et états restent ici) ; les données
-- simulées hors jeu (dossier dev/) ne sont jamais livrées
files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/sounds/*.ogg',
    'web/img/*.svg',
    'web/img/runes.png',
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
    'shared/pages.lua',
}

-- règles pures des blessures (shared/harm.lua) : servies au seul serveur, le client n'en télécharge rien
server_scripts {
    'shared/harm.lua',
    'server/core.lua',
    'bridge/server.lua',
    'server/world.lua',
    'server/sheets.lua',
    'server/mana.lua',
    'server/spells.lua',
    'server/progression.lua',
    'server/combat.lua',
    'server/protections.lua',
    'server/states.lua',
    'server/obstacles.lua',
    'server/zones.lua',
    'server/grounds.lua',
    'server/combos.lua',
    'server/projectiles.lua',
    'server/registers.lua',
    'server/sigils.lua',
    'server/casting.lua',
    'server/spells/murmure.lua',
    'server/spells/lueur.lua',
    'server/spells/boule_de_feu.lua',
    'server/spells/mur_de_flammes.lua',
    'server/spells/nova_ardente.lua',
    'server/spells/trait_de_glace.lua',
    'server/spells/vague.lua',
    'server/spells/brume.lua',
    'server/spells/projectile_de_roche.lua',
    'server/spells/secousse.lua',
    'server/spells/rempart.lua',
    'server/admin.lua',
    'server/api.lua',
    'server/commands.lua',
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
    'client/clouds.lua',
    'client/bursts.lua',
    'client/projectiles.lua',
    'client/combos.lua',
    'client/spells/murmure.lua',
    'client/spells/lueur.lua',
    'client/spells/boule_de_feu.lua',
    'client/spells/mur_de_flammes.lua',
    'client/spells/nova_ardente.lua',
    'client/spells/trait_de_glace.lua',
    'client/spells/vague.lua',
    'client/spells/brume.lua',
    'client/spells/projectile_de_roche.lua',
    'client/spells/secousse.lua',
    'client/spells/rempart.lua',
    'client/sigils.lua',
    'client/grimoire.lua',
    'client/register.lua',
    'client/main.lua',
}
