--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Diesel — CEO of DPN Technology'
description 'DPN Digital Dispatch v2 - unified persistent dispatch service for the complete DPN Emergency Network.'
version '4.0.0'

shared_scripts {
    'config.lua',
    'shared/bridge.lua'
}
client_scripts { 'client/main.lua' }
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js' }

dependencies {
    'qb-core',
    'oxmysql',
    'dpn-le-core'
}
