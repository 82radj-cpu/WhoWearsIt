local _, ns = ...
if GetLocale() ~= "esES" then return end

-- 0.1: esES reuses the esMX text (esMX.lua already ran for esES clients).
-- Put Spain-specific overrides here, for example:
-- ns.L["Search"] = "Buscar"
local overrides = {}
for k, v in pairs(overrides) do ns.L[k] = v end
