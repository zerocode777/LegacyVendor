# Changelog

All notable changes to Legacy Vendor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.3] - 2026-02-03

### Changed
- Minimap button now positioned on the outside edge of the minimap
- Works better with square minimap addons like ClassyMap

## [1.2.2] - 2026-02-03

### Fixed
- **Critical Fix** - Completely disabled bag highlighting feature to restore addon functionality
- Addon now loads correctly on all WoW versions again
- Sell button and minimap button are back

### Removed
- Temporarily removed bag item highlighting (will be re-added in a future update with proper testing)

## [1.2.1] - 2026-02-03

### Fixed
- Fixed addon not loading on Retail due to BackdropTemplate compatibility issue
- Protected event registration for events that may not exist in all WoW versions
- Protected hooksecurefunc calls for bag functions that may not exist in all versions
- Sell button and minimap button now appear correctly again

## [1.2.0] - 2026-02-02

### Added
- **Bag Item Highlighting** - Sellable items now glow red in your bags when enabled
- New `/lv highlight` slash command to toggle highlighting
- Highlight toggle in settings panel
- Automatic highlight refresh when bags change or filters are modified

### Changed
- Improved visual feedback for items that would be sold

## [1.1.4] - 2026-02-02

### Fixed
- Now supports 5 WoW versions: Retail, MoP Classic, Cata Classic, TBC Anniversary, Classic Era

## [1.1.3] - 2026-02-02

### Fixed
- Fixed Retail interface version from 120100 to 120000 for compatibility

## [1.1.2] - 2026-02-02

### Added
- **TBC Anniversary Support** - Added LegacyVendor_TBC.toc for TBC Anniversary servers (Interface 20504)
- **Classic Era Support** - Added LegacyVendor_Vanilla.toc for Classic Era (Interface 11505)

### Changed
- Renamed LegacyVendor_Classic.toc to LegacyVendor_Cata.toc for clarity

## [1.1.1] - 2026-02-02

### Fixed
- Removed invalid filter options:
  - Artifact rarity (cannot be sold)
  - Heirloom rarity (cannot be sold)
  - Robe slot (not a valid equipment slot, use Chest instead)

## [1.1.0] - 2026-02-02

### Added
- **Bind Type Filters** - New filter category to control which binding types to sell:
  - Bind on Pickup (Soulbound) - enabled by default
  - Bind on Equip (Bound) - sell BoE items you've equipped
  - Not Bound (Food, Reagents) - sell unbound items like old food, potions, crafting materials
- Verbose logging when selling to help diagnose issues
- Debug mode now shows detailed bind status for each item

### Changed
- Improved item type filter names for clarity:
  - "Consumables" → "Consumables (Food/Potions)"
  - "Reagents" → "Reagents (Crafting)"
  - "Trade Goods" → "Trade Goods (Materials)"
- Better handling of non-equippable items in filters
- Filter logic now properly checks bind status before other filters

### Fixed
- Button showing item count but not selling - improved sync between scan and sell
- Items being skipped without clear reason - added detailed debug output

## [1.0.0] - 2026-01-31

### Added
- Initial release
- Automatic detection of legacy expansion BoP items
- Expansion filter system (Classic through Midnight)
- Rarity filters (Poor through Heirloom)
- Equipment slot filters (all armor and weapon slots)
- Non-equippable item type filters
- Manual sell mode with merchant frame button
- Optional auto-sell mode
- Minimap button with drag support
- Configuration GUI (Settings API + fallback frame)
- Sale summary with gold earned
- Confirmation dialog option
- Item exclusion system
- Gray item selling option
- Multi-version support (Retail, Cataclysm Classic, Classic Era)
- Slash commands for all features

### Security
- Current expansion items always protected
- Legendary, Artifact, and Heirloom items protected by default
- Manual mode default to comply with Blizzard API restrictions
- Confirmation dialog enabled by default

## [Unreleased]

### Planned
- LibDataBroker support for data broker displays
- Per-character settings option
- Item level range filter
- Profession-specific item handling
- Localization support
