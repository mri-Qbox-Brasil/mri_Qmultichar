fx_version 'cerulean'
game 'gta5'

name 'mri_Qmultichar'
description 'Multichar externo com NUI moderna baseada em shadcn/ui'
author 'MRI'
version '1.2.2'

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
    'client/showroom.lua',
    'client/controller.lua',
    'client/admin.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/panel.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/**/*',
    'locales/*.json',
    'data/*.json',
    'nametag.html',
}

provide 'qb-multichar'

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'

