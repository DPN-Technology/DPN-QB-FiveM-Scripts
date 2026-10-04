--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dpn-mdt'
author 'Diesel — CEO of DPN Technology'
description 'DPN Mobile Data Terminal for Law Enforcement, EMS, Fire, Courts, MIB/Admin, Dispatch, and Unified Emergency Service Network'
version '1.1.1-charges'

ui_page 'html/index.html'

shared_scripts {
    'shared/constants.lua',
    'config.lua'
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
