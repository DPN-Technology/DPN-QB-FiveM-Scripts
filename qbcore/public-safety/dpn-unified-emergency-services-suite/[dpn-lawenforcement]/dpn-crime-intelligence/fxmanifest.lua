--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dpn-crime-intelligence'
author 'Diesel — CEO of DPN Technology'Diesel" Sherk'
description 'DPN Crime Intelligence v2 - searchable people, vehicles, reports, watchlists, links, risk scoring and dispatch alerts.'
version '4.0.0'

shared_scripts { 'shared/config.lua' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js' }

dependencies { 'qb-core', 'oxmysql', 'dpn-le-core' }
