-- Forever-mode rules: loaded into a separate addon table with the Forever flag set,
-- so the retail tests in test_filters.lua keep their own namespace.
local T = _G.__LV_TEST
local makeArgs = dofile("tests/wow_stub.lua")

local printed = {}
local addon = {
    isForever = true,
    ITEM_SOURCES = { dungeon = {}, housing = {}, pvp = {} },
    Print = function(msg) printed[#printed + 1] = msg end,
}
assert(loadfile("Filters.lua"))(makeArgs(addon))
assert(loadfile("ForeverMode.lua"))(makeArgs(addon))

local function freshDB()
    return {
        sellMode = "everything", expansions = { [0] = false, [5] = true },
        strictSeasonalProtection = true, sellWarbound = false,
        rarities = { [2] = true }, itemSources = {}, expansionProfiles = {},
        sellBoP = true,
    }
end

T.test("forever: effective sell mode is always matching", function()
    T.eq(addon.EffectiveSellMode({ sellMode = "everything" }), "matching")
    T.eq(addon.EffectiveSellMode({}), "matching")
end)

T.test("forever: rules force matching, single tier, no seasonal flag", function()
    local db = freshDB()
    addon.ApplyForeverRules(db)
    T.eq(db.sellMode, "matching")
    T.eq(db.expansions[0], true)
    T.eq(db.expansions[5], nil)
    T.eq(db.strictSeasonalProtection, false)
end)

T.test("forever: first-run defaults apply once and then stick", function()
    local db = freshDB()
    addon.ApplyForeverRules(db)
    T.eq(db.onlySellLowerIlvl, true)
    T.eq(db.protectUncollectedAppearances, true)
    db.onlySellLowerIlvl = false
    addon.ApplyForeverRules(db)
    T.eq(db.onlySellLowerIlvl, false, "user choice must survive a reload")
end)

T.test("forever: housing source removed, tier renamed", function()
    T.eq(addon.ITEM_SOURCES.housing, nil)
    T.eq(addon.ITEM_SOURCES.dungeon ~= nil, true)
    T.eq(addon.EXPANSIONS[0].short, "Forever")
    T.eq(addon.EXPANSIONS[1], nil)
end)

T.test("forever: sentence never mentions expansions", function()
    local db = freshDB()
    addon.ApplyForeverRules(db)
    local sentence = addon.BuildFilterSentence(db)
    T.eq(sentence:find(" from ", 1, true), nil, sentence)
    T.eq(sentence:find("Nothing will sell", 1, true), nil, sentence)
end)

T.test("forever: protection summary omits M+ and Warbound lines", function()
    local db = freshDB()
    db.strictSeasonalProtection = true -- e.g. from an imported retail string
    for _, line in ipairs(addon.BuildProtectionSummary(db)) do
        T.eq(line:find("Mythic", 1, true), nil, line)
        T.eq(line:find("Warbound", 1, true), nil, line)
    end
end)

T.test("forever: expansion slash commands are blocked", function()
    T.eq(addon.ForeverBlocksCommand("meta"), true)
    T.eq(addon.ForeverBlocksCommand("exp 3"), true)
    T.eq(addon.ForeverBlocksCommand("strict"), true)
    T.eq(addon.ForeverBlocksCommand("scan"), false)
    T.eq(#printed, 3)
end)
