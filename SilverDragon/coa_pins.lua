-- CoA standalone historical rare pins (no HandyNotes dependency).
local core = SilverDragon
local pins, miniPins = {}, {}
local texture = 'Interface\\Icons\\INV_Misc_Head_Dragon_01'
local function tip(frame, name, zone)
    GameTooltip:SetOwner(frame, 'ANCHOR_RIGHT')
    GameTooltip:AddLine(name, 1, .82, .2)
    GameTooltip:AddLine('Known spawn / recorded sighting', .8, .8, .8)
    local count, level, elite, kind, last, sightings = core:GetMob(zone, name)
    GameTooltip:AddDoubleLine('Level', tostring(level or '?') .. (elite and '+' or ''))
    GameTooltip:AddDoubleLine('Last seen', core:FormatLastSeen(last))
    GameTooltip:AddDoubleLine('Sightings', tostring(sightings or 0))
    GameTooltip:Show()
end
local function create(parent, size)
    local f = CreateFrame('Frame', nil, parent)
    f:SetWidth(size); f:SetHeight(size)
    f.tex = f:CreateTexture(nil, 'OVERLAY'); f.tex:SetAllPoints(f); f.tex:SetTexture(texture)
    f:EnableMouse(true)
    f:SetScript('OnEnter', function(self) tip(self, self.rareName, self.rareZone) end)
    f:SetScript('OnLeave', function() GameTooltip:Hide() end)
    return f
end
local function hideAll(t) for _, f in ipairs(t) do f:Hide() end end
local function mapZone()
    local c,z = GetCurrentMapContinent(), GetCurrentMapZone()
    return core.continent_list[c] and core.continent_list[c][z]
end
local function refresh()
    hideAll(pins); hideAll(miniPins)
    local db = core.db
    if not db or not db.profile then return end
    local zone = mapZone()
    if db.profile.coa_worldpins and WorldMapFrame and WorldMapFrame:IsVisible() and WorldMapButton and zone then
        local idx = 0
        for name in pairs(db.global.mobs_byzone[zone] or {}) do
            for _, coord in ipairs(db.global.mob_locations[name] or {}) do
                if idx >= 250 then break end
                local x,y = core:GetXY(coord)
                if x > 0 and x < 1 and y > 0 and y < 1 then
                    idx = idx + 1
                    local f = pins[idx]
                    if not f then f = create(WorldMapButton, 14); pins[idx] = f end
                    f.rareName = name; f.rareZone = zone
                    f:ClearAllPoints(); f:SetPoint('CENTER', WorldMapButton, 'TOPLEFT', x * WorldMapButton:GetWidth(), -y * WorldMapButton:GetHeight())
                    f:Show()
                end
            end
        end
    end
    -- Minimap coordinates require the map projection and zoom radius. Do not
    -- approximate with zone percentages: that produces misleading positions.
    -- HandyNotes, if installed, supplies the accurate minimap projection.
end
local ticker = CreateFrame('Frame')
local elapsed = 0
ticker:SetScript('OnUpdate', function(_, dt)
    elapsed = elapsed + dt
    if elapsed >= 1.5 then elapsed = 0; refresh() end
end)
core.RefreshCoAPins = refresh
