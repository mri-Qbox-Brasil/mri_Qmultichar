-- Container: a coyote's container lands at the port; dark inside, then the doors open onto Los Santos.

local ccfg = Config.Arrival.container
local fov = Config.Arrival.fov

local COWER = {
    male = { base = 'amb@code_human_cower@male@base', scared = 'amb@code_human_cower@male@idle_a', exit = 'amb@code_human_cower@male@exit' },
    female = { base = 'amb@code_human_cower@female@base', scared = 'amb@code_human_cower@female@idle_a', exit = 'amb@code_human_cower@female@exit' },
}

-- the player's crouch spot, as a fraction of the length from the doors
local PLAYER_DEPTH = 0.55

local function cowerSet(ped)
    return IsPedMale(ped) and COWER.male or COWER.female
end

local function cower(ped)
    local set = cowerSet(ped)
    if lib.requestAnimDict(set.base, 5000) then
        TaskPlayAnim(ped, set.base, 'base', 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
end

-- startled but still crouched (react_cowering's flinch is a standing one)
local function flinch(ped)
    local set = cowerSet(ped)
    if lib.requestAnimDict(set.scared, 5000) then
        local clips = { 'idle_a', 'idle_b', 'idle_c' }
        TaskPlayAnim(ped, set.scared, clips[math.random(#clips)], 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
end

-- stands up from the crouch, then walks each leg in order (no navmesh inside the container)
local function standAndWalk(ped, legs, heading)
    local set = cowerSet(ped)
    lib.requestAnimDict(set.exit, 5000)
    FreezeEntityPosition(ped, false)
    local seq = OpenSequenceTask()
    TaskPlayAnim(0, set.exit, 'exit', 4.0, -4.0, -1, 0, 0.0, false, false, false)
    for i, p in ipairs(legs) do
        TaskGoStraightToCoord(0, p.x, p.y, p.z, 1.0, -1, i == #legs and heading or 0.0, 0.3)
    end
    CloseSequenceTask(seq)
    TaskPerformSequence(ped, seq)
    ClearSequenceTask(seq)
end

local function headingTo(from, to)
    return GetHeadingFromVector_2d(to.x - from.x, to.y - from.y)
end

-- doors are part of the model: hold its opening animation on the first frame (closed)
local function holdDoorsClosed(ctx, box)
    if not lib.requestAnimDict(ccfg.openDict, 5000) then
        ctx.warn('animação das portas do contêiner não carregou')
        return nil
    end
    local pos = GetEntityCoords(box)
    local rot = GetEntityRotation(box, 2)
    local scene = CreateSynchronizedScene(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, 2)
    PlaySynchronizedEntityAnim(box, scene, ccfg.openAnim, ccfg.openDict, 1000.0, -8.0, 0, 1000.0)
    SetSynchronizedSceneHoldLastFrame(scene, true)
    SetSynchronizedScenePhase(scene, 0.0)
    SetSynchronizedSceneRate(scene, 0.0)
    -- applies the pose now instead of next frame (same as mri_supplyevent)
    ForceEntityAiAndAnimationUpdate(box)
    ctx.log('portas: animação de %.1f s, abrindo a partir de %.2f', GetAnimDuration(ccfg.openDict, ccfg.openAnim), ccfg.openPhase)
    return scene
end

local function groundAt(p)
    for _ = 1, 30 do
        local found, z = GetGroundZFor_3dCoord(p.x, p.y, p.z + 2.0, false)
        if found then return z end
        Wait(0)
    end
    return p.z - 1.0
end

-- runs onFrame every frame for ms; false when the player skipped
local function run(ctx, ms, onFrame)
    local startAt = GetGameTimer()
    while true do
        if ctx.skipped() then return false end
        local t = (GetGameTimer() - startAt) / ms
        if t >= 1.0 then return true end
        onFrame(t)
        Wait(0)
    end
end

local function stage(ctx, spawn)
    local model = ccfg.model
    if not lib.requestModel(model, 10000) then
        ctx.warn('modelo do contêiner inválido')
        return nil
    end
    local dmin, dmax = GetModelDimensions(model)
    local axis = ccfg.doorAxis >= 0 and 1 or -1
    local endY = axis > 0 and dmax.y or dmin.y
    local length = dmax.y - dmin.y
    local width = dmax.x - dmin.x
    ctx.log('contêiner: min %.2f %.2f %.2f, max %.2f %.2f %.2f', dmin.x, dmin.y, dmin.z, dmax.x, dmax.y, dmax.z)

    local fx, fy = ctx.forwardOf(spawn.heading)
    local door = vector3(spawn.x - fx * ccfg.gap, spawn.y - fy * ccfg.gap, spawn.z)
    ctx.streamArea(door.x, door.y, door.z)
    local ground = groundAt(door)

    -- doors face the spawn: with the doors on -Y the model turns around
    local heading = axis > 0 and spawn.heading or (spawn.heading + 180.0) % 360.0
    local ex, ey = ctx.forwardOf(heading)
    local origin = vector3(door.x - ex * endY, door.y - ey * endY, ground - dmin.z)
    -- the animated model's collision keeps the doors closed; prop_ld_container is its open
    -- collision. Both go through CreateObject on the same spot, like jomidar-ammorobbery,
    -- since CreateObject offsets each model its own way and the pair is lined up that way
    if not lib.requestModel(ccfg.collisionModel, 10000) then
        ctx.warn('modelo de colisão do contêiner inválido')
        return nil
    end
    local box = ctx.own(CreateObject(model, origin.x, origin.y, origin.z, false, false, false))
    local shell = ctx.own(CreateObject(ccfg.collisionModel, origin.x, origin.y, origin.z, false, false, false))
    SetModelAsNoLongerNeeded(model)
    SetModelAsNoLongerNeeded(ccfg.collisionModel)
    SetEntityHeading(box, heading)
    SetEntityHeading(shell, heading)
    SetEntityVisible(shell, false, false)
    -- lift or drop both together until the box stands on the ground
    local dz = ground - (GetEntityCoords(box).z + dmin.z)
    for _, e in ipairs({ box, shell }) do
        local p = GetEntityCoords(e)
        SetEntityCoordsNoOffset(e, p.x, p.y, p.z + dz, false, false, false)
        FreezeEntityPosition(e, true)
    end

    local floorZ = dmin.z + ccfg.floor
    -- inner point `depth` meters in from the doors, in the container's own space
    local function inside(x, depth, z)
        return GetOffsetFromEntityInWorldCoords(box, x, endY - axis * depth, floorZ + (z or 0.0))
    end

    -- the model's bottom is not the inner floor: probe it straight down from inside
    -- starts low enough to stay under the roof even if the estimate is off
    local probeFrom = inside(0.0, length * 0.5, 1.2)
    local probeTo = inside(0.0, length * 0.5, -2.5)
    local floorHit
    for _ = 1, 30 do
        local ray = StartExpensiveSynchronousShapeTestLosProbe(probeFrom.x, probeFrom.y, probeFrom.z, probeTo.x, probeTo.y, probeTo.z, 17, 0, 7)
        local _, hit, at = GetShapeTestResult(ray)
        if hit == 1 then
            floorHit = at.z
            break
        end
        Wait(0)
    end
    if floorHit then
        floorZ = floorZ + (floorHit - inside(0.0, length * 0.5, 0.0).z)
        ctx.log('contêiner: piso a %.2f m da base do modelo', floorZ - dmin.z)
    else
        ctx.warn('não achei o piso do contêiner; usando floor = %.2f do config', ccfg.floor)
    end

    local doorScene = holdDoorsClosed(ctx, box)

    local ped = PlayerPedId()
    local spot = inside(0.25, length * PLAYER_DEPTH)
    SetEntityCoordsNoOffset(ped, spot.x, spot.y, spot.z + 1.0, false, false, false)
    SetEntityHeading(ped, spawn.heading)
    FreezeEntityPosition(ped, true)
    cower(ped)

    local center = inside(0.0, length * 0.5, 0.0)
    local migrants = {}
    -- only at the back: near the doors they clip through the walls
    local slots = {
        { x = -(width / 2 - 0.5), depth = length * 0.72 },
        { x = width / 2 - 0.5, depth = length * 0.84 },
    }
    for i, slot in ipairs(slots) do
        local m = ccfg.migrants[(i - 1) % #ccfg.migrants + 1]
        if lib.requestModel(m, 8000) then
            local p = inside(slot.x, slot.depth, 0.0)
            local npc = CreatePed(26, m, p.x, p.y, p.z, 0.0, false, false)
            SetModelAsNoLongerNeeded(m)
            -- same placement as the player: CreatePed's z is not the ped origin
            SetEntityCoordsNoOffset(npc, p.x, p.y, p.z + 1.0, false, false, false)
            SetEntityHeading(npc, headingTo(p, center))
            SetBlockingOfNonTemporaryEvents(npc, true)
            SetEntityInvincible(npc, true)
            FreezeEntityPosition(npc, true)
            cower(npc)
            migrants[#migrants + 1] = npc
        end
    end

    return {
        box = box, doorScene = doorScene, migrants = migrants, ped = ped,
        heading = heading, axis = axis,
        inside = inside, length = length, width = width, endY = endY, floorZ = floorZ,
        doorCenter = inside(0.0, 0.0, 1.2),
        shell = shell,
    }
end

-- thin warm beams through the door seams, drawn every frame
local function drawSeams(s)
    for i = -1, 1 do
        local from = s.inside(i * 0.35, -0.4, 1.0 + i * 0.25)
        local to = s.inside(i * 0.2, 1.8, 0.2)
        local d = to - from
        DrawSpotLight(from.x, from.y, from.z, d.x, d.y, d.z, 255, 214, 160, 6.0, 9.0, 0.0, 3.5, 30.0)
    end
end

-- ===== sound design: GTA sounds played from the container itself (Config.Arrival.container.sounds)

local sfx = ccfg.sounds
local loops = {}

local function loadBanks(ctx)
    local missing = {}
    for _, name in ipairs(sfx.banks.script) do
        local ok = false
        for _ = 1, 20 do
            ok = RequestScriptAudioBank(name, false)
            if ok then break end
            Wait(0)
        end
        if not ok then missing[#missing + 1] = name end
    end
    for _, name in ipairs(sfx.banks.ambient) do
        local ok = false
        for _ = 1, 20 do
            ok = RequestAmbientAudioBank(name, false)
            if ok then break end
            Wait(0)
        end
        if not ok then missing[#missing + 1] = name end
    end
    if #missing > 0 then ctx.log('bancos de áudio que não carregaram: %s', table.concat(missing, ', ')) end
end

local function releaseBanks()
    for _, name in ipairs(sfx.banks.script) do ReleaseNamedScriptAudioBank(name) end
    ReleaseAmbientAudioBank()
end

-- one sound at a point; def = { name, soundset } (soundset nil when the dump lists it as 0)
local function soundAt(def, p)
    local id = GetSoundId()
    PlaySoundFromCoord(id, def[1], p.x, p.y, p.z, def[2], false, 0, false)
    return id
end

local function oneShot(def, p)
    ReleaseSoundId(soundAt(def, p))
end

local function startLoop(key, def, p)
    loops[key] = soundAt(def, p)
end

local function stopLoop(key)
    local id = loops[key]
    if not id then return end
    StopSound(id)
    ReleaseSoundId(id)
    loops[key] = nil
end

local function stopAllLoops()
    for key in pairs(loops) do stopLoop(key) end
end

local function cleanup(s)
    ClearTimecycleModifier()
    StopGameplayCamShaking(true)
    stopAllLoops()
    releaseBanks()
    if not s then return end
    FreezeEntityPosition(s.ped, false)
    -- the migrants finish walking out, then go their own way
    SetTimeout(5000, function()
        for _, npc in ipairs(s.migrants) do
            if DoesEntityExist(npc) then
                FreezeEntityPosition(npc, false)
                TaskWanderStandard(npc, 10.0, 10)
            end
        end
    end)
end

local function scene(ctx, spawn, s)
    local beats = ccfg.beats
    local ped = s.ped

    -- 1. dark: the face, the seams of light, the metal groaning, a ship far away
    SetTimecycleModifier(ccfg.darkness)
    SetTimecycleModifierStrength(1.0)
    local center = s.inside(0.0, s.length * 0.5, 1.2)
    local fx, fy = ctx.forwardOf(spawn.heading)
    local farAway = vector3(center.x + fx * 90.0, center.y + fy * 90.0, center.z + 10.0)
    startLoop('creak', sfx.creakLoop, center)
    local nextCreak = GetGameTimer() + 900
    local hornAt = GetGameTimer() + 1400
    local function creaks()
        local now = GetGameTimer()
        if now >= nextCreak then
            oneShot(sfx.creaks[math.random(#sfx.creaks)], s.inside((math.random() - 0.5) * s.width, math.random() * s.length, 2.0))
            nextCreak = now + math.random(1600, 3200)
        end
        if hornAt and now >= hornAt then
            hornAt = nil
            oneShot(sfx.horn, farAway)
        end
    end
    -- the crouched head, from the geometry: bone coords still hold the pre-teleport pose this frame
    local head = s.inside(0.25, s.length * PLAYER_DEPTH, 0.75)
    local camA = ctx.newCam(36.0)
    local fromA = s.inside(0.9, s.length * PLAYER_DEPTH - 1.1, 0.7)
    SetCamCoord(camA, fromA.x, fromA.y, fromA.z)
    PointCamAtCoord(camA, head.x, head.y, head.z)
    ctx.cutTo(camA)
    ctx.reveal()
    ctx.caption('container_1', beats.dark - 600)
    local toA = fromA + (head - fromA) * 0.25
    if not run(ctx, beats.dark, function(t)
        local k = t * t * (3 - 2 * t)
        SetCamCoord(camA, fromA.x + (toA.x - fromA.x) * k, fromA.y + (toA.y - fromA.y) * k, fromA.z + (toA.z - fromA.z) * k)
        drawSeams(s)
        creaks()
    end) then return false end

    -- 2. the crane drops the container: every impact layer at once
    for _, def in ipairs(sfx.impact) do oneShot(def, center) end
    ShakeCam(camA, 'LARGE_EXPLOSION_SHAKE', 0.22)
    for _, npc in ipairs(s.migrants) do flinch(npc) end
    flinch(ped)
    ctx.caption('container_2', beats.impact - 400)
    local settled = false
    if not run(ctx, beats.impact, function(t)
        if not settled and t > 0.35 then
            settled = true
            StopCamShaking(camA, false)
            for _, npc in ipairs(s.migrants) do cower(npc) end
            cower(ped)
        end
        drawSeams(s)
        creaks()
    end) then return false end

    -- 3. the doors open and the light floods in
    local camB = ctx.newCam(fov)
    local fromB = s.inside(-0.45, s.length * PLAYER_DEPTH + 1.0, 1.4)
    SetCamCoord(camB, fromB.x, fromB.y, fromB.z)
    PointCamAtCoord(camB, s.doorCenter.x, s.doorCenter.y, s.doorCenter.z)
    ctx.cutTo(camB)
    stopLoop('creak')
    oneShot(sfx.door, s.doorCenter)
    oneShot(sfx.flash, s.doorCenter)
    oneShot(sfx.gulls, vector3(s.doorCenter.x + fx * 20.0, s.doorCenter.y + fy * 20.0, s.doorCenter.z + 8.0))
    ctx.nui('storyFlash')
    if s.doorScene then
        SetSynchronizedScenePhase(s.doorScene, ccfg.openPhase)
        SetSynchronizedSceneRate(s.doorScene, 1.0)
        ForceEntityAiAndAnimationUpdate(s.box)
    end
    local opened = false
    if not run(ctx, beats.open, function(t)
        local k = math.min(1.0, (t * beats.open) / ccfg.doorOpenMs)
        SetTimecycleModifierStrength(math.max(0.0, 1.0 - k * 1.4))
        if not opened and k >= 1.0 then
            opened = true
            ClearTimecycleModifier()
            SetEntityCollision(s.box, false, true)
            ctx.caption('container_3', beats.open)
        end
        if k < 0.5 then drawSeams(s) end
    end) then return false end

    -- 4. out into the port, towards the camera; the ship again, further off
    oneShot(sfx.horn, vector3(farAway.x + fx * 60.0, farAway.y + fy * 60.0, farAway.z))
    local camC = ctx.newCam(fov)
    SetCamCoord(camC, spawn.x + fx * 3.2, spawn.y + fy * 3.2, spawn.z + 0.6)
    PointCamAtCoord(camC, s.doorCenter.x, s.doorCenter.y, s.doorCenter.z - 0.3)
    ctx.cutTo(camC)
    -- everyone lines up at the middle of the doorway before stepping out
    local doorway = s.inside(0.0, 0.5, 1.0)
    standAndWalk(ped, { doorway, vector3(spawn.x, spawn.y, spawn.z) }, spawn.heading)
    local rx, ry = ctx.rightOf(spawn.heading)
    for i, npc in ipairs(s.migrants) do
        SetTimeout(900 + i * 700, function()
            if not DoesEntityExist(npc) then return end
            local off = (i % 2 == 0) and 1.8 or -1.8
            local out = vector3(spawn.x + rx * off + fx * 2.0, spawn.y + ry * off + fy * 2.0, spawn.z)
            standAndWalk(npc, { doorway, out }, spawn.heading)
        end)
    end
    ctx.caption('container_4', beats.out - 600)
    if not ctx.hold(beats.out) then return false end

    -- the walk must not keep running under the player's control
    ClearPedTasks(ped)
    if #(GetEntityCoords(ped) - vector3(spawn.x, spawn.y, spawn.z)) > 2.5 then
        SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
    end
    SetEntityHeading(ped, spawn.heading)
    return true
end

Arrival.stories.container = function(ctx, spawn)
    loadBanks(ctx)
    local s = stage(ctx, spawn)
    if not s then return false end
    local ok = scene(ctx, spawn, s)
    cleanup(s)
    if ok then
        ctx.handBack(spawn, false)
    elseif ctx.skipped() then
        ctx.handBack(spawn, true)
        ok = true
    end
    ctx.releaseWhenGone(s.box, 40.0)
    ctx.releaseWhenGone(s.shell, 40.0)
    for _, npc in ipairs(s.migrants) do ctx.releaseWhenGone(npc, 25.0) end
    return ok
end
