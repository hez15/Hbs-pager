# hbs-pager

An item-based pager system for FiveM using **qbx-core**, **ox_inventory**, and **ox_lib**.

Players must have a physical pager item in their inventory to send and receive pages. Each pager is automatically assigned a unique number stored in the item's metadata — the number follows the item, not the player.

---

## Features

- Requires a `pager` item to use the system
- Auto-assigns a unique pager number on first use (stored in item metadata, persists across sessions)
- Send pages to any active pager number
- Bottom-left popup notification when a page is received (slides in, auto-dismisses)
- In-game inbox showing the last N received pages
- Full ox_lib UI — no custom NUI menus, no keybinds required
- Anti-spoofing: server verifies sender identity before routing pages
- Pager numbers freed from registry on disconnect

---

## Dependencies

- [qbx-core](https://github.com/Qbox-project/qbx_core)
- [ox_inventory](https://github.com/overextended/ox_inventory)
- [ox_lib](https://github.com/overextended/ox_lib)

---

## Installation

### 1. Add the item to ox_inventory

Open `ox_inventory/data/items.lua` and add the following inside the return table:

```lua
['pager'] = {
    label       = 'Pager',
    weight      = 200,
    stack       = false,
    close       = true,
    description = 'A small paging device. Use it to send and receive pages.',
    client = {
        event = 'hbs-pager:client:openPager',
    },
},
```

> `stack = false` is required — each pager must be a unique inventory slot so metadata (the pager number) is stored per item.
>
> `client.event` is required — without a use handler ox_inventory will not show a "Use" option for the item.

### 2. Add a pager image *(optional)*

Place a `pager.png` image (96×96 px) inside `ox_inventory/web/images/` to show an icon in the inventory.

### 3. Add the resource

Place the `hbs-pager` folder in your resources directory, then add the following to your `server.cfg`:

```
ensure ox_lib
ensure ox_inventory
ensure qbx_core
ensure hbs-pager
```

> `hbs-pager` must be ensured **after** its dependencies.

### 4. Give players a pager

Use any admin command or script to give the item:

```
/give [playerid] pager 1
```

---

## Configuration

All settings are in `shared/config.lua`:

| Option | Default | Description |
|--------|---------|-------------|
| `Config.MaxMessageLength` | `100` | Maximum characters in a page message |
| `Config.MaxInboxSize` | `10` | Number of pages stored in the inbox per session |
| `Config.PagerNumberDigits` | `4` | Digits in a pager number (4 = 1000–9999) |
| `Config.NotificationDuration` | `8000` | How long (ms) the popup stays on screen |

---

## Usage

1. Have a `pager` item in your inventory and use it
2. A menu opens showing your pager number and options:
   - **Send Page** — enter a recipient's pager number and a message
   - **Inbox** — view your last received pages
   - **My Number** — displays your pager number to share with others
3. When someone pages you, a notification slides in from the bottom-left of the screen

---

## File Structure

```
hbs-pager/
├── fxmanifest.lua       Resource manifest
├── shared/
│   └── config.lua       Shared configuration
├── server/
│   └── main.lua         Item hook, page routing, number registry
├── client/
│   └── main.lua         ox_lib UI menus, inbox, NUI trigger
└── html/
    ├── index.html        NUI popup structure
    ├── style.css         Pager popup styling and animations
    └── script.js         Popup show/hide logic
```
