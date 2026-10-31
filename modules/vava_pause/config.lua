--[[
    vava_pause/config.lua
    Rôle : réglages de la bannière lus par le seul serveur (servi au seul serveur, jamais téléchargé par les joueurs) :
           débits des RPC, fenêtre de combat, cache des habitants, plafonds de l'instantané, confrérie (ressource et
           export facultatifs, meubles connus), demande au Conseil, départ (délai, messages de déconnexion), touche
           déclarée au registre `core:commands`. Complète la table ouverte par config_client.lua sans en réécrire une
           clé (T-132). Les durées sont en millisecondes.
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaPause.config

config.coreVersion = '0.10.0'   -- core.net (taille mesurée des réponses, latent), registre core:commands

config.rateLimits = {
    open = { capacity = 4, refillPerSecond = 0.25 },        -- une ouverture par 4 s en continu, 4 d'avance
    council = { capacity = 2, refillPerSecond = 1 / 60 },   -- deux demandes d'avance, puis une par minute
    leave = { capacity = 2, refillPerSecond = 0.1 },
}

-- Fenêtre de combat : tout coup donné ou reçu passé par vava_health:hit (annulé compris) met la cible et l'auteur
-- « en combat » ce temps-là ; la faim et les pertes natives (chute, noyade) n'en sont pas.
config.combat = { windowMs = 10000, ignoredKinds = { 'privation', 'monde' } }

-- Habitants présents (personnages en jeu) : compte gardé ce temps.
config.people = { cacheMs = 10000 }

-- Instantané de l'ouverture : savoir-faire et touches au plus ; portées des touches montrées (registre core:commands).
config.snapshot = { maxSkills = 32, maxKeys = 48, keyScopes = { 'player' } }

-- Confrérie du joueur (facultatif, T-105) : export serveur `bannerOf(source)` de cette ressource ; meubles connus du
-- blason (web/img/charges.svg) ; avertissement de console au plus une fois par intervalle pour une réponse invalide.
config.guild = { resource = 'vava_guilds', export = 'bannerOf', charges = { 'croix' }, warnEveryMs = 60000 }

-- Demande au Conseil : caractères au moins, lignes au plus (500 octets au plus : VavaPause.MAX_COUNCIL_TEXT).
config.council = { minChars = 10, maxLines = 12 }

-- Quitter : la réponse part, puis le joueur est déconnecté après ce délai, avec ce message.
config.leave = {
    delayMs = 200,
    messages = {
        disconnect = 'Vous avez quitté Eldoria. Le royaume garde votre place.',
        quit = 'Vous avez quitté Eldoria : vous pouvez fermer le jeu.',
    },
}

-- Registre core:commands (Codex, onglet Touches). Échap et P sont lus directement : aucune liaison FiveM.
config.commands = {
    key = { name = 'vava_pause', label = 'Déployer la bannière du royaume', key = 'ESCAPE',
            keyDisplay = 'Échap ou P', chapter = 'Royaume' },
}
