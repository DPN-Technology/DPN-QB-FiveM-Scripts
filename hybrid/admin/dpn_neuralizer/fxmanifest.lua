--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Diesel — CEO of DPN Technology'
description 'Advanced FiveM RP Neuralizer with admin immunity, server validation, NUI flash effects, cooldowns, and model source.'
version '2.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'model_source/*',
    'items/*',
    'docs/*',
    'stream/README_MODEL.txt'
}
