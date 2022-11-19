local component = require("component")
local event = require("event")
local filesystem = require("filesystem")
local serialization = require("serialization")
local term = require("term")
local coroutine = require("coroutine")

local SIDES = {
    down = 0,
    top = 1,
    north = 2,
    south = 3,
    west = 4,
    east = 5
}
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
        :: continue ::
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
local function startsWith(text, prefix)
    return text:find(prefix, 1, true) == 1
end
local function printTable(table)
    for k, v in pairs(table) do
        print(k, v)
    end
end

---
-- Returns the component only if the type and name prefixes match only one in the network
---
local function getComponent(type, idPrefix)
    -- Get component
    local matched = 0
    local matchedK = nil
    local matchedV = nil
    for k, v in pairs(component.list(t)) do
        if startsWith(k, idPrefix) then
            matchedK = k
            matchedV = v
            matched = matched + 1
        end
    end
    if matched == 1 then
        return component.proxy(matchedK, matchedV)
    end
    if matched > 1 then
        error("duplicate match for " .. type .. " with prefix " .. idPrefix)
    else
        error("no match for " .. type .. " with prefix " .. idPrefix)
    end
end

local spareTransposer = getComponent("transposer", "24e")
local recycleTransposer = getComponent("transposer", "6e")
local reactorTransposer = getComponent("transposer", "567")

local function getTransposerSide(transposer, side)
    return {
        getAllItems = function()
            return transposer.getAllStacks(side).getAll()
        end,
        transposer = transposer,
        side = side
    }
end

-- rm v1.lua && wget http://192.168.5.102/mc/v1.lua && v1

local reactor = getTransposerSide(reactorTransposer, SIDES.down)
local recycleFuelBox = getTransposerSide(recycleTransposer, SIDES.top)
local recycleCoolBox = getTransposerSide(recycleTransposer, SIDES.west)
local newFuelBox = getTransposerSide(spareTransposer, SIDES.top)
local newCoolBox = getTransposerSide(spareTransposer, SIDES.west)

printTable(reactor.getAllItems()[0])