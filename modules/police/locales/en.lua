--[[
    vAvA_police - English Translation
]]

Locale = Locale or {}

Locale['en'] = {
    -- General
    ['police'] = 'Police',
    ['open_menu'] = 'Press ~INPUT_CONTEXT~ to open menu',
    ['no_players_nearby'] = 'No players nearby',
    ['player_not_online'] = 'Player is no longer online',
    ['action_cancelled'] = 'Action cancelled',
    
    -- Interaction menu
    ['citizen_interaction'] = 'Citizen Interaction',
    ['handcuff'] = 'Handcuff / Uncuff',
    ['search'] = 'Search',
    ['escort'] = 'Escort',
    ['put_in_vehicle'] = 'Put in vehicle',
    ['remove_from_vehicle'] = 'Remove from vehicle',
    ['fine'] = 'Give fine',
    ['jail'] = 'Send to jail',
    ['identity_check'] = 'Identity check',
    ['check_licenses'] = 'Check licenses',
    ['confiscate_items'] = 'Confiscate items',
    
    -- Handcuffs
    ['handcuffed'] = 'You are handcuffed',
    ['unhandcuffed'] = 'You have been uncuffed',
    ['handcuffed_target'] = 'You handcuffed ~y~%s~s~',
    ['unhandcuffed_target'] = 'You uncuffed ~y~%s~s~',
    
    -- Search
    ['search_in_progress'] = 'Search in progress...',
    ['searched_target'] = 'You searched ~y~%s~s~',
    ['being_searched'] = 'You are being searched',
    ['found_items'] = 'Items found: %s',
    ['no_items_found'] = 'No items found',
    ['illegal_items_confiscated'] = 'Illegal items confiscated: %s',
    
    -- Escort
    ['escorting'] = 'You are escorting ~y~%s~s~',
    ['being_escorted'] = 'You are being escorted',
    ['escort_stopped'] = 'Escort stopped',
    
    -- Vehicle
    ['put_in_vehicle_success'] = 'Citizen placed in vehicle',
    ['remove_from_vehicle_success'] = 'Citizen removed from vehicle',
    ['no_vehicle_nearby'] = 'No vehicle nearby',
    ['vehicle_full'] = 'Vehicle is full',
    
    -- Fines
    ['fine_issued'] = 'Fine issued: ~g~$%s~s~ for ~y~%s~s~',
    ['fine_received'] = 'You received a fine of ~r~$%s~s~\nReason: ~y~%s~s~',
    ['fine_paid'] = 'Fine paid: ~g~$%s~s~',
    ['fine_not_enough_money'] = 'Not enough money',
    ['select_fine_type'] = 'Select fine type',
    ['traffic_violations'] = 'Traffic violations',
    ['admin_violations'] = 'Administrative violations',
    ['criminal_violations'] = 'Criminal violations',
    ['custom_fine'] = 'Custom fine',
    ['enter_custom_amount'] = 'Enter fine amount',
    ['enter_fine_reason'] = 'Enter fine reason',
    
    -- Prison
    ['jail_time'] = 'Jail time: ~y~%s~s~ minutes',
    ['sent_to_jail'] = 'You sent ~y~%s~s~ to jail for ~r~%s~s~ minutes',
    ['jailed'] = 'You have been jailed for ~r~%s~s~ minutes\nReason: ~y~%s~s~',
    ['time_remaining'] = 'Time remaining: ~r~%s~s~ minutes',
    ['released_from_jail'] = 'You have been released from jail',
    ['work_to_reduce'] = 'Work to reduce your sentence',
    ['work_point'] = 'Press ~INPUT_CONTEXT~ to work',
    ['working'] = 'Working... (~y~-%s~s~ seconds)',
    ['time_reduced'] = 'Time reduced by ~g~%s~s~ minutes',
    ['enter_jail_time'] = 'Enter jail time (minutes)',
    ['enter_jail_reason'] = 'Enter jail reason',
    
    -- Criminal record
    ['criminal_record'] = 'Criminal Record',
    ['no_criminal_record'] = 'Clean record',
    ['record_added'] = 'Record added to criminal history',
    ['view_record'] = 'View record',
    ['offense'] = 'Offense',
    ['fine_amount'] = 'Fine amount',
    ['jail_time_served'] = 'Jail time',
    ['date'] = 'Date',
    ['officer'] = 'Officer',
    
    -- Tablet
    ['tablet'] = 'Police Tablet',
    ['open_tablet'] = 'Open tablet',
    ['search_person'] = 'Search person',
    ['search_vehicle'] = 'Search vehicle',
    ['search_plate'] = 'Search by plate',
    ['recent_alerts'] = 'Recent alerts',
    ['active_units'] = 'Active units',
    ['enter_name'] = 'Enter name',
    ['enter_plate'] = 'Enter plate',
    ['person_info'] = 'Person Information',
    ['vehicle_info'] = 'Vehicle Information',
    ['no_results'] = 'No results',
    ['name'] = 'Name',
    ['dob'] = 'Date of birth',
    ['gender'] = 'Gender',
    ['phone'] = 'Phone',
    ['job'] = 'Job',
    ['owner'] = 'Owner',
    ['model'] = 'Model',
    ['plate'] = 'Plate',
    ['color'] = 'Color',
    
    -- Cloakroom
    ['cloakroom'] = 'Cloakroom',
    ['civilian_outfit'] = 'Civilian outfit',
    ['police_outfit'] = 'Police uniform',
    ['outfit_changed'] = 'Outfit changed',
    
    -- Armory
    ['armory'] = 'Armory',
    ['take_weapon'] = 'Take weapon',
    ['deposit_weapon'] = 'Deposit weapon',
    ['weapon_taken'] = 'Weapon taken: ~y~%s~s~',
    ['weapon_deposited'] = 'Weapon deposited: ~y~%s~s~',
    ['insufficient_grade'] = 'Insufficient grade',
    ['ammo'] = 'Ammunition',
    ['ammo_taken'] = 'Ammunition taken: ~y~%s~s~',
    
    -- Garage
    ['vehicle_garage'] = 'Police Garage',
    ['spawn_vehicle'] = 'Take out vehicle',
    ['store_vehicle'] = 'Store vehicle',
    ['vehicle_spawned'] = 'Vehicle spawned: ~y~%s~s~',
    ['vehicle_stored'] = 'Vehicle stored',
    ['no_vehicle_nearby_to_store'] = 'No vehicle nearby',
    ['spawn_point_blocked'] = 'Spawn point blocked',
    
    -- Radar
    ['radar_on'] = 'Radar ~g~ENABLED~s~',
    ['radar_off'] = 'Radar ~r~DISABLED~s~',
    ['radar_speed'] = 'Speed detected: ~y~%s~s~ km/h',
    ['radar_limit'] = 'Limit: ~y~%s~s~ km/h',
    ['radar_speeding'] = '~r~SPEEDING~s~',
    ['radar_target'] = 'Vehicle: ~y~%s~s~',
    ['radar_no_target'] = 'No vehicle detected',
    
    -- Dispatch / Alerts
    ['dispatch_alert'] = 'DISPATCH ALERT',
    ['alert_code'] = 'Code',
    ['alert_location'] = 'Location',
    ['alert_set_waypoint'] = 'Press ~INPUT_CONTEXT~ for GPS',
    ['alert_respond'] = 'Press ~INPUT_PICKUP~ to respond',
    ['alert_responded'] = 'Alert responded by ~y~%s~s~',
    ['backup_requested'] = 'BACKUP REQUESTED by ~y~%s~s~',
    ['request_backup'] = 'Request backup',
    ['backup_sent'] = 'Backup request sent',
    
    -- Service
    ['on_duty'] = 'You are now ~g~on duty~s~',
    ['off_duty'] = 'You are now ~r~off duty~s~',
    ['duty_toggle'] = 'Toggle duty',
    
    -- Permissions
    ['no_permission'] = 'No permission',
    ['insufficient_rank'] = 'Insufficient rank',
    
    -- Misc
    ['press_to_interact'] = 'Press ~INPUT_CONTEXT~ to interact',
    ['cancelled'] = 'Cancelled',
    ['confirm'] = 'Confirm',
    ['cancel'] = 'Cancel',
    ['yes'] = 'Yes',
    ['no'] = 'No',
    ['close'] = 'Close',
    ['back'] = 'Back',
    ['submit'] = 'Submit'
}
