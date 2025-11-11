script_name("AutoTaxes")
script_author("Dawlat")
script_version("v1.0.0")

require 'lib.moonloader'
local se = require "samp.events"
local imgui = require 'mimgui'
local ffi = require 'ffi'
local encoding = require 'encoding'
local inicfg = require 'inicfg'

-- ######## General ########
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local version = "v1.0.0"
local scriptName = "AutoTaxes " .. version .. " by Dawlat"
local configFileName = "autotaxes_config"
local configFile
local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
local sizeX, sizeY = getScreenResolution()
local authTime
local famTaxesSum
local isAuth = false
local isTaxesPaid = false
local isFamTaxesPaid = false
local isHotelTaxesPaid = false

local config = {
    settings = {
        autoTaxes = false,
        autoFamTaxes = false,
        autoHotelTaxes = false,
        taxesActionDelay = 250,
        autoTaxesDelay = 60,
        autoFamTaxesDelay = 65,
        autoHotelTaxesDelay = 70
    }
}

-- -- ######## Setting menu ########
local tab = 1
local showSettings = imgui.new.bool(false)
local settingFlags = imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoCollapse
local autoTaxes
local autoFamTaxes
local autoHotelTaxes
local taxesActionDelay
local autoTaxesDelay
local autoFamTaxesDelay
local autoHotelTaxesDelay

function main()
    -- ######## On start ########
    while not isSampAvailable() do wait(100) end

    configFile = inicfg.load(config, configFileName)
    autoTaxes = imgui.new.bool(configFile.settings.autoTaxes)
    autoFamTaxes = imgui.new.bool(configFile.settings.autoFamTaxes)
    autoHotelTaxes = imgui.new.bool(configFile.settings.autoHotelTaxes)
    taxesActionDelay = new.char[256](numberToBuffer(configFile.settings.taxesActionDelay))
    autoTaxesDelay = new.char[256](numberToBuffer(configFile.settings.autoTaxesDelay))
    autoFamTaxesDelay = new.char[256](numberToBuffer(configFile.settings.autoFamTaxesDelay))
    autoHotelTaxesDelay = new.char[256](numberToBuffer(configFile.settings.autoHotelTaxesDelay))

    chatMessage("Открыть настройки - /tax")

    -- ######## Chat commands ########
    sampRegisterChatCommand("tax", toggleSettingWindow)
    sampRegisterChatCommand("ptax", payTaxes)
    sampRegisterChatCommand("pftax", payFamTaxes)
    sampRegisterChatCommand("phtax", payHotelTaxes)
    sampRegisterChatCommand("pall", payAllTaxes)

    -- ######## Execution every # ms ########
    while true do
        wait(0)

        if (isAuth) then
            if (not isTaxesPaid and autoTaxes[0] and os.difftime(os.time(), authTime) >= bufferToNumber(autoTaxesDelay)) then
                payTaxes()
            end

            if (not isFamTaxesPaid and autoFamTaxes[0] and os.difftime(os.time(), authTime) >= bufferToNumber(autoFamTaxesDelay)) then
                payFamTaxes()
            end

            if (not isHotelTaxesPaid and autoHotelTaxes[0] and os.difftime(os.time(), authTime) >= bufferToNumber(autoHotelTaxesDelay)) then
                payHotelTaxes()
            end
        end
    end
end

-- #################################################################
-- #======================= Основная логика =======================#
-- #################################################################
function payTaxes()
    isTaxesPaid = true
    lua_thread.create(function()
        sampSendChat("/phone")
        wait(bufferToNumber(taxesActionDelay))
        if (sampGetCurrentDialogId() == 1000) then
            sampCloseCurrentDialogWithButton(1)
            wait(bufferToNumber(taxesActionDelay))
        end
        sendCustomPacket('launchedApp|24')
        wait(bufferToNumber(taxesActionDelay))
        sampSendDialogResponse(6565, 1, 4, "")
        wait(bufferToNumber(taxesActionDelay))
        local dialogInfo = sampGetDialogText()
        if (string.find(dialogInfo, "У Вас нет налогов, которые требуется оплатить!")) then
            chatMessage("Обычные налоги уже оплачены!")
        end
        sampCloseCurrentDialogWithButton(1)
        sampSendChat("/phone")
    end)
end

function payFamTaxes()
    isFamTaxesPaid = true

    lua_thread.create(function()
        sampSendChat("/fammenu")
        wait(bufferToNumber(taxesActionDelay))
        sendCustomPacket('familyMenu.changePage|5')
        wait(bufferToNumber(taxesActionDelay))
        sendCustomPacket('familyMenu.apart.payTax')
        wait(bufferToNumber(taxesActionDelay))

        local dialogInfo = sampGetDialogText()
        if (string.find(dialogInfo, "Сейчас налог на квартиру составляет")) then
            local famTaxesSum = string.match(dialogInfo, "{FAAC58}%$([%d,]+)")
            famTaxesSum = famTaxesSum:gsub(",", "")
            if (tonumber(famTaxesSum) == 0) then
                chatMessage("Налоги за семейную квартиру уже оплачены!")
                goto skip
            end
            wait(bufferToNumber(taxesActionDelay))
            sampSendDialogResponse(27807, 1, 0, famTaxesSum)
            wait(bufferToNumber(taxesActionDelay))
            ::skip::
            sampCloseCurrentDialogWithButton(0)
            wait(bufferToNumber(taxesActionDelay))
            sendCustomPacket('familyMenu.exit')
            wait(bufferToNumber(taxesActionDelay))
            sendCustomPacket('onActiveViewChanged|null')
        else
            chatMessage("Ошибка оплаты налога за семейную квартиру!")
        end
    end)
end

function payHotelTaxes()
    isHotelTaxesPaid = true
    local attempt = 0
    local options = { 12, 24, 48, 96 }

    lua_thread.create(function()
        repeat
            local hours = 0
            sampSendChat("/phone")
            wait(bufferToNumber(taxesActionDelay))
            sendCustomPacket('launchedApp|24')
            wait(bufferToNumber(taxesActionDelay))

            local dialogInfo = sampGetDialogText()
            if (string.find(dialogInfo, "Продлить аренду номера в отеле")) then
                local items = {}
                for part in dialogInfo:gmatch("({73B461}[^%{]+)") do
                    table.insert(items, part)
                end
                local itemIndex = findItemIndex(items, "{73B461}Продлить аренду номера в отеле")
                sampSendDialogResponse(6565, 1, (itemIndex + 5) - 1, "")
                wait(bufferToNumber(taxesActionDelay))

                dialogInfo = sampGetDialogText()
                hours = tonumber(dialogInfo:match("Можно продлить на: {FF6666}(%d+){ffffff} часов")) or 0
                if (hours < 12) then
                    sampCloseCurrentDialogWithButton(0)
                    sampSendChat("/phone")
                    wait(bufferToNumber(taxesActionDelay))
                    chatMessage("Продление не возможно! Ваша задолженность менее 12 часов!")
                    return
                end

                for i = 4, 1, -1 do
                    if (hours >= options[i]) then
                        sampSendDialogResponse(26156, 1, i - 1, "")
                        wait(bufferToNumber(taxesActionDelay))
                        sampCloseCurrentDialogWithButton(1)
                        sampSendChat("/phone")
                        wait(bufferToNumber(taxesActionDelay))
                        break
                    end
                end
                attempt = attempt + 1
            else
                chatMessage("Ошибка продления аренды номера в отеле!")
            end
            wait(500)
        until (hours < 12 or attempt == 10)
    end)
end

function payAllTaxes()
    lua_thread.create(function()
        payTaxes()
        wait(3500)
        payFamTaxes()
        wait(3500)
        payHotelTaxes()
    end)
end

function toggleSettingWindow()
    showSettings[0] = not showSettings[0]
end

-- ################################################################################
-- #============================== USER INTERFACE ================================#
-- ################################################################################
local newFrame = imgui.OnFrame(
    function() return showSettings[0] end,
    function(player)

        imgui.SetNextWindowPos(
            imgui.ImVec2(
                sizeX / 2, 
                sizeY / 2)
            , 
            imgui.Cond.FirstUseEver, 
            imgui.ImVec2(0.5, 0.5)
        )
        
        imgui.SetNextWindowSize(
            imgui.ImVec2(600, 400), 
            imgui.Cond.Always
        )

        imgui.Begin(scriptName, showSettings, settingFlags)

        for numberTab, nameTab in pairs({'Настройки', 'Информация' }) do
            if imgui.Button(u8(nameTab), imgui.ImVec2(100, 30)) then
                tab = numberTab
            end
        end

        imgui.SetCursorPos(imgui.ImVec2(115, 28))
        if imgui.BeginChild('##AutoTaxesChild' .. tab, imgui.ImVec2(475, 360), true) then

                -- ######## Вкладка "Настройки" ########
            if tab == 1 then
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Настройка задержки:")
                imgui.PopStyleColor()
                imgui.PushItemWidth(50)
                if imgui.InputText(u8 "##taxesActionDelay", taxesActionDelay, 256) then
                    configFile.settings.taxesActionDelay = bufferToNumber(taxesActionDelay)
                    inicfg.save(configFile, configFileName)
                end
                imgui.SameLine()
                imgui.Text(u8 "задержка между действиями")
                imgui.SameLine()
                imgui.TextDisabled("(?)")
                if imgui.IsItemHovered(0) then
                    imgui.BeginTooltip()
                    imgui.Text(u8 "При стабильном соединении, оптимальная задержка - 250мс.\nКорректируйте данное значение в соответствии с вашим соединением.")
                    imgui.EndTooltip()
                end

                imgui.Dummy(imgui.ImVec2(0, 3))

                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Настройка оплаты налогов:")
                imgui.PopStyleColor()

                -- #### Авто-оплата налогов
                if imgui.Checkbox(u8 "Авто-оплата обычных налогов", autoTaxes) then
                    configFile.settings.autoTaxes = autoTaxes[0]
                    inicfg.save(configFile, configFileName)
                end
                if (autoTaxes[0]) then
                    imgui.PushItemWidth(50)
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if imgui.InputText(u8 "##autoTaxesDelay", autoTaxesDelay, 256) then
                        configFile.settings.autoTaxesDelay = bufferToNumber(autoTaxesDelay)
                        inicfg.save(configFile, configFileName)
                    end
                    imgui.SameLine()
                    imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                    imgui.Text(u8 "задержка после входа (секунд)")
                    imgui.PopStyleColor()
                end
                imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Ручная активация оплаты - /ptax\nАвтоматически оплачивает все обычные налоги при входе в игру\n(необходимо иметь возможность оплаты через телефон)")
                imgui.PopStyleColor()

                imgui.Dummy(imgui.ImVec2(0, 3))

                -- #### Авто-оплата семейных налогов
                if imgui.Checkbox(u8 "Авто-оплата семейных налогов", autoFamTaxes) then
                    configFile.settings.autoFamTaxes = autoFamTaxes[0]
                    inicfg.save(configFile, configFileName)
                end
                if (autoFamTaxes[0]) then
                    imgui.PushItemWidth(50)
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if imgui.InputText(u8 "##autoFamTaxesDelay", autoFamTaxesDelay, 256) then
                        configFile.settings.autoFamTaxesDelay = bufferToNumber(autoFamTaxesDelay)
                        inicfg.save(configFile, configFileName)
                    end
                    imgui.SameLine()
                    imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                    imgui.Text(u8 "задержка после входа (секунд)")
                    imgui.PopStyleColor()
                end
                imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Ручная активация оплаты - /pftax\nАвтоматически оплачивает налоги за семейную квартиру \nпри входе в игру с установленной задержкой")
                imgui.PopStyleColor()

                imgui.Dummy(imgui.ImVec2(0, 3))

                -- #### Авто-оплата налогов отеля
                if imgui.Checkbox(u8 "Авто-продление аренды отеля", autoHotelTaxes) then
                    configFile.settings.autoHotelTaxes = autoHotelTaxes[0]
                    inicfg.save(configFile, configFileName)
                end
                if (autoHotelTaxes[0]) then
                    imgui.PushItemWidth(50)
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if imgui.InputText(u8 "##autoHotelTaxesDelay", autoHotelTaxesDelay, 256) then
                        configFile.settings.autoHotelTaxesDelay = bufferToNumber(autoHotelTaxesDelay)
                        inicfg.save(configFile, configFileName)
                    end
                    imgui.SameLine()
                    imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                    imgui.Text(u8 "задержка после входа (секунд)")
                    imgui.PopStyleColor()
                end
                imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Ручная активация оплаты - /phtax\nАвтоматически продливает аренду отеля \nпри входе в игру с установленной задержкой")
                imgui.PopStyleColor()

                -- ######## Вкладка "Информация" ########
            elseif tab == 2 then
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Общая информация:")
                imgui.PopStyleColor()

                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 158, 0))
                imgui.Text(u8 'Сервер:')
                imgui.SameLine()
                imgui.PopStyleColor()
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 255, 255))
                imgui.Text(u8 'Scottdale[03]')
                imgui.PopStyleColor()

                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 158, 0))
                imgui.Text(u8 'Автор скрипта:')
                imgui.SameLine()
                imgui.PopStyleColor()
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 255, 255))
                imgui.Text(u8 'Satoru_Mercenari (Dawlat)')
                imgui.PopStyleColor()

                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 158, 0))
                imgui.Text(u8 'Больше скриптов:')
                imgui.SameLine()
                imgui.PopStyleColor()
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 255, 255))
                imgui.Text(u8 'https://github.com/OblivionGM')
                imgui.PopStyleColor()

                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 158, 0))
                imgui.Text(u8 'Связь:')
                imgui.SameLine()
                imgui.PopStyleColor()
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 255, 255))
                imgui.Text(u8 'Telegram @oblivionGM')
                imgui.PopStyleColor()

                imgui.Dummy(imgui.ImVec2(0, 3))

                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Список команд:")
                imgui.PopStyleColor()

                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 158, 0))
                imgui.Text(u8 "/pall")
                imgui.PopStyleColor()
                imgui.SameLine()
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 255, 255))
                imgui.Text(u8 "- оплатить все налоги")
                imgui.PopStyleColor()

                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 158, 0))
                imgui.Text(u8 "/ptax")
                imgui.PopStyleColor()
                imgui.SameLine()
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 255, 255))
                imgui.Text(u8 "- оплатить обычные налоги")
                imgui.PopStyleColor()

                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 158, 0))
                imgui.Text(u8 "/pftax")
                imgui.PopStyleColor()
                imgui.SameLine()
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 255, 255))
                imgui.Text(u8 "- оплатить семейные налоги")
                imgui.PopStyleColor()

                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 158, 0))
                imgui.Text(u8 "/phtax")
                imgui.PopStyleColor()
                imgui.SameLine()
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 255, 255))
                imgui.Text(u8 "- оплатить налоги отеля")
                imgui.PopStyleColor()

                imgui.Dummy(imgui.ImVec2(0, 3))

                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Примечание:")
                imgui.PopStyleColor()

                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 255, 255))
                imgui.Text(u8 "При автоматической оплате налогов контроллируйте\nвыполнение оплаты по сообщениям в чате. В следствии ошибок,\nобновлений игры и прочих факторов оплата может не сработать.")
                imgui.PopStyleColor()
            end
            imgui.EndChild()
        end
        imgui.End()
    end
)

-- #################################################################################
-- #============================== Обработка событий ==============================#
-- #################################################################################
function se.onServerMessage(color, text)
    if text:find("Добро пожаловать на Arizona Role Play!") and color == -10270721 then
        isAuth = true
        authTime = os.time()
    end
end

-- #################################################################################
-- #============================ Работа с RPC пакетами ============================#
-- #################################################################################
function bitStreamToString(bs)
    local text = ""
    raknetBitStreamIgnoreBits(bs, 8)
    if (raknetBitStreamReadInt8(bs) == 17) then
        raknetBitStreamIgnoreBits(bs, 32)
        local length = raknetBitStreamReadInt16(bs)
        local encoded = raknetBitStreamReadInt8(bs)
        text = (encoded ~= 0) and raknetBitStreamDecodeString(bs, length + encoded) or
            raknetBitStreamReadString(bs, length)
    end
    return text
end

function sendCustomPacket(str)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, #str)
    raknetBitStreamWriteString(bs, str)
    raknetBitStreamWriteInt32(bs, 0)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

-- #######################################################################################
-- #============================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==============================#
-- #######################################################################################
function findItemIndex(items, text)
    for i, item in ipairs(items) do
        if item:find(text) then
            return i
        end
    end
    return nil
end

function bufferToNumber(buffer)
    local strValue = ffi.string(buffer)
    strValue = strValue:gsub("[^%d]", "")

    return tonumber(strValue) or 0
end

function numberToBuffer(num)
    local strValue = tostring(num)
    return new.char[256](strValue)
end

function toRGBVec(r, g, b)
    return imgui.ImVec4(r / 255, g / 255, b / 255, 1);
end

function chatMessage(message, ...)
    message = ("[" .. scriptName .. "]" .. "{EEEEEE} " .. message)
    return sampAddChatMessage(message, 0xFFF2812D)
end

-- #################################################################
-- #============================ СТИЛИ ============================#
-- #################################################################
imgui.OnInitialize(function()
    imgui.Theme()
end)

function imgui.Theme()
    imgui.SwitchContext()
    -- ####### Style #######
    imgui.GetStyle().FramePadding                            = imgui.ImVec2(5, 5)
    imgui.GetStyle().TouchExtraPadding                       = imgui.ImVec2(0, 0)
    imgui.GetStyle().IndentSpacing                           = 0
    imgui.GetStyle().ScrollbarSize                           = 10
    imgui.GetStyle().GrabMinSize                             = 10

    -- ####### Border #######
    imgui.GetStyle().WindowBorderSize                        = 1
    imgui.GetStyle().ChildBorderSize                         = 1
    imgui.GetStyle().PopupBorderSize                         = 1
    imgui.GetStyle().FrameBorderSize                         = 1
    imgui.GetStyle().TabBorderSize                           = 1

    -- ####### Rounding #######
    imgui.GetStyle().WindowRounding                          = 5
    imgui.GetStyle().ChildRounding                           = 5
    imgui.GetStyle().FrameRounding                           = 5
    imgui.GetStyle().PopupRounding                           = 5
    imgui.GetStyle().ScrollbarRounding                       = 5
    imgui.GetStyle().GrabRounding                            = 5
    imgui.GetStyle().TabRounding                             = 5

    -- ####### Align #######
    imgui.GetStyle().WindowTitleAlign                        = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().ButtonTextAlign                         = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().SelectableTextAlign                     = imgui.ImVec2(0.5, 0.5)

    -- ####### Colors #######
    imgui.GetStyle().Colors[imgui.Col.Text]                  = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextDisabled]          = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    imgui.GetStyle().Colors[imgui.Col.WindowBg]              = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ChildBg]               = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PopupBg]               = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Border]                = imgui.ImVec4(0.25, 0.25, 0.25, 0.54)
    imgui.GetStyle().Colors[imgui.Col.BorderShadow]          = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBg]               = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]        = imgui.ImVec4(0.25, 0.25, 0.25, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive]         = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBg]               = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgActive]         = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed]      = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.MenuBarBg]             = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarBg]           = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]         = imgui.ImVec4(0.00, 0.00, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]  = imgui.ImVec4(0.25, 0.25, 0.25, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]   = imgui.ImVec4(0.00, 0.00, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.CheckMark]             = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrab]            = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]      = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Button]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered]         = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonActive]          = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Header]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderHovered]         = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderActive]          = imgui.ImVec4(0.47, 0.47, 0.47, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Separator]             = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SeparatorHovered]      = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SeparatorActive]       = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ResizeGrip]            = imgui.ImVec4(1.00, 1.00, 1.00, 0.25)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered]     = imgui.ImVec4(1.00, 1.00, 1.00, 0.67)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripActive]      = imgui.ImVec4(1.00, 1.00, 1.00, 0.95)
    imgui.GetStyle().Colors[imgui.Col.Tab]                   = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabHovered]            = imgui.ImVec4(0.28, 0.28, 0.28, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabActive]             = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocused]          = imgui.ImVec4(0.07, 0.10, 0.15, 0.97)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive]    = imgui.ImVec4(0.14, 0.26, 0.42, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLines]             = imgui.ImVec4(0.61, 0.61, 0.61, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered]      = imgui.ImVec4(1.00, 0.43, 0.35, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogram]         = imgui.ImVec4(0.90, 0.70, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered]  = imgui.ImVec4(1.00, 0.60, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]        = imgui.ImVec4(1.00, 1.00, 1.00, 0.25)
    imgui.GetStyle().Colors[imgui.Col.DragDropTarget]        = imgui.ImVec4(1.00, 1.00, 0.00, 0.90)
    imgui.GetStyle().Colors[imgui.Col.NavHighlight]          = imgui.ImVec4(0.26, 0.59, 0.98, 1.00)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight] = imgui.ImVec4(1.00, 1.00, 1.00, 0.70)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg]     = imgui.ImVec4(0.80, 0.80, 0.80, 0.20)
    imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg]      = imgui.ImVec4(0.00, 0.00, 0.00, 0.70)
end