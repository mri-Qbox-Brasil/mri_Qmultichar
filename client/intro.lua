-- Abertura: antes do showroom, planos lentos pela cidade com a marca e "Pressione
-- Enter" por cima (a NUI desenha a tela de título). Cada plano carrega a área dele
-- no escuro do corte. Aqui também ficam a hora e o clima fixos do menu.

Intro = Intro or {}

local cfg = Config.Intro

local function warn(msg)
    lib.print.warn(('[mri_Qmultichar] [ABERTURA] %s'):format(msg))
end

-- ===== hora e clima do menu ==========================================
-- Pelo contrato do qb-weathersync (DisableSync/EnableSync), que o Renewed-Weathersync
-- também atende. O Renewed repete o clima de `playerWeather` enquanto a sync está
-- desligada; outro weathersync ignora a chave.

local ambience = nil -- { hour, minute, weather } em vigor

local function applyAmbience()
    local a = ambience
    if not a then return end
    ClearOverrideWeather()
    SetWeatherTypeNowPersist(a.weather)
    NetworkOverrideClockTime(a.hour, a.minute, 0)
end

local function holdAmbience()
    LocalPlayer.state:set('playerWeather', ambience.weather, false)
    TriggerEvent('qb-weathersync:client:DisableSync')
    applyAmbience()
end

-- O Renewed zera o relógio quando a sync desliga: reaplica depois dele.
AddStateBagChangeHandler('syncWeather', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value == false and ambience then
        SetTimeout(0, applyAmbience)
    end
end)

---Fixa a hora e o clima do painel (aba Abertura), se ligado. Pode ser chamado de novo.
---@param a table|nil ambience do painel { enabled, hour, minute, weather }
function Intro.ambienceStart(a)
    if type(a) ~= 'table' or a.enabled ~= true then return end
    ambience = {
        hour = math.floor(tonumber(a.hour) or 19) % 24,
        minute = math.floor(tonumber(a.minute) or 0) % 60,
        weather = type(a.weather) == 'string' and a.weather ~= '' and a.weather or 'EXTRASUNNY',
    }
    holdAmbience()
end

---Volta a hora e o clima do servidor.
function Intro.ambienceStop()
    if not ambience then return end
    ambience = nil
    TriggerEvent('qb-weathersync:client:EnableSync')
end

---O OnPlayerLoaded da criação religa a sync (Renewed): o estúdio segue com a hora do menu.
function Intro.ambienceResume()
    if ambience then holdAmbience() end
end

-- ===== abertura ======================================================

local continued = false
local playing = false

-- direção da câmera a partir da rotação (pitch rx, heading rz, em graus)
local function dirFromRot(rx, rz)
    local x, z = math.rad(rx), math.rad(rz)
    local c = math.abs(math.cos(x))
    return vector3(-math.sin(z) * c, math.cos(z) * c, math.sin(x))
end

---Planos válidos do painel.
---@param intro table|nil
---@return table[]
local function validShots(intro)
    local out = {}
    for _, s in ipairs(type(intro) == 'table' and type(intro.shots) == 'table' and intro.shots or {}) do
        if type(s) == 'table' and type(s.x) == 'number' and type(s.y) == 'number' and type(s.z) == 'number' then
            out[#out + 1] = {
                x = s.x, y = s.y, z = s.z,
                rx = tonumber(s.rx) or 0.0, rz = tonumber(s.rz) or 0.0,
                fov = tonumber(s.fov) or 50.0,
            }
        end
    end
    return out
end

---A abertura está ligada e tem plano?
---@param panel table|nil config do painel
function Intro.enabled(panel)
    local intro = panel and panel.intro
    return type(intro) == 'table' and intro.enabled == true and #validShots(intro) > 0
end

local function awaitFadeOut()
    DoScreenFadeOut(cfg.dipMs)
    while not IsScreenFadedOut() do Wait(0) end
end

-- Carrega a área do plano (tela preta).
local function streamShot(s, dir)
    SetFocusPosAndVel(s.x, s.y, s.z, 0.0, 0.0, 0.0)
    NewLoadSceneStart(s.x, s.y, s.z, dir.x, dir.y, dir.z, cfg.loadDistance, 0)
    local deadline = GetGameTimer() + cfg.streamTimeout
    while not IsNewLoadSceneLoaded() and GetGameTimer() < deadline do Wait(0) end
    local loaded = IsNewLoadSceneLoaded()
    if not loaded then
        warn(('plano em %.0f, %.0f, %.0f não carregou em %d ms; segue montando'):format(s.x, s.y, s.z, cfg.streamTimeout))
    end
    NewLoadSceneStop()
end

-- Enter/Backspace pelos controles do jogo (teste do painel, sem foco na NUI).
local function pressedByControls()
    return IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201)
        or IsControlJustPressed(0, 194) or IsControlJustPressed(0, 202)
end

-- Um plano: clareia, anda `drift` metros pra frente e começa a escurecer antes do fim.
local function playShot(cam, s, dir, useControls)
    SetCamCoord(cam, s.x, s.y, s.z)
    SetCamRot(cam, s.rx, 0.0, s.rz, 2)
    SetCamFov(cam, s.fov)
    DoScreenFadeIn(cfg.dipMs)

    local startAt, dur = GetGameTimer(), cfg.shotTime * 1000
    local fadeAt = startAt + dur - cfg.dipMs
    local fading = false
    while not continued do
        local now = GetGameTimer()
        local t = (now - startAt) / dur
        if t >= 1.0 then break end
        local m = cfg.drift * t
        local x, y, z = s.x + dir.x * m, s.y + dir.y * m, s.z + dir.z * m
        SetCamCoord(cam, x, y, z)
        SetFocusPosAndVel(x, y, z, 0.0, 0.0, 0.0)
        if not fading and now >= fadeAt then
            DoScreenFadeOut(cfg.dipMs)
            fading = true
        end
        if useControls and pressedByControls() then continued = true end
        Wait(0)
    end
end

---Toca os planos em loop até o jogador continuar (Enter na tela de título ou
---Intro.continue). Termina com a tela preta, sem câmera de script própria.
---@param panel table config do painel
---@param useControls boolean|nil true = Enter/Backspace do jogo continuam (teste do painel)
---@return boolean played false = sem planos
function Intro.play(panel, useControls)
    local shots = validShots(panel and panel.intro)
    if #shots == 0 then return false end

    continued = false
    playing = true
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    local i = 1
    while not continued do
        local s = shots[i]
        local dir = dirFromRot(s.rx, s.rz)
        if not IsScreenFadedOut() then awaitFadeOut() end
        streamShot(s, dir)
        if continued then break end
        playShot(cam, s, dir, useControls)
        i = i % #shots + 1
    end

    awaitFadeOut()
    SetCamActive(cam, false)
    DestroyCam(cam, false)
    ClearFocus()
    playing = false
    return true
end

---A tela de título está no ar?
function Intro.isPlaying()
    return playing
end

---O jogador saiu da tela de título: a abertura termina no próximo frame.
function Intro.continue()
    continued = true
end

RegisterNUICallback('introContinue', function(_, cb)
    Intro.continue()
    cb({ success = true })
end)
