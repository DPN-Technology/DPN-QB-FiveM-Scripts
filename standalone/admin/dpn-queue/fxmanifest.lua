--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'

name 'dpn-queue'
author 'Diesel — CEO of DPN Technology'
description 'Advanced FiveM server queue with configurable reserved admin slots, priority, reconnect grace, and ACE/identifier checks.'
version '1.0.0'

lua54 'yes'

server_scripts {
    'config.lua',
    'server/main.lua'
}
