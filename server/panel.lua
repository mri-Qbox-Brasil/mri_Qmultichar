-- Config de painel (branding + opções da landing) gerida pelo /adminchar.
-- Segue o padrão do mri_Qspawn: JSON em data/config.json é a fonte de verdade,
-- CRUD gated por ACE, e broadcast em tempo real na alteração (sem restart).

local PANEL_FILE = 'data/config.json'

local defaultConfig = {
    branding = {
        title = 'MRI',
        subtitle = 'MULTICHARACTER',
        logoUrl = '',
    },
    landing = {
        showContinue = true,
    },
    -- música de fundo, trocada na aba Tela inicial (o valor vive no data/config.json)
    music = {
        enabled = false,
        url = '',
        volume = 0.3,
        loop = true,
        autoplay = true,
        -- faixas das outras fases da criação; vazio = segue a faixa da fase anterior
        cues = { creation = '', editor = '', arrival = '' },
    },
    -- histórias de chegada (client/stories/<id>.lua). spawn = onde o jogador termina a
    -- cena; no contêiner, onde ele pisa ao sair, de costas pro contêiner. Os valores
    -- vivem no data/config.json; aqui só o formato.
    arrivals = {
        container = { enabled = false, spawn = {}, track = '' },
        plane = { enabled = false, spawn = {}, track = '' },
    },
    -- abertura (tela de título antes do showroom): planos da cidade em loop, cada um
    -- { x, y, z, rx, rz, fov } (posição e rotação da câmera). Sem plano = sem abertura.
    intro = {
        enabled = false,
        shots = {},
    },
    -- hora e clima fixos enquanto a tela de personagens está aberta
    ambience = {
        enabled = false,
        hour = 19,
        minute = 0,
        weather = 'EXTRASUNNY',
    },
    -- slots de personagem geridos pelo painel (substituem os comandos).
    slots = {
        default = 3, -- slots que todo jogador tem por padrão
        max = 10,    -- teto pra conceder slots extra por jogador
    },
    -- posições do showroom (ordenadas): o i-ésimo personagem ocupa a i-ésima.
    -- cada uma: { x, y, z, heading, scenario }. vazio = usa a fileira automática do config.lua.
    showroom = {
        stages = {},
    },
}

local config = {}

---Preenche recursivamente as chaves que faltam em `target` a partir de `defaults`.
---@param target table
---@param defaults table
local function fillDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == 'table' then
            if type(target[key]) ~= 'table' then
                target[key] = {}
            end
            fillDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function loadFromDisk()
    local raw = LoadResourceFile(GetCurrentResourceName(), PANEL_FILE)
    if raw then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            config = decoded
            fillDefaults(config, defaultConfig)
            return
        end
        lib.print.warn('[mri_Qmultichar] data/config.json inválido, usando defaults')
    end

    config = {}
    fillDefaults(config, defaultConfig)
end

local function saveToDisk()
    local ok = SaveResourceFile(GetCurrentResourceName(), PANEL_FILE, json.encode(config, { indent = true }), -1)
    return ok == true or ok == 1
end

loadFromDisk()

---Checa se o source tem permissão de admin do painel.
---@param source integer
---@return boolean
function MultiCharIsAdmin(source)
    if not source or source == 0 then
        return true -- console
    end
    return IsPlayerAceAllowed(source, 'mri_Qmultichar.admin')
        or IsPlayerAceAllowed(source, 'command')
end

---Getter global consumido por outros scripts do servidor (ex.: getCharacters).
---@return table
function GetPanelConfig()
    return config
end

lib.callback.register('mri_Qmultichar:server:isAdmin', function(source)
    return MultiCharIsAdmin(source)
end)

lib.callback.register('mri_Qmultichar:server:getConfig', function(_source)
    return config
end)

lib.callback.register('mri_Qmultichar:server:saveConfig', function(source, payload)
    if not MultiCharIsAdmin(source) then
        return false, 'sem permissão'
    end
    if type(payload) ~= 'table' then
        return false, 'payload inválido'
    end

    -- garante o shape completo mesmo que o painel mande parcial
    fillDefaults(payload, defaultConfig)

    local music = payload.music
    music.enabled = music.enabled == true
    music.url = type(music.url) == 'string' and music.url:sub(1, 300) or ''
    music.volume = math.max(0.0, math.min(1.0, tonumber(music.volume) or 0.3))
    music.loop = music.loop ~= false
    music.autoplay = music.autoplay ~= false
    for _, cue in ipairs({ 'creation', 'editor', 'arrival' }) do
        local url = music.cues[cue]
        music.cues[cue] = type(url) == 'string' and url:sub(1, 300) or ''
    end
    -- only the stories that exist; anything else from an older config is dropped
    local arrivals = {}
    for id in pairs(defaultConfig.arrivals) do
        local a = type(payload.arrivals[id]) == 'table' and payload.arrivals[id] or {}
        local p = a.spawn
        local placed = type(p) == 'table' and type(p.x) == 'number' and type(p.y) == 'number' and type(p.z) == 'number'
        arrivals[id] = {
            enabled = a.enabled == true,
            spawn = placed and { x = p.x, y = p.y, z = p.z, heading = tonumber(p.heading) or 0.0 } or {},
            -- the story's own track (same link formats as the music tab); empty = the arrival track
            track = type(a.track) == 'string' and a.track:sub(1, 300) or '',
        }
    end
    payload.arrivals = arrivals
    local intro = payload.intro
    intro.enabled = intro.enabled == true
    local shots = {}
    for _, s in ipairs(type(intro.shots) == 'table' and intro.shots or {}) do
        if type(s) == 'table' and type(s.x) == 'number' and type(s.y) == 'number' and type(s.z) == 'number' then
            shots[#shots + 1] = {
                x = s.x, y = s.y, z = s.z,
                rx = tonumber(s.rx) or 0.0,
                rz = tonumber(s.rz) or 0.0,
                fov = math.max(10.0, math.min(90.0, tonumber(s.fov) or 50.0)),
            }
        end
    end
    intro.shots = shots
    local ambience = payload.ambience
    ambience.enabled = ambience.enabled == true
    ambience.hour = math.floor(math.max(0, math.min(23, tonumber(ambience.hour) or 19)))
    ambience.minute = math.floor(math.max(0, math.min(59, tonumber(ambience.minute) or 0)))
    local knownWeather = false
    for _, w in ipairs(Config.Intro.weathers) do
        if w.id == ambience.weather then knownWeather = true break end
    end
    if not knownWeather then ambience.weather = 'EXTRASUNNY' end
    config = payload

    if not saveToDisk() then
        return false, 'falha ao salvar'
    end

    TriggerClientEvent('mri_Qmultichar:client:configChanged', -1, config, ArrivalsOffered(config))
    return true, config
end)

-- Registro como plugin do mri_Qadmin (aba embutida). Opcional: se o Qadmin não
-- estiver rodando, o /adminchar standalone continua funcionando.
local function doRegister()
    if GetResourceState('mri_Qadmin') ~= 'started' then return end
    local ok, err = pcall(function()
        exports['mri_Qadmin']:RegisterPlugin({
            id = 'multichar',
            label = 'Multichar',
            icon = 'users',
            resource = 'mri_Qmultichar',
            htmlPath = 'html/index.html',
            requiredPerms = { 'mri_Qmultichar.admin', 'command' },
            description = 'Branding e opções da tela inicial do multichar',
        })
    end)
    if not ok then
        lib.print.warn(string.format('[mri_Qmultichar] Falha ao registrar plugin no mri_Qadmin: %s', tostring(err)))
    end
end

-- Sinal oficial do Qadmin: emitido sempre que o registry dele fica pronto,
-- inclusive num `ensure mri_Qadmin` com este resource já de pé. Sem escutar,
-- o registro era one-shot no boot e o plugin sumia do painel a cada restart
-- do Qadmin, sem voltar até reiniciar o multichar.
AddEventHandler('mri_Qadmin:server:pluginsReady', doRegister)

-- Qadmin inicia/reinicia → re-registra automaticamente. Redundante com o
-- pluginsReady de propósito: cobre o caso de o registry já estar pronto antes
-- deste handler existir. O RegisterPlugin é idempotente por `id`.
AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == 'mri_Qadmin' then doRegister() end
end)

-- Este resource inicia com o Qadmin já rodando → registra imediatamente.
CreateThread(function()
    Wait(0)
    doRegister()
end)
