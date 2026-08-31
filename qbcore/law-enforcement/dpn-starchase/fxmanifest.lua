--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dpn-starchase'
author 'Diesel — CEO of DPN Technology'
description 'Advanced QBCore StarChase GPS tracker launcher with NUI remote, lock-on HUD, safe low-profile tracker props, GPS blips, logs, and physical removal.'
version '1.1.1'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/ui.lua'
}

server_scripts {
    'server/database.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

dependency 'qb-core'
