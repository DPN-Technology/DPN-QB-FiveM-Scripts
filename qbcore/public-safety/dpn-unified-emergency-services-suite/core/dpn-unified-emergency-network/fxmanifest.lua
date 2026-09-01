--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'

name 'dpn-unified-emergency-network'
author 'Diesel — CEO of DPN Technology'
description 'Unified Emergency Service Network tying Law Enforcement, EMS, Fire, Courts, Corrections, Bail Bonds, and Admin/MIB systems together.'
version '4.0.0-mapfix'

lua54 'yes'

ui_page 'html/index.html'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'shared/config.lua',
    'shared/constants.lua'
}

client_scripts {
    'client/main.lua',
    'client/dispatch.lua',
    'client/ui.lua',
    'client/agency.lua',
    'client/integrations.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/correlation.lua',
    'server/main.lua',
    'server/incidents.lua',
    'server/dispatch.lua',
    'server/agency.lua',
    'server/integrations.lua',
    'server/exports.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/img/*'
}

dependencies {
    'qb-core',
    'oxmysql'
}
