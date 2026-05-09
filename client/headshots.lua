-- Captura e gerenciamento de pedheadshots dos personagens.
-- Mantém handles ativos/pendentes e expõe Headshots.capture para os fluxos
-- de criação e load. Cleanup é chamado pelo NUI ao fechar a tela.

Headshots = {}

local active = {}
local pending = {}

function Headshots.capture(citizenId, ped)
    if not citizenId then
        lib.print.error('[mri_Qmultichar] Headshots.capture: citizenId nao fornecido')
        return false
    end

    ped = ped or PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        lib.print.error('[mri_Qmultichar] Headshots.capture: ped invalido')
        return false
    end

    if not IsEntityVisible(ped) then
        SetEntityVisible(ped, true, false)
        Wait(100)
    end

    local handle = RegisterPedheadshotTransparent(ped)
    if not handle or handle == 0 then
        lib.print.error('[mri_Qmultichar] Falha ao registrar pedheadshot transparent')
        return false
    end

    local timeout = 200
    while not IsPedheadshotReady(handle) and timeout > 0 do
        Wait(10)
        timeout = timeout - 1
    end

    if not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle) then
        lib.print.error('[mri_Qmultichar] Pedheadshot nao ficou pronto/valido')
        UnregisterPedheadshot(handle)
        return false
    end

    local txd = GetPedheadshotTxdString(handle)
    if not txd or txd == '' then
        lib.print.error('[mri_Qmultichar] TXD string vazia')
        UnregisterPedheadshot(handle)
        return false
    end

    local previous = pending[citizenId]
    if previous and previous ~= handle then
        pcall(UnregisterPedheadshot, previous)
    end
    pending[citizenId] = handle
    active[#active + 1] = handle

    SendNUIMessage({
        action = 'captureBase64',
        citizenid = citizenId,
        txd = txd,
    })

    DebugPrint(string.format('[mri_Qmultichar] captureBase64 enviado para NUI: citizenid=%s, txd=%s', citizenId, txd))
    return true
end

function Headshots.consumePending(citizenId)
    local handle = pending[citizenId]
    pending[citizenId] = nil
    if handle then
        pcall(UnregisterPedheadshot, handle)
    end
end

function Headshots.cleanup()
    if type(active) ~= 'table' then
        active = {}
        return
    end

    for i = 1, #active do
        local handle = active[i]
        if handle and handle ~= 0 then
            pcall(UnregisterPedheadshot, handle)
        end
    end

    active = {}
end

exports('captureHeadshotForCharacter', Headshots.capture)
