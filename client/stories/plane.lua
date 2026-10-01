-- Plane: the GTA Online intro cutscene (MP_INTRO_CONCAT) with narration captions.

local pcfg = Config.Arrival.plane

local PASSENGER_FEMALE = { [1] = true, [2] = true, [4] = true, [6] = true }

local function dressPassenger(ped, female)
    SetPedHeadBlendData(ped, math.random(0, 45), math.random(0, 45), 0, math.random(0, 45), math.random(0, 45), 0,
        female and 0.8 or 0.2, math.random(), 0.0, false)
    SetPedRandomComponentVariation(ped, 0)
    SetPedRandomProps(ped)
end

Arrival.stories.plane = function(ctx, spawn)
    local ped = PlayerPedId()
    local male = IsPedMale(ped)
    local me = male and 'MP_Male_Character' or 'MP_Female_Character'
    local other = male and 'MP_Female_Character' or 'MP_Male_Character'

    RequestCutsceneWithPlaybackList('MP_INTRO_CONCAT', male and 31 or 103, 8)
    if not ctx.waitFor(HasCutsceneLoaded, pcfg.loadTimeout, 'carregar a cutscene do avião') or ctx.skipped() then
        RemoveCutscene()
        return false
    end

    RegisterEntityForCutscene(0, me, 3, GetEntityModel(ped), 0)
    RegisterEntityForCutscene(ped, me, 0, 0, 0)
    SetCutsceneEntityStreamingFlags(me, 0, 1)
    RegisterEntityForCutscene(0, other, 3, 0, 64)

    local passengers = {}
    local origin = GetEntityCoords(ped)
    for i = 0, 6 do
        local female = PASSENGER_FEMALE[i] == true
        local model = female and `mp_f_freemode_01` or `mp_m_freemode_01`
        if lib.requestModel(model, 5000) then
            local p = CreatePed(26, model, origin.x, origin.y, origin.z - 10.0, 0.0, false, false)
            dressPassenger(p, female)
            RegisterEntityForCutscene(p, ('MP_Plane_Passenger_%d'):format(i), 0, 0, 64)
            passengers[#passengers + 1] = p
        end
    end

    StartCutscene(4)
    ctx.reveal(800)

    local startedAt = GetGameTimer()
    local nextCaption = 1
    while IsCutsceneActive() and not ctx.skipped() do
        local elapsed = GetGameTimer() - startedAt
        local c = pcfg.captions[nextCaption]
        if c and elapsed >= c.at then
            ctx.caption(c.key, 5200)
            nextCaption = nextCaption + 1
        end
        if elapsed > pcfg.cutAtMs then break end
        Wait(0)
    end
    ctx.log('cutscene do avião: %d ms, pulou: %s', GetGameTimer() - startedAt, tostring(ctx.skipped()))

    ctx.fadeOut(400)
    if IsCutsceneActive() then StopCutsceneImmediately() end
    RemoveCutscene()
    for i = 1, #passengers do
        if DoesEntityExist(passengers[i]) then DeleteEntity(passengers[i]) end
    end

    -- the cutscene leaves the ped where it ended: go to the destination in the dark
    ctx.handBack(spawn, true)
    return true
end
