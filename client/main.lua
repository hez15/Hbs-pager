-- hbs-pager — client/main.lua

local inbox         = {} -- { sender, message, time }
local contacts      = {} -- { name, number } — loaded from item metadata via server
local myPagerNumber = nil

-- ──────────────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────────────

local function notify(msg, ntype)
    lib.notify({ title = 'Pager', description = msg, type = ntype or 'inform' })
end

-- ──────────────────────────────────────────────
-- UI — Send message dialog (shared by manual dial + contacts)
-- ──────────────────────────────────────────────

local function sendMessageTo(recipientNumber, recipientName)
    local title = recipientName
        and ('Page  %s  (#%s)'):format(recipientName, recipientNumber)
        or  ('Send Page')

    local input = lib.inputDialog(title, {
        {
            type        = 'input',
            label       = 'Message',
            required    = true,
            max         = Config.MaxMessageLength,
            placeholder = 'Type your message...',
        },
    })

    if not input or not input[1] then return end
    TriggerServerEvent('hbs-pager:server:sendPage', recipientNumber, input[1], myPagerNumber)
end

-- ──────────────────────────────────────────────
-- UI — Manual dial
-- ──────────────────────────────────────────────

local function sendPageDialog()
    local input = lib.inputDialog('Send Page', {
        {
            type        = 'number',
            label       = 'Pager Number',
            required    = true,
            placeholder = ('e.g. %s'):format(myPagerNumber),
        },
        {
            type        = 'input',
            label       = 'Message',
            required    = true,
            max         = Config.MaxMessageLength,
            placeholder = 'Type your message...',
        },
    })

    if not input then return end

    local recipientNumber = tonumber(input[1])
    if not recipientNumber then
        notify('Invalid pager number.', 'error')
        return
    end

    TriggerServerEvent('hbs-pager:server:sendPage', recipientNumber, input[2], myPagerNumber)
end

-- ──────────────────────────────────────────────
-- UI — Contacts
-- ──────────────────────────────────────────────

local openContactsMenu  -- forward declare so inbox can reference it

local function openContactMenu(contact, index)
    lib.registerContext({
        id      = 'hbs_pager_contact',
        title   = ('%s  —  #%s'):format(contact.name, contact.number),
        menu    = 'hbs_pager_contacts',
        options = {
            {
                title    = 'Send Page',
                icon     = 'paper-plane',
                onSelect = function()
                    sendMessageTo(contact.number, contact.name)
                end,
            },
            {
                title    = 'Delete Contact',
                icon     = 'trash',
                onSelect = function()
                    TriggerServerEvent('hbs-pager:server:deleteContact', index)
                end,
            },
        },
    })
    lib.showContext('hbs_pager_contact')
end

openContactsMenu = function()
    local options = {}

    -- Saved contacts
    if #contacts == 0 then
        options[#options + 1] = {
            title    = 'No contacts saved yet.',
            readOnly = true,
            icon     = 'address-book',
        }
    else
        for i, c in ipairs(contacts) do
            local idx = i
            options[#options + 1] = {
                title       = c.name,
                description = '#' .. c.number,
                icon        = 'user',
                onSelect    = function() openContactMenu(c, idx) end,
            }
        end
    end

    -- Add contact
    options[#options + 1] = {
        title    = 'Add Contact',
        icon     = 'user-plus',
        onSelect = function()
            local input = lib.inputDialog('Add Contact', {
                {
                    type        = 'input',
                    label       = 'Name',
                    required    = true,
                    max         = 24,
                    placeholder = 'e.g. Dispatch',
                },
                {
                    type        = 'number',
                    label       = 'Pager Number',
                    required    = true,
                    placeholder = '1234',
                },
            })

            if not input or not input[1] or not input[2] then return end

            local number = tonumber(input[2])
            if not number then
                notify('Invalid pager number.', 'error')
                return
            end

            TriggerServerEvent('hbs-pager:server:saveContact', input[1], number)
        end,
    }

    lib.registerContext({
        id      = 'hbs_pager_contacts',
        title   = 'Contacts',
        menu    = 'hbs_pager_menu',
        options = options,
    })
    lib.showContext('hbs_pager_contacts')
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
            local p = page
            options[#options + 1] = {
                title       = ('[%s] From #%s'):format(p.time, p.sender),
                description = p.message,
                icon        = 'envelope',
                onSelect    = function()
                    -- Quick actions on a received page
                    lib.registerContext({
                        id      = 'hbs_pager_inbox_action',
                        title   = ('From #%s'):format(p.sender),
                        menu    = 'hbs_pager_inbox',
                        options = {
                            {
                                title    = 'Reply',
                                icon     = 'reply',
                                onSelect = function()
                                    sendMessageTo(p.sender, nil)
                                end,
                            },
                            {
                                title    = 'Save to Contacts',
                                icon     = 'user-plus',
                                onSelect = function()
                                    local input = lib.inputDialog('Save Contact', {
                                        {
                                            type        = 'input',
                                            label       = 'Name',
                                            required    = true,
                                            max         = 24,
                                            placeholder = 'e.g. John',
                                        },
                                    })
                                    if not input or not input[1] then return end
                                    TriggerServerEvent('hbs-pager:server:saveContact', input[1], p.sender)
                                end,
                            },
                        },
                    })
                    lib.showContext('hbs_pager_inbox_action')
                end,
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
-- UI — Main pager menu
-- ──────────────────────────────────────────────

local function openPagerMenu()
    lib.registerContext({
        id      = 'hbs_pager_menu',
        title   = ('Pager  —  #%s'):format(myPagerNumber),
        options = {
            {
                title       = 'Contacts',
                description = ('%s saved'):format(#contacts),
                icon        = 'address-book',
                onSelect    = function() openContactsMenu() end,
            },
            {
                title       = 'Send Page',
                description = 'Dial a number manually',
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
AddEventHandler('hbs-pager:client:openPager', function()
    TriggerServerEvent('hbs-pager:server:registerPager')
end)

-- Server confirms the assigned/existing pager number and sends contacts
RegisterNetEvent('hbs-pager:client:pagerReady', function(pagerNumber, savedContacts)
    myPagerNumber = pagerNumber
    contacts      = savedContacts or {}
    openPagerMenu()
end)

-- Server sends updated contacts after save/delete
RegisterNetEvent('hbs-pager:client:contactsUpdated', function(updatedContacts)
    contacts = updatedContacts or {}
    notify('Contacts updated.', 'success')
    openContactsMenu()
end)

RegisterNetEvent('hbs-pager:client:receivePage', function(senderNumber, message)
    table.insert(inbox, 1, {
        sender  = senderNumber,
        message = message,
        time    = os.date('%H:%M'),
    })

    while #inbox > Config.MaxInboxSize do
        table.remove(inbox)
    end

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
