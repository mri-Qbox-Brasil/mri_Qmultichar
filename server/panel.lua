-- Config de painel (branding + opções da landing) gerida pelo /adminchar.
-- Segue o padrão do mri_Qspawn: JSON em data/config.json é a fonte de verdade,
-- CRUD gated por ACE, e broadcast em tempo real na alteração (sem restart).

local PANEL_FILE = 'data/config.json'

local defaultConfig = {
    branding = {
        title = 'MRI',
        subtitle = 'MULTICHARACTER',
        logoUrl = '',
    },
    landing = {
        showContinue = true,
    },
    -- slots de personagem geridos pelo painel (substituem os comandos).
    slots = {
        default = 3, -- slots que todo jogador tem por padrão
        max = 10,    -- teto pra conceder slots extra por jogador
    },
    -- posições do showroom (ordenadas): o i-ésimo personagem ocupa a i-ésima.
    -- cada uma: { x, y, z, heading, scenario }. vazio = usa a fileira automática do config.lua.
    showroom = {
        stages = {},
        -- nome 3D atrás do ped (DUI). tunável in-game pelo /adminchar.
        nametag = {
            enabled = true,
            back = 0.75,
            height = 1.15,
            width = 3.8,
        },
    },
}

local config = {}

---Preenche recursivamente as chaves que faltam em `target` a partir de `defaults`.
---@param target table
---@param defaults table
local function fillDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == 'table' then
            if type(target[key]) ~= 'table' then
                target[key] = {}
            end
            fillDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function loadFromDisk()
    local raw = LoadResourceFile(GetCurrentResourceName(), PANEL_FILE)
    if raw then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            config = decoded
            fillDefaults(config, defaultConfig)
            return
        end
        lib.print.warn('[mri_Qmultichar] data/config.json inválido, usando defaults')
    end

    config = {}
    fillDefaults(config, defaultConfig)
end

local function saveToDisk()
    local ok = SaveResourceFile(GetCurrentResourceName(), PANEL_FILE, json.encode(config, { indent = true }), -1)
    return ok == true or ok == 1
end

loadFromDisk()

---Checa se o source tem permissão de admin do painel.
---@param source integer
---@return boolean
function MultiCharIsAdmin(source)
    if not source or source == 0 then
        return true -- console
    end
    return IsPlayerAceAllowed(source, 'mri_Qmultichar.admin')
        or IsPlayerAceAllowed(source, 'command')
end

---Getter global consumido por outros scripts do servidor (ex.: getCharacters).
---@return table
function GetPanelConfig()
    return config
end

lib.callback.register('mri_Qmultichar:server:isAdmin', function(source)
    return MultiCharIsAdmin(source)
end)

lib.callback.register('mri_Qmultichar:server:getConfig', function(_source)
    return config
end)

lib.callback.register('mri_Qmultichar:server:saveConfig', function(source, payload)
    if not MultiCharIsAdmin(source) then
        return false, 'sem permissão'
    end
    if type(payload) ~= 'table' then
        return false, 'payload inválido'
    end

    -- garante o shape completo mesmo que o painel mande parcial
    fillDefaults(payload, defaultConfig)
    config = payload

    if not saveToDisk() then
        return false, 'falha ao salvar'
    end

    TriggerClientEvent('mri_Qmultichar:client:configChanged', -1, config)
    return true, config
end)

-- Registro como plugin do mri_Qadmin (aba embutida). Opcional: se o Qadmin não
-- estiver rodando, o /adminchar standalone continua funcionando.
CreateThread(function()
    if GetResourceState('mri_Qadmin') ~= 'started' then return end
    local ok, err = pcall(function()
        exports['mri_Qadmin']:RegisterPlugin({
            id = 'multichar',
            label = 'Multichar',
            icon = 'users',
            resource = 'mri_Qmultichar',
            htmlPath = 'html/index.html',
            requiredPerms = { 'mri_Qmultichar.admin', 'command' },
            description = 'Branding e opções da tela inicial do multichar',
        })
    end)
    if not ok then
        lib.print.warn(string.format('[mri_Qmultichar] Falha ao registrar plugin no mri_Qadmin: %s', tostring(err)))
    end
end)
