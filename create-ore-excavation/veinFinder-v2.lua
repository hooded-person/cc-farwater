-- recieve args
local args = { ... }
local autonomous = args[1] -- if true dont ask for user confirmation to start scanning

local version = "2"
local finder = peripheral.wrap("left")
-- DEFINE VARS
local data
local chunks
local pos
local facing
-- DEFINE DATA FUNCTIONS
-- define clear function
local function clear(only)
    term.clear()
    term.setCursorPos(1,1)
    if only ~= true then print("veinFinder v"..version) end
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
    local h = fs.open("data.json","r")
    local data = textutils.unserializeJSON(h.readAll())
    h.close()
    data.pos = vectorToArray(pos)
    data.facing = facing
    local h = fs.open("data.json","w")
    h.write(textutils.serializeJSON(data))
    h.close()
end
-- define chunks update function
local function updateChunks(chunks)
    local h = fs.open("chunks.json","w")
    h.write(textutils.serialize(chunks))
    h.close()
end
-- define attempt refuel function (not a data func but still needed here already)
local function attemptRefuel(refuelTo, hide)
    clear()
    if hide ~= true then print("fuel level to low, searching for fuel\n"..turtle.getFuelLevel().."/"..refuelTo) end
    for i = 1, 4*4 do
        turtle.select(i)
        turtle.refuel()
        if turtle.getFuelLevel() >= refuelTo then return true end
    end
        clear()
        print("did not find any (or enough)fuel, place fuel in last slot and press any key\n"..turtle.getFuelLevel().."/"..refuelTo)
    while true do
        repeat 
            local event = os.pullEvent("key")
        until event == "key"
        turtle.select(16)
        if not turtle.refuel() then 
            clear()
            print("did not find any fuel, place fuel in last slot and press any key\n"..turtle.getFuelLevel().."/"..refuelTo)
            goto continue
        end
        if turtle.getFuelLevel() >= refuelTo then
            return true 
        else
            clear()
            print("more fuel is needed, place fuel in last slot and press any key\n"..turtle.getFuelLevel().."/"..refuelTo)
        end
        ::continue::
    end    
    return false
end

if fs.exists("data.json") then
    local h = fs.open("data.json","r")
    data = h.readAll()
    data = textutils.unserializeJSON(data)
else
    data = {}
end
if not data then data = {
    ["pos"]={},
    ["areaDir"]="",
    ["areaSize"]={},
    ["facing"]=""
} end

if fs.exists("chunks.json") then
    local h = fs.open("chunks.json","r")
    chunks = textutils.unserializeJSON(h.readAll())
    h.readAll()
else
    chunks = {}
end
if not chunks then chunks = {} end

pos = data.pos
if not pos or #pos == 0 then
    print("defining pos..")
    pos = gps.locate()
    if not pos then
        print("failed to located turtle's position\nenter turtle's current pos (comma seperated e.g. 'x,y,z')")
        while true do
            pos = read()
            pos = pos:gsub(" ","")
            local values = {}
            for value in pos:gmatch("-?%w+") do table.insert(values, tonumber(value)) end
            local success = true
            if #values ~= 3 then
                success = false
                term.setTextColor(colors.red)
                print("enter 3 numbers, seperated by comma's (e.g. 'x,y,z')")
                term.setTextColor(colors.white)
            else
                for i=1, #values do
                    if not type(values[i]) == "number" then 
                        success = false
                        term.setTextColor(colors.red)
                        print("all 3 values must be numbers (e.g. 'x,y,z')")
                        term.setTextColor(colors.white) 
                    end
                end
            end
            if success then pos = vector.new(table.unpack(values)); 
                print("set pos to '"..pos:tostring().."', is this correct (y/n)")
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
        local directions = {["n"]="north", ["e"]="east", ["s"]="south", ["w"]="west"}
        local direction = directions[input]
        if direction then print("set direction to '"..direction.."'"); facing = direction; updateData(); break end
        term.setTextColor(colors.red)
        print("enter one of the following values: 'n','e','s','w'")
        term.setTextColor(colors.white)
    end
end


local array = vectorToArray(pos)
local toMove = { array[1]%16, array[3]%16 }
local fuelCost = toMove[1] + toMove[2]
if turtle.getFuelLevel() ~= "unlimited" and turtle.getFuelLevel() < fuelCost then assert(attemptRefuel(fuelCost),"could not refuel (somehow)") end
-- DEFINE FUNCTIONS
-- define movement functions
local function turnLeft()
    turtle.turnLeft()
    local directions = {"north", "east", "south", "west"}
    local indexes = {["north"]=1, ["east"]=2, ["south"]=3, ["west"]=4}
    local index = indexes[facing] - 1
    if index == 0 then index = 4 end
    facing = directions[index]
    updateData()
end

local function turnRight()
    turtle.turnRight()
    local directions = {"north", "east", "south", "west"}
    local indexes = {["north"]=1, ["east"]=2, ["south"]=3, ["west"]=4}
    local index = indexes[facing] + 1
    if index == 5 then index = 1 end
    facing = directions[index]
    updateData()
end

local function move(direction,count)
    local directions = {
        ["u"]="up",
        ["d"]="down",
        ["f"]="forward",
        ["b"]="back",
    }
    direction = directions[direction]

    local directions = {"north", "east", "south", "west"}
    local indexes = {["north"]=-1, ["east"]=1, ["south"]=1, ["west"]=-1}
    local index = indexes[facing]
    local movement
    if facing == "north" or facing == "south" then movement = vector.new(0,0,index) else movement = vector.new(index,0,0) end

    if not count then count = 1 end

    local moveDir = load("turtle."..direction.."()")
    for _ = 1, count do
        moveDir()
        pos = pos:add(movement)
        updateData()
    end
end

local function turnTo(direction)
    local directions = {"north", "east", "south", "west"}
    local indexes = {["north"]=1, ["east"]=2, ["south"]=3, ["west"]=4}
    local currentI = indexes[facing]
    local targetI = indexes[direction]
    local toTurn = targetI-currentI
    print(toTurn)
    if toTurn > 0 then
        for _=1,toTurn do
            turnRight()
        end
    elseif toTurn < 0 then
        for _=0,toTurn+1,-1 do
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
        move("f",toMove[1])
        toMove[1] = 0
    elseif (facing == "east" and toMove[1] > 0)then
        move("b",toMove[1])
        toMove[1] = 0
    end
end
local function moveZ()
    if (facing == "north" and toMove[2] > 0)then
        move("f",toMove[2])
        toMove[2] = 0
    elseif (facing == "south" and toMove[2] > 0)then
        move("b",toMove[2])
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
-- await user input if set
if autonomous ~= true then
    print("start scanning for veins? (y/n)")
    local event, key
    repeat 
        event, key = os.pullEvent('key')
    until event == 'key' and (key == 89 or key == 78)
    if key == 78 then
        clear(true)
        print("ended veinFinder v"..version)
        return
    end
end
--start parsing area
local areaSize = data.areaSize
local fuelCost = areaSize[1] * areaSize[2] * 16 - 16
if turtle.getFuelLevel() ~= "unlimited" and turtle.getFuelLevel() < fuelCost then assert(attemptRefuel(fuelCost),"could not refuel (somehow)") end
local areaDir = data.areaDir
local directions = { ["n"]="north", ["e"]="east", ["s"]="south", ["w"]="west" }
local dirX = {"east","west"}
local dirZ = {"south","north"}
turnTo(directions[string.sub(areaDir,1,1)])
for i=1,areaSize[1] do
    for j=1,areaSize[2] do
        local chunkX = tostring(math.floor(vectorToArray(pos)[1]/16))
        local chunkY = tostring(math.floor(vectorToArray(pos)[3]/16))
        local chunkCoord = chunkX.."."..chunkY
        local results = search()
        chunks[chunkCoord] = results
        updateChunks(chunks)
        if j ~= areaSize[2] then move("f",16) end
    end
    if i ~= areaSize[1] then
        if i%2 == 1 then
            turnRight()
            move("f",16)
            turnRight()
        else
            turnLeft()
            move("f",16)
            turnLeft()
        end
    end
end
