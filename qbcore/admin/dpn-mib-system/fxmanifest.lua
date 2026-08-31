--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Diesel — CEO of DPN Technology'
description 'DPN MIB System V4 - Admin + Developer Operations Suite with PG7X and Advanced Neuralizer'
version '4.0.0-admin-dev-pg7x'

ui_page 'html/index.html'

shared_scripts {
    'shared/config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua',
    'client/neuralizer.lua',
    'client/tools.lua',
    'client/spectate.lua',
    'client/devtools.lua',
    'client/pg7x.lua',
    'client/menu.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/logs.lua',
    'server/integrations.lua',
    'server/cases.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'sounds/neuralizer.ogg'
}

dependencies { 'qb-core' }
