--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'

name 'dpn-le-operations'
author 'Diesel — CEO of DPN Technology'
description 'DPN Law Enforcement Advanced Operations Center: shifts, units, warrants, pursuits, force review, fleet, armory and supervisor workflows.'
version '4.0.0'
lua54 'yes'

ui_page 'html/index.html'

shared_script 'config.lua'
client_script 'client/main.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    'qb-core',
    'oxmysql',
    'dpn-le-core',
    'dpn-digital-dispatch',
    'dpn-emergency-network'
}
