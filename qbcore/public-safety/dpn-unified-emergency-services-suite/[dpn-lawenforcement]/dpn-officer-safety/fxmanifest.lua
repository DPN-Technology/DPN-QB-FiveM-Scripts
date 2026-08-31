--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dpn-officer-safety'
author 'Diesel — CEO of DPN Technology'
description 'Automated officer safety, panic, crash, welfare and pursuit monitoring'
version '4.0.0'

ui_page 'html/index.html'
shared_scripts { 'config.lua', 'shared/bridge.lua' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
files { 'html/index.html', 'html/style.css', 'html/app.js' }

dependencies { 'qb-core', 'oxmysql', 'dpn-le-core' }
