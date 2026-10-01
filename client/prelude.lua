-- Passage from the appearance editor into the arrival story (README: "Histórias de chegada").

Prelude = {}

local pcfg = Config.Prelude

local cam
local active = false   -- prelude owns the camera
local frozen = false
local covering = false -- chapter card covers the screen
local chapterAt = 0

local function nui(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

local function sound(key)
    local s = pcfg.sounds[key]
    if s then PlaySoundFrontend(-1, s[1], s[2], true) end
end

local function easeOutCubic(t) return 1 - (1 - t) ^ 3 end

local function lerpAngle(a, b, t)
    local d = ((b - a + 180.0) % 360.0) - 180.0
    return a + d * t
end

-- rotation (pitch, 0, yaw) looking from `from` at `to`
local function lookRot(from, to)
    local d = to - from
    local flat = math.sqrt(d.x * d.x + d.y * d.y)
    return vector3(math.deg(math.atan(d.z, flat)), 0.0, math.deg(math.atan(-d.x, d.y)))
end

local function unfreeze()
    if not frozen then return end
    frozen = false
    AnimpostfxStop(pcfg.postfx)
    SetTimeScale(1.0)
end

local function dropCamera()
    if cam and DoesCamExist(cam) then
        SetCamActive(cam, false)
        DestroyCam(cam, false)
    end
    cam = nil
end

function Prelude.isActive()
    return active
end

function Prelude.isCovering()
    return covering
end

---Takes the camera exactly as rendered; call it in the frame the editor releases its camera.
function Prelude.takeCamera()
    if active then return end
    active = true
    local c = GetFinalRenderedCamCoord()
    local r = GetFinalRenderedCamRot(2)
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.x, c.y, c.z, r.x, r.y, r.z, GetFinalRenderedCamFov(), true, 2)
    RenderScriptCams(true, false, 0, true, true)
end

---Crash zoom, freeze with the name, then the chapter card wipes in. Blocks until it covers the screen.
---@param credit table { name, nationality, birthdate }
---@param story table { title = locale key }
---@param skipped fun(): boolean
function Prelude.play(credit, story, skipped)
    if not active then return end
    local ped = PlayerPedId()

    -- crash zoom towards the face
    local fromPos = GetCamCoord(cam)
    local fromRot = GetCamRot(cam, 2)
    local fromFov = GetCamFov(cam)
    local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local toPos = fromPos + (head - fromPos) * pcfg.zoomPush
    local toRot = lookRot(toPos, head)
    local toFov = fromFov * pcfg.zoomFov
    sound('zoom')
    local startAt = GetGameTimer()
    while true do
        local t = math.min(1.0, (GetGameTimer() - startAt) / pcfg.zoomMs)
        local k = easeOutCubic(t)
        SetCamCoord(cam, fromPos.x + (toPos.x - fromPos.x) * k, fromPos.y + (toPos.y - fromPos.y) * k, fromPos.z + (toPos.z - fromPos.z) * k)
        SetCamRot(cam, fromRot.x + (toRot.x - fromRot.x) * k, 0.0, lerpAngle(fromRot.z, toRot.z, k), 2)
        SetCamFov(cam, fromFov + (toFov - fromFov) * k)
        if t >= 1.0 then break end
        Wait(0)
    end

    frozen = true
    SetTimeScale(0.0)
    AnimpostfxPlay(pcfg.postfx, 0, true)
    sound('freeze')
    sound('flash')
    nui('preludeFreeze', { credit = credit })
    -- GetGameTimer slows down with SetTimeScale, Wait does not: the freeze counts its own time
    local elapsed = 0
    while elapsed < pcfg.freezeMs and not skipped() do
        Wait(50)
        elapsed = elapsed + 50
    end

    -- the story stages under the card
    nui('preludeChapter', { title = story.title, hour = GetClockHours(), minute = GetClockMinutes() })
    sound('wipe')
    Wait(pcfg.wipeMs)
    covering = true
    chapterAt = GetGameTimer()
    unfreeze()
end

---Removes the card over the story's first shot, honoring the card's minimum time.
function Prelude.reveal()
    if not covering then return end
    local wait = pcfg.chapterMinMs - (GetGameTimer() - chapterAt)
    if wait > 0 then Wait(wait) end
    covering = false
    sound('reveal')
    nui('preludeReveal')
    dropCamera()
    active = false
end

---Cleans up after a skip or a failed story; toGame hands the camera back to gameplay.
function Prelude.finish(toGame)
    if not active and not covering then return end
    unfreeze()
    if covering then
        covering = false
        nui('preludeReveal')
    else
        nui('preludeAbort')
    end
    dropCamera()
    if toGame then RenderScriptCams(false, false, 0, true, true) end
    active = false
end

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if frozen then
        AnimpostfxStop(pcfg.postfx)
        SetTimeScale(1.0)
    end
end)
