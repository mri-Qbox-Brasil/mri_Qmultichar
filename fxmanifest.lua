fx_version 'cerulean'
game 'gta5'

name 'mri_Qmultichar'
description 'Multichar externo com NUI moderna baseada em shadcn/ui'
author 'MRI'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'config.themes.lua',
}

client_scripts {
    'client/main.lua',
    'client/camera.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/commands.lua',
}

ui_page 'html/dist/index.html'

files {
    'html/index.html',
    'html/dist/**/*',
}

provide 'qb-multichar'

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'

