function DebugPrint(...)
    if Config and Config.Debug then
        lib.print.info(...)
    end
end
