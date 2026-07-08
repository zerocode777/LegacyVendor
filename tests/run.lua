-- Bare test runner: no external deps.
local tests = {}
local T = { test = function(name, fn) tests[#tests + 1] = { name = name, fn = fn } end }

local function eq(a, b, msg)
  if a ~= b then error((msg or "assert eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
T.eq = eq

-- Shared addon table + stub loader available to test files.
local makeArgs = dofile("tests/wow_stub.lua")
local addon = {}
_G.__LV_ADDON = addon
_G.__LV_ARGS = function() return makeArgs(addon) end
_G.__LV_TEST = T

dofile("tests/test_filters.lua")

local failed = 0
for _, t in ipairs(tests) do
  local ok, err = pcall(t.fn)
  if ok then print("PASS " .. t.name) else failed = failed + 1; print("FAIL " .. t.name .. "\n  " .. tostring(err)) end
end
print(("%d test(s), %d failed"):format(#tests, failed))
os.exit(failed == 0 and 0 or 1)
