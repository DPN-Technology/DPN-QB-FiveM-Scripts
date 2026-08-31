--[[
    DPN Technology — DPN QB FiveM Scripts
    Created by Diesel, CEO of DPN Technology
    DPN-CSL: commercial resale requires explicit DPN Technology authorization.
]]

fx_version 'cerulean'
game 'gta5'
author 'Diesel — CEO of DPN Technology'
description 'DPN Sit Anywhere'
version '1.0'

shared_script {
    '@qb-core/shared/locale.lua',
    'config.lua'
}

client_script {
    'client.lua',
}

dependencies {
    'qb-core',
    'qb-target' -- Optional, but recommended
}