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
    return Config.AccentColor or '#00E699'
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

local function reopenPanel()
    adminOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openAdmin',
        accentColor = currentAccent(),
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
local function startPlacement(targetIndex)
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

            -- assume o controle: olhar, movimento, ataque/arma, scroll, setas, E...
            DisableControlAction(0, 1, true); DisableControlAction(0, 2, true)   -- olhar (mouse)
            DisableControlAction(0, 24, true); DisableControlAction(0, 25, true) -- atk/mira
            DisableControlAction(0, 47, true); DisableControlAction(0, 257, true)
            DisableControlAction(0, 140, true); DisableControlAction(0, 37, true)
            DisableControlAction(0, 14, true); DisableControlAction(0, 15, true) -- scroll
            DisableControlAction(0, 16, true); DisableControlAction(0, 17, true)
            DisableControlAction(0, 30, true); DisableControlAction(0, 31, true) -- move analog
            DisableControlAction(0, 32, true); DisableControlAction(0, 33, true) -- W/S
            DisableControlAction(0, 34, true); DisableControlAction(0, 35, true) -- A/D
            DisableControlAction(0, 21, true) -- shift (rápido)
            DisableControlAction(0, 22, true) -- espaço (câmera sobe)
            DisableControlAction(0, 36, true) -- ctrl (câmera desce)
            DisableControlAction(0, 38, true) -- E (colocar)
            DisableControlAction(0, 172, true); DisableControlAction(0, 173, true) -- setas ↑↓
            DisableControlAction(0, 174, true); DisableControlAction(0, 175, true) -- setas ←→

            -- ===== freecam: mouse gira, WASD/espaço/ctrl movem =====
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
            -- streaming segue a freecam (senão áreas distantes ficam sem chão/LOD)
            SetFocusPosAndVel(camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0)

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
        reopenPanel()
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

    -- fecha o painel
    if adminOpen then
        adminOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeAdmin' })
    end

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
    if adminOpen then
        adminOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeAdmin' })
    end
    local idx = type(data) == 'table' and tonumber(data.index) or nil
    startPlacement(idx)
end)
