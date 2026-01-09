--[[
    vAvA_keys - Locales English
    English translations for keys module
]]

Locale = Locale or {}

Locale['en'] = {
    -- Notification messages
    ['vehicle_locked'] = 'Vehicle ~r~locked~s~',
    ['vehicle_unlocked'] = 'Vehicle ~g~unlocked~s~',
    ['engine_on'] = 'Engine ~g~started~s~',
    ['engine_off'] = 'Engine ~r~stopped~s~',
    ['no_keys'] = 'You don\'t have the keys to this vehicle',
    ['no_vehicle_nearby'] = 'No vehicle nearby',
    ['keys_received'] = 'You received the vehicle keys',
    ['keys_given'] = 'You gave the vehicle keys',
    ['keys_removed'] = 'Keys have been removed',
    ['already_has_keys'] = 'This person already has the keys',
    ['player_not_found'] = 'Player not found',
    ['carjack_success'] = 'Lockpicking ~g~successful~s~',
    ['carjack_failed'] = 'Lockpicking ~r~failed~s~',
    ['carjacking'] = 'Lockpicking in progress...',
    
    -- ox_lib interface
    ['give_keys_title'] = 'Give Keys',
    ['give_keys_desc'] = 'Select a nearby player',
    ['player_id'] = 'Player ID',
    ['confirm'] = 'Confirm',
    ['cancel'] = 'Cancel',
    
    -- Commands
    ['command_givekeys'] = 'Give vehicle keys',
    ['command_removekeys'] = 'Remove vehicle keys',
}
