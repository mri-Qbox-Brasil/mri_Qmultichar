-- Adapter: illenium-appearance e mri_Qappearance (mesma API e mesmo namespace de eventos).

local adapter = {}

function adapter.setPedAppearance(resourceName, ped, data)
    exports[resourceName]:setPedAppearance(ped, data)
end

function adapter.startCustomization(resourceName, cb, cfg)
    exports[resourceName]:startPlayerCustomization(cb, cfg)
end

function adapter.setPlayerModel(resourceName, model)
    exports[resourceName]:setPlayerModel(model)
end

function adapter.saveAppearance(_, data)
    TriggerServerEvent('illenium-appearance:server:saveAppearance', data)
end

Appearance.registerAdapter({ 'illenium-appearance', 'mri_Qappearance' }, adapter)
