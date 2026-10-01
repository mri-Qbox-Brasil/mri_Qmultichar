-- Showroom: fileira de peds (1 por personagem) num palco, cada um com a roupa
-- do personagem e uma animação idle. A câmera desliza pro ped do slot focado e
-- um holofote (DrawSpotLight) o destaca. Substitui o preview de 1 ped que dava
-- fade+recarga a cada troca de slot.

Showroom = Showroom or {}

local cfg = Config.Showroom

-- mapa id -> item do catálogo, pra tocar scenario ou anim clip por id.
local animById = {}
for _, a in ipairs(cfg.animations) do
    animById[a.id] = a
end

-- Toca a animação idle por id: anim clip (dict/clip) em loop, ou cenário GTA.
-- Global pra ser reusado pelo modo de posicionar (admin.lua).
function PlayShowroomAnim(ped, id)
    local a = animById[id]
    if a and a.dict then
        if lib.requestAnimDict(a.dict, 5000) then
            TaskPlayAnim(ped, a.dict, a.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
        end
        return
    end
    TaskStartScenarioInPlace(ped, id, 0, true)
end

local peds = {}            -- lista ordenada: { ped, citizenid, slot, groundZ, pos = {x,y} }
local pedByCitizen = {}    -- citizenid -> índice em `peds`
local focusedIndex = nil
local sceneCam = nil
local active = false
local buildToken = 0       -- invalida builds concorrentes
local firstStage = nil     -- stage da 1ª posição (palco da criação)
local buildStages = nil    -- stages do painel usadas no último build (posição dos slots livres)
-- modo criação: { entry, stage, want (gênero pedido), gender (montado), busy, returnTo }
local creation = nil

-- pose atual/alvo da câmera (glide temporizado com ease-in-out)
local cur = { x = 0, y = 0, z = 0, lx = 0, ly = 0, lz = 0 }
local target = { x = 0, y = 0, z = 0, lx = 0, ly = 0, lz = 0 }
local glideStart = { x = 0, y = 0, z = 0, lx = 0, ly = 0, lz = 0 }
local glideAt = 0
local glideDur = nil -- duração (s) do glide atual; nil = cfg.cam.transition
local glideArc = 0.0 -- metros que a câmera sobe no meio do glide (0 = reta)

local function copyPose(dst, src)
    dst.x, dst.y, dst.z, dst.lx, dst.ly, dst.lz = src.x, src.y, src.z, src.lx, src.ly, src.lz
end

-- começa uma transição temporizada da pose atual até o novo alvo; arc faz a
-- câmera subir no meio do caminho (grua) em vez de ir reta
local function beginGlide(newTarget, duration, arc)
    copyPose(glideStart, cur)
    target = newTarget
    glideAt = GetGameTimer()
    glideDur = duration
    glideArc = arc or 0.0
end

local function easeInOut(x)
    if x < 0.5 then return 2.0 * x * x end
    local a = -2.0 * x + 2.0
    return 1.0 - (a * a) * 0.5
end

-- Transição por CORTE (fade) pra saltos LONGOS entre peds (ex.: posições em
-- pontas opostas do mapa). Voar a câmera por essa distância passaria por área
-- não-streamada (void) e fica bugado — então funde a tela, teleporta e volta.
local cutting = false
local pendingPose, pendingE

local function snapPose(p)
    copyPose(cur, p)
    copyPose(glideStart, p)
    target = p
    glideAt = 0 -- e=1 imediato: câmera fica cravada no alvo
    if sceneCam and DoesCamExist(sceneCam) then
        SetCamCoord(sceneCam, p.x, p.y, p.z)
        PointCamAtCoord(sceneCam, p.lx, p.ly, p.lz)
    end
end

local function cutTo(pose, e, outMs, inMs)
    pendingPose, pendingE = pose, e
    if cutting then return end -- já há um corte rodando; ele aplica o último pendente
    cutting = true
    CreateThread(function()
        DoScreenFadeOut(outMs or 200)
        while not IsScreenFadedOut() do Wait(0) end
        -- tela preta: ninguém vê o snap. Aplica o ÚLTIMO alvo pedido.
        local p, en = pendingPose, pendingE
        snapPose(p)
        SetFocusPosAndVel(en.pos.x, en.pos.y, en.groundZ + 1.0, 0.0, 0.0, 0.0)
        local waited = 0
        while waited < 900 do
            RequestCollisionAtCoord(en.pos.x, en.pos.y, en.groundZ)
            if HasCollisionLoadedAroundEntity(en.ped) then break end
            Wait(50); waited = waited + 50
        end
        Wait(50)
        DoScreenFadeIn(inMs or 240)
        cutting = false
    end)
end

-- ===== DUI do nome 3D ================================================
-- Renderiza o nome numa DUI (browser), vira textura runtime e é desenhada num
-- quad no mundo atrás do ped focado (DrawSpritePoly respeita profundidade, então
-- o ped fica na frente das letras).
local NAME_TXD, NAME_TXN = 'mc_nametag_txd', 'mc_nametag'
local nameDui, nameReady, lastNameSent = nil, false, nil

local function ensureNameDui()
    if nameDui then return end
    nameDui = CreateDui(('https://cfx-nui-%s/nametag.html'):format(GetCurrentResourceName()), 2048, 512)
    local handle = GetDuiHandle(nameDui)
    local txd = CreateRuntimeTxd(NAME_TXD)
    CreateRuntimeTextureFromDuiHandle(txd, NAME_TXN, handle)
    CreateThread(function()
        while nameDui and not IsDuiAvailable(nameDui) do Wait(50) end
        Wait(150) -- garante que o JS da página registrou o listener
        nameReady = true
        if lastNameSent then
            SendDuiMessage(nameDui, json.encode({ name = lastNameSent }))
        end
    end)
end

local function setNametag(name)
    name = name or ''
    if name == lastNameSent then return end
    lastNameSent = name
    if nameDui and nameReady then
        SendDuiMessage(nameDui, json.encode({ name = name }))
    end
end

-- helpers vetoriais
local function vnorm(v) local l = #(v); if l == 0 then return v end return v / l end
local function vcross(a, b)
    return vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

-- Desenha a textura (DUI) como QUAD no mundo, billboard cilíndrico (encara a
-- câmera no eixo horizontal, fica em pé). 4 triângulos = dupla face; UV com w=1.0.
-- Mesma técnica do mri_interact (world-space => profundidade + nitidez).
function DrawWorldTextQuad(txd, txn, center, camPos, width)
    local toPanel = center - camPos
    local horiz = vector3(toPanel.x, toPanel.y, 0.0)
    if #(horiz) < 1e-4 then return end
    local face = vnorm(horiz)
    local r = vnorm(vcross(face, vector3(0.0, 0.0, 1.0)))
    local u = vnorm(vcross(r, face))
    local hw = width * 0.5
    local hh = width * 0.125 -- (width/4)/2 -> DUI 4:1
    local tl = center - r * hw + u * hh
    local tr = center + r * hw + u * hh
    local br = center + r * hw - u * hh
    local bl = center - r * hw - u * hh
    DrawSpritePoly(tl.x, tl.y, tl.z, tr.x, tr.y, tr.z, br.x, br.y, br.z, 255, 255, 255, 255, txd, txn, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0)
    DrawSpritePoly(tl.x, tl.y, tl.z, br.x, br.y, br.z, bl.x, bl.y, bl.z, 255, 255, 255, 255, txd, txn, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0)
    DrawSpritePoly(br.x, br.y, br.z, tr.x, tr.y, tr.z, tl.x, tl.y, tl.z, 255, 255, 255, 255, txd, txn, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0)
    DrawSpritePoly(bl.x, bl.y, bl.z, br.x, br.y, br.z, tl.x, tl.y, tl.z, 255, 255, 255, 255, txd, txn, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0)
end

-- ===== geometria =====================================================

local function forwardOf(h)
    local r = math.rad(h)
    return -math.sin(r), math.cos(r)
end

local function rightOf(h)
    local r = math.rad(h)
    return math.cos(r), math.sin(r)
end

local function groundZAt(x, y, zGuess)
    local found, gz = GetGroundZFor_3dCoord(x, y, zGuess + 10.0, false)
    if found then return gz end
    return zGuess
end

-- posição de cada ped na fileira (centralizada)
local function pedRowPos(index, total)
    local rx, ry = rightOf(cfg.heading)
    local offset = (index - (total + 1) / 2) * cfg.spacing
    local x = cfg.origin.x + rx * offset
    local y = cfg.origin.y + ry * offset
    local gz = groundZAt(x, y, cfg.origin.z)
    return x, y, gz
end

-- pose de câmera pra enquadrar o ped em `entry`
local function camPoseFor(entry)
    local fx, fy = forwardOf(entry.heading or cfg.heading)
    local px, py, gz = entry.pos.x, entry.pos.y, entry.groundZ
    return {
        x = px + fx * cfg.cam.distance,
        y = py + fy * cfg.cam.distance,
        z = gz + cfg.cam.height,
        lx = px,
        ly = py,
        lz = gz + cfg.cam.lookHeight,
    }
end

-- Pose de onde parte o voo da abertura (Config.Intro.approach): atrás e acima do
-- plano final, olhando por cima do palco. O glide desce até o enquadramento.
local function introPose(p)
    local a = Config.Intro.approach
    local dx, dy = p.x - p.lx, p.y - p.ly
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then dx, dy, len = 0.0, 1.0, 1.0 end
    dx, dy = dx / len, dy / len
    return {
        x = p.x + dx * a.distance,
        y = p.y + dy * a.distance,
        z = p.z + a.height,
        lx = p.lx - dx * a.lookAhead,
        ly = p.ly - dy * a.lookAhead,
        lz = p.lz + a.lookHeight,
    }
end

-- ===== spawn de peds =================================================

local function fetchAppearance(citizenId)
    local ok, clothing, model = pcall(function()
        return lib.callback.await('qbx_core:server:getPreviewPedData', false, citizenId)
    end)
    if ok and clothing and model then
        return clothing, model
    end
    return nil
end

-- resolve a stage (posição+heading+animação) do i-ésimo ped: usa a config do
-- painel (/adminchar) se houver, senão cai na fileira automática do config.lua.
local function resolveStage(index, total, stages)
    local s = stages and stages[index]
    if s and type(s.x) == 'number' and type(s.y) == 'number' then
        local z = s.z
        if type(z) ~= 'number' then
            z = groundZAt(s.x, s.y, cfg.origin.z)
        end
        return {
            x = s.x, y = s.y, z = z,
            heading = tonumber(s.heading) or cfg.heading,
            zOffset = tonumber(s.zOffset) or 0.0, -- sobe/abaixa manual (por cima do chão)
            scenario = (type(s.scenario) == 'string' and s.scenario ~= '') and s.scenario or nil,
        }
    end
    local x, y, gz = pedRowPos(index, total)
    return { x = x, y = y, z = gz, heading = cfg.heading, zOffset = 0.0, scenario = nil }
end

-- Z do ped na stage: chão REAL de x,y (o Z salvo pode estar off) + o offset manual
-- (subir/abaixar do /adminchar). Precisa da colisão carregada ali (o
-- SetFocusPosAndVel do build já streama o palco).
local function stageZ(stage)
    RequestCollisionAtCoord(stage.x, stage.y, stage.z)
    local found, groundZ = GetGroundZFor_3dCoord(stage.x, stage.y, stage.z + 3.0, false)
    return (found and groundZ or stage.z) + (stage.zOffset or 0.0)
end

-- Animação idle da stage (do painel, ou sorteada do catálogo do config.lua).
local function stageAnim(stage)
    if stage.scenario then return stage.scenario end
    local a = cfg.animations
    return a[math.random(1, #a)].id
end

-- Cria um ped local parado no palco da stage (chão real + offset do painel).
---@return number|nil ped, number groundZ
local function createStagePed(model, stage)
    local x, y, gz = stage.x, stage.y, stage.z

    if not lib.requestModel(model, 15000) then
        return nil, gz
    end

    -- SetEntityCoords (não NoOffset) faz o snap do ped ao solo sozinho.
    local finalZ = stageZ(stage)

    local ped = CreatePed(4, model, x, y, finalZ, stage.heading, false, false)
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(ped) then return nil, gz end

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedCanBeTargetted(ped, false)
    -- snap ao solo ANTES de tirar colisão/congelar
    SetEntityCoords(ped, x, y, finalZ, false, false, false, false)
    SetEntityHeading(ped, stage.heading)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    return ped, finalZ
end

local function spawnCharacterPed(character, stage)
    local x, y = stage.x, stage.y

    local clothing, model = fetchAppearance(character.citizenid)
    if not model then
        model = (character.charinfo and character.charinfo.gender == 1) and `mp_f_freemode_01` or `mp_m_freemode_01`
    end

    local ped, gz = createStagePed(model, stage)
    if not ped then return nil end

    if clothing then
        local ok, decoded = pcall(json.decode, clothing)
        if ok and decoded then
            Appearance.setPedAppearance(ped, decoded)
        end
    end

    local animId = stageAnim(stage)
    PlayShowroomAnim(ped, animId)

    local ci = character.charinfo
    return {
        ped = ped,
        citizenid = character.citizenid,
        slot = character.cid,
        groundZ = gz,
        pos = { x = x, y = y },
        heading = stage.heading,
        anim = animId,
        name = ci and ((ci.firstname or '') .. ' ' .. (ci.lastname or '')) or '',
    }
end

-- ===== câmera / holofote (thread) ====================================

-- Holofote de cima e luz frontal de preenchimento no ped do palco (vale só pro frame).
local function drawStageLights(entry)
    local s = cfg.spotlight
    DrawSpotLight(
        entry.pos.x, entry.pos.y, entry.groundZ + s.height,
        0.0, 0.0, -1.0,
        s.r, s.g, s.b,
        s.distance, s.brightness, s.hardness, s.radius, s.falloff
    )

    -- luz frontal (do lado da câmera): ilumina o rosto, que o holofote deixa na sombra
    local fl = cfg.frontlight
    if fl and fl.enabled ~= false then
        local ffx, ffy = forwardOf(entry.heading) -- ped encara a câmera
        DrawLightWithRange(
            entry.pos.x + ffx * fl.dist,
            entry.pos.y + ffy * fl.dist,
            entry.groundZ + fl.height,
            fl.r, fl.g, fl.b, fl.range, fl.intensity
        )
    end
end

-- true enquanto a câmera desce da abertura: sem desfoque (o foco no personagem
-- borraria a cidade inteira lá de cima)
local introFlying = false

-- Balanço de câmera na mão (Config.Showroom.cam.breathe): senos lentos e fora de
-- fase, pra a câmera nunca ficar morta. Só fora da criação, que termina cravada
-- no plano do editor.
local function breathe(t)
    local b = cfg.cam.breathe
    if not b or creation then return 0.0, 0.0, 0.0, 0.0, 0.0 end
    local s = t * (b.speed or 1.0)
    return math.sin(s * 0.47) * b.position,
        math.sin(s * 0.31 + 1.3) * b.position,
        math.sin(s * 0.59 + 2.1) * b.position * 0.6,
        math.sin(s * 0.37 + 0.7) * b.look,
        math.sin(s * 0.43 + 2.9) * b.look
end

-- Desfoque de fundo do showroom (Config.Showroom.cam.dof): foco na distância até o
-- ponto que a câmera mira, refeito a cada frame (acompanha os glides).
local function applyShowroomDof(cx, cy, cz)
    local d = cfg.cam.dof
    if not d or d.enabled == false then return end
    local dx, dy, dz = cur.lx - cx, cur.ly - cy, cur.lz - cz
    local focus = math.sqrt(dx * dx + dy * dy + dz * dz)
    SetCamUseShallowDofMode(sceneCam, true)
    SetCamNearDof(sceneCam, math.max(0.1, focus - d.near))
    SetCamFarDof(sceneCam, focus + d.far)
    SetCamDofStrength(sceneCam, d.strength)
    SetUseHiDof()
end

-- Largura do nome 3D: a do config, limitada a `fit` da largura que a câmera enxerga
-- naquela distância (nome comprido não sai cortado nas bordas).
local function nametagWidth(nt, center, camPos)
    if not nt.fit then return nt.width end
    local dist = #(center - camPos)
    local visible = 2.0 * dist * math.tan(math.rad(GetCamFov(sceneCam)) / 2.0) * GetAspectRatio(false)
    return math.min(nt.width, visible * nt.fit)
end

local function startRenderThread()
    local myToken = buildToken
    CreateThread(function()
        while active and buildToken == myToken and sceneCam and DoesCamExist(sceneCam) do
            -- glide temporizado (ease-in-out) da pose inicial até o alvo
            local dur = (glideDur or cfg.cam.transition or 0.75) * 1000.0
            local e = 1.0
            if dur > 0 then
                local tt = (GetGameTimer() - glideAt) / dur
                e = tt < 1.0 and easeInOut(tt) or 1.0
            end
            cur.x = glideStart.x + (target.x - glideStart.x) * e
            cur.y = glideStart.y + (target.y - glideStart.y) * e
            cur.z = glideStart.z + (target.z - glideStart.z) * e + glideArc * math.sin(math.pi * e)
            cur.lx = glideStart.lx + (target.lx - glideStart.lx) * e
            cur.ly = glideStart.ly + (target.ly - glideStart.ly) * e
            cur.lz = glideStart.lz + (target.lz - glideStart.lz) * e
            if introFlying and e >= 1.0 then introFlying = false end

            local bx, by, bz, blx, blz = breathe(GetGameTimer() / 1000.0)
            local cx, cy, cz = cur.x + bx, cur.y + by, cur.z + bz
            SetCamCoord(sceneCam, cx, cy, cz)
            PointCamAtCoord(sceneCam, cur.lx + blx, cur.ly, cur.lz + blz)

            -- desfoque de fundo (criação ou showroom): o nativo vale só pro frame atual
            if creation then
                if creation.dof then SetUseHiDof() end
            elseif not introFlying then
                applyShowroomDof(cx, cy, cz)
            end

            -- holofote no ped focado (na criação, no ped de preview)
            local entry = creation and creation.entry or (focusedIndex and peds[focusedIndex])
            if entry and DoesEntityExist(entry.ped) then
                drawStageLights(entry)

                -- nome 3D atrás do ped (quad world-space => o ped fica na frente)
                local nt = cfg.nametag
                if nameReady and nt.enabled ~= false and not creation then
                    local fx, fy = forwardOf(entry.heading) -- direção que o ped encara (pra câmera)
                    local center = vector3(
                        entry.pos.x - fx * nt.back,
                        entry.pos.y - fy * nt.back,
                        entry.groundZ + nt.height
                    )
                    local camPos = vector3(cx, cy, cz)
                    DrawWorldTextQuad(NAME_TXD, NAME_TXN, center, camPos, nametagWidth(nt, center, camPos))
                end
            end

            Wait(0)
        end
    end)
end

-- ===== API pública ===================================================

---Foca o slot do citizenid: a câmera desliza e o holofote acompanha.
---@param citizenId string
-- Leva a câmera até `pose` enquadrando `e`: salto longo corta com fade, curto desliza.
-- move (opcional) = { arc, dipOut, dipIn }: subida no meio do glide e tempos do fade.
local function moveCamera(pose, e, duration, move)
    SetFocusPosAndVel(e.pos.x, e.pos.y, e.groundZ + 1.0, 0.0, 0.0, 0.0)

    -- já em transição com fade? só atualiza o alvo final (o corte aplica o último)
    if cutting then
        pendingPose, pendingE = pose, e
        return
    end

    local dx, dy, dz = pose.x - cur.x, pose.y - cur.y, pose.z - cur.z
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    move = move or {}
    if dist > (cfg.cam.cutDistance or 18.0) then
        cutTo(pose, e, move.dipOut, move.dipIn)
    else
        beginGlide(pose, duration, move.arc)
    end
end

-- Enquadra a próxima posição livre do palco (depois do último personagem).
local function focusEmptyStage()
    focusedIndex = nil
    setNametag('')
    local total = math.max(1, #peds)
    local stage = #peds == 0 and firstStage or resolveStage(#peds + 1, total, buildStages)
    if not stage then return end
    local e = {
        pos = { x = stage.x, y = stage.y },
        groundZ = stage.z + (stage.zOffset or 0.0),
        heading = stage.heading,
    }
    moveCamera(camPoseFor(e), e)
end

---Slot livre selecionado na NUI: câmera na posição vazia, sem holofote nem nome.
function Showroom.focusEmpty()
    if not active then return end
    -- na criação só anota pra onde voltar se ela for cancelada
    if creation then creation.returnTo = false return end
    focusEmptyStage()
end

function Showroom.focus(citizenId)
    if not active then return end
    if creation then creation.returnTo = citizenId return end
    local idx = pedByCitizen[citizenId]
    if not idx then return end
    focusedIndex = idx
    local e = peds[idx]
    setNametag(e.name)
    moveCamera(camPoseFor(e), e)
end

function Showroom.isActive()
    return active
end

-- ===== personagem deletado ===========================================

-- Leva o alpha dos peds de `from` até `to` em `ms`, todos juntos. Bloqueia.
local function fadePeds(list, from, to, ms)
    local startAt = GetGameTimer()
    while true do
        local t = math.min(1.0, (GetGameTimer() - startAt) / ms)
        for i = 1, #list do
            if DoesEntityExist(list[i]) then SetEntityAlpha(list[i], math.floor(from + (to - from) * t), false) end
        end
        if t >= 1.0 then break end
        Wait(0)
    end
end

-- Põe um ped que já existe noutra stage (mesmo aterramento do createStagePed) e
-- toca a animação dela.
local function seatPed(entry, stage)
    local z = stageZ(stage)
    SetEntityCoords(entry.ped, stage.x, stage.y, z, false, false, false, false)
    SetEntityHeading(entry.ped, stage.heading)
    ClearPedTasksImmediately(entry.ped)
    entry.anim = stageAnim(stage)
    PlayShowroomAnim(entry.ped, entry.anim)
    entry.pos = { x = stage.x, y = stage.y }
    entry.groundZ = z
    entry.heading = stage.heading
end

---Tira da cena o personagem deletado: o ped some aos poucos e os seguintes andam
---uma posição, na mesma ordem de um build novo (sem remontar o showroom nem mexer
---na câmera; a NUI foca a próxima seleção depois). Bloqueia até terminar.
---@param citizenId string
function Showroom.removeCharacter(citizenId)
    local idx = active and pedByCitizen[citizenId]
    if not idx then return end

    local entry = peds[idx]
    if focusedIndex == idx then setNametag('') end
    focusedIndex = nil
    if DoesEntityExist(entry.ped) then
        ClearPedTasksImmediately(entry.ped) -- solta o objeto do cenário junto (celular, cigarro)
        fadePeds({ entry.ped }, 255, 0, cfg.removeFadeMs or 700)
        DeleteEntity(entry.ped)
    end
    table.remove(peds, idx)

    -- fileira automática (sem stages do painel) recentraliza todo mundo
    local total = #peds
    local from = buildStages and idx or 1
    local moving = {}
    for i = from, total do
        if DoesEntityExist(peds[i].ped) then moving[#moving + 1] = peds[i].ped end
    end
    if #moving > 0 then
        fadePeds(moving, 255, 0, 220)
        for i = from, total do
            if DoesEntityExist(peds[i].ped) then seatPed(peds[i], resolveStage(i, total, buildStages)) end
        end
        fadePeds(moving, 0, 255, 320)
        for i = 1, #moving do ResetEntityAlpha(moving[i]) end
    end

    pedByCitizen = {}
    for i = 1, #peds do pedByCitizen[peds[i].citizenid] = i end
end

-- ===== modo criação ==================================================
-- A NUI da criação pede um ped de preview no palco: os peds dos personagens
-- somem, o preview troca de modelo (gênero) ao vivo e a câmera o enquadra à
-- direita da tela, com um plano por capítulo. Cancelar devolve o showroom como
-- estava; confirmar termina com a pose final (creationFinale) antes do editor.

local FREEMODE = { [0] = `mp_m_freemode_01`, [1] = `mp_f_freemode_01` }
local ccfg = cfg.creation or {}
local enter = ccfg.enter or {}

-- Visual inicial da criação (Config.Showroom.creation.preset): o preview e o ped real
-- (prepareFreemodePedForCreation) passam pelo mesmo, então a troca entre eles não
-- aparece e o editor de aparência abre a partir dele.
---@param ped number
---@param gender number 1 = feminino
function Showroom.dressCreationPed(ped, gender)
    local p = ccfg.preset and ccfg.preset[gender == 1 and 'female' or 'male'] or {}

    for componentId = 0, 11 do
        local c = p.components and p.components[componentId]
        SetPedComponentVariation(ped, componentId, c and c[1] or 0, c and c[2] or 0, 2)
    end
    for _, propId in ipairs({ 0, 1, 2, 6, 7 }) do
        ClearPedProp(ped, propId)
    end

    local hb = p.headBlend or {}
    SetPedHeadBlendData(ped, hb.shapeFirst or 0, hb.shapeSecond or 0, 0, hb.skinFirst or 0, hb.skinSecond or 0, 0,
        hb.shapeMix or 0.0, hb.skinMix or 0.0, 0.0, false)

    local hair = p.hair or {}
    SetPedComponentVariation(ped, 2, hair.style or 0, hair.texture or 0, 2)
    SetPedHairColor(ped, hair.color or 0, hair.highlight or 0)
    if p.eyeColor then SetPedEyeColor(ped, p.eyeColor) end

    for overlayId = 0, 12 do
        local o = p.overlays and p.overlays[overlayId]
        if o then
            SetPedHeadOverlay(ped, overlayId, o.index, o.opacity or 1.0)
            if o.color then
                -- 1 = cor de pelo (barba, sobrancelha), 2 = maquiagem (blush, batom)
                local colorType = (overlayId == 5 or overlayId == 8) and 2 or 1
                SetPedHeadOverlayColor(ped, overlayId, colorType, o.color, o.color)
            end
        else
            SetPedHeadOverlay(ped, overlayId, 255, 0.0)
        end
    end
end

-- ----- animações -----------------------------------------------------

local missingDicts = {}

-- Carrega o dict; o que não existir no jogo é avisado uma vez e ignorado.
local function loadDict(dict)
    if not DoesAnimDictExist(dict) then
        if not missingDicts[dict] then
            missingDicts[dict] = true
            lib.print.warn(('[mri_Qmultichar] anim dict inexistente na criação: %s (Config.Showroom.creation.anims)'):format(dict))
        end
        return false
    end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end
    return HasAnimDictLoaded(dict)
end

-- Anim do catálogo da criação pro gênero: { dict, clip } direto ou por male/female.
local function animFor(key, gender)
    local a = ccfg.anims and ccfg.anims[key]
    if type(a) ~= 'table' then return nil end
    if a.dict then return a end
    return a[gender == 1 and 'female' or 'male'] or a.male
end

local function playIdle(ped, gender)
    local a = animFor('idle', gender)
    if a and loadDict(a.dict) then
        TaskPlayAnim(ped, a.dict, a.clip, 4.0, -4.0, -1, 1, 0, false, false, false)
    else
        PlayShowroomAnim(ped, ccfg.animation or cfg.animations[1].id)
    end
end

-- Gesto por cima do idle. upperBody = só tronco e braços (o idle continua nas
-- pernas); senão corpo inteiro e volta pro idle no fim. Retorna a duração (ms).
local function playGesture(ped, key, gender, upperBody)
    local a = animFor(key, gender)
    if not a or not loadDict(a.dict) then return 0 end
    TaskPlayAnim(ped, a.dict, a.clip, 4.0, -4.0, -1, upperBody and 48 or 0, 0, false, false, false)
    local duration = math.floor(GetAnimDuration(a.dict, a.clip) * 1000)
    if not upperBody then
        CreateThread(function()
            Wait(math.max(0, duration - 200))
            local state = creation
            if state and state.entry and state.entry.ped == ped and not state.finale and DoesEntityExist(ped) then
                playIdle(ped, gender)
            end
        end)
    end
    return duration
end

-- Vibração do controle (não faz nada no teclado).
local function haptic(duration, frequency)
    if ccfg.haptics == false or IsUsingKeyboard(0) then return end
    SetPadShake(0, duration, frequency)
end

-- ----- câmera --------------------------------------------------------

local function shotFor(name)
    local shots = ccfg.shots or {}
    return shots[name] or shots.gender or { distance = 1.9, height = 1.0, lookHeight = 0.95, lookOffset = 0.55 }
end

-- Pose do plano `shot` em volta do ped. A câmera e a mira andam juntas pro lado
-- (lookOffset), então o ped aparece à direita encarando a câmera, sem ângulo
-- torto; `angle` gira o plano em volta dele.
local function creationCamPose(e, shot)
    local h = e.heading + (shot.angle or 0.0)
    local fx, fy = forwardOf(h)
    local rx, ry = rightOf(h)
    local d = shot.distance or cfg.cam.distance
    local off = shot.lookOffset or 0.0
    return {
        x = e.pos.x + fx * d + rx * off,
        y = e.pos.y + fy * d + ry * off,
        z = e.groundZ + (shot.height or cfg.cam.height),
        lx = e.pos.x + rx * off,
        ly = e.pos.y + ry * off,
        lz = e.groundZ + (shot.lookHeight or cfg.cam.lookHeight),
    }
end

-- Foco na distância do ped: o fundo (e o que estiver muito perto) desfoca.
local function applyDof(state, shot)
    local dof = ccfg.dof
    if not sceneCam or not dof or dof.enabled == false then return end
    local d = shot.distance or cfg.cam.distance
    local focus = math.sqrt(d * d + (shot.lookOffset or 0.0) ^ 2)
    SetCamUseShallowDofMode(sceneCam, true)
    SetCamNearDof(sceneCam, math.max(0.1, focus - (dof.near or 0.35)))
    SetCamFarDof(sceneCam, focus + (dof.far or 0.9))
    SetCamDofStrength(sceneCam, dof.strength or 1.0)
    state.dof = true
end

local function clearDof()
    if sceneCam and DoesCamExist(sceneCam) then
        SetCamUseShallowDofMode(sceneCam, false)
        SetCamDofStrength(sceneCam, 0.0)
    end
end

-- Ped acompanha a câmera com a cabeça e o olhar.
local function lookAtPose(ped, pose)
    if ccfg.lookAtCamera == false or not DoesEntityExist(ped) then return end
    TaskLookAtCoord(ped, pose.x, pose.y, pose.z, -1, 0, 2)
end

-- Leva a câmera pro plano atual do estado (e o ped passa a olhar pra ela).
local function frameShot(state, duration, move)
    local e = state.entry
    if not e then return end
    local shot = shotFor(state.shot)
    local pose = creationCamPose(e, shot)
    moveCamera(pose, e, duration or shot.time, move)
    applyDof(state, shot)
    lookAtPose(e.ped, pose)
end

-- ----- preview -------------------------------------------------------

-- Troca de ped com fusão: o novo aparece enquanto o antigo some.
local function crossfade(newPed, oldPed, dur)
    SetEntityAlpha(newPed, 0, false)
    dur = dur or 320
    CreateThread(function()
        local startAt = GetGameTimer()
        while true do
            local t = math.min(1.0, (GetGameTimer() - startAt) / dur)
            if DoesEntityExist(newPed) then SetEntityAlpha(newPed, math.floor(255 * t), false) end
            if oldPed and DoesEntityExist(oldPed) then SetEntityAlpha(oldPed, math.floor(255 * (1.0 - t)), false) end
            if t >= 1.0 then break end
            Wait(0)
        end
        if DoesEntityExist(newPed) then ResetEntityAlpha(newPed) end
        if oldPed and DoesEntityExist(oldPed) then DeleteEntity(oldPed) end
    end)
end

-- Aplica o último gênero pedido no preview, um de cada vez: trocas rápidas
-- não criam peds em paralelo, só o estado final é montado.
local function syncCreation()
    local state = creation
    if not state or state.busy then return end
    state.busy = true
    CreateThread(function()
        while creation == state and state.gender ~= state.want do
            local gender = state.want
            local entry = state.entry

            local first = entry == nil
            -- entrada: o preview só aparece depois que os personagens saírem de cena
            while first and state.clearing and creation == state do Wait(0) end
            if creation ~= state then break end

            local ped, gz = createStagePed(FREEMODE[gender], state.stage)
            if not ped then break end
            if creation ~= state then DeleteEntity(ped) break end
            Showroom.dressCreationPed(ped, gender)
            crossfade(ped, entry and entry.ped, first and (enter.pedFadeMs or 320) or 320)

            entry = { ped = ped, groundZ = gz, pos = { x = state.stage.x, y = state.stage.y }, heading = state.stage.heading }
            state.entry = entry
            state.gender = gender

            -- entrada: gesto de corpo inteiro e depois o idle
            if playGesture(ped, 'enter', gender, false) == 0 then playIdle(ped, gender) end
            lookAtPose(ped, target)
        end
        state.busy = false
    end)
end

-- Some com o preview sem mexer no resto (usado ao destruir o showroom).
local function discardCreation()
    if not creation then return end
    local state = creation
    creation = nil
    if state.dof then clearDof() end
    if state.entry and DoesEntityExist(state.entry.ped) then
        DeleteEntity(state.entry.ped)
    end
end

---Entra no modo criação: esconde os personagens e monta o preview.
function Showroom.creationStart()
    if not active or not firstStage then return false end
    if creation then return true end
    local state = { stage = firstStage, want = 0, shot = 'gender', clearing = true }
    creation = state
    setNametag('')

    -- A câmera sai já, num arco lento até o plano do gênero (salto longo vira um
    -- fade mais demorado), enquanto os personagens somem com fade.
    local e = {
        pos = { x = firstStage.x, y = firstStage.y },
        groundZ = stageZ(firstStage),
        heading = firstStage.heading,
    }
    state.entry = nil
    local pose = creationCamPose(e, shotFor('gender'))
    moveCamera(pose, e, enter.time or 2.4, { arc = enter.arc, dipOut = enter.dipOut, dipIn = enter.dipIn })
    if ccfg.dof then applyDof(state, shotFor('gender')) end

    local leaving = {}
    for i = 1, #peds do
        if DoesEntityExist(peds[i].ped) then leaving[#leaving + 1] = peds[i].ped end
    end
    CreateThread(function()
        -- cancelada no meio do fade: para aqui, o creationStop traz eles de volta
        local startAt, ms = GetGameTimer(), enter.fadeMs or 600
        while creation == state do
            local t = math.min(1.0, (GetGameTimer() - startAt) / ms)
            for i = 1, #leaving do
                if DoesEntityExist(leaving[i]) then SetEntityAlpha(leaving[i], math.floor(255 * (1.0 - t)), false) end
            end
            if t >= 1.0 then break end
            Wait(0)
        end
        if creation ~= state then return end
        for i = 1, #leaving do
            if DoesEntityExist(leaving[i]) then
                SetEntityVisible(leaving[i], false, false)
                ResetEntityAlpha(leaving[i])
            end
        end
        state.clearing = false
    end)

    syncCreation()
    return true
end

---Troca o gênero do preview (0 masculino, 1 feminino).
function Showroom.creationPreview(gender)
    if not creation then return end
    creation.want = tonumber(gender) == 1 and 1 or 0
    syncCreation()
end

---Plano do capítulo (Config.Showroom.creation.shots).
function Showroom.creationShot(name)
    local state = creation
    if not state or state.finale or type(name) ~= 'string' then return end
    state.shot = name
    frameShot(state)
end

---Reação do preview ao capítulo: 'confirm' faz um gesto, 'error' só vibra.
function Showroom.creationReact(kind)
    local state = creation
    if not state or state.finale then return end
    if kind == 'confirm' then
        if state.entry and not state.busy then playGesture(state.entry.ped, 'confirm', state.gender, true) end
        haptic(90, 110)
    elseif kind == 'error' then
        haptic(160, 60)
    end
end

-- ----- passagem pro editor de aparência -------------------------------

-- Plano com que o editor de aparência abre, em volta do ped (editorCamera).
local function editorPose(ped)
    local ec = ccfg.editorCamera
    local c = GetOffsetFromEntityInWorldCoords(ped, ec.offset.x, ec.offset.y, ec.offset.z)
    local p = GetOffsetFromEntityInWorldCoords(ped, ec.point.x, ec.point.y, ec.point.z)
    return { x = c.x, y = c.y, z = c.z, lx = p.x, ly = p.y, lz = p.z }
end

-- Desfoque igual ao do editor (mesmos nativos e valores), pra a troca não aparecer.
local function applyEditorDof(state)
    local dof = ccfg.editorCamera.dof
    if not sceneCam or not dof then clearDof() return end
    SetCamUseShallowDofMode(sceneCam, true)
    SetCamNearDof(sceneCam, dof.near)
    SetCamFarDof(sceneCam, dof.far)
    SetCamDofStrength(sceneCam, dof.strength)
    SetCamDofFnumberOfLens(sceneCam, dof.fnumber)
    SetCamDofFocusDistanceBias(sceneCam, 0.0)
    SetCamDofMaxNearInFocusDistanceBlendLevel(sceneCam, 1.0)
    state.dof = true
end

-- Leva a abertura da lente até `fov` junto com o movimento da câmera.
local function tweenFov(fov, seconds)
    local cam = sceneCam
    if not cam then return end
    local from, startAt, dur = GetCamFov(cam), GetGameTimer(), math.max(1, seconds * 1000)
    CreateThread(function()
        while cam == sceneCam and DoesCamExist(cam) do
            local t = math.min(1.0, (GetGameTimer() - startAt) / dur)
            SetCamFov(cam, from + (fov - from) * easeInOut(t))
            if t >= 1.0 then break end
            Wait(0)
        end
    end)
end

-- Espera o preview do gênero pedido estar montado.
local function awaitPreview(state)
    local waited = 0
    while creation == state and (state.busy or not state.entry) and waited < 3000 do
        Wait(50); waited = waited + 50
    end
    return creation == state and state.entry ~= nil
end

---Ponto do ped de preview no palco (x, y, z e heading da mesma chamada que o pôs
---lá). O ped do jogador vai pra esse ponto antes do final.
---@return vector4|nil
function Showroom.creationStagePose()
    local state = creation
    if not state or not awaitPreview(state) then return nil end
    local e = state.entry
    return vector4(e.pos.x, e.pos.y, e.groundZ, e.heading)
end

-- ms em que o preview para a pose antes da troca (os dois peds ficam parados iguais)
local SWAP_SETTLE = 450

---Momento final (a criação foi aceita): pose, câmera indo até o plano inicial do
---editor de aparência e a NUI faz o encerramento dela. O ped do jogador já está no
---ponto do preview, invisível (main.lua); no fim os dois trocam de lugar no mesmo
---frame. Bloqueia até terminar.
function Showroom.creationFinale()
    local state = creation
    if not state or not awaitPreview(state) then return end

    state.finale = true
    SendNUIMessage({ action = 'creationFinale' })

    local playerPed = PlayerPedId()
    local time = shotFor('finale').time or 1.8
    local pose = editorPose(playerPed)
    moveCamera(pose, state.entry, time)
    tweenFov(ccfg.editorCamera.fov, time)
    applyEditorDof(state)
    lookAtPose(state.entry.ped, pose)
    playGesture(state.entry.ped, 'finale', state.gender, false)
    haptic(380, 170)
    Wait(math.max(0, (ccfg.finaleHold or 2400) - SWAP_SETTLE))

    -- o preview volta a ficar parado, olhando pra frente, como o ped do jogador
    local preview = state.entry.ped
    if DoesEntityExist(preview) then
        TaskClearLookAt(preview)
        ClearPedTasks(preview)
    end
    Wait(SWAP_SETTLE)

    SetEntityVisible(playerPed, true, false)
    if DoesEntityExist(preview) then DeleteEntity(preview) end
    state.entry.ped = playerPed
end

-- Luz do palco acesa enquanto o editor de aparência está aberto nele.
local studioToken = 0

local function startStudioLights(entry)
    studioToken = studioToken + 1
    local myToken = studioToken
    CreateThread(function()
        while studioToken == myToken do
            drawStageLights(entry)
            Wait(0)
        end
    end)
end

---Apaga a luz do palco (a criação terminou).
function Showroom.studioEnd()
    studioToken = studioToken + 1
end

---Desmonta o showroom depois do final. `editorOpened` = a câmera do editor já está
---ativa: a do showroom sai sem desligar as câmeras de script (senão corta pra câmera
---do jogo). Sem editor, volta a câmera do jogo. A luz do palco fica até studioEnd.
---@param editorOpened boolean
function Showroom.creationHandoff(editorOpened)
    if not active then return end
    local entry = creation and creation.entry
    creation = nil
    active = false
    buildToken = buildToken + 1 -- encerra o render thread

    if sceneCam and DoesCamExist(sceneCam) then
        SetCamActive(sceneCam, false)
        DestroyCam(sceneCam, false)
    end
    sceneCam = nil
    if not editorOpened then
        RenderScriptCams(false, false, 0, true, true)
    end

    -- o ped do jogador está no palco: o streaming volta a segui-lo
    ClearFocus()

    for i = 1, #peds do
        if peds[i].ped and DoesEntityExist(peds[i].ped) then
            DeleteEntity(peds[i].ped)
        end
    end
    peds = {}
    pedByCitizen = {}
    focusedIndex = nil
    setNametag('')

    if entry then startStudioLights(entry) end
end

---A criação falhou depois do final ter começado: volta pro último capítulo.
function Showroom.creationRecover()
    local state = creation
    if not state then return end
    state.finale = false
    state.shot = 'birth'
    if state.entry and DoesEntityExist(state.entry.ped) then playIdle(state.entry.ped, state.gender) end
    frameShot(state)
end

---Sai do modo criação (cancelou): volta os personagens e a câmera.
function Showroom.creationStop()
    if not creation then return end
    -- criação de verdade em andamento: quem desmonta tudo é o fluxo dela
    if Multichar and Multichar.isCharacterCreationFlowActive and Multichar.isCharacterCreationFlowActive() then return end
    -- a NUI avisa (focus/focusEmpty) qual seleção volta; sem aviso, a de antes
    local returnTo = creation.returnTo
    discardCreation()
    -- os personagens voltam com fade, como saíram
    local back = {}
    for i = 1, #peds do
        if DoesEntityExist(peds[i].ped) then
            SetEntityAlpha(peds[i].ped, 0, false)
            SetEntityVisible(peds[i].ped, true, false)
            back[#back + 1] = peds[i].ped
        end
    end
    CreateThread(function()
        fadePeds(back, 0, 255, enter.fadeMs or 600)
        for i = 1, #back do
            if DoesEntityExist(back[i]) then ResetEntityAlpha(back[i]) end
        end
    end)
    if returnTo and pedByCitizen[returnTo] then
        Showroom.focus(returnTo)
        return
    end
    local e = returnTo == nil and focusedIndex and peds[focusedIndex]
    if e then
        setNametag(e.name)
        moveCamera(camPoseFor(e), e)
    else
        focusEmptyStage()
    end
end

---Monta o showroom com a lista de personagens (ocupados). `preferId` = citizenid
---que já começa focado (ex.: last-played).
---@param characters table
---@param preferId string|nil
---@param intro boolean|nil true = vem da abertura: a câmera desce do alto até o
--- enquadramento em Config.Intro.approach.time segundos (a tela está preta)
function Showroom.build(characters, preferId, intro)
    Showroom.destroy()

    buildToken = buildToken + 1
    local token = buildToken

    TriggerServerEvent('mri_Qmultichar:server:setBucket', 1)

    -- isola o player: invisível e congelado fora de cena
    local playerPed = PlayerPedId()
    SetEntityVisible(playerPed, false, false)
    FreezeEntityPosition(playerPed, true)

    -- stages configuradas no painel /adminchar (posição + heading + animação)
    local panelCfg = lib.callback.await('mri_Qmultichar:server:getConfig', false)
    local stages = panelCfg and panelCfg.showroom and panelCfg.showroom.stages or nil

    local occupied = {}
    for i = 1, #(characters or {}) do
        if characters[i] and characters[i].citizenid then
            occupied[#occupied + 1] = characters[i]
        end
    end

    -- Foco de streaming no palco: sem isso o mundo fica sem textura/LOD, porque
    -- o foco de streaming do jogo segue o PLAYER PED (que está escondido noutro
    -- lugar), não a câmera. SetFocusPosAndVel força o streaming pro palco.
    local focusStage = resolveStage(1, math.max(1, #occupied), stages)
    firstStage = focusStage
    buildStages = stages
    SetFocusPosAndVel(focusStage.x, focusStage.y, focusStage.z + 1.0, 0.0, 0.0, 0.0)

    -- carrega colisão/streaming no palco e espera a cena carregar (o foco já
    -- está no palco, então o streaming acontece ali)
    -- Sai assim que o chao resolve, com um settle curto pras texturas/LOD
    -- entrarem. Antes o break exigia `waited >= 700`, entao mesmo com o chao
    -- pronto em 50ms o loop girava ate completar 700ms — era piso fixo, nao
    -- teto. O 3000 continua sendo o teto de streaming (nao e rede de seguranca:
    -- estourando, o mundo aparece montando).
    local SETTLE_MS = 150
    local grounded = false
    local waited = 0
    local settleUntil
    while waited < 3000 do
        RequestCollisionAtCoord(focusStage.x, focusStage.y, focusStage.z)
        Wait(50)
        waited = waited + 50
        if not grounded and GetGroundZFor_3dCoord(focusStage.x, focusStage.y, focusStage.z + 10.0, false) then
            grounded = true
            settleUntil = waited + SETTLE_MS
        end
        if grounded and waited >= settleUntil then break end
    end
    if not grounded then
        Wait(200)
    end

    -- o voo da abertura vê o palco de longe: carrega o entorno até de onde ele parte
    if intro then
        local ic = Config.Intro
        NewLoadSceneStartSphere(focusStage.x, focusStage.y, focusStage.z, ic.approach.distance + 40.0, 0)
        local deadline = GetGameTimer() + ic.streamTimeout
        while not IsNewLoadSceneLoaded() and GetGameTimer() < deadline do Wait(0) end
        if not IsNewLoadSceneLoaded() then
            lib.print.warn(('[mri_Qmultichar] [ABERTURA] entorno do palco não carregou em %d ms; o voo segue'):format(ic.streamTimeout))
        end
        NewLoadSceneStop()
    end

    peds = {}
    pedByCitizen = {}
    local total = #occupied
    for i = 1, total do
        if token ~= buildToken then return end -- outro build começou
        local stage = resolveStage(i, total, stages)
        local entry = spawnCharacterPed(occupied[i], stage)
        if entry then
            peds[#peds + 1] = entry
            pedByCitizen[entry.citizenid] = #peds
        end
    end

    -- câmera
    sceneCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(sceneCam, true)
    RenderScriptCams(true, false, 0, true, true)

    active = true

    -- foco inicial (sem glide: já começa enquadrado)
    ensureNameDui()
    focusedIndex = nil
    if #peds > 0 then
        focusedIndex = (preferId and pedByCitizen[preferId]) or 1
        target = camPoseFor(peds[focusedIndex])
        local fe = peds[focusedIndex]
        SetFocusPosAndVel(fe.pos.x, fe.pos.y, fe.groundZ + 1.0, 0.0, 0.0, 0.0)
        setNametag(fe.name)
        cur = { x = target.x, y = target.y, z = target.z, lx = target.lx, ly = target.ly, lz = target.lz }
        copyPose(glideStart, cur)
        glideAt = 0 -- foco inicial já enquadrado (e=1 imediato)
        SetCamCoord(sceneCam, cur.x, cur.y, cur.z)
        PointCamAtCoord(sceneCam, cur.lx, cur.ly, cur.lz)
    else
        -- Sem personagens: enquadra a MESMA stage que recebeu o foco de streaming
        -- lá em cima (`focusStage`). Antes a câmera ia pro `cfg.origin` do
        -- config.lua enquanto o SetFocusPosAndVel apontava pra `stages[1]` do
        -- painel — lugares diferentes, então a câmera ficava numa área não
        -- streamada e o mundo aparecia sem textura/LOD.
        setNametag('')
        local fe = {
            pos = { x = focusStage.x, y = focusStage.y },
            groundZ = focusStage.z + (focusStage.zOffset or 0.0),
            heading = focusStage.heading,
        }
        target = camPoseFor(fe)
        cur = { x = target.x, y = target.y, z = target.z, lx = target.lx, ly = target.ly, lz = target.lz }
        copyPose(glideStart, cur)
        glideAt = 0
        SetCamCoord(sceneCam, cur.x, cur.y, cur.z)
        PointCamAtCoord(sceneCam, cur.lx, cur.ly, cur.lz)
    end

    -- abertura: parte do alto e desce até o enquadramento
    introFlying = intro == true
    if intro then
        local final = target
        snapPose(introPose(final))
        beginGlide(final, Config.Intro.approach.time)
    end

    startRenderThread()

    -- re-envia o nome focado periodicamente: a 1ª msg pode chegar antes do
    -- listener da DUI existir. A página ignora se o nome for igual.
    local rToken = buildToken
    CreateThread(function()
        while active and buildToken == rToken do
            if nameReady and nameDui and focusedIndex and peds[focusedIndex] then
                SendDuiMessage(nameDui, json.encode({ name = peds[focusedIndex].name or '' }))
            end
            Wait(500)
        end
    end)

    if not keepFaded then
        DoScreenFadeIn(intro and Config.Intro.dipMs or 800)
    end
end

---Busca a lista de personagens e monta o showroom (usado no logout/reabrir).
---@param characters table|nil se já tiver a lista, evita refetch
---@param preferId string|nil
function Showroom.open(characters, preferId)
    if not characters then
        local payload = lib.callback.await('mri_Qmultichar:server:getCharacters', false)
        characters = payload and payload.characters or {}
        preferId = preferId or (payload and payload.lastPlayed)
    end
    Showroom.build(characters, preferId)
end

---@param keepFaded boolean|nil true = nao faz fade-in ao sair. Use quando quem
--- chama vai continuar a transicao (ex: entrar no personagem -> UI do spawn):
--- abrir a tela no meio mostra o mundo com a camera solta e o ped escondido,
--- e o jogo parece travado ate a proxima UI aparecer.
function Showroom.destroy(keepFaded)
    Showroom.studioEnd()
    active = false
    buildToken = buildToken + 1
    discardCreation()

    if sceneCam and DoesCamExist(sceneCam) then
        SetCamActive(sceneCam, false)
        DestroyCam(sceneCam, false)
    end
    sceneCam = nil
    RenderScriptCams(false, false, 0, true, true)

    -- devolve o foco de streaming pro player (senão o spawn real fica sem LOD)
    ClearFocus()

    for i = 1, #peds do
        if peds[i].ped and DoesEntityExist(peds[i].ped) then
            DeleteEntity(peds[i].ped)
        end
    end
    peds = {}
    pedByCitizen = {}
    focusedIndex = nil

    if DoesEntityExist(PlayerPedId()) then
        SetEntityVisible(PlayerPedId(), true, false)
        FreezeEntityPosition(PlayerPedId(), false)
    end

    -- devolve o bucket 0, a não ser que esteja no meio da criação (que usa 2)
    if not (Multichar and Multichar.isCharacterCreationFlowActive and Multichar.isCharacterCreationFlowActive()) then
        TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
    end
end

exports('showroomBuild', Showroom.build)
exports('showroomOpen', Showroom.open)
exports('showroomFocus', Showroom.focus)
exports('showroomDestroy', Showroom.destroy)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then
        Showroom.destroy()
        if nameDui then DestroyDui(nameDui) nameDui = nil end
        -- garante que a HUD volte se o resource parar com a NUI aberta
        LocalPlayer.state:set('hideHud', false, false)
    end
end)
