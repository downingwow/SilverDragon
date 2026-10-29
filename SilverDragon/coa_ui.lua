-- Optional ElvUI presentation; detection and saved data remain UI-independent.
local function apply()
    if InCombatLockdown() then return end
    local engine = type(ElvUI) == "table" and ElvUI[1]
    local media = type(engine) == "table" and engine.media
    local popup = SilverDragonPopupButton
    if type(media) ~= "table" or not popup then return end
    local normal = popup:GetNormalTexture()
    if normal then normal:SetTexture(nil) end
    popup:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    local color = media.backdropcolor
    if type(color) == "table" then
        popup:SetBackdropColor(color[1] or .1, color[2] or .1, color[3] or .1, .95)
    else
        popup:SetBackdropColor(.1, .1, .1, .95)
    end
    popup.details:SetTextColor(1, 1, 1)
    popup.subtitle:SetTextColor(.8, .8, .8)
end
local listener = CreateFrame("Frame")
listener:RegisterEvent("PLAYER_LOGIN")
listener:RegisterEvent("ADDON_LOADED")
listener:RegisterEvent("PLAYER_REGEN_ENABLED")
listener:SetScript("OnEvent", apply)
