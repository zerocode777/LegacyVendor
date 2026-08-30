# Legacy Vendor

**Clear years of old-expansion clutter out of your bags, without selling anything you meant to keep.**

You farm old raids, delves, transmog, achievements. Your bags fill with Wrath gear you'll never wear, MoP food you forgot about, and crafting leftovers from three expansions ago. Legacy Vendor sells that — and only that — when you're standing at a vendor.

It is **not** a junk seller. Scrap and Dejunk already do greys perfectly well, and Legacy Vendor works happily alongside them. This is for the pile of *old but not worthless* things they leave behind.

---

## Set it up in about thirty seconds

Type `/lv setup` and answer three questions:

1. **Which expansions do you want to clear out?**
2. **What kinds of items?** — Gear only / Gear + old consumables / Everything
3. **How careful should it be?** — Very careful / Balanced / Aggressive

The number of matching items in your bags updates live under every question, so you can see the effect of a choice while you're making it. Nothing is saved until you press Finish, and Cancel puts everything back exactly as it was.

Prefer to do it by hand? The full panel walks you through the same decisions one step at a time, revealing the next question as you answer the last, and branching on your answers — picking "Gear" is what makes the gear-slot list appear.

---

## It tells you what it's going to do

The thing that makes bag cleanup stressful is not knowing what a setting will actually sell. So Legacy Vendor answers that everywhere:

- **A plain-English sentence** at the top of the settings, rewritten as you click:
  *Selling Rare, Epic items from Burning Crusade that are Soulbound, but never from Professions.*
- **A live count from your real bags:** *23 items would sell right now (about 612g).*
- **Everything that's protected**, listed right beside it — so the sentence is never mistaken for the whole story.
- **On the item itself.** Hover anything in your bags:
  *Legacy Vendor: will sell (2g 40s)*
  *Legacy Vendor: keeping — uncollected appearance*
  *Legacy Vendor: keeping — Shadowlands is not selected*
- **In your bags.** Matching items are highlighted while a vendor is open, in one of ten styles and any colour you like. If some matches are scrolled out of view, a button jumps you to each one.

---

## Safety

These run **before** every filter and override all of them. They're listed at the top of the filter flow so you always know they're on.

- **Uncollected appearances, mounts, toys and pets are never sold.** Appearances only count when your character could actually learn them, so this doesn't quietly stop the addon selling other armour types.
- **An item level ceiling.** Never sell gear at or above a level you choose. This one doesn't care which expansion an item is from or where it came from — it just asks how good the item is, which makes it the most dependable guard of the lot.
- **Current-season Mythic+ gear is hard-protected.** Legacy dungeons in the current rotation drop current-tier loot wearing an old expansion's label; that gear is never sold.
- **Warbound items are their own category, off by default.** They're shared by every character on your account, so selling one from here removes it for all of them.
- **A never-sell list you can actually see.** Drag an item onto it to protect it, review it any time, remove things individually.
- **Manual by default.** A Sell button appears at the vendor; nothing happens until you click it. Optional confirmation on top of that.
- **Nothing sells that you didn't enable.** Crafting materials and quest items stay off until you deliberately turn them on.

---

## Filtering, when you want the detail

Every filter below narrows the same rule, and the sentence at the top shows the combined result.

- **Expansions** — Classic through Midnight, or "sell everything from these expansions" for a fast pass
- **Rarity** — Poor through Legendary
- **Bind type** — Soulbound, Bind on Equip, Not Bound, Warbound
- **Gear slots** — every equipment slot, with the character sheet's own icons
- **Item types** — bags, quest items, keys, gems, reagents, trade goods, recipes, misc
- **Sources to never sell from** — consumables, dungeons, raids, world, professions, vendors, PvP, reputation, housing/delves
- **Only sell lower item level than equipped** — optional
- **Per-expansion overrides** — keep one expansion broad and another strict, under Advanced

All / None buttons on every large group, and three one-click presets: **Conservative**, **Everything old**, **Transmog-safe**.

---

## Profiles and sharing

- **Named profiles.** Save a setup, switch between them, and star one to load automatically on a given character — a leveling alt and a transmog main want different rules.
- **Share your setup as a string.** Export it for a friend or a guide, import theirs, or keep one as a backup before experimenting. An imported config can only ever *tighten* your protections, never switch them off.

## Track what you've cleared

`/lv stats` shows how much gold you've reclaimed and from which expansions:

```
Reclaimed 4,182g from 118 old item(s).
   WotLK      1,904g  (41 items)
   Cata         887g  (26 items)
   MoP          612g  (19 items)
```

---

## Slash commands

| Command | What it does |
|---|---|
| `/lv setup` | Guided setup — three questions instead of forty options |
| `/lv config` | Open the settings panel |
| `/lv scan` | Preview what would be sold |
| `/lv sell` | Sell matching items (at a vendor) |
| `/lv protected` | Manage the never-sell list |
| `/lv exclude` | Protect the item you're hovering |
| `/lv profiles` | Save and switch between named setups |
| `/lv export` / `/lv import` | Share your filter setup as a string |
| `/lv stats` | Gold reclaimed, by expansion |
| `/lv find` | Scroll your bags to the next matching item |
| `/lv highlight` | Toggle bag highlighting |
| `/lv strict` | Toggle current-season protection |
| `/lv auto` | Toggle auto-sell |
| `/lv toggle` | Enable or disable the addon |
| `/lv minimap` / `/lv resetbutton` | Minimap button |
| `/lv debug` / `/lv exportlog` | Record a diagnostic log and open it to copy |
| `/lv reset` | Reset all settings |

---

## Supported versions

Retail (The War Within / Midnight) · Mists of Pandaria Classic · Burning Crusade Classic Anniversary · Classic Era / Season of Discovery

---

## Reporting a problem

Turn on Debug mode in the settings, reproduce the issue, then `/lv exportlog` and copy the text into a comment. That log says exactly which rule made the decision for every item in your bags, which usually pins the cause immediately.
