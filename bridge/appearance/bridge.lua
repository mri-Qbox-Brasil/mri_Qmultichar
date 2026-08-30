-- Bridge de appearance: detecta o resource ativo (auto ou fixo no Config),
-- resolve `provides` do FxManifest e despacha as chamadas para o adapter certo.

Appearance = {}

local adapters = {}
local resolvedName, resolvedAdapter

local function isStarted(name)
    local s = GetResourceState(name)
    return s == 'started' or s == 'starting'
end

-- `provide 'x'` e `provides { 'x' }` podem cair em chaves de metadata diferentes
local PROVIDE_KEYS = { 'provide', 'provides' }

local function resourceProvides(resourceName, providedName)
    for _, key in ipairs(PROVIDE_KEYS) do
        local n = GetNumResourceMetadata(resourceName, key) or 0
        for j = 0, n - 1 do
            if GetResourceMetadata(resourceName, key, j) == providedName then
                return true
            end
        end
    end
    return false
end

local function findProviderOf(providedName)
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name and name ~= GetCurrentResourceName() and isStarted(name) then
            if resourceProvides(name, providedName) then
                return name
            end
        end
    end
end

-- Um nome de `provide` responde 'started' no GetResourceState, mas os exports só
-- existem sob o nome REAL do resource. GetResourceByFindIndex só lista nomes reais.
local function isRealResource(name)
    for i = 0, GetNumResources() - 1 do
        if GetResourceByFindIndex(i) == name then return true end
    end
    return false
end

local function tryResolve(target)
    if isStarted(target) and isRealResource(target) then return target end
    return findProviderOf(target)
end

local function pickAdapterFor(name)
    if adapters[name] then return adapters[name] end
    for _, key in ipairs(PROVIDE_KEYS) do
        local n = GetNumResourceMetadata(name, key) or 0
        for j = 0, n - 1 do
            local provided = GetResourceMetadata(name, key, j)
            if adapters[provided] then return adapters[provided] end
        end
    end
end

local function resolve()
    local cfg = (Config and Config.Appearance) or {}
    local mode = cfg.resource or 'auto'

    if mode ~= 'auto' then
        return tryResolve(mode)
    end

    local pref = cfg.autoPreference or { 'mri_Qappearance', 'illenium-appearance', 'fivem-appearance' }
    for _, target in ipairs(pref) do
        local found = tryResolve(target)
        if found then return found end
    end
end

function Appearance.registerAdapter(names, adapter)
    if type(names) == 'string' then names = { names } end
    for _, n in ipairs(names) do
        adapters[n] = adapter
    end
end

function Appearance.getResourceName()
    if resolvedName then return resolvedName end
    resolvedName = resolve()
    if resolvedName then
        resolvedAdapter = pickAdapterFor(resolvedName)
    end
    return resolvedName
end

function Appearance.getAdapter()
    if not resolvedAdapter then Appearance.getResourceName() end
    return resolvedAdapter
end

function Appearance.isReady()
    return Appearance.getResourceName() ~= nil and Appearance.getAdapter() ~= nil
end

local function call(method, ...)
    local adapter = Appearance.getAdapter()
    if not adapter or not adapter[method] then return false end
    local ok, err = pcall(adapter[method], Appearance.getResourceName(), ...)
    if not ok then
        lib.print.error(('[bridge/appearance] %s falhou: %s'):format(method, tostring(err)))
        return false
    end
    return true
end

function Appearance.setPedAppearance(ped, data)
    return call('setPedAppearance', ped, data)
end

function Appearance.startCustomization(cb, cfg)
    local adapter = Appearance.getAdapter()
    if not adapter or not adapter.startCustomization then
        if cb then cb(nil) end
        return false
    end
    local ok, err = pcall(adapter.startCustomization, Appearance.getResourceName(), cb, cfg)
    if not ok then
        lib.print.error(('[bridge/appearance] startCustomization falhou: %s'):format(tostring(err)))
        if cb then cb(nil) end
        return false
    end
    return true
end

function Appearance.saveAppearance(data)
    return call('saveAppearance', data)
end

---Troca o modelo do ped pelo appearance (ele já faz componentes default + head blend).
---@param model number|string
---@return boolean ok false se o adapter não suporta
function Appearance.setPlayerModel(model)
    return call('setPlayerModel', model)
end

AddEventHandler('onClientResourceStop', function(name)
    if name == resolvedName then
        resolvedName, resolvedAdapter = nil, nil
    end
end)
