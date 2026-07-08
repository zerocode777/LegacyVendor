-- Minimal stubs so pure addon modules load outside the WoW client.
-- Only what Filters.lua touches. NOT shipped.
_G.LegacyVendorDB = _G.LegacyVendorDB or nil

local function noop() end
_G.C_Timer = { After = function(_, f) if f then f() end end }
_G.CreateFrame = _G.CreateFrame or function() return setmetatable({}, {__index = function() return noop end}) end

-- Addon namespace vararg emulation: modules are loaded as chunks with (name, addon).
return function(addonTable)
  return "LegacyVendor", addonTable
end
