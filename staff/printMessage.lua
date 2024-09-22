local templateDir = "templates/"
if templateDir:sub(-1) ~= "/" then templateDir = templateDir .. "/" end
local spclib = require("libs/spclib")
local printerHost = 15
-- use debug() instead of print() for debugging for easier removal(or disabling) of the statments after debugging is done
local debug = print
-- load and prepare templates
local typeColors = {
    ["WARN"] = colors.orange,
    ["EVIC"] = colors.red,
}
local templatesStrings = fs.list(templateDir)
--local templateExists = { {}, {} }
local templateListBuild = {
    ["type"] = {},
--    ["reason"] = {}
}
local templates = {}
for i, templatePath in ipairs(templatesStrings) do
    local validTemplate = templatePath:sub(-5) == ".sdoc" 
        and templatePath:sub(1,4) ~= "hide"
    if validTemplate then
        template = templatePath:gsub(".sdoc", "")
        local keywords = {}
        local str = template:gsub("^%U*", "")
        for wrd in str:gmatch("%u%U*") do
            table.insert(keywords, string.lower(wrd))
        end
        -- load template
        local h = fs.open(templateDir .. templatePath, "r")
        local templateContent = h.readAll()
        h.close()
        -- get data vars in template
        local dataVars = {}
        for match in templateContent:gmatch("<([^>]*)>") do
            table.insert(dataVars, match)
        end
        -- setup table
        typeIndex = string.upper(template:match("^%U*")) -- warn or evic
        if not templates[typeIndex] then templates[typeIndex] = {} end
        table.insert(templates[typeIndex], {
            string.upper(template:match("^%U*")),
            table.concat(keywords, " "),
            dataVars,
            templatePath,
        })
        -- setup values while preventing duplicates
        templateListBuild["type"][typeIndex] = true
        --templateListBuild["reason"][table.concat(keywords, " ")] = true
    end
end
-- building the values into the array
local templateList = {
    ["type"] = {},
--    ["reason"] = {}
}
for k, _ in pairs(templateListBuild["type"]) do
    table.insert(templateList["type"], k)
end
--[[for k, _ in pairs(templateListBuild["reason"]) do
    table.insert(templateList["reason"], k)
end]]

local function getCurrentDate(offset, pattern, timezone)
    offset = offset or 0
    pattern = pattern or "%d/%m/%Y"
    timezone = timezone or "utc"
    local date = os.date(
        pattern,
        os.epoch(timezone) / 1000 -- convert milisec to sec
        + 2 * 60 * 60             -- convert UTC to CEST
        + offset                  -- aply offset
    )
    return date
end

local function getTemplateDoc(template, formatData)
    local tempType, reason, _, path = table.unpack(template)
    local h = fs.open(templateDir .. path, "r")
    local template = h.readAll()
    h.close()
    template = template:gsub("<([^>]*)>", function(var)
        return formatData[var]
    end)
    return template
end

local function getFormatData(template)
    local conversionTable = {
        ["s"] = 1,
        ["m"] = 60,
        ["h"] = 60 * 60,
        ["d"] = 24 * 60 * 60,
        ["w"] = 7 * 24 * 60 * 60,
    }
    term.clear()
    term.setTextColor(colors.white)
    term.setCursorPos(1, 1)
    write("formating for template ")
    term.setTextColor(typeColors[template[1]])
    write(template[1])
    term.setTextColor(colors.white)
    print(":" .. template[2])
    local formatData = {}
    for i = 1, #template[3] do
        local var = template[3][i]
        if var == "date" then
            formatData[var] = getCurrentDate()
        elseif var == "deadline" then
            print("enter deadline (number+'m/h/d/w')(default '1w')")
            local input = read()
            if input == "" then
                local x, y = term.getCursorPos()
                term.setCursorPos(x, y - 1)
                print("1w")
                input = { 1, "w" }
            else
                input = {
                    tonumber(input:match("%d")),
                    input:match("%a"),
                }
            end
            input = input[1] * conversionTable[input[2]]
            local deadline = getCurrentDate(input)
            print("deadline set to:", deadline)
            formatData[var] = deadline
        else
            print("enter value for " .. var)
            local input = read()
            formatData[var] = input
        end
    end
    return formatData
end

local function drawArea(selectedType, selectedTemplate, tempSelected)
    term.clear()
    term.setTextColor(colors.white)
    term.setCursorPos(1, 2)
    local theString = "SELECT A TEMPLATE"
    local x, y = term.getSize()
    local amountOfDashes = (x - #theString) / 2
    for i = 1, amountOfDashes do
        write("-")
    end
    write(theString)
    for i = 1, amountOfDashes do
        write("-")
    end
    term.setCursorPos(10, 3)
    for name, _ in pairs(templates) do
        if templateList["type"][selectedType] == name then
            term.setCursorPos(9, select(2, term.getCursorPos()) + 1)
            if not tempSelected then
                term.setTextColor(colors.white)
                write("[")
                term.setTextColor(typeColors[name])
                write(name)
                term.setTextColor(colors.white)
                write("]")
            else
                term.setTextColor(colors.white)
                write("(")
                term.setTextColor(typeColors[name])
                write(name)
                term.setTextColor(colors.white)
                write(")")
            end
        else
            term.setCursorPos(10, select(2, term.getCursorPos()) + 1)
            term.setTextColor(typeColors[name])
            write(name)
            term.setTextColor(colors.white)
        end
    end
    term.setCursorPos(30, 3)
    local selectedTypeTemplates = templates[templateList["type"][selectedType]]
    for i = 1, #selectedTypeTemplates do
        term.setTextColor(colors.white)
        name = selectedTypeTemplates[i][2]
        if selectedTypeTemplates[selectedTemplate][2] == name then
            term.setCursorPos(29, select(2, term.getCursorPos()) + 1)
            if tempSelected then
                write("[" .. name .. "]")
            else
                write("(" .. name .. ")")
            end
        else
            term.setCursorPos(30, select(2, term.getCursorPos()) + 1)
            write(name)
        end
    end
end

local function selectTemplate()
    local selectedType = 2
    local selectedTemp = 1
    local tempSelected = false
    while true do

        drawArea(selectedType, selectedTemp, tempSelected)
        local event, key = os.pullEvent("key")
        if event == "key" then
            if not tempSelected then
                -- up and down
                if key == keys.up or key == keys.w then
                    selectedType = selectedType - 1
                elseif key == keys.down or key == keys.s then
                    selectedType = selectedType + 1
                end
                if key == keys.right or key == keys.d or key == keys.enter then tempSelected = true end
            else
                -- up and down
                if key == keys.up or key == keys.w then
                    selectedTemp = selectedTemp - 1
                elseif key == keys.down or key == keys.s then
                    selectedTemp = selectedTemp + 1
                end
                -- switch too other menu
                if key == keys.left or key == keys.a then tempSelected = false end
                if key == keys.right or key == keys.d or key == keys.enter then return selectedType, selectedTemp end
            end
            -- keep selectedType and selectedTemp within length of the list (after possible list changes have occured)
            if selectedType < 1 then
                selectedType = #templateList["type"]
            elseif selectedType > #templateList["type"] then
                selectedType = 1
            end

            if selectedTemp < 1 then
                selectedTemp = #templates[templateList["type"][selectedType]]
            elseif selectedTemp > #templates[templateList["type"][selectedType]] then
                selectedTemp = 1
            end
                
        end
    end
end

-- main
local selectedType, selectedTemp = selectTemplate()
local template = templates[templateList["type"][selectedType]][selectedTemp]
local formatData = getFormatData(template)
local toPrint = getTemplateDoc(template, formatData)
local amount = redstone.getAnalogInput("left")
if amount == 0 then
    print("[WARN] amount is 0, printing 2"); amount = 2
end

rednet.open("back")
spclib.printDocument(printerHost, toPrint, amount, false)

print("finished")
shell.run("adminShell")
