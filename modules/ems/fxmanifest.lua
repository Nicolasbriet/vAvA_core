fx_version 'cerulean'
game 'gta5'

name 'vAvA_ems'
description 'Système EMS complet - Urgences, diagnostic, soins, hospitalisation'
author 'vAvA'
version '1.0.0'

-- Dépendances
dependencies {
    'vAvA_core',
    'oxmysql'
}

-- Fichiers shared
shared_scripts {
    '@vAvA_core/shared/utils.lua',
    'shared/*.lua'
}

-- Fichiers serveur
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/*.lua',
    'server/*.lua'
}

-- Fichiers client
client_scripts {
    'config/*.lua',
    'client/*.lua'
}

-- Interface NUI
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/img/*.png',
    'html/img/*.jpg',
    'locales/*.lua'
}

-- Exports serveur
server_exports {
    'GetPlayerMedicalState',
    'SetPlayerMedicalState',
    'AddInjury',
    'RemoveInjury',
    'GetVitalSigns',
    'SetVitalSign',
    'GetBloodType',
    'SetBloodType',
    'GetBloodStock',
    'AddBloodStock',
    'RemoveBloodStock',
    'TransfuseBlood',
    'CreateEmergencyCall',
    'GetActiveCalls'
}

-- Exports client
client_exports {
    'GetLocalMedicalState',
    'OpenEMSMenu',
    'OpenPatientDiagnosis',
    'UseEquipment'
}

lua54 'yes'
