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
