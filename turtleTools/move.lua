local args = { ... }

local h = fs.open("data.json","r")
local data = h.readAll()
local data = textutils.unserializeJSON(data)
if not data then data = {} end
local pos = vector.new(table.unpack(data.pos))
local oldPos = pos
print(pos)
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

local directions = {
    ["up"]="up",
    ["u"]="up",
    ["down"]="down",
    ["d"]="down",
    ["forward"]="forward",
    ["forwards"]="forward",
    ["f"]="forward",
    ["back"]="back",

    ["backward"]="back",
    ["backwards"]="back",
    ["b"]="back",
}
if tonumber(args[1],10) ~= nil then table.insert(args,1,"f") end
local direction = directions[args[1]]
assert(type(direction)== "string","direction was not correct")

local count = args[2]
if not count then count = 1 end

local directions = {"north", "east", "south", "west"}
local indexes = {["north"]=-1, ["east"]=1, ["south"]=1, ["west"]=-1}
local index = indexes[facing]
local movement
if facing == "north" or facing == "south" then movement = vector.new(0,0,index) else movement = vector.new(index,0,0) end

local moveDir = load("turtle."..direction.."()")
for _ = 1, count do
    moveDir()
    pos = pos:add(movement)
    updateData()
end
print("moved from "..tostring(oldPos).." to "..tostring(pos))
