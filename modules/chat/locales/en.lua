--[[
    vAvA_chat - Locales English
    English translations for chat module
]]

Locale = Locale or {}

Locale['en'] = {
    -- General messages
    ['not_staff'] = 'You are not staff',
    ['not_police'] = 'You are not a police officer',
    ['not_ems'] = 'You are not EMS',
    ['player_not_found'] = 'Player ID not found',
    ['message_too_long'] = 'Message too long (255 characters maximum)',
    
    -- Commands
    ['cmd_me_help'] = '3rd person RP action',
    ['cmd_do_help'] = 'RP description',
    ['cmd_de_help'] = 'Roll a dice (1-20)',
    ['cmd_ooc_help'] = 'Out of character message',
    ['cmd_mp_help'] = 'Private message',
    ['cmd_police_help'] = 'Police radio channel',
    ['cmd_ems_help'] = 'EMS radio channel',
    ['cmd_staff_help'] = 'Staff channel',
    
    -- Message prefixes
    ['prefix_me'] = '[ME]',
    ['prefix_do'] = '[DO]',
    ['prefix_de'] = '[DICE]',
    ['prefix_ooc'] = '[OOC]',
    ['prefix_mp'] = '[PM]',
    ['prefix_police'] = '[POLICE]',
    ['prefix_ems'] = '[EMS]',
    ['prefix_staff'] = '[STAFF]',
    
    -- Dice
    ['dice_roll'] = '%s rolls a dice: %d/20',
}
