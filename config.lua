Config = {}

Config.Locale = 'pt'

-- Tema a ser utilizado (dark, blue, purple, green, red, orange, mri)
Config.Theme = 'mri'

-- Permitir que players mudem o tema (false = apenas admin pode mudar)
Config.AllowThemeChange = true

-- Configuração de música de fundo
-- Pode ser um link direto (URL) ou caminho relativo para arquivo na pasta html/sounds/
-- Exemplo de link: 'https://example.com/music.mp3'
-- Exemplo de arquivo local: 'sounds/background.mp3' (arquivo deve estar em html/sounds/)
-- Deixe vazio ou nil para desabilitar música
Config.Music = {
    enabled = true, -- Ativar/desativar música
    url = 'https://youtu.be/fregObNcHC8?si=_qk-0wCV-HJ4BVTQ', -- URL ou caminho do arquivo (ex: 'sounds/background.mp3' ou 'https://example.com/music.mp3')
    volume = 0.3, -- Volume (0.0 a 1.0)
    loop = true, -- Repetir música
    autoplay = true, -- Tentar iniciar automaticamente (YouTube geralmente inicia mutado até interação do usuário)
}

Config.CharacterSlots = {
    defaultSlots = 3, -- Número padrão de slots
    maxSlots = 10, -- Número máximo de slots permitidos
}

Config.Preview = {
    -- Preview padrão (quando não há job específico)
    -- Localização fixa do personagem e câmera (sempre a mesma)
    -- Local aberto: Praia de Vespucci (área aberta sem paredes)
    default = {
        pedCoords = vector4(-1645.48, -1115.97, 13.03, 307.43), -- Praia de Vespucci, local aberto
        scenarios = {
            'WORLD_HUMAN_COP_IDLES',
            'WORLD_HUMAN_STAND_MOBILE',
            'WORLD_HUMAN_STAND_IMPATIENT',
            'WORLD_HUMAN_GUARD_STAND',
            'WORLD_HUMAN_CLIPBOARD',
            'WORLD_HUMAN_SMOKING',
            'WORLD_HUMAN_AA_COFFEE',
            'WORLD_HUMAN_LEANING',
        },
    },
    -- Preview para Police
    -- Viatura atrás do personagem
    police = {
        pedCoords = vector4(404.68, -982.15, 29.28, 93.27), -- Localização do player (polícia)
        vehicleModel = `police`,
        vehicleCoords = vector4(409.13, -981.26, 29.27, 45.39), -- Viatura atrás
        scenario = 'WORLD_HUMAN_COP_IDLES',
        enableSiren = true, -- Giroflex ligado
    },
    -- Preview para Ambulance/EMS
    -- Ambulância atrás do médico
    ambulance = {
        pedCoords = vector4(284.97, -572.22, 43.15, 67.13), -- Localização do player (médico)
        vehicleModel = `ambulance`,
        vehicleCoords = vector4(284.97, -575.0, 43.15, 67.13), -- Ambulância atrás
        scenario = 'WORLD_HUMAN_CLIPBOARD', -- Médico com prancheta
        isNight = true, -- Definir noite para este preview
        enableSiren = true, -- Giroflex ligado
         zoomOut = true, -- Zoom out para ver carro também
    },
    -- Preview para Mechanic
    -- Carro atrás, mecânico apoiado no capô com chave
    mechanic = {
        pedCoords = vector4(534.47, -181.41, 54.28, 298.20), -- Localização do player (mecânico) - mais para trás
        vehicleModel = `sultan`, -- Carro para mexer
        vehicleCoords = vector4(532.79, -185.0, 54.24, 96.40), -- Carro atrás
        scenario = nil, -- Sem animação específica (será definida no leanOnHood)
        hoodOpen = true, -- Capô aberto
        leanOnHood = true, -- Apoiado no capô com chave
        zoomOut = true, -- Zoom out para ver carro também
    },
}

Config.CharacterCreation = {
    dateFormat = 'DD/MM/YYYY',
    dateMin = '01/01/1900',
    dateMax = '31/12/2006',
    limitNationalities = true,
    profanityWords = {
        ['bad word'] = true,
    },
    -- Localização onde o personagem será criado (illenium-appearance)
    -- Esta é a localização que será usada quando criar um personagem novo
    createLocation = vector4(-66.28, -822.13, 285.61 - 1, 70.82), -- Localização do illenium
}

-- Tabelas adicionais para deletar quando um personagem é deletado
-- Formato: {nome_da_tabela, nome_da_coluna}
-- Exemplo: {'player_vehicles', 'citizenid'} deleta todas as linhas onde citizenid = citizenid do personagem
-- As tabelas padrão do qbx_core já são deletadas automaticamente
Config.DeleteTables = {
    -- Adicione aqui tabelas customizadas que devem ser deletadas
    -- Exemplo:
    -- {'minha_tabela_custom', 'citizenid'},
    -- {'outra_tabela', 'player_id'},
}

return Config

