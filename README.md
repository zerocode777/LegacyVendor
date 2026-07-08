# Legacy Vendor

**Automatically sell Bind on Pickup items from legacy expansions when visiting a vendor.**

![Version](https://img.shields.io/badge/version-2.2.0-blue)
![WoW Version](https://img.shields.io/badge/WoW-Retail%20%7C%20Classic%20%7C%20Cataclysm-green)
![License](https://img.shields.io/badge/license-MIT-green)

## Description

Legacy Vendor helps you keep your bags clean by automatically identifying and selling Bind on Pickup items from previous expansions. Perfect for players who run old content for transmog, mounts, or achievements and end up with bags full of outdated gear.

## Features

- 🎯 **Smart Detection**: Identifies BoP items from legacy expansions
- 🛡️ **Current Expansion Protection**: Never sells items from the current expansion
- 🔒 **Strict Seasonal M+ Protection**: Hard-blocks current-season scaled items from legacy dungeons before any other sell filter runs
- ⚙️ **Granular Filters**: Filter by expansion, rarity, equipment slot, and item type
- 🔘 **Manual or Auto Mode**: Choose between button-click selling or automatic
- 🗺️ **Minimap Button**: Quick access to settings
- 💰 **Sale Summary**: See how much gold you earned
- ✅ **Safe Defaults**: Nothing sells until you configure your preferences

## Supported WoW Versions

| Version | Status |
|---------|--------|
| Retail (Midnight 12.0) | ✅ Supported |
| Retail (The War Within 11.0) | ✅ Supported |
| Cataclysm Classic | ✅ Supported |
| Classic Era / Season of Discovery | ✅ Supported |
| Hardcore | ✅ Supported |

## Installation

1. Download the latest release
2. Extract the `LegacyVendor` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory
   - For Classic: `World of Warcraft\_classic_\Interface\AddOns\`
   - For Classic Era: `World of Warcraft\_classic_era_\Interface\AddOns\`
3. Restart World of Warcraft
4. Enable the addon in the addon list

## Usage

### Getting Started

1. Open the configuration with `/lv config` or click the minimap button
2. Select which **expansions** you want to sell items from
3. Configure **rarity**, **equipment slots**, and **item type** filters
4. Visit any vendor - a **"Sell Legacy"** button will appear
5. Click the button to sell matching items

### Slash Commands

| Command | Description |
|---------|-------------|
| `/lv` or `/lv help` | Show all commands |
| `/lv config` | Open configuration panel |
| `/lv toggle` | Enable/disable addon |
| `/lv auto` | Toggle auto-sell mode |
| `/lv scan` | Preview items that would be sold |
| `/lv sell` | Manually sell at vendor |
| `/lv exclude` | Exclude hovered item |
| `/lv expansions` | List expansion settings |
| `/lv minimap` | Toggle minimap button |
| `/lv reset` | Reset to defaults |
| `/lv debug` | Toggle debug messages |
| `/lv strict` | Toggle strict seasonal M+ protection |

### Filter Logic

First, choose your **sell mode** — one of two options:

- **Sell everything from enabled expansions** — every BoP item from a checked expansion is sold. No further filter evaluation.
- **Only sell items matching my filters** — items must also pass the global filter set (rarity, source, slot, type, bind) before selling.

When in "matching" mode, all active filters work as an **intersection (AND)**. An item must match ALL enabled criteria:

```
✅ Expansion is enabled (e.g., WotLK)
AND ✅ Sell mode is "Only sell items matching my filters"
AND ✅ Rarity is enabled (e.g., Epic)
AND ✅ Equipment slot is enabled (e.g., Head) OR Item type is enabled
AND ✅ Item's source is NOT in the skip list (see below)
AND ✅ Item is Bind on Pickup
AND ✅ Item is not manually excluded
= 💰 Item will be sold
```

**Source skip list ("Don't sell from these sources"):** tick a source (e.g. Consumables) to *stop* selling items from that source. Unticked sources are allowed. This replaces the old master source toggle that could fail silently.

The settings panel shows a plain-English summary of exactly what will sell and greys out filters that aren't currently in effect.

**Advanced per-expansion overrides** are available via a collapsible "Advanced" section (off by default). When expanded, each enabled expansion can have its own filter set instead of using the global one.

## Configuration Options

### General Settings
- **Enable LegacyVendor** - Master toggle
- **Auto-Sell Mode** - Sell automatically when opening vendor (off by default)
- **Strict Seasonal M+ Protection** - Hard-protect current-season scaled legacy dungeon items (on by default)
- **Show Sale Summary** - Display gold earned after selling
- **Confirm Before Selling** - Show confirmation dialog
- **Also Sell Gray Items** - Sell all gray items regardless of filters

### Sell Mode
- **Sell everything from enabled expansions** - All BoP items from checked expansions are sold; no filters applied.
- **Only sell items matching my filters** - Items must pass the global filter set (rarity, source, slot, type, bind) to be sold.

### Expansion Filters
Select which expansions to sell items from:
- Classic (Vanilla)
- The Burning Crusade
- Wrath of the Lich King
- Cataclysm
- Mists of Pandaria
- Warlords of Draenor
- Legion
- Battle for Azeroth
- Shadowlands
- Dragonflight
- The War Within
- Midnight (Protected - cannot enable)

### Global Filter Set (active when sell mode is "matching")

#### Rarity Filters
- Poor (Gray) ✅
- Common (White)
- Uncommon (Green) ✅
- Rare (Blue) ✅
- Epic (Purple) ✅
- Legendary (Protected)
- Artifact (Protected)
- Heirloom (Protected)

#### Equipment Slot Filters
All armor and weapon slots can be individually toggled.

#### Non-Equippable Item Filters
- Consumables
- Containers (Bags)
- Reagents
- Trade Goods
- Recipes
- Quest Items
- Keys
- Miscellaneous

#### Don't Sell From These Sources (skip list)
Tick any source to exclude it from selling. Unticked sources are allowed. Sources include: Dungeons, Raids, Outdoor/World, Professions, Vendors, PvP, Reputation, Consumables, and Unknown.

### Advanced Per-Expansion Overrides
Expand the "Advanced" collapsible in the settings panel to configure a separate filter set for individual expansions, overriding the global set for that expansion only. Hidden by default.

## API Compatibility

This addon uses modern WoW APIs with fallbacks for Classic:
- `C_Container` API with legacy `GetContainerItemInfo` fallback
- `C_Item` API with compatibility wrappers
- `Settings` API with custom frame fallback for Classic
- `C_Timer` with frame-based fallback

## FAQ

**Q: Will this sell my current expansion gear?**
A: No! The current expansion is always protected and cannot be enabled.

**Q: Can strict seasonal protection ignore my other filters?**
A: Yes. When enabled, strict protection runs first and always keeps current-season scaled legacy dungeon items, even if other filters would normally sell them.

**Q: Can I recover items I accidentally sold?**
A: Yes, use the Buyback tab at any vendor within the same session.

**Q: Why is there a button instead of auto-selling?**
A: Blizzard's API restrictions require user interaction for some actions. The button ensures compatibility.

**Q: Does this work in Classic?**
A: Yes! The addon detects your WoW version and adjusts accordingly.

## Support

- **Issues**: Report bugs on GitHub or CurseForge
- **Feature Requests**: Open an issue with the "enhancement" label

## License

This addon is released under the MIT License. See LICENSE file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
