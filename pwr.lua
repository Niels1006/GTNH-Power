-- Original by Merung (October, 2018)
-- V1 Forked/Edit by Just_Benji (Februari, 2023) - Added and changed GTNH LSC Compatibility
-- V2 with sensorInformation by Just_Benji (March,2023)
-- V3 disable the average table and enable the new average in/out from v2.3 LSC
-- V3.1 added Toggle functions for clr.Red100Off and ArrowOff
-- V4 forked by NeroOneTrueKing to add wireless redstone support
-- For original:
--     pastebin get dU5feqYz pwr.lua
local table = require("table")
local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local gpu = component.gpu
local sides = require("sides")
local RS = require("redstone-control")
local cfg = require("config")
local clr = cfg.clr

-- START OF CODE
-- Find LSC
for k, v in component.list("gt_machine") do
    if component.invoke(k, "getName") == "multimachine.supercapacitor" then
        msc = component.proxy(k)
    end
end

assert(msc ~= nil, "ERROR: Needs an adaptor next to an LSC!")

-- Set Resolution
res_x = 120
res_y = 27
gpu.setResolution(res_x, res_y)

-- Conversions
-- formats:
-- 'e' -- engineering notation;             ex) 123.45 e9
-- 'a' -- gregtech amp notation;            ex) 1.23 A LuV
-- 'p' -- SI prefix notation;               ex) 1.23 G
function convert_value(eu, format)
    local exp;
    local tier;
    if eu == 0 then
        exp = 0
        tier = 1
    else
        exp = math.floor(math.log(eu, 1000))
        tier = math.floor(math.log(eu / 8, 4))
        if tier > 14 then
            tier = 14
        end

    end

    local tiers_str = {
        [0] = "",
        "LV",
        "MV",
        "HV",
        "EV",
        "IV",
        "LuV",
        "ZPM",
        "UV",
        "UHV",
        "UEV",
        "UIV",
        "UMV",
        "UXV",
        "MAX"
    }
    local prefx_str = {
        [0] = " ",
        "K",
        "M",
        "G",
        "T",
        "P",
        "E",
        "Z",
        "Y"
    }

    if format == "e" or format == "E" then
        return string.format("%6.2f %s%d", eu / math.pow(1000, exp), format, exp * 3)
    elseif format == "p" or format == "P" then
        return string.format("%6.2f %s", eu / math.pow(1000, exp), prefx_str[exp])
    elseif format == "a" or format == "A" then
        return string.format("%5.2f %s %3s", eu / (math.pow(4, tier) * 8), format, tiers_str[tier])
    else
        return string.format("%6.2f", eu)
    end
end

function get_percent_color(energy)
    local energycolor
    if energy <= 5 then
        energycolor = clr.RED
    elseif energy <= 25 then
        energycolor = clr.ORANGE
    elseif energy <= 50 then
        energycolor = clr.YELLOW
    elseif energy <= 75 then
        energycolor = clr.GREEN
    elseif energy <= 99 then
        energycolor = clr.BLUE
    else
        energycolor = clr.PURPLE
    end
    return energycolor
end

-- Draw sections
function draw_legend()
    gpu.setForeground(fg_default)

    for loc = 0, 100, 10 do
        term.setCursor(offset + loc, visual_y_start + 16)
        term.write(loc)
        term.setCursor(offset + loc, visual_y_start + 17)
        term.write("|")
    end
end

-- 
io_increment = cfg.io_max_rate / 100
function draw_direction(io)
    local is_neg
    local pos_num
    if io == 0 then
        return
    elseif io > 0 then
        is_neg = 0
        pos_num = io
    elseif io < 0 then
        is_neg = 1
        pos_num = io * -1
    end

    -- Determine how many "="
    local num_col = pos_num / io_increment
    if num_col > 100 then
        num_col = 100
    end
    if num_col < 1 then
        num_col = 1
    end

    -- Create the bars
    local base_bar = ""
    local base_bar1 = ""
    local base_bar2 = ""
    local base_bar3 = ""
    local num_spaces = 100 - num_col
    local space_offset = num_spaces / 2

    for int_space = 0, space_offset, 1 do
        base_bar = base_bar .. " "
    end

    if is_neg == 1 then
        base_bar1 = base_bar .. "/"
        base_bar2 = base_bar .. "<="
        base_bar3 = base_bar .. "\\"
    else
        base_bar1 = base_bar
        base_bar2 = base_bar
        base_bar3 = base_bar
    end

    for int_eq = 0, num_col, 1 do
        base_bar1 = base_bar1 .. "="
        base_bar2 = base_bar2 .. "="
        base_bar3 = base_bar3 .. "="
    end

    if is_neg == 0 then
        base_bar1 = base_bar1 .. "\\"
        base_bar2 = base_bar2 .. "=>"
        base_bar3 = base_bar3 .. "/"
    end

    for int_space = 0, space_offset, 1 do
        base_bar1 = base_bar1 .. " "
        base_bar2 = base_bar2 .. " "
        base_bar3 = base_bar3 .. " "
    end

    -- Draw the actual bars
    if is_neg == 1 then
        gpu.setForeground(clr.RED)
        term.setCursor(offset, visual_y_start + 20)
        term.write(base_bar1)
        term.setCursor(offset - 1, visual_y_start + 21)
        term.write(base_bar2)
        term.setCursor(offset, visual_y_start + 22)
        term.write(base_bar3)
        gpu.setForeground(fg_default)
    else
        gpu.setForeground(clr.GREEN)
        term.setCursor(offset, visual_y_start + 20)
        term.write(base_bar1)
        term.setCursor(offset, visual_y_start + 21)
        term.write(base_bar2)
        term.setCursor(offset, visual_y_start + 22)
        term.write(base_bar3)
        gpu.setForeground(fg_default)
    end
end

function draw_visuals(percent)
    term.setCursor(offset, visual_y_start + 18)
    for check = 0, 100, 1 do
        if check <= percent then
            gpu.setForeground(get_percent_color(check))
            term.write("|")
            gpu.setForeground(fg_default)
        else
            gpu.setForeground(fg_default)
            term.write(".")
        end
    end
end

-- Convert string to number  , credits to nidas
function parser(string)
    if type(string) == "string" then
        local numberString = string.gsub(string, "([^0-9]+)", "")
        if tonumber(numberString) then
            return math.floor(tonumber(numberString) + 0)
        end
        return 0
    else
        return 0
    end
end

-- Main Code
term.clear()

ylogo = 36
gpu.setForeground(clr.YELLOW)
term.setCursor(ylogo, 1 + 4)
term.write("        ░░░             ░░             ░░░        ")
term.setCursor(ylogo, 1 + 5)
term.write("          ░░░           ░░           ░░░          ")
term.setCursor(ylogo, 1 + 6)
term.write("         ░░             ░░             ░░░        ")
term.setCursor(ylogo, 1 + 7)
term.write("        ░░░░            ░░               ░░       ")
term.setCursor(ylogo, 1 + 8)
term.write("       ░░  ░░           ░░               ░░░      ")
term.setCursor(ylogo, 1 + 9)
term.write("      ░░    ░░░         ░░                ░░░     ")
term.setCursor(ylogo, 1 + 10)
term.write("      ░░      ░░        ░░                ░░░     ")
term.setCursor(ylogo, 1 + 11)
term.write(
    "  ░░░░░░        ░░      ░░░░░░░░░░░░░░░░░░░░░░░░  ")
term.setCursor(ylogo, 1 + 12)
term.write("      ░░         ░░░    ░░                ░░░     ")
term.setCursor(ylogo, 1 + 13)
term.write("      ░░           ░░   ░░                ░░░     ")
term.setCursor(ylogo, 1 + 14)
term.write("       ░░            ░░░░░               ░░       ")
term.setCursor(ylogo, 1 + 15)
term.write("        ░░            ░░░░              ░░░       ")
term.setCursor(ylogo, 1 + 16)
term.write("         ░░             ░░             ░░         ")
term.setCursor(ylogo, 1 + 17)
term.write("          ░░░           ░░           ░░░          ")
term.setCursor(ylogo, 1 + 18)
term.write("         ░░             ░░             ░░░        ")

gpu.setForeground(clr.WHITE)
term.setCursor(35, 22)
term.write(
    "█▀█ █▀█ █░█░█ █▀▀ █▀█   █▀▀ █▀█ █▄░█ ▀█▀ █▀█ █▀█ █░░")
term.setCursor(35, 23)
term.write(
    "█▀▀ █▄█ ▀▄▀▄▀ ██▄ █▀▄   █▄▄ █▄█ █░▀█ ░█░ █▀▄ █▄█ █▄▄")
os.sleep(0.1)

-- General GUI settings
offset = 10
visual_y_start = 4
fg_default = clr.WHITE
fg_color_max = clr.PURPLE
eucolor = fg_default
eucolorx = fg_default

function DrawStaticScreen(wirelessenergy_array)
    term.clear()
    gpu.setForeground(fg_default)
    term.setCursor(35, visual_y_start - 2)
    term.write(
        "█▀█ █▀█ █░█░█ █▀▀ █▀█   █▀▀ █▀█ █▄░█ ▀█▀ █▀█ █▀█ █░░")
    term.setCursor(35, visual_y_start - 1)
    term.write(
        "█▀▀ █▄█ ▀▄▀▄▀ ██▄ █▀▄   █▄▄ █▄█ █░▀█ ░█░ █▀▄ █▄█ █▄▄")

    -- Current energy stored
    term.setCursor(30, visual_y_start + 2)
    term.write("Current stored Energy / Max Energy: ")

    -- Draw percentage 
    term.setCursor(30, visual_y_start + 3)
    term.write("Percent Full:         ")

    -- Draw Actual In
    term.setCursor(30, visual_y_start + 4)
    term.write("Average EU In/t:     ")

    -- Draw Actual Out
    term.setCursor(30, visual_y_start + 5)
    term.write("Average EU Out/t:    ")

    -- Draw Actual Change in/out
    term.setCursor(30, visual_y_start + 6)
    term.write("Average EU Change/t: ")

    -- Draw EU/Average Change: 
    if AVEUToggle == true then
        term.setCursor(30, visual_y_start + 7)
        term.write("Average EU Change/t: ")
    end

    -- Draw time till empty
    term.setCursor(30, visual_y_start + 7)
    term.write("Time till full: ")

    -- Draw wireless energy
    term.setCursor(30, visual_y_start + 9)
    term.write("Wireless energy: ")

    -- Draw wireless i/o
    term.setCursor(30, visual_y_start + 10)
    term.write("Wireless I/O: ")

    -- Draw wireless tte
    term.setCursor(30, visual_y_start + 11)
    term.write("Time till full: ")

    -- Draw Maintenance status
    term.setCursor(30, visual_y_start + 13)
    term.write("Maintenance status:  ")

    -- Draw Generator Status
    term.setCursor(30, visual_y_start + 14)
    term.write("Generators status:   ")

    -- Draw Pointline
    draw_legend()
end

function eol()
    term.write("                ")
end

function DrawDynamicScreen()
    local sensorInformation = msc.getSensorInformation()

    -- Get information
    local storedenergyinit = parser(sensorInformation[2])
    local maxenergyinit = parser(sensorInformation[5])

    local ioratein = parser(string.gsub(sensorInformation[10], "last 5 seconds", ""))
    local iorateout = parser(string.gsub(sensorInformation[11], "last 5 seconds", ""))
    local iorate = ioratein - iorateout
    local strInfo = sensorInformation[13]

    local wirelessenergy = parser(sensorInformation[19])
    local MStatus
    if strInfo == nil then
    else
        y = string.find(strInfo, "§")
        z = string.len(strInfo)
        MStatus = string.sub(strInfo, (y + 3), (z - 3))
    end
    local percentenergy = storedenergyinit / maxenergyinit * 100

    local convstored = convert_value(storedenergyinit, "E")
    local convmax = convert_value(maxenergyinit, "E")

    local fg_color_stored = get_percent_color(percentenergy)
    local fg_color_percent = fg_color_stored

    local fg_color_io

    if iorate <= 0 then
        fg_color_io = clr.RED
    else
        fg_color_io = clr.GREEN
    end

    -- Power Toggle
    RS.toggle(percentenergy)

    -- RS status
    statusRS = RS.getstatus()
    -- Draw current energy stored
    term.setCursor(30 + 36, visual_y_start + 2)
    gpu.setForeground(fg_color_stored)
    term.write(convstored)
    gpu.setForeground(fg_default)
    term.write(" / ")
    gpu.setForeground(fg_color_max)
    term.write(convmax);
    eol();
    gpu.setForeground(fg_default)

    -- Draw percentage 
    term.setCursor(30 + 21, visual_y_start + 3)
    gpu.setForeground(fg_color_percent)
    term.write(string.format("  %.5f %s", percentenergy, "%"));
    eol();
    gpu.setForeground(fg_default)

    -- Draw Actual In
    term.setCursor(30 + 21, visual_y_start + 4)
    gpu.setForeground(clr.GREEN)
    term.write(" " .. convert_value(ioratein, "A") .. " equal to " .. convert_value(ioratein, "E") .. " EU/t");
    eol();
    gpu.setForeground(fg_default)

    -- Draw Actual Out
    term.setCursor(30 + 21, visual_y_start + 5)
    gpu.setForeground(clr.RED)
    term.write(" " .. convert_value(iorateout, "A") .. " equal to " .. convert_value(iorateout, "E") .. " EU/t");
    eol();
    gpu.setForeground(fg_default)

    -- Draw Actual Change in/out
    term.setCursor(30 + 21, visual_y_start + 6)
    if iorate ~= nil then
        ioratechange = convert_value(math.abs(iorate), "A")
    end
    if iorate < 0 then
        spacer = " "
    else
        spacer = " "
    end
    gpu.setForeground(fg_color_io)
    if ioratechange ~= nil then
        term.write(spacer .. ioratechange);
        eol();
    end
    gpu.setForeground(fg_default)

    -- Draw time till empty
    term.setCursor(30 + 21, visual_y_start + 7)
    empty_time = ((storedenergyinit / iorate) / 20) / 3600
    gpu.setForeground(fg_color_io)

    if iorate < 0 then
        term.write(" " .. (math.floor(empty_time * 10) / 10) .. "h");
        eol();
    else
        full_time = ((maxenergyinit - storedenergyinit) / iorate) / 72000
        term.write("  " .. math.floor(full_time * 10) / 10 .. "h");
        eol();
    end
    gpu.setForeground(fg_default)

    -- Draw Wireless EU Status

    term.setCursor(30 + 21, visual_y_start + 9)
    gpu.setForeground(clr.GREEN)
    term.write("" .. convert_value(wirelessenergy, "E"));
    eol();
    gpu.setForeground(fg_default)

    -- Draw Wireless energy i/o
    eu_ar = get_wireless_average(wirelessenergy, wirelessenergy_array)

    term.setCursor(30 + 21, visual_y_start + 10)
    gpu.setForeground(eu_ar[3])
    term.write("" .. convert_value(eu_ar[1], "E"));
    eol();
    gpu.setForeground(fg_default)

    -- Draw wireless time till empty 
    term.setCursor(30 + 21, visual_y_start + 11)
    empty_time = ((wirelessenergy / eu_ar[1]) / 20) / 3600
    gpu.setForeground(fg_color_io)

    if eu_ar[2] == "-" then
        term.write(" -" .. (math.floor(empty_time * 10) / 10) .. "h");
        eol();
    else
        term.write(" inf h");
        eol();
    end
    gpu.setForeground(fg_default)

    -- Draw Maintenance status
    term.setCursor(30 + 21, visual_y_start + 13)
    if MStatus == "Working perfectly" then
        MColor = clr.GREEN
    else
        MColor = clr.RED
    end
    gpu.setForeground(MColor)
    if MColor == clr.RED then
        gpu.setBackground(clr.YELLOW)
    end
    term.write("  " .. MStatus);
    eol();
    gpu.setForeground(fg_default)
    gpu.setBackground(clr.BLACK)

    -- Draw Generator Status
    term.setCursor(30 + 21, visual_y_start + 14)
    gpu.setForeground(fg_default)
    term.write("  " .. statusRS);
    eol();
    gpu.setForeground(fg_default)
    gpu.setBackground(clr.BLACK)

    -- Draw ColorScreen
    draw_visuals(percentenergy)
    if cfg.ArrowOff == false then
        draw_direction(iorate)
    end
end

-- if user presses a key, end program
local event_loop = true
local event_id
function end_event_loop()
    event_loop = false
    event.cancel(event_id) -- very important, lol
    RS.off()
    gpu.setForeground(fg_default)
    term.clear()
    print("Key pressed; program ended.")
    os.exit()
end
event_id = event.listen("key_up", end_event_loop)

function get_wireless_average(wirelessenergy, wirelessenergy_array)
    table.insert(wirelessenergy_array_raw, 1, wirelessenergy)

    if #wirelessenergy_array_raw > ar_length then
        table.remove(wirelessenergy_array_raw, ar_length + 1)

        diff = math.floor((wirelessenergy_array_raw[1] - wirelessenergy_array_raw[ar_length]) /
                              (cfg.loopdelay * ar_length * 20))

        if diff < 0 then
            return {-diff, "-", clr.RED}
        else
            return {diff, "+", clr.GREEN}
        end
    else
        return 1
    end

end

ar_length = 20
-- local wirelessenergy_array = nil
wirelessenergy_array_raw = {}
for i = 1, ar_length do
    table.insert(wirelessenergy_array_raw, 1)
end

-- Init
RS.init()
DrawStaticScreen(wirelessenergy_array_raw)

-- Loop
while event_loop do
    DrawDynamicScreen()
    os.sleep(cfg.loopdelay)
end