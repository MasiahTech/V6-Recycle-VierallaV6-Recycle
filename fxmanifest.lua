fx_version 'cerulean'
game 'gta5'
name "V6 Recycle / VierllaV6_Recycle"
author "Onecitgo"
version "0.1"
description "Recycling Script for city im making... No im not giving you support its open source figure it out"
this_is_a_map 'yes'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

server_scripts {
    'config/server.lua',
    'server/*',
}

client_scripts {
    'config/client.lua',
    'client/*'
}

files {
    'config/client.lua',
    'config/server.lua',
    'locales/*.json',
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'qbx_core'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'