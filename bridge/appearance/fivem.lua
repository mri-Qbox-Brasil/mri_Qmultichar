-- Adapter: fivem-appearance (upstream original).
-- A API de set/start é compatível com illenium (que é fork dele).
-- Não tem evento canônico de save server-side; saveAppearance fica no-op.

local adapter = {}

function adapter.setPedAppearance(resourceName, ped, data)
    exports[resourceName]:setPedAppearance(ped, data)
end

function adapter.startCustomization(resourceName, cb, cfg)
    exports[resourceName]:startPlayerCustomization(cb, cfg)
end

function adapter.saveAppearance()
end

Appearance.registerAdapter({ 'fivem-appearance' }, adapter)
