# extra function for the [bigFont lib by wojbie](https://pastebin.com/3LfWxRWh) too allow different background/foreground on each line
paste it on the empty line after the `end` statement of the function for `b.writeOn` and before `b.doc.blitOn`
```lua
b.doc.writeOnMod = [[writeOnMod(tTerminal, nSize, sString, tColors, [nX], [nY]) - Writes sString on tTerminal using current tColors colours per line. nX, nY are coordinates. If any of them are nil then text is centered in that axis using tTerminal size.]]
b.writeOnMod = function(tTerminal, nSize, sString, tColors, nX, nY)
    expect(1, tTerminal, "table")
    field(tTerminal, "getSize", "function")
    field(tTerminal, "scroll", "function")
    field(tTerminal, "setCursorPos", "function")
    field(tTerminal, "blit", "function")
    field(tTerminal, "getTextColor", "function")
    field(tTerminal, "getBackgroundColor", "function")
    expect(2, nSize, "number")
    expect(3, sString, "string")
    expect(4, tColors, "table") -- added this line

    expect(5, nX, "number", "nil") -- increased number by 1
    expect(6, nY, "number", "nil") -- increased number by 1
    local text = makeText(nSize, sString, tColors[1][1], tColors[1][2]) -- make the text
    local textJSON = textutils.serialise(text) -- store for comparison
    local h = fs.open("generated.lua","w")
    h.write(textJSON)
    h.close()
    local peter =false
    for i=1,#text[2] do -- loop through text by line
        local lineHeight = nSize
        local line = math.ceil(i/lineHeight)
        local cFColor = tHex[tColors[line][1]]
        text[2][i] = text[2][i]:gsub(tHex[tColors[1][1]],cFColor)
    end
    for i=1,#text[3] do -- loop through text by line
        local lineHeight = nSize
        local line = math.ceil(i/lineHeight)
        local cBColor = tHex[tColors[line][2]]
        text[3][i] = text[3][i]:gsub(tHex[tColors[1][2]],cBColor)
    end
    local textJSON2 = textutils.serialise(text) -- store for comparison
    local h = fs.open("generatedMod.lua","w")
    h.write(textJSON2)
    h.close()
    press(tTerminal,text , nX, nY) -- took out maketext() and use variable
end
```
