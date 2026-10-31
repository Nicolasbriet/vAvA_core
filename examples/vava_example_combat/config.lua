--[[
    vava_example_combat/config.lua
    Rôle : configuration de la ressource d'essai de la chaîne de dégâts (lue par le client et le serveur) : accès,
           commandes (dont /frapper_arme, T-111), délais, armes et explosion vanilla d'essai (provisoires), textes.
    Dépendances : aucune
]]

VavaExampleCombat = {
    config = {
        coreVersion = '0.10.0',

        -- Qui peut s'en servir (le serveur revérifie à chaque appel) : droit vava_admin `permission`, ou ACE `ace`.
        -- Le mode développement (`set vava_env dev`) est exigé en plus.
        access = { permission = 'staff', ace = 'vava.dev' },
        -- accord demandé par le client avant /arme, /explosion, /tricher
        accessRateLimit = { capacity = 2, refillPerSecond = 1 },
        cooldownMs = 500,           -- délai entre deux commandes d'un même joueur

        commands = {
            hit = 'frapper', dodge = 'esquive', shield = 'bouclier', resistance = 'resistance', chain = 'chaine',
            weapon = 'arme', explosion = 'explosion', cheat = 'tricher',
            -- coup de l'arme tenue en main par exports.vava_combat:strike (vava_combat ≥ 1.0.0, facultatif)
            weaponHit = 'frapper_arme',
        },
        chapter = 'Essais de combat',
        chatAuthor = 'Combat',

        defaultKind = 'tranchant',  -- type d'un coup de /frapper sans type
        dodgeMs = 3000,             -- fenêtre ouverte par /esquive

        -- Armes et explosion vanilla d'essai, pour vérifier l'annulation des dégâts natifs entre joueurs.
        weapons = { pistolet = 'WEAPON_PISTOL', couteau = 'WEAPON_KNIFE' }, -- PLACEHOLDER : armes vanilla d'essai
        ammo = 60,
        explosion = { distance = 3.0, type = 2 }, -- PLACEHOLDER : explosion vanilla d'essai

        -- Libellés du journal du Registre (vava_admin:log, 32 signes au plus) ; sans Registre, console du serveur.
        journal = {
            hit = 'Essai de combat : coup porté',
            modifier = 'Essai de combat : protection',
            weaponHit = 'Essai de combat : coup d\'arme',
        },

        -- Raisons d'annulation montrées au lanceur (les autres s'affichent telles quelles).
        reasons = { downed = 'à terre', esquive = 'esquive', pvp_off = 'combats entre joueurs coupés',
            no_weapon = 'aucune arme en main', too_far = 'trop loin' },
    },
}
