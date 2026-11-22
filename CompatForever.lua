-- Loaded only by LegacyVendor_Forever.toc, before Compat.lua.
--
-- WoW: Forever runs the Mainline (Midnight) client and API, but reports interface
-- 16001 from GetBuildInfo(). Compat.lua would read that as Classic Era, so the
-- Forever TOC sets this flag first and Compat.lua branches on it explicitly.
local _, addon = ...
addon.isForever = true
