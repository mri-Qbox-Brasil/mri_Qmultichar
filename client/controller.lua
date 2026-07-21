-- Navegação por gamepad do multichar.
-- Com SetNuiFocus(true, true), teclado/mouse vão pro CEF (a NUI nativa cuida
-- deles), mas o gamepad NÃO é capturado — então lemos o controle aqui e
-- enviamos mensagens pra NUI mover o foco. Mouse/teclado seguem interagindo
-- diretamente com a NUI.

local CONTROLS = {
    up = 172,     -- INPUT_FRONTEND_UP (D-Pad cima)
    down = 173,   -- INPUT_FRONTEND_DOWN
    left = 174,   -- INPUT_FRONTEND_LEFT
    right = 175,  -- INPUT_FRONTEND_RIGHT
    accept = 176, -- INPUT_FRONTEND_RDOWN (A / Cross)
    back = 177,   -- INPUT_FRONTEND_RRIGHT (B / Circle)
}

local REPEAT_MS = 150
local controllerModeSent = nil

local function sendMode(enabled)
    if controllerModeSent == enabled then return end
    controllerModeSent = enabled
    SendNUIMessage({ action = 'controllerMode', enabled = enabled })
end

CreateThread(function()
    local lastDirAt = 0

    while true do
        if Multichar.isNuiOpen and Multichar.isNuiOpen() then
            -- IsUsingKeyboard(2) => true no teclado/mouse; gamepad é o inverso.
            -- (mesmo nativo que a StreetKings usa em SKInput.isUsingKeyboard)
            local usingPad = not IsUsingKeyboard(2)
            sendMode(usingPad == true)

            if usingPad then
                local now = GetGameTimer()

                local dir
                if IsControlPressed(0, CONTROLS.up) then dir = 'up'
                elseif IsControlPressed(0, CONTROLS.down) then dir = 'down'
                elseif IsControlPressed(0, CONTROLS.left) then dir = 'left'
                elseif IsControlPressed(0, CONTROLS.right) then dir = 'right' end

                if dir then
                    if (now - lastDirAt) >= REPEAT_MS then
                        lastDirAt = now
                        SendNUIMessage({ action = 'controllerInput', input = dir })
                    end
                else
                    lastDirAt = 0
                end

                if IsControlJustPressed(0, CONTROLS.accept) then
                    SendNUIMessage({ action = 'controllerInput', input = 'accept' })
                end
                if IsControlJustPressed(0, CONTROLS.back) then
                    SendNUIMessage({ action = 'controllerInput', input = 'back' })
                end

                -- impede que esses controles afetem o jogo por baixo da NUI
                for _, id in pairs(CONTROLS) do
                    DisableControlAction(0, id, true)
                end
            end

            Wait(0)
        else
            if controllerModeSent then
                sendMode(false)
            end
            Wait(250)
        end
    end
end)
