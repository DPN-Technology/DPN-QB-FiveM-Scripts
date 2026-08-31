--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dpn-real-traffic'
author 'Diesel — CEO of DPN Technology'Diesel" Sherk'
description 'Advanced realistic AI traffic for QBCore with emergency vehicle yielding and ts_Trafficlights compatibility.'
version '1.0.0'

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependency 'qb-core'
