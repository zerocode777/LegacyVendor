# Legacy Vendor — Filter UI Simplification (Design)

**Date:** 2026-07-08
**Status:** Approved for spec review
**Scope:** Simplify the filter configuration model and the "active filters" readout without removing any filtering capability.

---

## 1. Problem

The addon's filtering is powerful but confusing. Users cannot tell what is actually active, and some toggles silently do nothing. A representative user report:

> "How do I filter out pvp potions? They seem to belong to Legion, but disabling/enabling 'consumable' in source filter doesn't do a thing."

### Root cause (from code)

Every detailed filter (source, rarity, slot, type, bind) exists in **two scopes**:

- a **global** set (`db.itemSources`, `db.rarities`, …), and
- a **per-expansion-profile** set (`db.expansionProfiles[i].itemSources`, …).

Which scope drives selling depends on a per-expansion flag, `useDetailedFilters`
([Core.lua:695-697](../../../Core.lua#L695)):

```lua
local activeFilterBySource = (useDetailedFilters and expansionProfile.filterBySource) or db.filterBySource
local activeItemSources    = (useDetailedFilters and expansionProfile.itemSources)    or db.itemSources
```

But the config panel's Source Filter checkboxes **only ever write to the per-profile scope**
([Config.lua:911-922](../../../Config.lua#L911)). In the default state (Meta mode on,
"Use Detailed Filters" off), the seller reads the **global** scope
([Core.lua:724-730](../../../Core.lua#L724)) — so unchecking "Consumable" edits a value the
seller never reads. The checkbox is genuinely inert, exactly as reported.

Secondary problem: nothing on screen communicates scope or mode, so the user cannot see that
the checkbox is inert. The existing one-line summary bar only reports expansions, the
currently-viewed profile's rarities, and a few global flags — it omits sources/slots/types
entirely and is a hand-maintained string that can disagree with the seller.

---

## 2. Goals / Non-goals

**Goals**
- Preserve every existing *filtering capability* (expansion, rarity, source, slot, type, bind, ilvl, grays, M+ protection).
- Eliminate the possibility of a checkbox being silently inert.
- Make "what will sell right now" obvious at a glance.
- Keep power-user per-expansion granularity available, but out of the default path.

**Non-goals**
- No change to the actual sell mechanics at the vendor (button/auto, buyback, M+ seasonal guard logic stay as-is).
- No new filter dimensions.
- No redesign of the minimap button or slash commands (beyond wording that references removed toggles, if any).

---

## 3. New filter model

### 3.1 One top-level mode (replaces two interacting toggles)

Replace the global "Expansion Meta Mode" checkbox **and** the per-expansion "Use Detailed
Filters For This Expansion" checkbox with a single radio at the top of the panel:

> **Sell from enabled expansions:**  ( ) Everything   (•) Only items matching my filters

- **Everything** → tick expansions only; all detailed filter sections **grey out** (visibly inert).
- **Only matching** → detailed filter sections are active.

### 3.2 Expansions = plain checklist

Expansions become a simple "sell from these" checklist. Remove the Prev/Next profile selector
and the inline `[detail]` / `[all]` / `[global]` badges from the default view.

### 3.3 Detailed filters = ONE global set

Rarity / source / slot / type / bind become a single global set applied to all enabled
expansions. This removes the dual-scope trap: there is exactly one place each filter lives,
and it is the place the seller reads.

### 3.4 Advanced door (off by default)

A single collapsible "Advanced: per-expansion overrides", closed by default. Opened, a power
user may override the global set for a specific expansion. The existing `expansionProfiles`
data structure is retained to back this, so the capability and any saved data survive. Crucially,
using an override is now an **explicit, visible** action rather than a hidden mode.

---

## 4. Source-filter semantics (skip-list)

Delete the "Enable Source Filtering" master toggle (the gate that caused the inert checkbox).
In "Only matching" mode, sources are always considered.

Sources use **skip-list (opt-out)** semantics, matching how users describe the problem
("filter *out* pvp potions"):

- Header: **"Don't sell from these sources"**
- All boxes **unchecked** by default (nothing skipped → current behavior preserved).
- Tick **Consumable** to stop selling potions/food/oils. (PvP potions resolve to the
  `consumable` bucket via item class — [Core.lua:417](../../../Core.lua#L417).)

Rarity / slot / type keep **allow-list (opt-in)** semantics:

- "checked = sellable; none checked = all allowed."

The two sections carry explicit headers stating the difference, so behavior is read, not inferred.

---

## 5. Active-filters readout (hybrid)

Replace the top summary bar with a hybrid readout:

```
┌─────────────────────────────────────────────┐
│ ✔ Selling Green/Blue dungeon & raid gear     │
│   from Wrath & Legion.                        │
│ ───────────────────────────────────────────  │
│ Rarity ▸ Green Blue    Source ▸ Dungeon Raid  │
│ Expansions ▸ Wrath Legion   +Grays  M+Prot    │
└─────────────────────────────────────────────┘
```

- Plain-English headline for instant understanding; compact chip rows beneath for detail.
- In "Everything" mode the detail rows **grey out**; the sentence alone carries it
  (e.g. "✔ Selling everything from Wrath & Legion").
- The readout is **derived** from the same resolved values the seller uses
  ([Core.lua:687-697](../../../Core.lua#L687)) — never a hand-maintained string — so it can
  never again claim something is active that the seller ignores.

---

## 6. Migration & backwards compatibility

One-time migration on load (guarded by a `settingsSchemaVersion` bump):

1. Derive the single global detailed set from current global `db.*` values.
2. Preserve any existing per-expansion `expansionProfiles` into the Advanced override buckets.
3. Map the old source scope: existing `db.itemSources` (include-list) is converted to the new
   skip-list representation so no item that sold before starts/stops selling silently.
4. `expansionSellAllMode` maps to the new top-level mode: `true` → "Everything",
   `false` → "Only matching".

Nothing sells differently on upgrade without the change being visible in the readout.
`/lv reset` continues to restore safe defaults (nothing sells until configured).

Signature-safety: per the repo's backwards-compat rule, the resolver in
[Core.lua:684-697](../../../Core.lua#L684) is updated in place (it already reads a single
resolved set), and any removed DB fields are handled by the migration rather than left dangling.

---

## 7. Affected files

- `Config.lua` — rebuild `CreateSimpleConfig` sections: top mode radio, expansion checklist,
  global detailed filters, skip-list source section, Advanced collapsible, hybrid readout
  (`BuildActiveSummary` → derived, richer). Watch the 300-line rule: `Config.lua` is already
  large; extract the readout builder and (if needed) the section builders into a focused helper
  so no single file balloons further.
- `Core.lua` — remove the `filterBySource` master-gate branch; adjust `PassesSourceFilter` to
  skip-list semantics; ensure the resolved-set resolver reflects the single-global + optional
  override model; add migration.
- `CHANGELOG.md` — user-facing entry describing the simplified filters and the source-filter fix.
- `README.md` — update the Configuration/Filter Logic sections to the new model.
- `.toc` version bump if this ships as a release.

---

## 8. Rollout (repo-specific)

- **Copy to live install after changes:** copy shipped files to
  `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\LegacyVendor` every time,
  not just at release, so the change is testable in-game.
- **Changelog:** every user-facing change recorded in `CHANGELOG.md` for CurseForge users.

---

## 9. Risks

- **Migration correctness** is the highest risk: a wrong mapping could change what auto-sells.
  Mitigation: migration is conservative (preserve current sell outcomes), gated by schema
  version, and the readout makes the resulting state visible before the user visits a vendor.
- **Skip-list vs allow-list mix** could confuse if headers are weak. Mitigation: explicit
  section headers and the readout describing the net effect in plain English.
- **Config.lua size**: the rebuild must reduce, not add, complexity; extract helpers.

---

## 10. Testing

- Fresh install: nothing sells until configured; readout shows "nothing".
- Upgrade from 2.1.0 with global filters set: post-migration sell set is identical; readout matches.
- Upgrade with a per-expansion profile set: override preserved under Advanced; behavior identical.
- "Everything" mode: detail sections grey; readout sentence correct.
- Source skip-list: ticking Consumable stops potion/food sales (the reported bug); readout shows the skip.
- Allow-list rarity: empty = all rarities; checked subset = only those.
- `/lv reset` restores safe defaults.
