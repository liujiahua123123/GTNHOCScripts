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
    mapping = {},
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
            self.mapping[counter] = type
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
function ReactorDesign:slotType(slotNum)
    return self.mapping[slotNum]
end


---
-- Helper functions
---
local function startsWith(text, prefix)
    return text:find(prefix, 1, true) == 1
end

local function printTable(table)
    if table == nil then
        print("nil table")
        return
    end
    if isNullOrEmpty(table) then
        print("empty table")
        return
    end
    for k, v in pairs(table) do
        print(k, v)
    end
end

function isNullOrEmpty(table)
    if table == nil then
        return true;
    end
    for i, v in pairs(table) do
        return false;
    end
    return true;
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

local function findNonEmptyIndex(item_in_box)

    local boxLocation = 0

    for idx = 0, #item_in_box, 1 do
        if ((not isNullOrEmpty(item_in_box[idx])) and item_in_box[idx].size > 0) then
            boxLocation = idx + 1
            break
        end
    end
    if boxLocation == 0 then
        return nil
    end
    return boxLocation
end

local function getTransposerSide(t, side, name)
    return {
        getAllItems = function()
            return t.getAllStacks(side).getAll()
        end,
        transposer = t,
        side = side,
        moveItem = function(sourceSlot, target, count, targetSlot)
            if count == nil then
                count = 1
            end
            --if targetSlot == nil then
            --    targetSlot = findEmptySlot(t.getAllStacks(targetSide).getAll())
            --end
            -- sourceSide, sinkSide, count, sourceSlot, sinkSlot
            if targetSlot == nil then
                t.transferItem(side, target.side, count, sourceSlot)
            else
                t.transferItem(side, target.side, count, sourceSlot, targetSlot + 1)
            end
        end,
        name = name,
    }
end

local gpu = getComponent("gpu", "5a4")
gpu.setDepth(gpu.maxDepth())

local RED, YELLOW, GREEN, BLUE, PURPLE, CYAN, WHITE, BG, FG, BLACK, CLEAR
function initColor()
    local palette = {
        0x21252B, 0xABB2BF, 0x21252B, 0xE06C75, 0x98C379, 0xE5C07B,
        0x61AFEF, 0xC678DD, 0x56B6C2, 0xABB2BF
    }
    gpu.setBackground(palette[1])
    gpu.setForeground(palette[2])
    RED = function()
        gpu.setForeground(palette[4])
        return ""
    end
    YELLOW = function()
        gpu.setForeground(palette[6])
        return ""
    end
    GREEN = function()
        gpu.setForeground(palette[5])
        return ""
    end
    BLUE = function()
        gpu.setForeground(palette[7])
        return ""
    end
    PURPLE = function()
        gpu.setForeground(palette[8])
        return ""
    end
    CYAN = function()
        gpu.setForeground(palette[9])
        return ""
    end
    WHITE = function()
        gpu.setForeground(palette[10])
        return ""
    end
    BG = function()
        gpu.setBackground(palette[1])
        return ""
    end
    FG = function()
        gpu.setForeground(palette[2])
        return ""
    end
    BLACK = function()
        gpu.setForeground(palette[3])
        return ""
    end
end
initColor()

function colorPrint(color, string)
    color()
    print(string)
    FG()
end

local transposer = getComponent("transposer", "5f6")
local reactorThermostat = getComponent("redstone", "11d")
local reactorThermostatSide = SIDES.down
local reactorController = getComponent("redstone", '41c')
local reactorEnabled = false
local enableReactorSide = SIDES.east

local chestNewFuel = getTransposerSide(transposer, SIDES.top, "chestNewFuel")
local chestNewCooler = getTransposerSide(transposer, SIDES.north, "chestNewCooler")
local chestDamagedCooler = getTransposerSide(transposer, SIDES.down, "chestDamagedCooler")

local chestDamagedFuel = getTransposerSide(transposer, SIDES.south, "chestDamagedFuel")
local reactor = getTransposerSide(transposer, SIDES.west, "reactor")

local design = ReactorDesign:fromTemplate(
        [[CFFFCFFFC
              FFCFFFCFF
              CFFFCFFFC
              FFCFFFCFF
              CFFFCFFFC
              FFCFFFCFF]])

function initReactor()
    disableReactor()
end

function disableReactor()
    reactorController.setOutput(enableReactorSide, 0)
    reactorEnabled = false
end

function enableReactor()
    reactorController.setOutput(enableReactorSide, 15)
    reactorEnabled = true
end

function checkTemperature()
    --if reactorController.getInput(enableReactorSide) == 0 then
    --    print("Reactor is disabled. Ignoring temperature check.")
    --    return
    --end,"

    if reactorThermostat.getInput(reactorThermostatSide) ~= 0 then
        -- Temperature high
        colorPrint(RED, "Disabling reactor due to high temperature!")
        disableReactor()
        return
    end

end

while true do
    checkTemperature()

    local reactorItems = reactor.getAllItems()
    for i = 0, 53 do
        local item = reactorItems[i]
        local slotType = design:slotType(i)

        print("Checking i=" .. i .. " type= " .. slotType)
        --printTable(item)

        --if (item == nil or item.maxDamage == 0) then
        --    print("replace fuel at " .. i)
        --    reactor.moveItem(i, chestDamagedFuel)
        --    goto continue
        --end

        if ((not isNullOrEmpty(item)) and slotType == 'C') then
            --replace nearly damaged
            --check if it is already damaged
            local damaged = (item.maxDamage == 0 or ((0.1 + item.damage) / (0.1 + item.maxDamage)) > 0.8)
            print("cooler damaged: " .. tostring(damaged))
            if damaged then
                disableReactor()
                print("remove cooler at " .. i)
                reactor.moveItem(i, chestDamagedCooler)
                item = nil
            end
        end

        -- 拿出来坏的 fuel
        if ((not isNullOrEmpty(item)) and slotType == 'F') then
            local damaged = (item.maxDamage == 0)
            print("fuel damaged: " .. tostring(damaged))
            if damaged then
                print("remove fuel rod at " .. i)
                reactor.moveItem(i, chestDamagedFuel)
                item = nil
            end
        end

        if (isNullOrEmpty(item)) then
            local newItem = nil
            local src = nil
            if slotType == 'F' then
                newItem = findNonEmptyIndex(chestNewFuel.getAllItems())
                src = chestNewFuel
            elseif slotType == 'C' then
                newItem = findNonEmptyIndex(chestNewCooler.getAllItems())
                src = chestNewCooler
            end

            if newItem == nil then
                colorPrint(RED, "Nothing to move!! from " .. src.name)
                disableReactor()
            else
                colorPrint(GREEN, "Moving from " .. src.name .. "." .. tostring(newItem) .. " to " .. reactor.name .. "." .. tostring(i))
                src.moveItem(newItem, reactor, 1, i)
            end
        end


    end

    --开机iff

    for i = 0, 53 do
        local item = reactorItems[i]
        local slotType = design:slotType(i)
    end

    break
end