local name, A = ...
A.name = name
A.version = "0.2.1"
A.Professions = {
    {id=197, skillLine=2540, name="Tailoring"},
    {id=333, skillLine=2494, name="Enchanting"},
    {id=185, skillLine=2548, name="Cooking"},
}
function A.Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = A.Copy(entry) end
    return result
end
function A.SortedKeys(value)
    local keys = {}
    for key in pairs(value) do keys[#keys+1] = key end
    table.sort(keys)
    return keys
end
function A.Money(copper)
    if not copper or copper == math.huge then return "unknown" end
    copper = math.ceil(copper)
    return string.format("%dg %ds %dc", math.floor(copper/10000), math.floor(copper/100)%100, copper%100)
end
function A.Message(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffedbf65Craftalot:|r " .. tostring(text)) end
end
