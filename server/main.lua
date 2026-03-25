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
-- ox_inventory item export (replaces registerHook)
-- Item definition must have: server = { export = 'hbs-pager.usePager' }
-- ──────────────────────────────────────────────

exports('usePager', function(payload, cb)
    local src      = payload.source
    local metadata = payload.item.metadata or {}

    -- Assign pager number on first use; store in item metadata
    if not metadata.pagerNumber then
        metadata.pagerNumber = generatePagerNumber()
        exports.ox_inventory:SetMetadata(src, payload.item.slot, metadata)
    else
        -- Re-register in case the player re-logged
        if not usedNumbers[metadata.pagerNumber] then
            usedNumbers[metadata.pagerNumber] = true
        end
    end

    -- Always refresh the live registry with current source
    pagerRegistry[metadata.pagerNumber] = src

    TriggerClientEvent('hbs-pager:client:openPager', src, metadata.pagerNumber)

    cb(true) -- required: signals ox_inventory the use action completed
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
