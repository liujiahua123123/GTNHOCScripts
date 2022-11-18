---
-- CONST as Config
---


---
-- Reactor Design
---

ReactorDesign = {
    fuel_slots = {},
    cool_slots = {},
}

function ReactorDesign:fromTemplate(src)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    local row = 0
    local counter = 0
    for s in src:gmatch("[^\r\n]+") do
        s = s:gsub("^%s*(.-)%s*$", "%1")
        if s == "" then
            goto continue
        end
        row = row + 1
        if string.len(s) ~= 9 then
            error("Each row has 9 slots")
        end
        for i = 1, #s do
            local type = string.sub(s, i, i)
            if type == "F" then
                table.insert(self.fuel_slots, counter)
            elseif type == "C" then
                table.insert(self.cool_slots, counter)
            else
                error("Unknown type " .. type)
            end
            counter = counter + 1
        end
        ::continue::
    end
    if row ~= 6 then
        error("Should have 6 rows")
    end
    return obj
end
function ReactorDesign:fuelSlots()
    return self.fuel_slots
end
function ReactorDesign:coolSlots()
    return self.cool_slots
end
function ReactorDesign:numOfFuel()
    return #self.fuel_slots
end
function ReactorDesign:numOfCool()
    return #self.cool_slots
end

---
-- Helper functions
---


---
-- Returns the component only if the type and name prefixes match only one in the network
---
local function getComponent(type, idPrefix) -- Get component
    local matched = 0
    local matchedK = nil
    local matchedV = nil
    for k,v in pairs(component.list(t)) do
        if string.startswith(k, idPrefix) then
            matchedK = k
            matchedV = v
            matched = matched + 1
        end
    end
    if matched == 1 then
        return component.proxy(matchedK,matchedV)
    end
    if matched > 1 then
        error("duplicate match for " .. type .. " with prefix " .. idPrefix)
    else
        error("no match for " .. type .. " with prefix " .. idPrefix)
    end
end


print(getComponent("transposer", "24e"))
print(getComponent("transposer", "6e"))