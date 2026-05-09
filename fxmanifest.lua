fx_version 'cerulean'
game 'gta5'

name 'mri_Qmultichar'
description 'Multichar externo com NUI moderna baseada em shadcn/ui'
author 'MRI'
version '1.0.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/debug.lua',
}

client_scripts {
    'bridge/appearance/bridge.lua',
    'bridge/appearance/illenium.lua',
    'bridge/appearance/fivem.lua',
    'client/headshots.lua',
    'client/nui.lua',
    'client/main.lua',
    'client/camera.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/commands.lua',
}

ui_page 'html/index.html'

files {
    'html/**/*',
    'locales/*.json',
}

provide 'qb-multichar'

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'

