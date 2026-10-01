-- Painel admin do multichar (/adminchar), no estilo do mri_Qspawn.
-- Standalone abre a própria NUI em modo admin; quando embutido no mri_Qadmin
-- o React detecta ?embedded=1 e usa o bridge de plugin (sem passar por aqui).

local adminOpen = false
local placing = false

local function loadLocales()
    local file = LoadResourceFile(GetCurrentResourceName(), string.format('locales/%s.json', Config.Locale or 'pt-br'))
    if not file then return {} end
    local ok, decoded = pcall(json.decode, file)
    if ok and type(decoded) == 'table' then
        return decoded
    end
    return {}
end

local function currentAccent()
    local convar = GetConvar('mri:color', '')
    if convar ~= '' then return convar end
    return '#00E699'
end

RegisterCommand('adminchar', function()
    if adminOpen or placing then return end

    local isAdmin = lib.callback.await('mri_Qmultichar:server:isAdmin', false)
    if not isAdmin then
        lib.notify({
            type = 'error',
            description = locale('admin.no_permission'),
        })
        return
    end

    adminOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openAdmin',
        accentColor = currentAccent(),
        backgroundColor = GetConvar('mri:backgroundColor', ''),
        locales = loadLocales(),
    })
end, false)

RegisterNUICallback('adminGetConfig', function(_, cb)
    local config = lib.callback.await('mri_Qmultichar:server:getConfig', false)
    cb({
        success = true,
        config = config,
        locales = loadLocales(),
        animations = Config.Showroom.animations,
        weathers = Config.Intro.weathers,
    })
end)

RegisterNUICallback('adminSaveConfig', function(data, cb)
    local ok, result = lib.callback.await('mri_Qmultichar:server:saveConfig', false, data)
    cb({ success = ok == true, config = result })
end)

-- Slots: lista de players online + setar por player (substitui os comandos).
RegisterNUICallback('adminListPlayers', function(_, cb)
    cb(lib.callback.await('mri_Qmultichar:server:adminListPlayers', false))
end)

RegisterNUICallback('adminSetSlots', function(data, cb)
    cb(lib.callback.await('mri_Qmultichar:server:adminSetSlots', false, data.id, data.slots))
end)

RegisterNUICallback('adminClose', function(_, cb)
    if adminOpen then
        adminOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeAdmin' })
    end
    cb({ success = true })
end)

-- ===== Modo de posicionar (ghost ped + raycast + scroll) =============

local QADMIN_PLUGIN_ID = 'multichar'

local function isEmbeddedRequest(data)
    return type(data) == 'table' and data.embedded == true
end

local function hidePanel(embedded)
    if embedded then
        if GetResourceState('mri_Qadmin') == 'started' then
            pcall(function() exports['mri_Qadmin']:ClosePlugin(QADMIN_PLUGIN_ID) end)
        end
        return
    end
    if adminOpen then
        adminOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeAdmin' })
    end
end

local function reopenPanel(embedded)
    if embedded and GetResourceState('mri_Qadmin') == 'started' then
        local ok, opened = pcall(function() return exports['mri_Qadmin']:OpenPlugin(QADMIN_PLUGIN_ID) end)
        if ok and opened then return end
    end
    adminOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openAdmin',
        accentColor = currentAccent(),
        backgroundColor = GetConvar('mri:backgroundColor', ''),
        locales = loadLocales(),
    })
end

local function round2(n)
    return math.floor(n * 100 + 0.5) / 100
end

-- direção (forward) a partir de uma rotação de câmera (pitch em .x, yaw em .z)
local function dirFromRot(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

-- "right" horizontal (normalizado) a partir do forward — pro strafe do freecam
local function rightFromDir(fwd)
    local r = vector3(fwd.y, -fwd.x, 0.0)
    local len = #r
    if len < 0.0001 then return vector3(1.0, 0.0, 0.0) end
    return r / len
end

-- controles que o freecam toma pra si: olhar, movimento, ataque/arma, scroll, setas, E...
local FREECAM_CONTROLS = {
    1, 2,                   -- olhar (mouse)
    24, 25, 47, 257, 140, 37, -- atk/mira/arma
    14, 15, 16, 17,         -- scroll
    30, 31, 32, 33, 34, 35, -- movimento (analógico, W/S, A/D)
    21,                     -- shift (rápido)
    22, 36,                 -- espaço/ctrl (câmera sobe/desce)
    38,                     -- E
    172, 173, 174, 175,     -- setas
}

-- Um frame do freecam: mouse gira, WASD/espaço/ctrl movem, Shift acelera. O streaming
-- segue a câmera (senão áreas distantes ficam sem chão/LOD).
---@return vector3 camPos, vector3 camRot, vector3 fwd, boolean fast
local function stepFreecam(cam, camPos, camRot)
    for i = 1, #FREECAM_CONTROLS do
        DisableControlAction(0, FREECAM_CONTROLS[i], true)
    end

    local fast = IsDisabledControlPressed(0, 21)
    local lookX = GetDisabledControlNormal(0, 1)
    local lookY = GetDisabledControlNormal(0, 2)
    camRot = vector3(
        math.max(-89.0, math.min(89.0, camRot.x - lookY * 5.0)),
        0.0,
        camRot.z - lookX * 8.0
    )
    local fwd = dirFromRot(camRot)
    local right = rightFromDir(fwd)
    local spd = fast and 0.65 or 0.16
    local mx, my, mz = 0.0, 0.0, 0.0
    if IsDisabledControlPressed(0, 32) then mx, my, mz = mx + fwd.x, my + fwd.y, mz + fwd.z end
    if IsDisabledControlPressed(0, 33) then mx, my, mz = mx - fwd.x, my - fwd.y, mz - fwd.z end
    if IsDisabledControlPressed(0, 34) then mx, my = mx - right.x, my - right.y end
    if IsDisabledControlPressed(0, 35) then mx, my = mx + right.x, my + right.y end
    if IsDisabledControlPressed(0, 22) then mz = mz + 1.0 end
    if IsDisabledControlPressed(0, 36) then mz = mz - 1.0 end
    camPos = vector3(camPos.x + mx * spd, camPos.y + my * spd, camPos.z + mz * spd)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    SetCamRot(cam, camRot.x, camRot.y, camRot.z, 2)
    SetFocusPosAndVel(camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0)
    return camPos, camRot, fwd, fast
end

-- raycast de `from` na direção `dir` (até 300m); retorna o ponto de impacto
local function raycastFrom(from, dir)
    local to = from + dir * 300.0
    local handle = StartShapeTestRay(from.x, from.y, from.z, to.x, to.y, to.z, 1, PlayerPedId(), 0)
    local _, hit, coords = GetShapeTestResult(handle)
    if hit and hit ~= 0 then
        return coords
    end
    return nil
end

local function createGhost()
    local model = `mp_m_freemode_01`
    lib.requestModel(model, 10000)
    local p = GetEntityCoords(PlayerPedId())
    local ped = CreatePed(4, model, p.x, p.y, p.z, 0.0, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityAlpha(ped, 160, false)
    SetEntityCollision(ped, false, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    return ped
end

local function animIndexById(anims, id)
    for i = 1, #anims do
        if anims[i].id == id then return i end
    end
    return 1
end

local function placementHelp(anims, idx, editIndex, count)
    local head
    if editIndex then
        head = ('**Reposicionar posição %d**  \n[Enter] Salvar aqui'):format(editIndex)
    else
        head = ('**Adicionar posições**  \n[E] Colocar  ·  adicionadas: %d  \n[Enter] Concluir'):format(count or 0)
    end
    lib.showTextUI(
        ('%s  \n[WASD+Mouse] Voar  ·  [Espaço/Ctrl] Câmera ↑↓  ·  [Shift] rápido  \n[Scroll] Girar ped  ·  [↑/↓] Altura ped  ·  [←/→] Animação: %s  \n[Backspace] Cancelar'):format(head, anims[idx].label),
        { position = 'top-center' }
    )
end

-- targetIndex (1-based) opcional: se apontar uma posição existente, entra em modo
-- "reposicionar" (move só aquela; Enter salva onde o ghost estiver). Sem ele, é
-- modo "adicionar" (E acrescenta novas posições no fim; Enter salva tudo).
local function startPlacement(targetIndex, embedded)
    if placing then return end
    placing = true

    local anims = Config.Showroom.animations

    local cfgData = lib.callback.await('mri_Qmultichar:server:getConfig', false) or {}
    cfgData.showroom = cfgData.showroom or {}
    local stages = cfgData.showroom.stages or {}

    local editing = targetIndex and stages[targetIndex] ~= nil
    local animIdx = editing and animIndexById(anims, stages[targetIndex].scenario) or 1

    local ghost = createGhost()
    PlayShowroomAnim(ghost, anims[animIdx].id)
    placementHelp(anims, animIdx, editing and targetIndex or nil, #stages)

    -- freecam: câmera solta que voa (WASD + mouse) pra alcançar qualquer lugar
    -- (telhado, interior, beirada) — o raycast sai dela, não do olhar do player.
    local player = PlayerPedId()
    FreezeEntityPosition(player, true)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local camPos = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    SetCamRot(cam, camRot.x, camRot.y, camRot.z, 2)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    CreateThread(function()
        local save = false
        -- pose/heading/altura manuais do ped
        local rot = editing and (tonumber(stages[targetIndex].heading) or 0.0) or 0.0
        local zOff = editing and (tonumber(stages[targetIndex].zOffset) or 0.0) or 0.0
        local rotInit = editing -- em edição já vem do stage; em adição encara a câmera no 1º hit
        -- último chão sob a mira (pro Enter salvar no modo reposicionar)
        local curX, curY, curBaseZ, haveHit

        while placing do
            Wait(0)

            -- freecam: câmera solta (WASD + mouse); o raycast sai dela
            local fwd, fast
            camPos, camRot, fwd, fast = stepFreecam(cam, camPos, camRot)

            -- ===== mira no chão a partir da freecam =====
            local hit = raycastFrom(camPos, fwd)
            if hit then
                local found, groundZ = GetGroundZFor_3dCoord(hit.x, hit.y, hit.z + 3.0, false)
                local baseZ = found and groundZ or hit.z

                -- no modo adicionar, o 1º ped encara a câmera; depois é manual
                if not rotInit then
                    rot = GetHeadingFromVector_2d(camPos.x - hit.x, camPos.y - hit.y)
                    rotInit = true
                end

                -- scroll gira o ped (Shift = passo grosso)
                local rstep = fast and 22.5 or 3.0
                if IsDisabledControlJustPressed(0, 15) then rot = (rot + rstep) % 360.0
                elseif IsDisabledControlJustPressed(0, 14) then rot = (rot - rstep) % 360.0 end

                -- setas ↑/↓ sobem/abaixam o ped (offset por cima do chão)
                local vstep = fast and 0.03 or 0.008
                if IsDisabledControlPressed(0, 172) then zOff = zOff + vstep end
                if IsDisabledControlPressed(0, 173) then zOff = zOff - vstep end

                -- setas ←/→ trocam animação
                local changed = false
                if IsDisabledControlJustPressed(0, 175) then animIdx = animIdx % #anims + 1; changed = true
                elseif IsDisabledControlJustPressed(0, 174) then animIdx = (animIdx - 2) % #anims + 1; changed = true end
                if changed then
                    ClearPedTasksImmediately(ghost)
                    PlayShowroomAnim(ghost, anims[animIdx].id)
                    placementHelp(anims, animIdx, editing and targetIndex or nil, #stages)
                end

                local finalZ = baseZ + zOff
                SetEntityCoords(ghost, hit.x, hit.y, finalZ, false, false, false, false)
                SetEntityHeading(ghost, rot)
                curX, curY, curBaseZ, haveHit = hit.x, hit.y, baseZ, true

                -- E adiciona uma posição nova (só no modo adicionar)
                if not editing and IsDisabledControlJustPressed(0, 38) then
                    stages[#stages + 1] = {
                        x = round2(hit.x), y = round2(hit.y), z = round2(baseZ),
                        heading = round2(rot), zOffset = round2(zOff), scenario = anims[animIdx].id,
                    }
                    lib.notify({ type = 'success', description = ('Posição %d adicionada'):format(#stages) })
                    placementHelp(anims, animIdx, nil, #stages)
                end
            end

            -- Enter conclui (salva), Backspace cancela
            if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 201) then
                -- no modo reposicionar, grava a pose atual na posição alvo
                if editing and haveHit then
                    stages[targetIndex] = {
                        x = round2(curX), y = round2(curY), z = round2(curBaseZ),
                        heading = round2(rot), zOffset = round2(zOff), scenario = anims[animIdx].id,
                    }
                end
                save = true
                break
            end
            if IsDisabledControlJustPressed(0, 194) or IsDisabledControlJustPressed(0, 202) then
                break
            end
        end

        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        ClearFocus()
        FreezeEntityPosition(player, false)

        if save then
            cfgData.showroom.stages = stages
            lib.callback.await('mri_Qmultichar:server:saveConfig', false, cfgData)
        end

        if DoesEntityExist(ghost) then DeleteEntity(ghost) end
        lib.hideTextUI()
        placing = false
        reopenPanel(embedded)
    end)
end

-- teleporta o player até a posição salva (pra conferir o local in-game)
RegisterNUICallback('adminTeleportStage', function(data, cb)
    cb({ success = true })
    local idx = type(data) == 'table' and tonumber(data.index) or nil
    if not idx then return end

    local cfgData = lib.callback.await('mri_Qmultichar:server:getConfig', false) or {}
    local stages = cfgData.showroom and cfgData.showroom.stages
    local s = stages and stages[idx]
    if not s or type(s.x) ~= 'number' then return end

    hidePanel(isEmbeddedRequest(data))

    CreateThread(function()
        DoScreenFadeOut(300)
        while not IsScreenFadedOut() do Wait(0) end

        local ped = PlayerPedId()
        local zBase = tonumber(s.z) or Config.Showroom.origin.z
        SetFocusPosAndVel(s.x, s.y, zBase, 0.0, 0.0, 0.0)
        local waited = 0
        while waited < 3000 do
            RequestCollisionAtCoord(s.x, s.y, zBase)
            if HasCollisionLoadedAroundEntity(ped) then break end
            Wait(50); waited = waited + 50
        end

        local found, gz = GetGroundZFor_3dCoord(s.x, s.y, zBase + 3.0, false)
        SetEntityCoords(ped, s.x, s.y, (found and gz or zBase), false, false, false, false)
        SetEntityHeading(ped, tonumber(s.heading) or 0.0)
        ClearFocus()
        Wait(150)
        DoScreenFadeIn(400)
    end)
end)

RegisterNUICallback('adminEnterPlacement', function(data, cb)
    cb({ success = true })
    if placing then return end
    local embedded = isEmbeddedRequest(data)
    hidePanel(embedded)
    local idx = type(data) == 'table' and tonumber(data.index) or nil
    startPlacement(idx, embedded)
end)

-- ===== Chegadas (capítulo Chegada da criação) ========================

-- Ponto de uma chegada = onde o admin está agora. Dentro de um veículo vale o veículo
-- (a atracação do barco é marcada pilotando até ela, de frente pra onde ele chega).
RegisterNUICallback('adminCaptureArrival', function(_, cb)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local entity = veh ~= 0 and veh or ped
    local c = GetEntityCoords(entity)
    cb({ success = true, pose = { x = round2(c.x), y = round2(c.y), z = round2(c.z), heading = round2(GetEntityHeading(entity)) } })
end)

-- Toca a chegada salva no próprio admin, numa instância à parte (o veículo da cena é
-- local), e reabre o painel no fim. O admin termina no destino.
RegisterNUICallback('adminTestArrival', function(data, cb)
    cb({ success = true })
    if type(data) ~= 'table' or type(data.id) ~= 'string' or Arrival.isPlaying() then return end
    local embedded = isEmbeddedRequest(data)

    local cfgData = lib.callback.await('mri_Qmultichar:server:getConfig', false) or {}
    local a = cfgData.arrivals and cfgData.arrivals[data.id]
    if not a then return end

    local player = exports.qbx_core:GetPlayerData()
    local ci = player and player.charinfo or {}
    hidePanel(embedded)
    CreateThread(function()
        TriggerServerEvent('mri_Qmultichar:server:setBucket', 2)
        Prelude.takeCamera()
        Arrival.play(data.id, a, {
            name = ('%s %s'):format(ci.firstname or '', ci.lastname or ''),
            nationality = ci.nationality or '',
            birthdate = ci.birthdate or '',
        })
        TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
        reopenPanel(embedded)
    end)
end)

-- ===== Abertura (planos da tela de título) ============================

local capturing = false

local function shotHelp(index, fov)
    local head = index and ('**Refazer plano %d**'):format(index) or '**Novo plano da abertura**'
    lib.showTextUI(
        ('%s  \n[WASD+Mouse] Voar  ·  [Espaço/Ctrl] Câmera ↑↓  ·  [Shift] rápido  \n[Scroll] Zoom: %.0f°  \n[Enter] Salvar plano  ·  [Backspace] Cancelar'):format(head, fov),
        { position = 'top-center' }
    )
end

-- Freecam pra enquadrar um plano; Enter grava posição, rotação e zoom da câmera e salva.
-- index (1-based) = refaz aquele plano, partindo dele; sem index, acrescenta no fim.
local function startShotCapture(index, embedded)
    if capturing or placing then return end
    capturing = true

    local cfgData = lib.callback.await('mri_Qmultichar:server:getConfig', false) or {}
    cfgData.intro = cfgData.intro or {}
    local shots = type(cfgData.intro.shots) == 'table' and cfgData.intro.shots or {}
    local editing = index and shots[index] or nil

    local player = PlayerPedId()
    FreezeEntityPosition(player, true)
    local camPos, camRot, fov
    if editing then
        camPos = vector3(editing.x, editing.y, editing.z)
        camRot = vector3(tonumber(editing.rx) or 0.0, 0.0, tonumber(editing.rz) or 0.0)
        fov = tonumber(editing.fov) or 50.0
    else
        camPos = GetGameplayCamCoord()
        camRot = GetGameplayCamRot(2)
        fov = GetGameplayCamFov()
    end
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    SetCamRot(cam, camRot.x, camRot.y, camRot.z, 2)
    SetCamFov(cam, fov)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    shotHelp(editing and index or nil, fov)

    CreateThread(function()
        local save = false
        while true do
            Wait(0)
            local _, fast
            camPos, camRot, _, fast = stepFreecam(cam, camPos, camRot)

            -- scroll pra cima aproxima (fov menor), pra baixo afasta
            local step = fast and 5.0 or 1.0
            local zoomed = false
            if IsDisabledControlJustPressed(0, 15) then fov = math.max(10.0, fov - step); zoomed = true
            elseif IsDisabledControlJustPressed(0, 14) then fov = math.min(90.0, fov + step); zoomed = true end
            if zoomed then
                SetCamFov(cam, fov)
                shotHelp(editing and index or nil, fov)
            end

            if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 201) then
                save = true
                break
            end
            if IsDisabledControlJustPressed(0, 194) or IsDisabledControlJustPressed(0, 202) then
                break
            end
        end

        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        ClearFocus()
        FreezeEntityPosition(player, false)
        lib.hideTextUI()

        if save then
            local shot = {
                x = round2(camPos.x), y = round2(camPos.y), z = round2(camPos.z),
                rx = round2(camRot.x), rz = round2(camRot.z % 360.0), fov = round2(fov),
            }
            if editing then shots[index] = shot else shots[#shots + 1] = shot end
            cfgData.intro.shots = shots
            lib.callback.await('mri_Qmultichar:server:saveConfig', false, cfgData)
        end

        capturing = false
        reopenPanel(embedded)
    end)
end

RegisterNUICallback('adminCaptureShot', function(data, cb)
    cb({ success = true })
    if capturing or placing then return end
    local embedded = isEmbeddedRequest(data)
    hidePanel(embedded)
    startShotCapture(type(data) == 'table' and tonumber(data.index) or nil, embedded)
end)

-- Toca a abertura salva (com a hora e o clima do menu, se ligados) até Enter ou
-- Backspace, e reabre o painel. O admin fica onde estava.
RegisterNUICallback('adminTestIntro', function(data, cb)
    cb({ success = true })
    if capturing or placing or Intro.isPlaying() then return end
    local embedded = isEmbeddedRequest(data)
    local cfgData = lib.callback.await('mri_Qmultichar:server:getConfig', false) or {}

    hidePanel(embedded)
    CreateThread(function()
        local player = PlayerPedId()
        FreezeEntityPosition(player, true)
        Intro.ambienceStart(cfgData.ambience)
        SendNUIMessage({ action = 'introPreview', branding = cfgData.branding })

        Intro.play(cfgData, true)

        SendNUIMessage({ action = 'introPreviewEnd' })
        Intro.ambienceStop()
        RenderScriptCams(false, false, 0, true, true)
        FreezeEntityPosition(player, false)
        DoScreenFadeIn(Config.Intro.dipMs)
        reopenPanel(embedded)
    end)
end)
