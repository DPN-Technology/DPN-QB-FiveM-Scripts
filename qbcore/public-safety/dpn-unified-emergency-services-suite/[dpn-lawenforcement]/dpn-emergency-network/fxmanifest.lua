--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'

name 'dpn-emergency-network'
author 'Diesel — CEO of DPN Technology'Diesel" Sherk'
description 'Unified DPN emergency-service integration bus, health monitor, cross-system event correlation, and secure interoperability layer.'
version '4.0.0'
lua54 'yes'

shared_script 'config.lua'
client_script 'client/main.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'qb-core',
    'oxmysql'
}
