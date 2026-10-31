--[[
    vava_loading/config_client.lua
    Rôle : réglages du client Lua de l'écran de chargement : écran de sélection attendu, durée de l'éclair, filets.
           La page s'affiche avant tout script Lua et ne peut pas lire ce fichier : ses propres réglages (rythmes,
           effets, musique) sont dans web/js/config.js, ses textes dans web/js/strings.js.
    Dépendances : shared/constants.lua
]]

VavaLoading.config = {
    -- En dessous, le core ferme lui-même l'écran de chargement à la mise en attente du joueur (spawn.loadingScreen
    -- absent) : écran noir bref avant la sélection, signalé une fois en avertissement dans la console du client (F8).
    coreVersion = '0.13.0',

    -- Écran de sélection attendu : sa ressource, le hook client qu'il émet quand il est affiché, et l'export lu au
    -- démarrage (ressource redémarrée, hook déjà passé). Un autre écran de sélection n'a qu'à changer ces trois noms.
    selection = {
        resource = 'vava_characters_ui',
        shownHook = 'vava_characters_ui:shown',
        isShownExport = 'isShown',
    },

    -- Durée de l'éclair « Le royaume vous attend » et du fondu de la page (ms, bornée de 300 à 5000), envoyée à la
    -- page avec le message de passage ; l'écran de chargement est fermé à la fin.
    handoffMs = 1800,

    -- Sélection mise en attente mais jamais signalée affichée : passage quand même après ce délai (ms). Doit dépasser
    -- rpc.defaultTimeoutMs du core (10 s) : la liste des personnages peut attendre jusque-là.
    selectionFallbackMs = 20000,

    -- Sans API du core (core absent ou en erreur) : attente de la session réseau à cet intervalle (ms), puis
    -- fermeture sans éclair.
    noCorePollMs = 250,
}
