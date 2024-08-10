-- recieve args
local args = { ... }
local autonomous = args[1] -- if true dont ask for user confirmation to start scanning

local version = "3"
local server = "https://localhost:3000"
-- assert PERIPHERALS
if not (peripheral.getType("left") and peripheral.getType("left") == "coe_vein_finder") then
    term.setTextColor(colors.red)
    print("ERROR: left slot does not contain an 'createoreexcavation:vein_finder', attach and restart")
    term.setTextColor(colors.white)
    return
end
local finder = peripheral.wrap("left")
if peripheral.getType("right") ~= "modem" then
    term.setTextColor(colors.orange)
    print(
        "WARN: left slot does not contain an 'computercraft:wireless_modem' or 'computercraft:wireless_modem_advanced'")
    term.setTextColor(colors.white)
    sleep(1.5)
else
    local modem = peripheral.wrap("right")
end
-- assert ITEMS
local items = { "minecraft:cobblestone", "minecraft:diamond_pickaxe" }
for i = 1, #items do
    turtle.select(i)
    if not (turtle.getItemDetail() and turtle.getItemDetail().name == items[i]) then
        term.setTextColor(colors.red)
        print("ERROR: turtle slot 1 does not contain item '" .. items[i] .. "'")
        term.setTextColor(colors.white)
        return
    end
end
-- DEFINE VARS
local data
local chunks
local pos
local facing
local areaSize
local areaDir
local settings = {}
local state = {}
-- DEFINE DATA FUNCTIONS
-- define clear function
local function clear(only)
    term.clear()
    term.setCursorPos(1, 1)
    if only ~= true then print("veinFinder v" .. version) end
end
clear() -- clearing screen after function def
-- define vector to array conversion function
local function vectorToArray(vector)
    local array = {}
    for value in vector:tostring():gmatch("[%d-]+") do table.insert(array, tonumber(value)) end
    return array
end
-- define data update function
local function updateData()
    local h = fs.open("data.json", "r")
    data = textutils.unserializeJSON(h.readAll())
    h.close()
    if not data or #data == 0 then
        data = {
            ["pos"] = {},
            ["areaDir"] = "",
            ["areaSize"] = {},
            ["facing"] = ""
        }
    end
    data.pos = vectorToArray(pos)
    data.facing = facing
    data.areaSize = settings.areaSize
    data.areaDir = settings.areaDir
    data.state = state
    local h = fs.open("data.json", "w")
    h.write(textutils.serializeJSON(data))
    h.close()
end
-- define chunks update function
local function updateChunks(chunks)
    local h = fs.open("chunks.json", "w")
    h.write(textutils.serialize(chunks))
    h.close()
    http.request({
        method = "POST",
        url = server.."api/chunks",
        body = textutils.serialiseJSON(chunks)
    })
end
-- define attempt refuel function (not a data func but still needed here already)
local function attemptRefuel(refuelTo, hide)
    clear()
    if hide ~= true then print("fuel level to low, searching for fuel\n" .. turtle.getFuelLevel() .. "/" .. refuelTo) end
    for i = 1, 4 * 4 do
        turtle.select(i)
        turtle.refuel()
        if turtle.getFuelLevel() >= refuelTo then return true end
    end
    clear()
    print("did not find any (or enough)fuel, place fuel in last slot and press any key\n" ..
        turtle.getFuelLevel() .. "/" .. refuelTo)
    while true do
        repeat
            local event = os.pullEvent("key")
        until event == "key"
        turtle.select(16)
        if not turtle.refuel() then
            clear()
            print("did not find any fuel, place fuel in last slot and press any key\n" ..
                turtle.getFuelLevel() .. "/" .. refuelTo)
            goto continue
        end
        if turtle.getFuelLevel() >= refuelTo then
            return true
        else
            clear()
            print("more fuel is needed, place fuel in last slot and press any key\n" ..
                turtle.getFuelLevel() .. "/" .. refuelTo)
        end
        ::continue::
    end
    return false
end

if fs.exists("data.json") then
    local h = fs.open("data.json", "r")
    data = h.readAll()
    data = textutils.unserializeJSON(data)
else
    data = {}
    local h = fs.open("data.json", "w")
    h.close()
end
if not data or next(data) == nil then
    data = {
        ["pos"] = {},
        ["areaDir"] = "",
        ["areaSize"] = {},
        ["facing"] = "",
        ["state"]={
            ["chunkPos"]={1,1}
        }
    }
end

if fs.exists("chunks.json") then
    local h = fs.open("chunks.json", "r")
    chunks = textutils.unserializeJSON(h.readAll())
    h.readAll()
else
    chunks = {}
end
if not chunks then chunks = {} end
pos = data.pos
settings.areaSize = data.areaSize
settings.areaDir = data.areaDir
state = data.state
if not pos or #pos == 0 then
    print("defining pos..")
    pos = gps.locate()
    if not pos then
        print("failed to located turtle's position\nenter turtle's current pos (comma seperated e.g. 'x,y,z')")
        while true do
            pos = read()
            pos = pos:gsub(" ", "")
            local values = {}
            for value in pos:gmatch("-?%w+") do table.insert(values, tonumber(value)) end
            local success = true
            if #values ~= 3 then
                success = false
                term.setTextColor(colors.red)
                print("enter 3 numbers, seperated by comma's (e.g. 'x,y,z')")
                term.setTextColor(colors.white)
            else
                for i = 1, #values do
                    if not type(values[i]) == "number" then
                        success = false
                        term.setTextColor(colors.red)
                        print("all 3 values must be numbers (e.g. 'x,y,z')")
                        term.setTextColor(colors.white)
                    end
                end
            end
            if success then
                pos = vector.new(table.unpack(values));
                print("set pos to '" .. pos:tostring() .. "', is this correct (y/n)")
                local event, key
                repeat
                    event, key = os.pullEvent('key')
                until event == 'key' and (key == 89 or key == 78)
                if key == 89 then break else print("enter turtle's current pos (comma seperated e.g. 'x,y,z')") end
            end
        end
    end
else
    pos = vector.new(table.unpack(pos))
end
facing = data.facing
data.pos = vectorToArray(pos)
updateData()
if not facing or facing == "" then
    while true do
        print("enter the facing direction of turtle ('n','e','s','w')")
        local input = read()
        local directions = { ["n"] = "north", ["e"] = "east", ["s"] = "south", ["w"] = "west" }
        local direction = directions[input]
        if direction then
            print("set direction to '" .. direction .. "'"); facing = direction; updateData(); break
        end
        term.setTextColor(colors.red)
        print("enter one of the following values: 'n','e','s','w'")
        term.setTextColor(colors.white)
    end
end


local array = vectorToArray(pos)
local toMove = { array[1] % 16, array[3] % 16 }
local fuelCost = toMove[1] + toMove[2]
if turtle.getFuelLevel() ~= "unlimited" and turtle.getFuelLevel() < fuelCost then
    assert(attemptRefuel(fuelCost),
        "could not refuel (somehow)")
end
-- DEFINE FUNCTIONS
-- define movement functions
local function turnLeft()
    turtle.turnLeft()
    local directions = { "north", "east", "south", "west" }
    local indexes = { ["north"] = 1, ["east"] = 2, ["south"] = 3, ["west"] = 4 }
    local index = indexes[facing] - 1
    if index == 0 then index = 4 end
    facing = directions[index]
    updateData()
end

local function turnRight()
    turtle.turnRight()
    local directions = { "north", "east", "south", "west" }
    local indexes = { ["north"] = 1, ["east"] = 2, ["south"] = 3, ["west"] = 4 }
    local index = indexes[facing] + 1
    if index == 5 then index = 1 end
    facing = directions[index]
    updateData()
end

local function move(direction, count)
    local directions = {
        ["u"] = "up",
        ["d"] = "down",
        ["f"] = "forward",
        ["b"] = "back",
    }
    direction = directions[direction]

    local directions = { "north", "east", "south", "west" }
    local indexes = { ["north"] = -1, ["east"] = 1, ["south"] = 1, ["west"] = -1 }
    local index = indexes[facing]
    local movement
    if facing == "north" or facing == "south" then
        movement = vector.new(0, 0, index)
    else
        movement = vector.new(index, 0,
            0)
    end

    if not count then count = 1 end

    local moveDir = load("turtle." .. direction .. "()")
    for _ = 1, count do
        moveDir()
        pos = pos:add(movement)
        updateData()
    end
end

local function turnTo(direction)
    local directions = { "north", "east", "south", "west" }
    local indexes = { ["north"] = 1, ["east"] = 2, ["south"] = 3, ["west"] = 4 }
    local currentI = indexes[facing]
    local targetI = indexes[direction]
    local toTurn = targetI - currentI
    print(toTurn)
    if toTurn > 0 then
        for _ = 1, toTurn do
            turnRight()
        end
    elseif toTurn < 0 then
        for _ = 0, toTurn + 1, -1 do
            turnLeft()
        end
    end
end
-- define search function
local function search()
    turtle.select(1)
    print(turtle.placeDown())
    turtle.select(2)
    local result = table.pack(finder.search())
    turtle.equipLeft()
    turtle.digDown("left")
    turtle.equipLeft()
    turtle.select(3)
    turtle.transferTo(1)
    return result
end
-- define alignment movement functions
local function moveX()
    if (facing == "west" and toMove[1] > 0) then
        move("f", toMove[1])
        toMove[1] = 0
    elseif (facing == "east" and toMove[1] > 0) then
        move("b", toMove[1])
        toMove[1] = 0
    end
end
local function moveZ()
    if (facing == "north" and toMove[2] > 0) then
        move("f", toMove[2])
        toMove[2] = 0
    elseif (facing == "south" and toMove[2] > 0) then
        move("b", toMove[2])
        toMove[2] = 0
    end
end
moveX()
if toMove[2] ~= 0 and (facing ~= "north" and facing ~= "south") then
    turnLeft()
end
moveZ()
if toMove[1] ~= 0 then
    turnLeft()
    moveX()
end
-- MENU FUNCTIONS
-- select option
local function select(options,currentValues)
    if currentValues and #options ~= #currentValues then currentValues = nil end
    while true do
        clear()
        for i = 1, #options do
            if currentValues then 
                if type(currentValues[i]) == "table" then currentValues[i] = table.concat(currentValues[i], ",") end 
                print(tostring(i)..". "..options[i][1].." = "..currentValues[i])
            else print(tostring(i) .. ". " .. options[i][1]) end
        end
        write("> ")
        local input = read()
        if tonumber(input) and tonumber(input) >= 1 and tonumber(input) <= #options then
            return tonumber(input)
        end
        term.setTextColor(colors.red)
        print("please enter a number on the list")
        term.setTextColor(colors.white)
        sleep(1.5)
    end
end
-- SETTINGS
-- set a setting (only works for the 2 settings - cause me lazy)
local function setSetting(name, setTemplate, setType, setConditions)
    -- !! only works for the 2 settings !! - cause me lazy
    -- if type ARRAY(use 'table') conditions: length(int), itemType(string)
    -- if type STRING conditions: options(array(string))
    if setType == "string" then
        setTemplate = setConditions[1][1]
        for i = 2, #setConditions[1] do
            setTemplate = setTemplate .. ", " .. setConditions[1][i]
        end
    end
    -- if type INT conditions: min(int), max(int)
    local setName = name:gsub("(%l)(%w*)", function(a, b) return string.upper(a) .. b end):gsub(" ", ""):gsub("^(.)(.*)",
        function(a, b) return string.lower(a) .. b end)
    while true do
        print("set " .. name .. " (" .. setTemplate .. ")")
        local output
        local input = read()
        input = input:gsub(" ", "")
        local values
        if setType == "table" and setConditions[2] == "int" then
            values = {}
            for value in input:gmatch("-?%w+") do table.insert(values, tonumber(value)) end
        elseif setType == "string" then
            output = input
        end
        local success = true
        if setType == "table" then
            if #values ~= setConditions[1] then
                success = false
                term.setTextColor(colors.red)
                print("enter " .. setConditions[1] .. " numbers, seperated by comma's (e.g. '" .. setTemplate .. "')")
                term.setTextColor(colors.white)
            else
                for i = 1, #values do
                    if not type(values[i]) == "number" then
                        success = false
                        term.setTextColor(colors.red)
                        print("all 2 values must be numbers (e.g. '" .. setTemplate .. "')")
                        term.setTextColor(colors.white)
                    end
                end
            end
            if success then output = values end
        elseif setType == "string" then
            local optionTable = {}
            for i = 1, #setConditions[1] do
                optionTable[setConditions[1][i]] = true
            end
            if optionTable[input] then
            else
                term.setTextColor(colors.red)
                print("please enter one of the following (e.g. '" .. setTemplate .. "')")
                term.setTextColor(colors.white)
                success = false
            end
        end
        if success then
            if setType == "table" then
                print("setting '" .. setName .. "' to", table.unpack(output))
            else
                print("setting '" .. setName .. "' to", output)
            end
            settings[setName] = output
            sleep(3)
            updateData()
            break
        end
    end
end
-- main selection menu
local function settingsMenu()
    local menuOptions = {
        { "areaSize", setSetting, {
            "area size",
            "width,height",
            "table",
            { 2, "int" }
        } },
        { "areaDir", setSetting, {
            "area dir",
            "wn",
            "string",
            { { "ne", "nw", "se", "sw", "en", "wn", "es", "ws" } }
        } }
    }
    local currentValues = {}
    for i=1,#menuOptions do currentValues[i] = settings[menuOptions[i][1]] end
    local index = select(menuOptions,currentValues)
    local option = menuOptions[index]
    if option[2](table.unpack(option[3])) == "end" then menu = false end
    if option[4] then sleep(1.5) end
end
-- define the options
local options = {
    { "start scanning", function() return "end" end, {} },
    { "visualise area", print,                       { "not implemented yet, and wont be soon" }, true },
    { "edit settings",  settingsMenu,                {} },
    { "exit",           os.queueEvent,               { "terminate" } },
}
-- set areasize and areadir
if not settings.areaSize or #settings.areaSize ~= 2 then
    setSetting(table.unpack({
        "area size",
        "width,height",
        "table",
        { 2, "int" }
    }))
end
if not settings.areaDir or #settings.areaDir ~= 2 then
    setSetting(table.unpack({
        "area dir",
        "wn",
        "string",
        { { "ne", "nw", "se", "sw", "en", "wn", "es", "ws" } }
    }))
end
-- await user input if not autonomous
local menu = true
if autonomous ~= true then
    while menu do
        local index = select(options)
        local option = options[index]
        if option[2](table.unpack(option[3])) == "end" then menu = false end
        if option[4] then sleep(1.5) end
    end
end
-- correctly load settings
areaSize = settings.areaSize
areaDir = settings.areaDir
--start parsing area
local fuelCost = areaSize[1] * areaSize[2] * 16 - 16
if turtle.getFuelLevel() ~= "unlimited" and turtle.getFuelLevel() < fuelCost then
    assert(attemptRefuel(fuelCost),
        "could not refuel (somehow)")
end
local directions = { ["n"] = "north", ["e"] = "east", ["s"] = "south", ["w"] = "west" }
local dirX = { "east", "west" }
local dirZ = { "south", "north" }
turnTo(directions[string.sub(areaDir, 1, 1)])
local loadI = true
local loadJ = true
for i = 1, areaSize[1] do
    if loadI then i = state.chunkPos[1];loadI=false end
    state.chunkPos[1] = i
    for j = 1, areaSize[2] do
        if loadJ then j = state.chunkPos[2];loadJ=false end
        state.chunkPos[2] = j
        local chunkX = tostring(math.floor(vectorToArray(pos)[1] / 16))
        local chunkY = tostring(math.floor(vectorToArray(pos)[3] / 16))
        local chunkCoord = chunkX .. "." .. chunkY
        local results = search()
        chunks[chunkCoord] = results
        updateChunks(chunks)
        if j ~= areaSize[2] then move("f", 16) end
    end
    if i ~= areaSize[1] then
        turnTo(directions[string.sub(areaDir, 2, 2)])
        move("f", 16)
        turnTo(directions[string.sub(areaDir, 1, 1)])
    end
end
