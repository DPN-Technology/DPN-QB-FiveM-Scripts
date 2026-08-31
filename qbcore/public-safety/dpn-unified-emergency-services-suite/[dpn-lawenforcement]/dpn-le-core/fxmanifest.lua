--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'

name 'dpn-le-core'
author 'Diesel — CEO of DPN Technology'Diesel" Sherk'
description 'DPN Law Enforcement Core v2 - independent qb-core law enforcement framework, officer actions, records, permissions and DPN Emergency Network bridge.'
version '4.0.0'
lua54 'yes'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'shared/bridge.lua'
}

client_scripts {
    'client/main.lua'
}

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
    'oxmysql'
}
