# Changelog

All notable changes to Legacy Vendor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-08-30

The settings panel is rebuilt, selling is safer, and the addon can now explain
itself. Everything below is new unless marked otherwise.

### Added

**Protection**
- A plain item-level ceiling: never sell gear at or above a level you choose
  (default 620). Unlike the Mythic+ guard, this does not depend on identifying an
  item's expansion or its source - it only asks how good the item is - which makes it
  a dependable backstop when the game reports nothing useful about where something
  came from. It reads the item's effective level, so legacy gear scaled up by
  current-season bonuses is judged at its real strength.
- Uncollected appearances, mounts, toys and caged pets are never sold. Appearances
  are only protected when your character could actually learn them, so this does not
  quietly stop the addon selling other armour types.
- Warbound (account-bound) items are now their own category with their own toggle,
  off by default. They were previously treated as unbound.
- A visible never-sell list (`/lv protected`). Items can be added by dragging them
  onto the window, removed individually, and inspected by hovering. Previously this
  list could only be added to from chat, and never reviewed.

**Understanding what will sell**
- Item tooltips now say whether an item will sell, and if not, why: "keeping -
  Shadowlands is not selected", "keeping - uncollected appearance".
- The settings panel shows a live plain-English sentence describing exactly what will
  sell, updating as you click: *Selling Rare, Epic items from Burning Crusade that
  are Soulbound, but never from Professions.*
- Under it, a live count from your actual bags: "23 items would sell right now
  (about 612g)", and a line naming everything that is protected regardless of your
  filters, so the sentence above is never mistaken for the whole story.
- The filter flow now opens with an "Always protected" summary listing the guards
  that run before any filter, because they override every choice made below them.
- The Sell button count updates as your bags change, instead of only when reopening
  the vendor.
- When matching items sit outside the visible part of your bag window, a button
  beside Sell jumps to each one (`/lv find`).

**Setting it up**
- Guided setup (`/lv setup`): three questions instead of forty options, with a live
  preview of what each answer would sell.
- The filter panel is now a step-by-step flow that reveals one question at a time and
  branches on your answers - choosing "Gear" is what shows the gear slot list.
- One-click presets: Conservative, Everything old, Transmog-safe.
- All / None buttons on every large filter group.
- Filter groups are icon and colour chips instead of checkbox columns. Rarity chips
  carry the real quality colour, gear slots use the character sheet's own art.
- Named profiles (`/lv profiles`) that can be saved, switched, and starred to load
  automatically on a given character.
- Filter setups can be exported and imported as a string (`/lv export`, `/lv import`)
  to share a configuration or keep a backup.

**Tracking**
- Lifetime totals (`/lv stats`): how much gold you have reclaimed and how many items,
  broken down per expansion.

**Appearance**
- Ten bag highlight styles to choose from, with a live preview, plus a colour picker.

### Changed
- Debug mode no longer prints to chat. It records to a log you can open and copy from
  (`/lv exportlog`).
- General settings are grouped into Selling mode, Safety, Behaviour, Appearance and
  Troubleshooting, and options are named for what they do rather than what they are
  called internally.
- Chat output during a sale is reduced to a single summary line.

### Fixed
- Current-season gear from refreshed dungeons (for example Kings' Rest and Temple of
  Sethraliss) could be sold even with Mythic+ protection enabled. Protection depended
  on being able to identify an item's source, and for most items the game reports no
  source at all - so the item-level checks that catch scaled legacy gear never ran.
  Those checks no longer depend on source detection, which also means future seasonal
  rotations are handled without waiting for an addon update.
- The item level thresholds behind Mythic+ protection were left on the pre-squish
  scale, where current gear sat in the hundreds. Nothing could reach them any more, so
  every item-level check silently never fired. They are now set against the current
  scale.
- Mythic+ protection was also being bypassed entirely whenever "Sell everything from
  those expansions" was active with the current expansion ticked - which is the
  default mode, so for many setups the option did nothing at all while appearing to
  be on. It is now an unconditional hard stop, as its description always claimed.

### Notes
- Existing settings are carried over. Nothing new sells without you enabling it, and
  the two protection options default to on.

## [2.3.0] - 2026-08-27

### Added
- Bag highlight style picker in Settings, with 10 options: Pulsing Glow (default), Marching Ants
  (Classic), Solid Border, Flash Pulse, Full Icon Wash, Soft Corners, Corner Brackets, Double
  Ring, Spinning Accent, and Dashed Border. A live-animated preview swatch next to the dropdown
  shows exactly what the selected style looks like before committing to it.
- Highlight color picker next to the style dropdown - a clickable swatch opens the standard color
  picker (works on both the modern retail API and the older Classic one) and updates the preview
  and any currently-highlighted bag items live.

### Fixed
- Declared `## Interface` versions in every .toc were stale, which could make the client flag
  LegacyVendor as out of date depending on client settings. Updated to match current live patches:
  Retail 12.1.0 (120100, verified against the installed client's own build info), Classic Era
  1.15.9 (11509), TBC Classic Anniversary 2.5.6 (20506, the Phase 3 client patch), and Mists of
  Pandaria Classic 5.5.4 (50504). This is metadata only - `Compat.lua` already detects the actual
  running client version at runtime via `GetBuildInfo()`, so expansion-detection logic itself was
  never affected.

### Changed
- Redesigned the bag highlight: the rotating orange "marching ants" border is replaced with a
  slow, smooth-pulsing light purple glow frame (a soft outer wash plus a crisp thin border on
  each edge). Same detection/sell logic, just a calmer, more modern look. Existing saves still on
  the old red default are migrated to the new color automatically; anyone with a genuinely
  customized color keeps it.

## [2.2.5] - 2026-08-26

### Fixed
- Opening bags or the vendor could freeze the client for several seconds once bag highlighting
  actually had items to highlight. The button-finding fallback did two whole-UI scans (every
  frame in the game, every global variable) and was redoing both from scratch for every single
  sellable item, on every highlight retry - up to hundreds of full UI walks per vendor visit.
- Added a scoped scan of EllesmereUI's own bag window (its frame tree only, not the whole UI) so
  its item buttons are found directly, the same way ElvUI's already were - the expensive whole-UI
  fallback is no longer reached at all during normal use with EllesmereUI installed. Also fixed a
  gap where, even after finding an addon's own button pool, the code could still fall through to
  the expensive scan if nothing in that pool happened to be sellable in a given pass.

## [2.2.4] - 2026-08-26

### Fixed
- The 2.2.3 fix only isolated the final ApplyHighlight step; the same unrelated-addon crash
  (Blizzard_BuffFrame.lua indexing a nil `buttonInfo`, from another addon's hook) was still
  hitting earlier, inside the button-finding scan itself - specifically while walking every
  frame in the UI looking for the right bag slot's button, which inevitably touches other
  addons' buttons (buff icons, etc.). That walk now isolates each candidate frame it inspects,
  so one unrelated addon's broken hook only skips that one frame instead of failing the whole
  search for that bag slot.

## [2.2.3] - 2026-08-26

### Fixed
- Bag highlighting could still silently apply to zero items in a pass: an unrelated addon
  crashing inside Blizzard's own BuffFrame code (seen triggered by another UI's aura/skin hooks
  reacting to a shared texture's SetVertexColor call) was propagating up through the highlight
  scan's single outer guard and aborting the entire batch, even though it wasn't caused by
  LegacyVendor. Each item's highlight is now applied in its own isolated try, so one unrelated
  crash only skips that one item instead of cancelling the whole pass (which retries every 0.25s
  anyway while the vendor is open).

## [2.2.2] - 2026-08-26

### Fixed
- Bag item highlighting could silently fail to appear entirely (not just with EllesmereUI - any
  setup exercising this code path) whenever an item actually qualified to sell. The button-finding
  scan crashed on a Blizzard API whose iterator now returns `(index, frame)` pairs instead of a
  bare frame; the scan only captured one loop variable, bound it to the index number, then errored
  indexing it - aborting the whole highlight pass before any item got marked. Fixed the iterator
  usage and wrapped the scan in a guard so a future API surprise degrades to "no highlight" instead
  of silently killing the pass.

### Added
- `/lv exportlog` opens a copyable text window with the full debug log (Ctrl+A, Ctrl+C), plus a
  Clear Log button. Debug Mode no longer prints to the chat frame - it buffers into this window
  instead, so a report can be pasted as plain text rather than cropped screenshots.

## [2.2.1] - 2026-08-26

### Fixed
- Bag item highlighting now works with EllesmereUI (EllesmereUIBags) installed. Its bag buttons
  use the retail "ItemButton" widget type, which the bag-scanning fallback didn't recognize
  (it only matched "Button"/"CheckButton"), so highlights silently never appeared.

## [2.2.0] - 2026-07-08

### Changed
- Simplified filtering: one clear choice — "Sell everything from enabled expansions" or
  "Only sell items matching my filters". No more hidden meta/detailed modes.
- Filters (rarity, source, slot, type, bind) are now one global set applied to every enabled
  expansion. Per-expansion tuning moved to an optional "Advanced" section (off by default).
- The settings panel now shows a plain-English summary of exactly what will sell, plus a detail
  line, and greys out filters that aren't in effect.

### Fixed
- Source filtering now works as expected. Ticking a source under "Don't sell from these sources"
  (e.g. Consumables) reliably stops those items from selling — previously the toggle could do
  nothing. Fixes the reported inability to stop selling PvP potions / consumables.

### Notes
- Your existing settings are migrated automatically; nothing new will sell without you seeing it
  in the summary. Use /lv reset to start fresh.
- If you previously used source filtering, upgrading may conservatively skip a rarely-used source
  (it only ever sells less, never more) — glance at the summary's "(skipping …)" note and re-enable
  anything you want by unticking it under "Don't sell from these sources".

## [2.1.0] - 2026-04-30

### Added
- Complete per-option in-game tooltip guidance for the custom config window:
  - Every checkbox now has explicit hover help text
  - Tooltip titles now include scope tags (`[Global]` or `[Per-Expansion]`)
  - Tooltips include an always-visible filter evaluation order so users can understand precedence without guessing
- Animated bag preview highlighting for sellable items while a merchant window is open:
  - Automatic refresh on merchant open
  - Automatic refresh on bag updates while merchant is open
  - Automatic clear on merchant close
- New visual "cut-here" style highlight language for sellable bag items:
  - Marching rectangular border dots (clockwise loop animation)
  - High-visibility tint/fill to improve discoverability
  - Slimmer ant size refinement for better readability at real bag scale

### Changed
- Major filter behavior clarification and precedence consistency improvements:
  - Source filtering now participates correctly in expansion meta flow so unchecked sources are not accidentally sold through meta short-circuiting
  - Expansion meta behavior and detailed profile behavior are now explained directly in UI copy to reduce ambiguity
- Configuration UI readability overhaul (large quality-of-life pass):
  - Improved section hierarchy and spacing
  - Better grouping and clearer labels around expansion profile editing
  - Scope-aware phrasing to distinguish global toggles from per-expansion profile toggles
- Expansion profile UX refinements:
  - Profile editor language now explicitly communicates what overrides what
  - Option text updated to reduce interpretation errors around "sell all" vs nested filtering

### Fixed
- Fixed critical load-order regression where profile default construction was referenced before function definition, which prevented full addon initialization (slash commands, minimap button, and merchant button could fail to appear)
- Fixed custom settings window anchor behavior in modern clients where frame inset assumptions could cause content to render outside the window bounds
- Fixed source precedence confusion in edge paths that caused users to see items sold despite source filters being disabled
- Fixed consumable filter duplication confusion by removing redundant consumable control from non-equippable type paths and keeping consumables under source filtering where they belong
- Fixed bag highlight system reliability in modern container UIs by replacing brittle frame-name assumptions with safer bag/slot mapping and container enumeration fallbacks

### Notes
- This release focuses on two themes: filter predictability and visual trust.
- If an item is highlighted, it is expected to be sell-candidate under current settings and merchant context.
- If an item is not highlighted while merchant is open, it is expected to be protected by at least one active filter gate.
- A follow-up pass is planned for deeper offhand-slot debugging based on live user reports.

## [2.0.0] - 2026-04-30

### Fixed
- Fixed consumables being grouped into broader source paths by introducing a dedicated source bucket for food, oils, flasks, and potions
- Strict seasonal M+ guard now only targets dungeon/raid gear logic and no longer overrides consumables
- Sell button count now updates live while merchant is open when bags change (manual sells, buys, loot changes)

### Added
- New item source category: Consumables (Food, Potions, Oils)
- New expansion meta mode: checked expansions can sell all items in that expansion bucket
- In expansion meta mode, current-season M+ legacy dungeon gear is mapped to current expansion filtering
- New slash command: /lv meta
- New per-expansion profile engine with nested filters:
  - Bind type filters per expansion
  - Item source filters per expansion
  - Rarity filters per expansion
  - Equipment slot filters per expansion
  - Item type filters per expansion
  - Per-expansion "only sell lower item level" toggle
- New in-game expansion profile editor in the LegacyVendor config frame
- New always-visible expansion sell-state summary in config (SELL ALL / DETAIL / GLOBAL / KEEP)

### Changed
- LegacyVendor config now always opens the in-game frame to expose the full expansion profile editor

## [1.4.3] - 2026-04-02

### Fixed
- Seasonal M+ dungeon protection completely reworked (1.4.2 single-threshold approach was insufficient)
  - **New primary check: instance table** — items are cross-referenced against a maintained list of Encounter Journal instance IDs for legacy dungeons in the current M+ rotation (Pit of Saron, Skyreach confirmed for TWW Season 3). Works for WoD and Legion where pre-squish ilvl peaks make ilvl comparison unreliable
  - **New secondary check: per-expansion ilvl ceiling** — replaces the broken single global threshold (554) with historically accurate per-expansion maximums; reliably catches scaled-up items from Classic through MoP and post-squish BFA/SL/DF 
  - Enable debug mode (`/lv debug`) to see `Item source instanceID:` output and help identify seasonal dungeons not yet in the table
- Unrecognized non-equippable item types now default to protected (skip, do not sell) instead of potentially passing through filters depending on other settings

### Added
- **Crafting & Profession Items** — new dedicated section in the addon settings
  - Gems (item classID 3) now tracked and protected by default (was missing from filters entirely and could slip through)
  - Reagents, Trade Goods (Vellums), and Recipes grouped under a clear "Crafting & Profession Items" header in the UI with an explicit "never sell by default" note

## [1.4.2] - 2026-03-23

### Fixed
- Items from refreshed M+ dungeons (Skyreach, Pit of Saron, etc.) are no longer auto-sold
  - Old expansion dungeons in the seasonal M+ rotation drop current-ilvl gear
  - Addon now detects items with legacy expansion IDs but current-content item levels (554+) and protects them from being sold

## [1.4.1] - 2026-03-04

### Changed
- Reduced chat spam when selling items — per-item messages ("Attempting to sell...", "Sold successfully!") now only show when debug mode is enabled
  - Previously each item sold generated 3 chat messages; now only the final summary is shown
  - Enable debug mode with `/lv debug` if you want verbose per-item output

## [1.4.0] - 2026-03-01

### Added
- **Item Source Filtering**: New filter category to sell items based on where they came from
  - Dungeons, Raids, Outdoor/World, Professions, Vendors, PvP, Reputation, Housing/Delves, Unknown
  - "Enable Source Filtering" master toggle to activate/deactivate source filtering
  - All sources disabled by default for safety
  - Uses C_ItemSourceInfo API on Retail with tooltip-based fallback for Classic

### Fixed
- Fixed minimap button moving to center of screen when FarmHud or similar minimap-replacing addons are active
  - Button now properly parents to Minimap frame when in attached mode, so it follows the minimap
  - Freeform mode still parents to UIParent for free placement anywhere on screen

## [1.3.1] - 2026-02-28

### Fixed
- Fixed `/lv exclude` command doing nothing — `GameTooltip:GetItem()` returns `name, link` but only the first value (name) was being captured, causing the item ID match to silently fail with no output

## [1.3.0] - 2026-02-27

### Changed
- Midnight expansion items can now be sold like any other expansion (no longer force-protected)
- All expansion filters are now user-controlled with no hardcoded restrictions

### Removed
- Removed "current expansion" protection system - users can now choose to sell items from any expansion

## [1.2.9] - 2026-02-27

### Changed
- Midnight is now live - updated Retail TOC description accordingly

## [1.2.8] - 2026-02-25

### Changed
- Updated Retail interface version to 120001 (Patch 12.0.1 - Midnight)
- Updated Classic Era interface version to 11508 (Patch 1.15.8)
- Updated TBC Anniversary interface version to 20505 (Patch 2.5.5)
- Updated MoP Classic interface version to 50503 (Patch 5.5.3)

### Removed
- Removed Cata Classic TOC (Cata Classic no longer exists)

## [1.2.7] - 2026-02-06

### Added
- **Only Sell Lower Item Level filter** - New toggle that only sells equippable items whose item level is lower than the currently equipped item in the same slot. Non-equippable items are unaffected. Disabled by default.

## [1.2.6] - 2026-02-04

### Fixed
- Fixed Sell button count not reflecting actual items found (button now updates immediately after scanning)

## [1.2.5] - 2026-02-03

### Fixed
- Fixed infinite loop crash in minimap shape detection (caused "script ran too long" error)
- Fixed `/lv minimap` command error when button settings weren't initialized

## [1.2.4] - 2026-02-03

### Added
- **Freeform minimap button positioning** - Shift+Drag the button to place it anywhere on screen
- Works with all minimap addons regardless of shape (square, circular, resized)
- New `/lv resetbutton` command to reset button back to default minimap-attached position
- Button now shows current position mode in tooltip (Freeform or Minimap-attached)

### Changed
- Minimap button is now clamped to screen to prevent it from going off-screen

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
