--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'

name 'dpn-medical-hospital'
author 'Diesel — CEO of DPN Technology'
description 'dpn-medical-hospital v14 - time-critical trauma and resuscitation command'
version '14.0.0'

lua54 'yes'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'shared/config.lua',
    'shared/states.lua'
}

client_scripts {
    'client/main.lua',
    'client/beds.lua',
    'client/checkin.lua',
    'client/recovery.lua',
    'client/nui.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/beds.lua',
    'server/admissions.lua',
    'server/main.lua',
    'server/billing.lua',
    'server/exports.lua',
    'server/standalone.lua',
    'server/advanced.lua',
    'server/v6.lua',
    'server/v7.lua',
    'server/v8.lua',
    'server/v9.lua',
    'server/v10.lua',
    'server/v11.lua',
    'server/v12.lua',
    'server/v13.lua',
    'server/v14.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    'qb-core',
    'oxmysql',
    'dpn-medical-core'
}
