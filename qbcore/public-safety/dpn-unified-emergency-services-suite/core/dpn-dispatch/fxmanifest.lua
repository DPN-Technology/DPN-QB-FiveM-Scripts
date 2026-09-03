--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Diesel — CEO of DPN Technology'
description 'DPN Unified Dispatch System for Law Enforcement, EMS, Fire, Courts, MIB/Admin, Reporting, and MDT Sync'
version '1.3.0'

ui_page 'html/index.html'

shared_scripts {
    'shared/config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua',
    'client/blips.lua',
    'client/nui.lua'
}

server_scripts {
    'server/database.lua',
    'server/mdt_bridge.lua',
    'server/main.lua',
    'server/correlation_bridge.lua',
    'server/exports.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependency 'qb-core'
