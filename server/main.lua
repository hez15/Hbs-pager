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
-- Register / assign pager number
-- Called by client when item is used.
-- Item definition must have: client = { event = 'hbs-pager:client:openPager' }
-- ──────────────────────────────────────────────

RegisterNetEvent('hbs-pager:server:registerPager', function(slot)
    local src  = source
    -- Read metadata directly from inventory — never trust client-sent data
    local item = exports.ox_inventory:GetSlotWithItem(src, 'pager')

    if not item then return end

    local metadata = item.metadata or {}

    if not metadata.pagerNumber then
        metadata.pagerNumber = generatePagerNumber()
        exports.ox_inventory:SetMetadata(src, item.slot, metadata)
    else
        if not usedNumbers[metadata.pagerNumber] then
            usedNumbers[metadata.pagerNumber] = true
        end
    end

    pagerRegistry[metadata.pagerNumber] = src
    TriggerClientEvent('hbs-pager:client:pagerReady', src, metadata.pagerNumber)
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
