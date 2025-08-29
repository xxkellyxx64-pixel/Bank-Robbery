fx_version 'adamant'
game 'gta5'
lua54 'yes'
version '1.0.0'
author 'miraf'

this_is_a_map 'yes'

shared_scripts {
    "@ox_lib/init.lua", -- This can be commented if you're not using ox_lib's notifications
	'config.lua',
	'locales/*.lua'
}

client_scripts {
	'client/*.lua',
}

server_scripts {
	'server/*.lua',
}