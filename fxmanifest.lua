fx_version 'cerulean'
game 'gta5'

name 'hbs-pager'
description 'Item-based pager system using ox_inventory, ox_lib and qbx_core'
version '1.0.0'
author 'Hbs'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

shared_scripts { 'shared/config.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }

dependencies {
    'ox_inventory',
    'ox_lib',
    'qbx_core',
}
