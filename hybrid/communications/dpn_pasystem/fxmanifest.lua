--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dpn_pasystem'
author 'Diesel — CEO of DPN Technology'
description 'Advanced in-vehicle PA system for emergency personnel using pma-voice proximity override.'
version '2.0.2'

ui_page 'html/index.html'

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependency 'pma-voice'

escrow_ignore {
    'shared/config.lua',
    'client/main.lua',
    'server/main.lua',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'README.md'
}
