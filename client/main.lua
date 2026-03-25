-- hbs-pager — client/main.lua

local inbox         = {} -- { sender, message, time }
local contacts      = {} -- { name, number }
local myPagerNumber = nil

-- ──────────────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────────────

local function notify(msg, ntype)
    lib.notify({ title = 'Pager', description = msg, type = ntype or 'inform' })
end

-- ──────────────────────────────────────────────
-- NUI open / close
-- ──────────────────────────────────────────────

local function openPagerUI()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action      = 'openPager',
        pagerNumber = myPagerNumber,
        contacts    = contacts,
        inbox       = inbox,
    })
end

local function closePagerUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closePager' })
end

-- ──────────────────────────────────────────────
-- NUI callbacks (JS → Lua)
-- ──────────────────────────────────────────────

RegisterNUICallback('closePager', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('sendPage', function(data, cb)
    local number  = tonumber(data.number)
    local message = tostring(data.message or '')
    if not number or message == '' then cb('invalid') return end
    TriggerServerEvent('hbs-pager:server:sendPage', number, message, myPagerNumber)
    cb('ok')
end)

RegisterNUICallback('saveContact', function(data, cb)
    local name   = tostring(data.name   or '')
    local number = tonumber(data.number)
    if name == '' or not number then cb('invalid') return end
    TriggerServerEvent('hbs-pager:server:saveContact', name, number)
    cb('ok')
end)

RegisterNUICallback('deleteContact', function(data, cb)
    local index = tonumber(data.index)
    if not index then cb('invalid') return end
    TriggerServerEvent('hbs-pager:server:deleteContact', index)
    cb('ok')
end)

-- ──────────────────────────────────────────────
-- Events from server / ox_inventory
-- ──────────────────────────────────────────────

-- Fired by ox_inventory when the pager item is used
AddEventHandler('hbs-pager:client:openPager', function()
    TriggerServerEvent('hbs-pager:server:registerPager')
end)

-- Server confirms number, contacts, and persistent inbox loaded from item metadata
RegisterNetEvent('hbs-pager:client:pagerReady', function(pagerNumber, savedContacts, savedInbox)
    myPagerNumber = pagerNumber
    contacts      = savedContacts or {}
    inbox         = savedInbox    or {}
    openPagerUI()
end)

-- Server sends refreshed contacts after save/delete
RegisterNetEvent('hbs-pager:client:contactsUpdated', function(updatedContacts)
    contacts = updatedContacts or {}
    SendNUIMessage({ action = 'updateContacts', contacts = contacts })
    notify('Contacts updated.', 'success')
end)

-- Incoming page — timestamp comes from server so it matches what was saved to metadata
RegisterNetEvent('hbs-pager:client:receivePage', function(senderNumber, message, timeStr)
    local entry = { sender = senderNumber, message = message, time = timeStr }
    table.insert(inbox, 1, entry)
    while #inbox > Config.MaxInboxSize do table.remove(inbox) end

    SendNUIMessage({
        action   = 'showPage',
        sender   = senderNumber,
        message  = message,
        time     = timeStr,
        duration = Config.NotificationDuration,
    })
end)

RegisterNetEvent('hbs-pager:client:notify', function(msg, ntype)
    notify(msg, ntype)
end)
