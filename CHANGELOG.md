# Changelog

All notable changes to Legacy Vendor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
