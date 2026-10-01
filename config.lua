Config = {}

Config.Debug = false

Config.Locale = 'pt-br'

Config.AllowAccentOverride = false

-- Showroom: em vez de 1 ped que recarrega a cada slot, monta uma fileira com
-- 1 ped por personagem (roupa de cada um), cada um com animação idle. A câmera
-- desliza pro ped do slot focado e um holofote (DrawSpotLight) o destaca.
Config.Showroom = {
    -- ponto-base da fileira (chão) e direção que os peds encaram (pra câmera).
    origin = vector3(-1645.48, -1115.97, 13.03),
    heading = 307.43,
    spacing = 1.55, -- distância entre peds na fileira

    -- câmera relativa ao ped focado (offsets a partir do chão do ped).
    cam = {
        distance = 2.6,
        height = 0.55,     -- altura da câmera acima do chão do ped
        lookHeight = 0.6,  -- altura do ponto que a câmera mira
        fov = 36.0,
        transition = 0.75,  -- duração (s) do glide entre peds próximos (ease-in-out)
        cutDistance = 18.0, -- salto ACIMA disso corta com fade (não voa pelo mundo)
        -- desfoque do fundo: nítido de (distância até o personagem - near) a (+ far) metros
        dof = { enabled = true, strength = 0.85, near = 0.8, far = 1.3 },
        -- câmera na mão: balanço em metros da câmera (position) e da mira (look); nil desliga
        breathe = { position = 0.03, look = 0.018, speed = 1.0 },
    },

    removeFadeMs = 700, -- personagem deletado some da cena em tantos ms

    -- luz de preenchimento frontal (do lado da câmera) — ilumina o rosto/frente,
    -- que o holofote (de cima) deixa escuro.
    frontlight = {
        enabled = true,
        dist = 1.5,   -- distância na frente do ped (em direção à câmera)
        height = 0.95, -- altura acima do chão
        range = 4.5,  -- alcance da luz
        intensity = 3.0,
        r = 255, g = 246, b = 230, -- branco levemente quente
    },

    -- nome em 3D atrás do ped (DUI num quad world-space — profundidade + nitidez).
    nametag = {
        enabled = true,
        back = 0.29,   -- distância atrás do ped (metros)
        height = 1.56, -- altura do centro do nome acima do chão (metros)
        width = 7.40,  -- largura do painel no mundo (metros); altura = width/4 (DUI 4:1)
        fit = 0.8,     -- teto: fração da largura que a câmera enxerga ali (nome não sai cortado)
    },

    -- criação de personagem: o ped de preview fica no palco da 1ª posição e a
    -- câmera o enquadra à direita da tela (a NUI da criação ocupa a esquerda).
    -- O palco é também o estúdio do editor de aparência: no final o ped do jogador
    -- toma o lugar do preview e o editor abre ali, sem fade nem teleporte.
    creation = {
        -- um plano por capítulo; a câmera desliza de um pro outro em `time` segundos.
        -- distance/height/lookHeight em metros; lookOffset desloca câmera e mira pro
        -- lado (o ped vai pra direita da tela); angle gira o plano em volta do ped (graus).
        shots = {
            gender = { distance = 1.9,  height = 1.0,  lookHeight = 0.95, lookOffset = 0.55, angle = 0,   time = 0.9 },
            name   = { distance = 0.95, height = 1.62, lookHeight = 1.58, lookOffset = 0.28, angle = 0,   time = 1.1 },
            origin = { distance = 1.35, height = 1.4,  lookHeight = 1.3,  lookOffset = 0.38, angle = 25,  time = 1.1 },
            birth  = { distance = 2.1,  height = 0.8,  lookHeight = 1.0,  lookOffset = 0.6,  angle = -12, time = 1.0 },
            arrival = { distance = 1.6, height = 1.35, lookHeight = 1.25, lookOffset = 0.45, angle = 18, time = 1.1 },
            -- o final termina no plano inicial do editor (editorCamera), só o tempo vem daqui
            finale = { time = 1.8 },
        },
        -- entrada na criação: os personagens somem em fadeMs, a câmera vai até o plano do
        -- gênero em time segundos subindo arc metros no meio do caminho, e o preview
        -- aparece em pedFadeMs. Palco a mais de cam.cutDistance: fade de dipOut/dipIn ms.
        enter = { time = 2.6, arc = 1.2, fadeMs = 650, pedFadeMs = 900, dipOut = 700, dipIn = 1100 },
        -- desfoque do fundo: nítido de (distância até o ped - near) a (+ far) metros
        dof = { enabled = true, strength = 1.0, near = 0.35, far = 0.9 },
        lookAtCamera = true, -- o ped acompanha a câmera com a cabeça
        haptics = true,      -- vibração do controle ao confirmar, errar e no final
        finaleHold = 2400,   -- ms do momento final antes do editor de aparência abrir
        -- Plano e desfoque com que o editor de aparência abre, pra o final da criação
        -- terminar igual e a troca pro editor não aparecer. Valores do mri_Qappearance
        -- (constants.CAMERAS.default e Config.DepthOfField); offset/point relativos ao ped.
        editorCamera = {
            offset = vec3(0.0, 2.5, 0.5),
            point = vec3(-0.05, 0.0, 0.0),
            fov = 49.0,
            dof = { near = 0.5, far = 5.0, strength = 1.0, fnumber = 1.2 },
        },
        -- dict/clip direto ou por gênero (male/female). Dict que não existir no jogo
        -- avisa uma vez no F8 e é ignorado.
        anims = {
            idle    = { dict = 'anim@heists@heist_corona@single_team', clip = 'single_team_loop_boss' },
            enter   = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            confirm = {
                male   = { dict = 'gestures@m@standing@casual', clip = 'gesture_pleased' },
                female = { dict = 'gestures@f@standing@casual', clip = 'gesture_pleased' },
            },
            finale  = {
                male   = { dict = 'anim@mp_player_intcelebrationmale@thumbs_up', clip = 'thumbs_up' },
                female = { dict = 'anim@mp_player_intcelebrationfemale@thumbs_up', clip = 'thumbs_up' },
            },
        },
        animation = 'WORLD_HUMAN_GUARD_STAND', -- idle de reserva (catálogo `animations` abaixo)
        -- Visual com que o ped aparece na criação e com que o editor de aparência abre.
        -- headBlend: pais do criador do GTA Online (0-20 e 42-44 pais, 21-41 e 45 mães);
        -- shapeMix/skinMix de 0.0 (puxa o 1º) a 1.0 (puxa o 2º).
        -- hair: style = drawable do cabelo, color/highlight = paleta de cabelo (0-63).
        -- overlays por id: 1 barba, 2 sobrancelha, 5 blush, 8 batom; index = estilo,
        -- opacity 0.0 a 1.0, color = paleta de cabelo (1, 2) ou de maquiagem (5, 8).
        -- components por id: { drawable, texture }; o que faltar fica 0.
        preset = {
            male = {
                headBlend = { shapeFirst = 4, shapeSecond = 31, skinFirst = 4, skinSecond = 31, shapeMix = 0.3, skinMix = 0.4 },
                hair = { style = 19, texture = 0, color = 2, highlight = 4 }, -- High Slicked Sides
                eyeColor = 5,
                overlays = {
                    [1] = { index = 0, opacity = 0.65, color = 2 }, -- barba curta por fazer
                    [2] = { index = 12, opacity = 0.9, color = 2 },
                },
                components = {},
            },
            female = {
                headBlend = { shapeFirst = 9, shapeSecond = 25, skinFirst = 9, skinSecond = 25, shapeMix = 0.8, skinMix = 0.6 },
                hair = { style = 4, texture = 0, color = 4, highlight = 10 }, -- Ponytail
                eyeColor = 3,
                overlays = {
                    [2] = { index = 3, opacity = 0.85, color = 3 },
                    [5] = { index = 0, opacity = 0.25, color = 5 },
                    [8] = { index = 0, opacity = 0.45, color = 2 },
                },
                components = {},
            },
        },
    },

    -- holofote no ped focado (args do nativo DrawSpotLight).
    spotlight = {
        height = 3.6,      -- altura do facho acima do ped
        r = 255, g = 255, b = 255,
        distance = 12.0,   -- alcance do facho
        brightness = 20.0,
        hardness = 0.4,    -- dureza da borda
        radius = 26.0,     -- raio do cone (maior = pool mais largo)
        falloff = 14.0,    -- queda da intensidade
    },

    -- catálogo de animações idle (fonte única: usado no modo de posicionar do
    -- /adminchar, no dropdown do painel e como sorteio de fallback).
    -- Cada item: { id, label } usa um cenário GTA (TaskStartScenarioInPlace);
    -- se tiver { dict, clip } toca um anim clip em loop (TaskPlayAnim).
    -- Dica: sentado/encostado ficam melhores posicionando o ped contra a
    -- geometria certa (parede, degrau, banco) — o preview do modo de posicionar
    -- mostra ao vivo antes de confirmar.
    animations = {
        -- Em pé — atitude / cool
        { id = 'WORLD_HUMAN_STAND_IMPATIENT',    label = 'Impaciente' },
        { id = 'WORLD_HUMAN_STAND_MOBILE',       label = 'No celular' },
        { id = 'WORLD_HUMAN_GUARD_STAND',        label = 'Braços cruzados' },
        { id = 'WORLD_HUMAN_GUARD_PATROL',       label = 'Guarda (alerta)' },
        { id = 'WORLD_HUMAN_COP_IDLES',          label = 'Policial (parado)' },
        { id = 'WORLD_HUMAN_STAND_ARMY',         label = 'Postura militar' },
        { id = 'WORLD_HUMAN_DRUG_DEALER',        label = 'De boa (mãos)' },
        { id = 'WORLD_HUMAN_DRUG_DEALER_HARD',   label = 'Durão' },
        { id = 'WORLD_HUMAN_HANG_OUT_STREET',    label = 'De boa na rua' },
        { id = 'WORLD_HUMAN_TOURIST_MAP',        label = 'Olhando mapa' },
        { id = 'WORLD_HUMAN_BINOCULARS',         label = 'Binóculos' },
        { id = 'WORLD_HUMAN_WINDOW_SHOP_BROWSE', label = 'Olhando vitrine' },
        { id = 'WORLD_HUMAN_CHEERING',           label = 'Comemorando' },
        -- Em pé — vícios / lazer (segura item)
        { id = 'WORLD_HUMAN_SMOKING',            label = 'Fumando' },
        { id = 'WORLD_HUMAN_SMOKING_POT',        label = 'Fumando (maconha)' },
        { id = 'WORLD_HUMAN_AA_SMOKE',           label = 'Fumando (relaxado)' },
        { id = 'WORLD_HUMAN_AA_COFFEE',          label = 'Tomando café' },
        { id = 'WORLD_HUMAN_DRINKING',           label = 'Bebendo' },
        { id = 'WORLD_HUMAN_PARTYING',           label = 'Curtindo (drink)' },
        { id = 'WORLD_HUMAN_STUPOR',             label = 'Bêbado (cambaleando)' },
        { id = 'WORLD_HUMAN_MOBILE_FILM_SHOCKING', label = 'Filmando com o celular' },
        { id = 'WORLD_HUMAN_PAPARAZZI',          label = 'Tirando foto' },
        { id = 'WORLD_HUMAN_MUSICIAN',           label = 'Músico' },
        -- Academia / físico (chão plano)
        { id = 'WORLD_HUMAN_MUSCLE_FLEX',        label = 'Flexionando (pose)' },
        { id = 'WORLD_HUMAN_MUSCLE_FREE_WEIGHTS', label = 'Halteres' },
        { id = 'WORLD_HUMAN_JOG_STANDING',       label = 'Correndo no lugar' },
        { id = 'WORLD_HUMAN_YOGA',               label = 'Yoga' },
        { id = 'WORLD_HUMAN_PUSH_UPS',           label = 'Flexões (chão)' },
        { id = 'WORLD_HUMAN_SIT_UPS',            label = 'Abdominais (chão)' },
        -- Trabalho (variedade)
        { id = 'WORLD_HUMAN_CLIPBOARD',          label = 'Prancheta' },
        { id = 'WORLD_HUMAN_HAMMERING',          label = 'Martelando' },
        -- Encostado (posicione contra uma parede)
        { id = 'WORLD_HUMAN_LEANING',            label = 'Encostado (parede)' },
        -- Sentado (posicione na geometria: degrau/muro/banco)
        { id = 'SIT_GROUND',                     label = 'Sentado no chão',   dict = 'amb@world_human_picnic@male@base', clip = 'base' },
        { id = 'WORLD_HUMAN_SEAT_STEPS',         label = 'Sentado (degrau)' },
        { id = 'WORLD_HUMAN_SEAT_WALL',          label = 'Sentado (muro)' },
        { id = 'WORLD_HUMAN_SEAT_LEDGE',         label = 'Sentado (beirada)' },
        { id = 'PROP_HUMAN_SEAT_BENCH',          label = 'Sentado (banco)' },
    },
}

-- Histórias de chegada (capítulo "O que te trouxe" da criação), uma por arquivo em
-- client/stories. Quais ficam ligadas e o destino de cada uma se ajustam no /adminchar;
-- aqui ficam câmera, ritmo e tetos.
Config.Arrival = {
    fov = 42.0,
    blendOutMs = 1600,     -- câmera deslizando pra câmera do jogo no fim
    streamTimeout = 6000,  -- teto pra carregar a área da cena (ms)
    -- contêiner do coyote: o destino marcado é onde o personagem pisa ao sair, de costas
    -- pro contêiner; o contêiner aparece atrás dele, com as portas viradas pra lá
    container = {
        -- contêiner do trem do Tuners: as portas são do próprio modelo e abrem pela animação
        model = `tr_prop_tr_container_01a`,
        openDict = 'anim@scripted@player@mission@tunf_train_ig1_container_p1@male@',
        openAnim = 'action_container',
        openPhase = 0.66,      -- ponto da animação em que as portas começam a abrir (0 a 1)
        doorAxis = -1,         -- -1 = portas no lado -Y do modelo (o do trem), 1 = no lado +Y
        doorOpenMs = 1300,     -- a luz invadindo enquanto as portas abrem
        -- colisão de porta aberta, invisível no mesmo lugar (a do contêiner animado não abre)
        collisionModel = `prop_ld_container`,
        floor = 0.12,          -- piso acima da base do modelo; só vale se a medição do piso falhar (m)
        gap = 1.4,             -- distância entre as portas e o destino (m)
        darkness = 'int_extlight_none_dark',
        migrants = { `a_m_m_mexlabor_01`, `a_f_m_downtown_01`, `a_m_y_mexthug_01`, `a_m_m_soucent_01` },
        beats = { dark = 5200, impact = 3800, open = 4200, out = 7000 },
        -- desenho de som: sons do próprio GTA (nomes do soundNames.json do DurtyFree),
        -- tocados do contêiner; { nome, soundset } (sem soundset quando o dump lista 0)
        sounds = {
            banks = {
                script = { 'DLC_HEI4/DLC_HEI4_Submarine', 'Container_Lifter', 'DLC_APARTMENT/APT_Yacht_01' },
                ambient = { 'Crane', 'Crane_Impact_Sweeteners', 'Crane_Stress', 'CREAK_V1' },
            },
            creakLoop = { 'Creaking_Loop', 'DLC_H4_Submarine_Crush_Depth_Sounds' },
            creaks = { { 'CREAK_01', 'DOCKS_HEIST_SETUP_SOUNDS' }, { 'Strain', 'CRANE_SOUNDS' } },
            horn = { 'HORN', 'DLC_Apt_Yacht_Ambient_Soundset' },
            impact = {
                { 'Container_Impact_Land', 'CRANE_SOUNDS' },
                { 'Container_Land', 'CONTAINER_LIFTER_SOUNDS' },
                { 'FAMILY1_CAR_CRASH_BIG' },
            },
            door = { 'container_door', 'dlc_prison_break_heist_sounds' },
            flash = { 'SCREEN_FLASH', 'CELEBRATION_SOUNDSET' },
            gulls = { 'Seagulls', 'JEWEL_HEIST_SOUNDS' },
        },
    },
    plane = {
        loadTimeout = 10000, -- teto pra carregar a cutscene (ms)
        cutAtMs = 38600,     -- corta aqui, no fim da aterrissagem (a cutscene segue além)
        -- legendas (locales: story.plane_N), em ms desde o começo da cutscene
        captions = { { at = 2500, key = 'plane_1' }, { at = 12000, key = 'plane_2' }, { at = 26000, key = 'plane_3' } },
    },
}

-- Passagem do editor de aparência pra história de chegada: zoom seco no personagem,
-- freeze em preto e branco com o nome, cartão do capítulo cobrindo a tela enquanto a
-- história monta, e a revelação. Sons e efeito de tela são do próprio GTA.
Config.Prelude = {
    zoomMs = 260,          -- zoom seco até o rosto
    zoomPush = 0.4,        -- quanto a câmera anda até o rosto (0 a 1)
    zoomFov = 0.62,        -- fov final em relação ao inicial
    freezeMs = 2800,       -- quanto o freeze com o nome fica na tela
    wipeMs = 480,          -- o cartão do capítulo entrando até cobrir tudo
    chapterMinMs = 1900,   -- tempo mínimo do cartão na tela (o carregamento pode pedir mais)
    postfx = 'HeistCelebPassBW',
    sounds = {
        zoom = { 'Whoosh_1s_L_to_R', 'MP_LOBBY_SOUNDS' },
        freeze = { 'Hit_In', 'PLAYER_SWITCH_CUSTOM_SOUNDSET' },
        flash = { 'SCREEN_FLASH', 'CELEBRATION_SOUNDSET' },
        wipe = { 'Whoosh_1s_R_to_L', 'MP_LOBBY_SOUNDS' },
        reveal = { 'Short_Transition_Out', 'PLAYER_SWITCH_CUSTOM_SOUNDSET' },
    },
}

-- Abertura (tela de título antes do showroom) e hora/clima do menu. Os planos, ligar e
-- desligar, a hora e o clima se ajustam no /adminchar, aba Abertura; aqui ficam ritmo,
-- tetos e o voo até o palco.
Config.Intro = {
    shotTime = 8.0,        -- segundos de cada plano
    drift = 7.0,           -- metros que a câmera anda pra frente durante o plano
    dipMs = 700,           -- escurecer/clarear entre planos (ms)
    loadDistance = 800.0,  -- alcance da carga de cada plano, na direção da câmera
    streamTimeout = 5000,  -- teto pra carregar a área de um plano (ms)
    -- depois do Enter a câmera parte do alto, atrás do palco, olhando por cima dele, e
    -- desce até o enquadramento do personagem
    approach = {
        distance = 55.0,   -- metros atrás do plano final
        height = 26.0,     -- metros acima dele
        lookAhead = 30.0,  -- a mira começa esses metros além do palco
        lookHeight = 6.0,  -- e essa altura acima do ponto final
        time = 5.0,        -- duração do voo (s)
    },
    -- climas do dropdown do painel (tipos do jogo)
    weathers = {
        { id = 'EXTRASUNNY', label = 'Sol forte' },
        { id = 'CLEAR',      label = 'Céu limpo' },
        { id = 'CLOUDS',     label = 'Nuvens' },
        { id = 'OVERCAST',   label = 'Nublado' },
        { id = 'SMOG',       label = 'Neblina seca' },
        { id = 'FOGGY',      label = 'Nevoeiro' },
        { id = 'CLEARING',   label = 'Abrindo depois da chuva' },
        { id = 'RAIN',       label = 'Chuva' },
        { id = 'THUNDER',    label = 'Tempestade' },
        { id = 'SNOWLIGHT',  label = 'Neve fraca' },
        { id = 'XMAS',       label = 'Natal (neve no chão)' },
        { id = 'HALLOWEEN',  label = 'Halloween' },
    },
}

Config.DeleteTables = {
}

Config.Appearance = {
    resource = 'auto',
    autoPreference = {
        'illenium-appearance',
        'fivem-appearance',
    },
}

return Config
