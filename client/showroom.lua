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

-- pose atual/alvo da câmera (glide temporizado com ease-in-out)
local cur = { x = 0, y = 0, z = 0, lx = 0, ly = 0, lz = 0 }
local target = { x = 0, y = 0, z = 0, lx = 0, ly = 0, lz = 0 }
local glideStart = { x = 0, y = 0, z = 0, lx = 0, ly = 0, lz = 0 }
local glideAt = 0

local function copyPose(dst, src)
    dst.x, dst.y, dst.z, dst.lx, dst.ly, dst.lz = src.x, src.y, src.z, src.lx, src.ly, src.lz
end

-- começa uma transição temporizada da pose atual até o novo alvo
local function beginGlide(newTarget)
    copyPose(glideStart, cur)
    target = newTarget
    glideAt = GetGameTimer()
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

local function cutTo(pose, e)
    pendingPose, pendingE = pose, e
    if cutting then return end -- já há um corte rodando; ele aplica o último pendente
    cutting = true
    CreateThread(function()
        DoScreenFadeOut(200)
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
        DoScreenFadeIn(240)
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

local function spawnCharacterPed(character, stage)
    local x, y, gz = stage.x, stage.y, stage.z

    local clothing, model = fetchAppearance(character.citizenid)
    if not model then
        model = (character.charinfo and character.charinfo.gender == 1) and `mp_f_freemode_01` or `mp_m_freemode_01`
    end

    if not lib.requestModel(model, 15000) then
        return nil
    end

    -- Re-aterra no chão REAL de x,y (o Z salvo pode estar off). SetEntityCoords
    -- (não NoOffset) faz o snap do ped ao solo sozinho — método comprovado do
    -- camera.lua antigo. Precisa da colisão carregada ali (o SetFocusPosAndVel
    -- do build já streama o palco).
    RequestCollisionAtCoord(x, y, gz)
    local found, groundZ = GetGroundZFor_3dCoord(x, y, gz + 3.0, false)
    -- offset manual (subir/abaixar do /adminchar) aplicado por cima do chão real
    local finalZ = (found and groundZ or gz) + (stage.zOffset or 0.0)

    local ped = CreatePed(4, model, x, y, finalZ, stage.heading, false, false)
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(ped) then return nil end

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedCanBeTargetted(ped, false)
    -- snap ao solo ANTES de tirar colisão/congelar
    SetEntityCoords(ped, x, y, finalZ, false, false, false, false)
    SetEntityHeading(ped, stage.heading)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    gz = finalZ

    if clothing then
        local ok, decoded = pcall(json.decode, clothing)
        if ok and decoded then
            Appearance.setPedAppearance(ped, decoded)
        end
    end

    -- animação idle (do painel, ou sorteada do catálogo do config.lua como fallback)
    local animId = stage.scenario
    if not animId then
        local a = cfg.animations
        animId = a[math.random(1, #a)].id
    end
    PlayShowroomAnim(ped, animId)

    local ci = character.charinfo
    return {
        ped = ped,
        citizenid = character.citizenid,
        slot = character.cid,
        groundZ = gz,
        pos = { x = x, y = y },
        heading = stage.heading,
        name = ci and ((ci.firstname or '') .. ' ' .. (ci.lastname or '')) or '',
    }
end

-- ===== câmera / holofote (thread) ====================================

local function startRenderThread()
    local myToken = buildToken
    CreateThread(function()
        while active and buildToken == myToken and sceneCam and DoesCamExist(sceneCam) do
            -- glide temporizado (ease-in-out) da pose inicial até o alvo
            local dur = (cfg.cam.transition or 0.75) * 1000.0
            local e = 1.0
            if dur > 0 then
                local tt = (GetGameTimer() - glideAt) / dur
                e = tt < 1.0 and easeInOut(tt) or 1.0
            end
            cur.x = glideStart.x + (target.x - glideStart.x) * e
            cur.y = glideStart.y + (target.y - glideStart.y) * e
            cur.z = glideStart.z + (target.z - glideStart.z) * e
            cur.lx = glideStart.lx + (target.lx - glideStart.lx) * e
            cur.ly = glideStart.ly + (target.ly - glideStart.ly) * e
            cur.lz = glideStart.lz + (target.lz - glideStart.lz) * e

            SetCamCoord(sceneCam, cur.x, cur.y, cur.z)
            PointCamAtCoord(sceneCam, cur.lx, cur.ly, cur.lz)

            -- holofote no ped focado
            local entry = focusedIndex and peds[focusedIndex]
            if entry and DoesEntityExist(entry.ped) then
                local s = cfg.spotlight
                DrawSpotLight(
                    entry.pos.x, entry.pos.y, entry.groundZ + s.height,
                    0.0, 0.0, -1.0,
                    s.r, s.g, s.b,
                    s.distance, s.brightness, s.hardness, s.radius, s.falloff
                )

                -- luz frontal de preenchimento (do lado da câmera) — ilumina o rosto,
                -- que o holofote de cima deixa na sombra.
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

                -- nome 3D atrás do ped (quad world-space => o ped fica na frente)
                local nt = cfg.nametag
                if nameReady and nt.enabled ~= false then
                    local fx, fy = forwardOf(entry.heading) -- direção que o ped encara (pra câmera)
                    local center = vector3(
                        entry.pos.x - fx * nt.back,
                        entry.pos.y - fy * nt.back,
                        entry.groundZ + nt.height
                    )
                    DrawWorldTextQuad(NAME_TXD, NAME_TXN, center, vector3(cur.x, cur.y, cur.z), nt.width)
                end
            end

            Wait(0)
        end
    end)
end

-- ===== API pública ===================================================

---Foca o slot do citizenid: a câmera desliza e o holofote acompanha.
---@param citizenId string
function Showroom.focus(citizenId)
    if not active then return end
    local idx = pedByCitizen[citizenId]
    if not idx then return end
    focusedIndex = idx
    local e = peds[idx]
    local pose = camPoseFor(e)
    SetFocusPosAndVel(e.pos.x, e.pos.y, e.groundZ + 1.0, 0.0, 0.0, 0.0)
    setNametag(e.name)

    -- já em transição com fade? só atualiza o alvo final (o corte aplica o último)
    if cutting then
        pendingPose, pendingE = pose, e
        return
    end

    -- salto longo → corte com fade; salto curto → glide suave
    local dx, dy, dz = pose.x - cur.x, pose.y - cur.y, pose.z - cur.z
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    if dist > (cfg.cam.cutDistance or 18.0) then
        cutTo(pose, e)
    else
        beginGlide(pose)
    end
end

function Showroom.isActive()
    return active
end

---Monta o showroom com a lista de personagens (ocupados). `preferId` = citizenid
---que já começa focado (ex.: last-played).
---@param characters table
---@param preferId string|nil
function Showroom.build(characters, preferId)
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
        DoScreenFadeIn(800)
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
    active = false
    buildToken = buildToken + 1

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

---Recria o showroom (ex.: após deletar personagem).
function Showroom.rebuild()
    if not active and not Multichar.isNuiOpen() then return end
    Showroom.open()
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
