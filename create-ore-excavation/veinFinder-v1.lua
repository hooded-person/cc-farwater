local finder = peripheral.wrap("left")

if fs.exists("data.json") then
    local h = fs.open("data.json","r")
    local data = h.readAll()
    local data = textutils.unserializeJSON(data)
    if not data then data = {} end
else
    local data = {}
end

local h = fs.open("chunks.json","r")
local chunks = textutils.unserializeJSON(h.readAll())
h.readAll()
if not chunks then chunks = {} end


local pos = data.pos
if not pos or pos == {} then
    pos = gps.locate()
    if not pos then
        print("failed to located turtle's position\nenter turtle's current pos (comma seperated e.g. 'x,y,z')")
        while true do
            pos = read()
            pos = pos:gsub(" ","")
            local values = {}
            for value in pos:gmatch("%w+") do table.insert(values, tonumber(value)) end
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
            if success then pos = vector.new(table.unpack(values)); break end
        end
    end
else
    pos = vector.new(table.unpack(pos))
end
local facing = data.facing
if not facing or facing == "" then
    while true do
        print("enter the facing direction of turtle ('n','e','s','w')")
        local input = read()
        local directions = {["n"]="north", ["e"]="east", ["s"]="south", ["w"]="west"}
        local direction = directions[input]
        if direction then print("set direction to '"..direction.."'"); data.facing = direction; updateData() end
        term.setTextColor(colors.red)
        print("enter one of the following values: 'n','e','s','w'")
        term.setTextColor(colors.white)
    end
end

local function vectorToArray(vector)
    local array = {}
    for value in vector:tostring():gmatch("[%d-]+") do table.insert(array, tonumber(value)) end
    return array
end

data.pos = vectorToArray(pos)


local array = vectorToArray(pos)
local toMove = { array[1]%16, array[3]%16 }
-- DEFINE FUNCTIONS
-- define data update function
local function updateData()
    local h = fs.open("data.json","r")
    local data = textutils.unserializeJSON(h.readAll())
    h.close()
    local h = fs.open("data.json","w")
    data.pos = vectorToArray(pos)
    data.facing = facing
    h.write(textutils.serializeJSON(data))
    h.close()
end
-- define chunks update function
local function updateChunks(chunks)
    local h = fs.open("chunks.json","w")
    h.write(textutils.serialize(chunks))
    h.close()
end
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
--start parsing area
local areaSize = data.areaSize
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
