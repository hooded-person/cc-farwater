local args = { ... }

local h = fs.open("data.json","r")
local data = h.readAll()
local data = textutils.unserializeJSON(data)
if not data then data = {} end
local pos = vector.new(table.unpack(data.pos))
local facing = data.facing

local function vectorToArray(vector)
    local array = {}
    for value in vector:tostring():gmatch("[%d-]+") do table.insert(array, tonumber(value)) end
    return array
end

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
-- define turning functions
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

local directions = {
    ["left"]="l",
    ["l"]="l",
    ["right"]="r",
    ["r"]="r",
}
local direction = directions[args[1]]
assert(type(direction)== "string","direction was not correct")
local count = args[2]
if not count then count = 1 end 

if direction == "l" then
    for i=1,count do 
        turnLeft() 
    end
elseif direction == "r" then
    for i=1,count do 
        turnRight() 
    end
end
