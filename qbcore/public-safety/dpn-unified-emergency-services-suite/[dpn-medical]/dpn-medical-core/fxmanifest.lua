--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Diesel — CEO of DPN Technology'
description 'dpn-medical-core v14 - time-critical trauma and resuscitation command'
version '14.0.0'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

shared_scripts {
    'shared/config.lua',
    'shared/body.lua',
    'shared/api.lua',
    'shared/advanced.lua',
    'shared/v6.lua',
    'shared/test_scenarios.lua',
    'shared/v8.lua',
    'shared/v9.lua',
    'shared/v10.lua',
    'shared/v11.lua',
    'shared/v12.lua',
    'shared/v13.lua',
    'shared/v14.lua'
}

client_scripts {
    'client/main.lua',
    'client/damage.lua',
    'client/effects.lua',
    'client/lifecycle.lua',
    'client/ui.lua',
    'client/debug.lua',
    'client/visual_guard.lua',
    'client/v8.lua',
    'client/v9.lua',
    'client/v10.lua',
    'client/v11.lua',
    'client/v12.lua',
    'client/v13.lua',
    'client/v14.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/persistence.lua',
    'server/main.lua',
    'server/authority.lua',
    'server/commands.lua',
    'server/advanced.lua',
    'server/v6.lua',
    'server/testlab.lua',
    'server/v8.lua',
    'server/v9.lua',
    'server/v10.lua',
    'server/v11.lua',
    'server/v12.lua',
    'server/v13.lua',
    'server/v14.lua'
}

dependencies {
    'qb-core',
    'oxmysql'
}
