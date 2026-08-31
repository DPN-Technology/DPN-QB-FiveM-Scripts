--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dpn-smart-city'
author 'Diesel — CEO of DPN Technology'Diesel" Sherk'
description 'Smart-city sensors, cameras, traffic controls and automated alerts'
version '4.0.0'

ui_page 'html/index.html'
shared_scripts { 'config.lua', 'shared/bridge.lua' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
files { 'html/index.html', 'html/style.css', 'html/app.js' }

dependencies { 'qb-core', 'oxmysql', 'dpn-le-core' }
