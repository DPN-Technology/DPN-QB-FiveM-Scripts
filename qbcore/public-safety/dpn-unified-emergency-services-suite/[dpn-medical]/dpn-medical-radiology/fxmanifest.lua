--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Diesel — CEO of DPN Technology'
description 'dpn-medical-radiology v14 - time-critical trauma and resuscitation command'
version '14.0.0'

shared_script 'shared/config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/advanced.lua',
    'server/v6.lua',
    'server/v8.lua',
    'server/v9.lua',
    'server/v10.lua',
    'server/v11.lua',
    'server/v12.lua',
    'server/v13.lua',
    'server/v14.lua'
}

dependencies {
    'qb-core', 'oxmysql', 'dpn-medical-core'
}
