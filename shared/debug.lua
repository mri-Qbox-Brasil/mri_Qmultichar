-- Quando usar:
--   DebugPrint(...)      tracing verboso de dev (entrei função X, passei pelo passo Y).
--                        Silenciado se Config.Debug = false.
--   lib.print.warn(...)  algo inesperado mas não fatal — admin precisa ver mesmo em prod.
--   lib.print.error(...) algo quebrou — admin TEM que ver mesmo em prod.

function DebugPrint(...)
    if Config and Config.Debug then
        lib.print.info(...)
    end
end
