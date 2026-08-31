--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'

name 'dpn-pg-7x'
author 'Diesel — CEO of DPN Technology'
description 'DPN PG-7X Admin Portal Gun for FiveM with Nearest Postal Integration, NUI, vertical paired two-way portals'
version '1.3.1'

lua54 'yes'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/server.lua'
}

ui_page 'html/index.html'

files {
    'destinations.json',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/*'
}
