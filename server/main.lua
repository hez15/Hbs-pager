-- hbs-pager — server/main.lua

local pagerRegistry = {} -- [pagerNumber] = playerSource
local usedNumbers   = {} -- set of currently assigned numbers

math.randomseed(os.time())

-- ──────────────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────────────

local function generatePagerNumber()
    local min = 10 ^ (Config.PagerNumberDigits - 1)
    local max = (10 ^ Config.PagerNumberDigits) - 1
    local num
    repeat
        num = math.random(min, max)
    until not usedNumbers[num]
    usedNumbers[num] = true
    return num
end

-- ──────────────────────────────────────────────
-- Assign pager number on first use
-- Item definition must have: client = { event = 'hbs-pager:client:openPager' }
-- ──────────────────────────────────────────────

-- Returns the pager number for a player, assigning one if this is the first use.
-- Search() returns full slot objects including metadata; GetSlotWithItem only
-- returns a slot number so we use Search here.
local function assignPagerNumber(src)
    local slots = exports.ox_inventory:Search(src, 'slots', 'pager')

    if not slots or #slots == 0 then return nil end

    local item     = slots[1]
    local metadata = item.metadata or {}

    if not metadata.pagerNumber then
        -- First use — generate a unique number and write it to the item permanently
        metadata.pagerNumber = generatePagerNumber()
        exports.ox_inventory:SetMetadata(src, item.slot, metadata)
    else
        -- Returning user — make sure the number is tracked in usedNumbers
        if not usedNumbers[metadata.pagerNumber] then
            usedNumbers[metadata.pagerNumber] = true
        end
    end

    return metadata.pagerNumber
end

RegisterNetEvent('hbs-pager:server:registerPager', function()
    local src    = source
    local number = assignPagerNumber(src)

    if not number then return end

    pagerRegistry[number] = src

    -- Also pass saved contacts so the client can populate the contacts list
    local slots = exports.ox_inventory:Search(src, 'slots', 'pager')
    local savedContacts = (slots and slots[1] and slots[1].metadata and slots[1].metadata.contacts) or {}

    TriggerClientEvent('hbs-pager:client:pagerReady', src, number, savedContacts)
end)

-- ──────────────────────────────────────────────
-- Contacts
-- ──────────────────────────────────────────────

local function getItemAndMeta(src)
    local slots = exports.ox_inventory:Search(src, 'slots', 'pager')
    if not slots or #slots == 0 then return nil, nil end
    local item = slots[1]
    return item, item.metadata or {}
end

RegisterNetEvent('hbs-pager:server:saveContact', function(name, number)
    local src = source
    if type(name) ~= 'string' or type(number) ~= 'number' then return end

    name   = string.sub(name, 1, 24)
    number = math.floor(number)

    local item, metadata = getItemAndMeta(src)
    if not item then return end

    metadata.contacts = metadata.contacts or {}

    -- Prevent duplicate numbers
    for _, c in ipairs(metadata.contacts) do
        if c.number == number then
            TriggerClientEvent('hbs-pager:client:notify', src, 'That number is already in your contacts.', 'error')
            return
        end
    end

    table.insert(metadata.contacts, { name = name, number = number })
    exports.ox_inventory:SetMetadata(src, item.slot, metadata)
    TriggerClientEvent('hbs-pager:client:contactsUpdated', src, metadata.contacts)
end)

RegisterNetEvent('hbs-pager:server:deleteContact', function(index)
    local src = source
    if type(index) ~= 'number' then return end

    local item, metadata = getItemAndMeta(src)
    if not item then return end

    metadata.contacts = metadata.contacts or {}
    if not metadata.contacts[index] then return end

    table.remove(metadata.contacts, index)
    exports.ox_inventory:SetMetadata(src, item.slot, metadata)
    TriggerClientEvent('hbs-pager:client:contactsUpdated', src, metadata.contacts)
end)

-- ──────────────────────────────────────────────
-- Send page
-- ──────────────────────────────────────────────

RegisterNetEvent('hbs-pager:server:sendPage', function(recipientNumber, message, senderNumber)
    local src = source

    -- Basic validation
    if type(recipientNumber) ~= 'number' or type(message) ~= 'string' then return end
    if type(senderNumber) ~= 'number' then return end

    -- Sanitise message length
    message = string.sub(message, 1, Config.MaxMessageLength)

    if recipientNumber == senderNumber then
        TriggerClientEvent('hbs-pager:client:notify', src, 'You cannot page yourself.', 'error')
        return
    end

    local recipientSrc = pagerRegistry[recipientNumber]
    if not recipientSrc then
        TriggerClientEvent('hbs-pager:client:notify', src, 'Pager #' .. recipientNumber .. ' is not active or online.', 'error')
        return
    end

    TriggerClientEvent('hbs-pager:client:receivePage', recipientSrc, senderNumber, message)
    TriggerClientEvent('hbs-pager:client:notify', src, 'Page sent to #' .. recipientNumber .. '.', 'success')
end)

-- ──────────────────────────────────────────────
-- Cleanup on disconnect
-- ──────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    local src = source
    for number, s in pairs(pagerRegistry) do
        if s == src then
            pagerRegistry[number] = nil
            usedNumbers[number]   = nil
            break
        end
    end
end)
