Config = {}

Config.Debug = false

Config.Locale = 'pt-br'

Config.AccentColor = GetConvar('mri:color', '#00E699')

Config.AllowAccentOverride = false

Config.CameraEffects = true
Config.CameraEffectType = 'cinema'
Config.StreamerMode = false

Config.Music = {
    enabled = true,
    url = 'https://youtu.be/xAgUYyosqVM?si=G511dtT_olRxkkSZ',
    volume = 0.3,
    loop = true,
    autoplay = true,
}

Config.CharacterSlots = {
    defaultSlots = 3,
    maxSlots = 10,
}

Config.Preview = {
    default = {
        pedCoords = vector4(-1645.48, -1115.97, 13.03, 307.43),
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
    police = {
        pedCoords = vector4(404.68, -982.15, 29.28, 93.27),
        vehicleModel = `police`,
        vehicleCoords = vector4(409.13, -981.26, 29.27, 45.39),
        scenario = 'WORLD_HUMAN_COP_IDLES',
        enableSiren = true,
    },
    ambulance = {
        pedCoords = vector4(284.97, -572.22, 43.15, 67.13),
        vehicleModel = `ambulance`,
        vehicleCoords = vector4(284.97, -575.0, 43.15, 67.13),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        isNight = true,
        enableSiren = true,
        zoomOut = true,
    },
    mechanic = {
        pedCoords = vector4(534.47, -181.41, 54.28, 298.20),
        vehicleModel = `sultan`,
        vehicleCoords = vector4(532.79, -185.0, 54.24, 96.40),
        scenario = nil,
        hoodOpen = true,
        leanOnHood = true,
        zoomOut = true,
    },
}

-- Showroom: em vez de 1 ped que recarrega a cada slot, monta uma fileira com
-- 1 ped por personagem (roupa de cada um), cada um com animação idle. A câmera
-- desliza pro ped do slot focado e um holofote (DrawSpotLight) o destaca.
Config.Showroom = {
    -- ponto-base da fileira (chão) e direção que os peds encaram (pra câmera).
    origin = vector3(-1645.48, -1115.97, 13.03),
    heading = 307.43,
    spacing = 1.55, -- distância entre peds na fileira

    -- câmera relativa ao ped focado (offsets a partir do chão do ped).
    cam = {
        distance = 2.6,
        height = 0.55,     -- altura da câmera acima do chão do ped
        lookHeight = 0.6,  -- altura do ponto que a câmera mira
        fov = 36.0,
        transition = 0.75,  -- duração (s) do glide entre peds próximos (ease-in-out)
        cutDistance = 18.0, -- salto ACIMA disso corta com fade (não voa pelo mundo)
    },

    -- luz de preenchimento frontal (do lado da câmera) — ilumina o rosto/frente,
    -- que o holofote (de cima) deixa escuro.
    frontlight = {
        enabled = true,
        dist = 1.5,   -- distância na frente do ped (em direção à câmera)
        height = 0.95, -- altura acima do chão
        range = 4.5,  -- alcance da luz
        intensity = 3.0,
        r = 255, g = 246, b = 230, -- branco levemente quente
    },

    -- nome em 3D atrás do ped (DUI num quad world-space — profundidade + nitidez).
    nametag = {
        enabled = true,
        back = 0.29,   -- distância atrás do ped (metros)
        height = 1.56, -- altura do centro do nome acima do chão (metros)
        width = 7.40,  -- largura do painel no mundo (metros); altura = width/4 (DUI 4:1)
    },

    -- holofote no ped focado (args do nativo DrawSpotLight).
    spotlight = {
        height = 3.6,      -- altura do facho acima do ped
        r = 255, g = 255, b = 255,
        distance = 12.0,   -- alcance do facho
        brightness = 20.0,
        hardness = 0.4,    -- dureza da borda
        radius = 26.0,     -- raio do cone (maior = pool mais largo)
        falloff = 14.0,    -- queda da intensidade
    },

    -- catálogo de animações idle (fonte única: usado no modo de posicionar do
    -- /adminchar, no dropdown do painel e como sorteio de fallback).
    -- Cada item: { id, label } usa um cenário GTA (TaskStartScenarioInPlace);
    -- se tiver { dict, clip } toca um anim clip em loop (TaskPlayAnim).
    -- Dica: sentado/encostado ficam melhores posicionando o ped contra a
    -- geometria certa (parede, degrau, banco) — o preview do modo de posicionar
    -- mostra ao vivo antes de confirmar.
    animations = {
        -- Em pé — atitude / cool
        { id = 'WORLD_HUMAN_STAND_IMPATIENT',    label = 'Impaciente' },
        { id = 'WORLD_HUMAN_STAND_MOBILE',       label = 'No celular' },
        { id = 'WORLD_HUMAN_GUARD_STAND',        label = 'Braços cruzados' },
        { id = 'WORLD_HUMAN_GUARD_PATROL',       label = 'Guarda (alerta)' },
        { id = 'WORLD_HUMAN_COP_IDLES',          label = 'Policial (parado)' },
        { id = 'WORLD_HUMAN_STAND_ARMY',         label = 'Postura militar' },
        { id = 'WORLD_HUMAN_DRUG_DEALER',        label = 'De boa (mãos)' },
        { id = 'WORLD_HUMAN_DRUG_DEALER_HARD',   label = 'Durão' },
        { id = 'WORLD_HUMAN_HANG_OUT_STREET',    label = 'De boa na rua' },
        { id = 'WORLD_HUMAN_TOURIST_MAP',        label = 'Olhando mapa' },
        { id = 'WORLD_HUMAN_BINOCULARS',         label = 'Binóculos' },
        { id = 'WORLD_HUMAN_WINDOW_SHOP_BROWSE', label = 'Olhando vitrine' },
        { id = 'WORLD_HUMAN_CHEERING',           label = 'Comemorando' },
        -- Em pé — vícios / lazer (segura item)
        { id = 'WORLD_HUMAN_SMOKING',            label = 'Fumando' },
        { id = 'WORLD_HUMAN_SMOKING_POT',        label = 'Fumando (maconha)' },
        { id = 'WORLD_HUMAN_AA_SMOKE',           label = 'Fumando (relaxado)' },
        { id = 'WORLD_HUMAN_AA_COFFEE',          label = 'Tomando café' },
        { id = 'WORLD_HUMAN_DRINKING',           label = 'Bebendo' },
        { id = 'WORLD_HUMAN_PARTYING',           label = 'Curtindo (drink)' },
        { id = 'WORLD_HUMAN_STUPOR',             label = 'Bêbado (cambaleando)' },
        { id = 'WORLD_HUMAN_MOBILE_FILM_SHOCKING', label = 'Filmando com o celular' },
        { id = 'WORLD_HUMAN_PAPARAZZI',          label = 'Tirando foto' },
        { id = 'WORLD_HUMAN_MUSICIAN',           label = 'Músico' },
        -- Academia / físico (chão plano)
        { id = 'WORLD_HUMAN_MUSCLE_FLEX',        label = 'Flexionando (pose)' },
        { id = 'WORLD_HUMAN_MUSCLE_FREE_WEIGHTS', label = 'Halteres' },
        { id = 'WORLD_HUMAN_JOG_STANDING',       label = 'Correndo no lugar' },
        { id = 'WORLD_HUMAN_YOGA',               label = 'Yoga' },
        { id = 'WORLD_HUMAN_PUSH_UPS',           label = 'Flexões (chão)' },
        { id = 'WORLD_HUMAN_SIT_UPS',            label = 'Abdominais (chão)' },
        -- Trabalho (variedade)
        { id = 'WORLD_HUMAN_CLIPBOARD',          label = 'Prancheta' },
        { id = 'WORLD_HUMAN_HAMMERING',          label = 'Martelando' },
        -- Encostado (posicione contra uma parede)
        { id = 'WORLD_HUMAN_LEANING',            label = 'Encostado (parede)' },
        -- Sentado (posicione na geometria: degrau/muro/banco)
        { id = 'SIT_GROUND',                     label = 'Sentado no chão',   dict = 'amb@world_human_picnic@male@base', clip = 'base' },
        { id = 'WORLD_HUMAN_SEAT_STEPS',         label = 'Sentado (degrau)' },
        { id = 'WORLD_HUMAN_SEAT_WALL',          label = 'Sentado (muro)' },
        { id = 'WORLD_HUMAN_SEAT_LEDGE',         label = 'Sentado (beirada)' },
        { id = 'PROP_HUMAN_SEAT_BENCH',          label = 'Sentado (banco)' },
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
    createLocation = vector4(-66.28, -822.13, 285.61 - 1, 70.82),
}

Config.DeleteTables = {
}

Config.Appearance = {
    resource = 'auto',
    autoPreference = {
        'mri_Qappearance',
        'illenium-appearance',
        'fivem-appearance',
    },
}

return Config
