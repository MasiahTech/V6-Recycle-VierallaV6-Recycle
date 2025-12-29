# V6 Recycle Job

A modern, fully-featured recycling job script for QBX Core with seamless integration and intuitive gameplay mechanics.

## 📋 Features

- **Dynamic Package Spawning** - Randomized pickup locations for engaging gameplay
- **Interactive Dropoff System** - Persistent dropoff box with ZSX UI integration
- **Dual Interaction System** - Choose between ox_target (mouse) or lib.zones (keyboard E)
- **Smart Option Filtering** - Dropoff only shows when carrying package
- **Trade NPC** - Trade recycled materials for rewards
- **Modern UI** - Built-in notifications and text UI guidance + ZSX points
- **Configurable Rewards** - Fully customizable payment and item rewards
- **Job Blips** - Map markers for job locations
- **Smooth Animations** - Professional carrying and scrapping animations
- **Multi-location Support** - Multiple pickup spawn points
- **Performance Optimized** - Client-side prop management with proper cleanup

## 🛠 Requirements

- **QBX Core** - Core framework
- **ox_lib** - UI and utility library
- **ox_inventory** - Inventory system
- **ZSX_UIV2** - UI points system (optional, for visual markers)

## ⚙️ Configuration

### Client Configuration (`config/client.lua`)

```lua
Config = {
    -- Toggle targeting system (true = ox_target, false = lib.zones)
    useTarget = GetConvar('UseTarget', 'false') == 'true',
    
    -- Location coordinates (vec4 format: x, y, z, heading)
    outsideLocation = vec4(746.85, -1399.99, 25.58, 182.61),
    insideLocation = vec4(737.49, -1374.3, 11.63, 273.21),
    dutyLocation = vec4(739.4, -1376.59, 12.46, 270.49),
    dropLocation = vec4(743.62, -1369.65, 11.88, 331.85),
    
    -- UI Display
    drawPackageLocationBlip = true,
    drawDropLocationBlip = true,
    
    -- Warehouse pickup locations (randomized)
    pickupLocations = { ... },
    
    -- Model configuration
    warehouseObjects = { ... },
    pickupBoxModel = 'prop_cs_cardbox_01',
    dropoffBoxModel = 'prop_boxpile_05a',
}
```

### Server Configuration (`config/server.lua`)

```lua
Config = {
    -- Payment settings
    payment = 150,  -- Reward per package
    
    -- Trade rewards (NPC trading)
    tradeRewards = {
        metal = { item = 'metalscrap', amount = 5, money = 100 },
        plastic = { item = 'plasticscrap', amount = 4, money = 75 },
        -- Add more trade options...
    }
}
```

## 🎮 Gameplay

### Clock In/Out
1. Navigate to the warehouse entrance
2. Press **E** on the duty marker inside
3. Clock in to start receiving packages

### Pickup Packages
1. Follow the on-screen marker to a random package location
2. Press **E** on the package to pick it up
3. A carrying animation plays automatically

### Deliver Packages
1. Head to the dropoff box at the designated location
2. Press **E** on the dropoff box
3. Receive payment for your delivery
4. A new package automatically spawns

### Trade with NPC
1. Approach the trade NPC (if enabled)
2. Press **E** to open trade menu
3. Exchange recyclable materials for rewards

## 📦 Package Locations

Packages spawn randomly at configured pickup locations. Customize the spawn points in `config/client.lua`:

```lua
pickupLocations = {
    [1] = vec4(748.01, -1368.06, 11.90, 0.0),
    [2] = vec4(750.44, -1368.08, 11.90, 0.0),
    [3] = vec4(752.81, -1368.07, 11.90, 0.0),
    -- Add more locations...
}
```

## 🎯 Interactions

### Mouse Target (ox_target)
Enable in config: `useTarget = true` for mouse-based interactions.

**Features:**
- Click on targets with mouse
- Icons appear when aiming at interactable objects
- Only available when carrying package for dropoff (smart filtering)
- Works for all job interactions (pickups, dropoffs)

**Example:**
```lua
-- In config/client.lua
useTarget = GetConvar('UseTarget', 'false') == 'true'
```

### Keyboard (lib.zones)
Default method - press **E** when prompted in interaction zones.

**Features:**
- No dependencies (works standalone)
- Text UI prompts showing when to press E
- Debounced input to prevent double-interactions
- Works for all job interactions (pickups, dropoffs)

## 🔧 Customization

### Add New Trade Rewards
Edit `config/server.lua` and add to `tradeRewards` table.

### Change Warehouse Layout
Modify coordinates in `config/client.lua` (`insideLocation`, `dutyLocation`, `dropLocation`).

### Adjust Payment
Update `payment` value in `config/server.lua`.

### Change Package Models
Update `warehouseObjects` array for random package models.
Update `dropoffBoxModel` for the dropoff location.

## 📡 Events

### Client Events
- `qbx_recyclejob:client:target:toggleDuty` - Clock in/out
- `qbx_recyclejob:client:target:pickupPackage` - Pickup a package
- `qbx_recyclejob:client:target:dropPackage` - Dropoff a package
- `qbx_recyclejob:client:target:tradeWithNpc` - Trade with NPC

### Server Events
- `qbx_recyclejob:server:packagePickedUp` - Validate and process package pickup
- `qbx_recyclejob:server:packageDelivered` - Process delivery and payment
- `qbx_recyclejob:server:tradeWithNpc` - Process NPC trade

## 🐛 Troubleshooting

### Props not spawning
- Check if player is clocked in (`onDuty = true`)
- Verify model names exist in the game
- Check console for load errors

### Interaction not working
- Ensure you're standing within the interaction zone
- Try increasing zone `size` in config for better interaction range
- Check if `useTarget` matches your setup

### Points not showing
- Verify ZSX_UIV2 resource is running
- Check console for export errors
- Restart the script with `/refresh qbx_recyclejob`

## 📝 Localization

Supported languages in `locales/` directory:
- English (en.json)
- Spanish (es.json)
- French (fr.json)
- German (de.json)
- Portuguese (pt.json)
- Turkish (tr.json)
- And more...

Add custom translations by editing locale files.

## 🚀 Performance

- **Client-optimized** - Props managed locally per player
- **Automatic cleanup** - Entities deleted on clock out
- **Minimal network usage** - Server-side validation only
- **No global scanning** - Distance-based interactions only

## 📄 License

Open source - feel free to modify and use in your server.

## 🤝 Support

This is an open-source resource. Modify as needed for your server.

---

**Made for QBX Core** | Version 0.1
