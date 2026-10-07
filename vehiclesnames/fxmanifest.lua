fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'Lyla'
description 'Browse resource folders and list every vehicle spawncode in a vehicle pack to copy, or spawn directly'

shared_script 'config.lua'

client_script 'client.lua'
server_scripts { 'server.lua', 'server.js' }

ui_page 'ui/index.html'
files { 'ui/index.html' }
