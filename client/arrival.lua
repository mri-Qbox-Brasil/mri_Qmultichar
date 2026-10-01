-- Arrival stories that close character creation; each story lives in client/stories/<id>.lua.

Arrival = {}
Arrival.stories = {} -- id -> function(ctx, spawn, a): boolean played

local acfg = Config.Arrival

local SKIP_CONTROLS = { 22, 201 } -- space, enter

local playing = false
local skipRequested = false
local storyTrack = '' -- the story's own track, handed to the NUI music player on reveal
local cams = {}
local leftovers = {}

local ctx = {}

function ctx.log(fmt, ...)
    DebugPrint(('[mri_Qmultichar] [CHEGADA] ' .. fmt):format(...))
end

function ctx.warn(fmt, ...)
    lib.print.warn(('[mri_Qmultichar] [CHEGADA] ' .. fmt):format(...))
end

function ctx.nui(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

function ctx.forwardOf(h)
    local r = math.rad(h)
    return -math.sin(r), math.cos(r)
end

function ctx.rightOf(h)
    local r = math.rad(h)
    return math.cos(r), math.sin(r)
end

function ctx.skipped()
    return skipRequested
end

function ctx.fadeOut(ms)
    if IsScreenFadedOut() then return end
    DoScreenFadeOut(ms)
    while not IsScreenFadedOut() do Wait(0) end
end

-- waits for cond(); bails out on skip, warns in F8 when it runs past maxMs
function ctx.waitFor(cond, maxMs, what)
    local deadline = GetGameTimer() + maxMs
    while not skipRequested do
        if cond() then return true end
        if GetGameTimer() > deadline then
            ctx.warn('%s passou de %d ms; a cena segue', what, maxMs)
            return false
        end
        Wait(0)
    end
    return true
end

-- sleeps ms, waking early on skip; returns false when skipped
function ctx.hold(ms)
    local untilAt = GetGameTimer() + ms
    while GetGameTimer() < untilAt do
        if skipRequested then return false end
        Wait(0)
    end
    return true
end

function ctx.streamArea(x, y, z)
    SetFocusPosAndVel(x, y, z, 0.0, 0.0, 0.0)
    NewLoadSceneStartSphere(x, y, z, 120.0, 0)
    local deadline = GetGameTimer() + acfg.streamTimeout
    while not IsNewLoadSceneLoaded() and GetGameTimer() < deadline do
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
    end
    if not IsNewLoadSceneLoaded() then
        ctx.warn('área em %.1f, %.1f não carregou em %d ms; seguindo', x, y, acfg.streamTimeout)
    end
    NewLoadSceneStop()
end

function ctx.newCam(fov)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, fov or acfg.fov)
    cams[#cams + 1] = cam
    return cam
end

function ctx.cutTo(cam)
    for i = 1, #cams do
        if cams[i] ~= cam then SetCamActive(cams[i], false) end
    end
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
end

local function destroyCams()
    for i = 1, #cams do
        if DoesCamExist(cams[i]) then DestroyCam(cams[i], false) end
    end
    cams = {}
end

-- entity cleaned up once the player is far or not looking
function ctx.releaseWhenGone(entity, nearDist)
    leftovers[#leftovers + 1] = entity
    CreateThread(function()
        while DoesEntityExist(entity) do
            local dist = #(GetEntityCoords(entity) - GetEntityCoords(PlayerPedId()))
            if dist > nearDist * 3 or (dist > nearDist and not IsEntityOnScreen(entity)) then
                DeleteEntity(entity)
                break
            end
            Wait(500)
        end
    end)
end

-- story-owned entity deleted when the story ends
function ctx.own(entity)
    leftovers[#leftovers + 1] = entity
    return entity
end

---Shows the story's first shot: lifts the prelude card (or fades in) and brings the letterbox.
function ctx.reveal(fadeMs)
    ctx.nui('arrivalStart', { letterbox = true, track = storyTrack })
    if Prelude.isCovering() then
        Prelude.reveal()
    else
        DoScreenFadeIn(fadeMs or 700)
    end
end

---One line of the story's narration (locales: story.<key>).
function ctx.caption(key, ms)
    ctx.nui('storyCaption', { key = key, ms = ms })
end

local function watchSkip()
    skipRequested = false
    CreateThread(function()
        while playing do
            DisableAllControlActions(0)
            for _, control in ipairs(SKIP_CONTROLS) do
                if IsDisabledControlJustPressed(0, control) and not skipRequested then
                    skipRequested = true
                    ctx.log('jogador pulou a cena')
                end
            end
            Wait(0)
        end
    end)
end

---Hands control back at the destination; snap = skipped or failed: teleports in the dark, no camera blend.
function ctx.handBack(spawn, snap)
    local ped = PlayerPedId()
    if snap then
        ctx.fadeOut(250)
        if IsPedInAnyVehicle(ped, false) then
            ClearPedTasksImmediately(ped)
        end
        ctx.streamArea(spawn.x, spawn.y, spawn.z)
        SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
        SetEntityHeading(ped, spawn.heading)
    end
    SetGameplayCamRelativeHeading(0.0)
    SetGameplayCamRelativePitch(0.0, 1.0)
    RenderScriptCams(false, not snap, snap and 0 or acfg.blendOutMs, true, true)
    destroyCams()
    ClearFocus()
    ctx.nui('storyCaptionClear')
    ctx.nui('arrivalEnd')
    if IsScreenFadedOut() or IsScreenFadingOut() then
        DoScreenFadeIn(600)
    end
end

-- ===== API ================================================================

function Arrival.isPlaying()
    return playing
end

---Plays the arrival story and hands control back at the destination. Blocks.
---@param id string story id (client/stories/<id>.lua)
---@param a table arrival from data/config.json ({ enabled, spawn })
---@param credit table { name, nationality, birthdate }
---@return boolean played
function Arrival.play(id, a, credit)
    if playing then return false end
    local story = Arrival.stories[id]
    local spawn = type(a) == 'table' and a.spawn or nil
    if not story or type(spawn) ~= 'table' or type(spawn.x) ~= 'number' then
        ctx.warn('história %s sem cena ou sem destino marcado no /adminchar', tostring(id))
        Prelude.finish(true)
        return false
    end
    spawn = { x = spawn.x, y = spawn.y, z = spawn.z, heading = tonumber(spawn.heading) or 0.0 }

    playing = true
    storyTrack = type(a.track) == 'string' and a.track or ''
    watchSkip()
    if Prelude.isActive() then
        Prelude.play(credit, { title = id }, ctx.skipped)
    else
        ctx.fadeOut(300)
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, true)
    ctx.log('tocando %s', id)

    local ok, played = pcall(story, ctx, spawn, a)
    if not ok then
        ctx.warn('a história %s deu erro: %s', id, tostring(played))
        played = false
    end
    if not played then
        ctx.warn('a história %s não tocou; indo direto pro destino', id)
        ctx.handBack(spawn, true)
    end
    Prelude.finish(false)

    SetEntityInvincible(PlayerPedId(), false)
    playing = false
    return played == true
end

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for i = 1, #leftovers do
        if DoesEntityExist(leftovers[i]) then DeleteEntity(leftovers[i]) end
    end
    if playing then
        destroyCams()
        RenderScriptCams(false, false, 0, true, true)
        ClearFocus()
        DoScreenFadeIn(0)
    end
end)
