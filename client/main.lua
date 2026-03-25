-- hbs-pager — client/main.lua

local inbox         = {} -- { sender, message, time }
local myPagerNumber = nil

-- ──────────────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────────────

local function notify(msg, ntype)
    lib.notify({ title = 'Pager', description = msg, type = ntype or 'inform' })
end

-- ──────────────────────────────────────────────
-- UI — Inbox
-- ──────────────────────────────────────────────

local function openInbox()
    local options = {}

    if #inbox == 0 then
        options[#options + 1] = {
            title    = 'No pages received yet.',
            readOnly = true,
        }
    else
        for _, page in ipairs(inbox) do
            options[#options + 1] = {
                title       = ('[%s] From #%s'):format(page.time, page.sender),
                description = page.message,
                readOnly    = true,
            }
        end
    end

    lib.registerContext({
        id      = 'hbs_pager_inbox',
        title   = 'Inbox',
        menu    = 'hbs_pager_menu',
        options = options,
    })
    lib.showContext('hbs_pager_inbox')
end

-- ──────────────────────────────────────────────
-- UI — Send page dialog
-- ──────────────────────────────────────────────

local function sendPageDialog()
    local input = lib.inputDialog('Send Page', {
        {
            type     = 'number',
            label    = 'Recipient Pager Number',
            required = true,
        },
        {
            type     = 'input',
            label    = 'Message',
            required = true,
            max      = Config.MaxMessageLength,
        },
    })

    if not input then return end

    local recipientNumber = tonumber(input[1])
    local message         = tostring(input[2])

    if not recipientNumber then
        notify('Invalid pager number.', 'error')
        return
    end

    TriggerServerEvent('hbs-pager:server:sendPage', recipientNumber, message, myPagerNumber)
end

-- ──────────────────────────────────────────────
-- UI — Main pager menu
-- ──────────────────────────────────────────────

local function openPagerMenu()
    lib.registerContext({
        id      = 'hbs_pager_menu',
        title   = ('Pager  —  #%s'):format(myPagerNumber),
        options = {
            {
                title       = 'Send Page',
                description = 'Send a message to another pager number',
                icon        = 'paper-plane',
                onSelect    = function() sendPageDialog() end,
            },
            {
                title       = ('Inbox  (%s)'):format(#inbox),
                description = 'View pages you have received',
                icon        = 'inbox',
                onSelect    = function() openInbox() end,
            },
            {
                title       = ('My Number:  #%s'):format(myPagerNumber),
                description = 'Share this number so others can page you',
                icon        = 'hashtag',
                readOnly    = true,
            },
        },
    })
    lib.showContext('hbs_pager_menu')
end

-- ──────────────────────────────────────────────
-- Events
-- ──────────────────────────────────────────────

-- Fired by ox_inventory when the item is used (client.event in item definition)
-- itemData = { slot, name, label, count, metadata, ... }
AddEventHandler('hbs-pager:client:openPager', function(itemData)
    TriggerServerEvent('hbs-pager:server:registerPager', itemData.slot)
end)

-- Server confirms the assigned/existing pager number
RegisterNetEvent('hbs-pager:client:pagerReady', function(pagerNumber)
    myPagerNumber = pagerNumber
    openPagerMenu()
end)

RegisterNetEvent('hbs-pager:client:receivePage', function(senderNumber, message)
    -- Store in inbox
    table.insert(inbox, 1, {
        sender  = senderNumber,
        message = message,
        time    = os.date('%H:%M'),
    })

    -- Trim to max size
    while #inbox > Config.MaxInboxSize do
        table.remove(inbox)
    end

    -- Show NUI popup (does not steal focus)
    SendNUIMessage({
        action   = 'showPage',
        sender   = senderNumber,
        message  = message,
        time     = os.date('%H:%M'),
        duration = Config.NotificationDuration,
    })
end)

RegisterNetEvent('hbs-pager:client:notify', function(msg, ntype)
    notify(msg, ntype)
end)
