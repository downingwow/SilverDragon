local BZR = LibStub("LibBabble-Zone-3.0"):GetReverseLookupTable()
local BCT = LibStub("LibBabble-CreatureType-3.0"):GetUnstrictLookupTable()
local BCTR = LibStub("LibBabble-CreatureType-3.0"):GetReverseLookupTable()

local addon = LibStub("AceAddon-3.0"):NewAddon("SilverDragon", "AceEvent-3.0", "AceTimer-3.0")
SilverDragon = addon
addon.events = LibStub("CallbackHandler-1.0"):New(addon)

local debugf = tekDebug and tekDebug:GetFrame("SilverDragon")
local function Debug(...) if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end end
addon.Debug = Debug

local globaldb
function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("SilverDragon2DB", {
		global = {
			mobs_byzone = {
				['*'] = {}, -- zones
			},
			mob_locations = {
				['*'] = {}, -- mob names
			},
			mob_id = {}, -- NPC ids, only available for mobs from wowhead
			mob_type = {},
			mob_level = {},
			mob_elite = {},
			mob_tameable = {},
			coa_history = {}, -- per-zone, per-rare last sighting metadata
			mob_count = {
				['*'] = 0,
			},
		},
		profile = {
			scan = 0.5, -- scan interval, 0 for never
            coa_worldpins = true,
            coa_minimap_notes = true, -- HandyNotes handles accurate minimap projection
            cache_scan_interval = 5, -- cache lookups are costly; separate from nameplates
			delay = 600, -- number of seconds to wait between recording the same mob
			cache_tameable = true, -- whether to alert for tameable mobs found through cache-scanning
			mouseover = true,
			targets = true,
			nameplates = true,
			cache = true,
			combatlog = true,
			instances = true,
			taxi = true,
		},
	})
	globaldb = self.db.global
end

function addon:OnEnable()
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	if self.db.profile.scan > 0 then
		self:ScheduleRepeatingTimer("CheckNearby", self.db.profile.scan)
	end
end

function addon:PLAYER_FOCUS_CHANGED()
	if self.db.profile.targets then self:ProcessUnit("focus", "focus") end
end

function addon:PLAYER_TARGET_CHANGED()
	if self.db.profile.targets then
		self:ProcessUnit('target', 'target')
	end
end

function addon:UPDATE_MOUSEOVER_UNIT()
	if self.db.profile.mouseover then
		self:ProcessUnit('mouseover', 'mouseover')
	end
end

local lastseen = {}
-- CoA: combat-log NPC IDs can be visible before a nameplate enters range.
-- This is evidence of nearby activity, not proof that a rare is still alive.
local function npcIdFromGUID(guid)
    if type(guid) ~= "string" then return nil end
    -- 3.3.5 GUID format: 0xF13000XXXXYYYYYY (creature), 0xF53000XXXXYYYYYY (vehicle)
    if guid:sub(1, 6) ~= "0xF130" and guid:sub(1, 6) ~= "0xF530" then return nil end
    return tonumber(guid:sub(9, 12), 16)
end
function addon:COMBAT_LOG_EVENT_UNFILTERED(_, _, eventType, sourceGUID, sourceName, _, destGUID, destName)
    if not self.db.profile.combatlog then return end
    -- Most combat events do not concern a known rare. Filter by name and ID
    -- before querying map coordinates (which may trigger expensive map changes).
    if not ((sourceName and globaldb.mob_id[sourceName]) or (destName and globaldb.mob_id[destName])) then return end
    local zone, x, y = self:GetPlayerLocation()
    if not zone then return end
    local zoneMobs = globaldb.mobs_byzone[zone]
    if not zoneMobs then return end
    local function consider(guid, name)
        if not name or not zoneMobs[name] then return end
        local id = npcIdFromGUID(guid)
        if not id or globaldb.mob_id[name] ~= id then return end
        if lastseen[name] and time() < lastseen[name] + self.db.profile.delay then return end
        lastseen[name] = time()
        self:SaveMob(zone, name, x, y, nil, false, nil)
        self.events:Fire("Seen", zone, name, x, y, false, true, "combatlog", false, id)
    end
    consider(sourceGUID, sourceName)
    consider(destGUID, destName)
end

function addon:ProcessUnit(unit, source)
	if UnitPlayerControlled(unit) then return end -- helps filter out player-pets
	local unittype = UnitClassification(unit)
	if not (unittype == 'rare' or unittype == 'rareelite') or not UnitIsVisible(unit) then return end
	-- from this point on, it's a rare
	local zone, x, y = self:GetPlayerLocation()
	if not zone then return end -- there are only a few places where this will happen
	
	local name = UnitName(unit)
	if lastseen[name] and time() < lastseen[name] + self.db.profile.delay then
		-- we saw it too recently to *record* it, but we'll let the caller know
		self.events:Fire("Seen_Silent", zone, name, x, y, UnitIsDead(unit), false, source or 'target', unit, globaldb.mob_id[name])
		return true
	end

	local level = UnitLevel(unit)
	local creature_type = UnitCreatureType(unit)
	
	local newloc = self:SaveMob(zone, name, x, y, level, unittype=='rareelite', creature_type)

	lastseen[name] = time()
	self.events:Fire("Seen", zone, name, x, y, UnitIsDead(unit), newloc, source or 'target', unit, globaldb.mob_id[name])
	return true
end

function addon:SaveMob(zone, name, x, y, level, elite, creature_type, force, unseen)
	if not (zone and name) then return end
	-- saves a mob's information, returns true if this is the first time a mob has been seen at this location
	if not globaldb.mob_locations[name] then globaldb.mob_locations[name] = {} end

	globaldb.mobs_byzone[zone][name] = unseen and 0 or time()
	if level then globaldb.mob_level[name] = level end
	if elite then globaldb.mob_elite[name] = true end
	if creature_type then globaldb.mob_type[name] = BCTR[creature_type] end
	globaldb.mob_count[name] = globaldb.mob_count[name] + (unseen and 0 or 1)
    if not unseen then
        local key = zone .. ':' .. name
        local h = globaldb.coa_history[key] or {count = 0}
        h.count = (h.count or 0) + 1
        h.last = time(); h.x = x; h.y = y
        globaldb.coa_history[key] = h
    end
	
	if not (x and y and x > 0 and y > 0) then return end

	local newloc = true
	if not force then
		for _, coord in ipairs(globaldb.mob_locations[name]) do
			local loc_x, loc_y = self:GetXY(coord)
			if (math.abs(loc_x - x) < 0.03) and (math.abs(loc_y - y) < 0.03) then
				-- We've seen it close to here before. (within 5% of the zone)
				newloc = false
				break
			end
		end
	end
	if newloc then
		table.insert(globaldb.mob_locations[name], self:GetCoord(x, y))
	end
	return newloc
end

-- Returns num_locs, level, is_elite, creature_type, last_seen, times_seen, mob_id, is_tameable
function addon:GetMob(zone, name)
	if not (zone and name and globaldb.mobs_byzone[zone][name]) then
		return 0, 0, false, UNKNOWN, nil, 0, nil, nil
	end
	return #globaldb.mob_locations[name], globaldb.mob_level[name], globaldb.mob_elite[name], BCT[globaldb.mob_type[name]], globaldb.mobs_byzone[zone][name], globaldb.mob_count[name], globaldb.mob_id[name], globaldb.mob_tameable[name]
end

-- Returns name, addon:GetMob(zone, name)
function addon:GetMobByCoord(zone, coord)
	if not globaldb.mobs_byzone[zone] then return end
	for name in pairs(globaldb.mobs_byzone[zone]) do
		for _, mob_coord in ipairs(globaldb.mob_locations[name]) do
			if coord == mob_coord then
				return name, self:GetMob(zone, name)
			end
		end
	end
end

function addon:DeleteMob(zone, name)
	if not (zone and name) then return end
	if not globaldb.mobs_byzone[zone] then return end
	globaldb.mobs_byzone[zone][name] = nil
	globaldb.mob_level[name] = nil
	globaldb.mob_elite[name] = nil
	globaldb.mob_type[name] = nil
	globaldb.mob_count[name] = nil
	globaldb.mob_locations[name] = nil
end

function addon:DeleteAllMobs()
	local n = 0
	for zone,mobs in pairs(globaldb.mobs_byzone) do for name, info in pairs(mobs) do
		self:DeleteMob(zone, name)
		n = n + 1
	end end
	DEFAULT_CHAT_FRAME:AddMessage("SilverDragon: Removed "..n.." rare mobs from database.")
	self.events:Fire("DeleteAll", n)
end

-- Scanning:

function addon:CheckNearby()
	local zone = self:GetPlayerLocation()
	if not zone then return end
	if (not self.db.profile.instances) and IsInInstance() then return end
	if (not self.db.profile.taxi) and UnitOnTaxi('player') then return end
	
	if self.db.profile.targets then
		addon:ScanTargets(zone)
	end
	if self.db.profile.nameplates then
		addon:ScanNameplates(zone)
	end
	if self.db.profile.cache then
        local now = GetTime()
        if not self._nextCacheScan or now >= self._nextCacheScan then
            self._nextCacheScan = now + (self.db.profile.cache_scan_interval or 5)
            addon:ScanCache(zone)
        end
    end
end

local units_to_scan = {'target', 'mouseover', 'focus', 'targettarget', 'pettarget', 'party1target', 'party2target', 'party3target', 'party4target', 'party5target', 'boss1', 'boss2', 'boss3', 'boss4', 'boss5'}
function addon:ScanTargets()
	for _, unit in ipairs(units_to_scan) do
		self:ProcessUnit(unit, 'grouptarget')
	end
end

-- CoA: nameplate skins often change the texture/layout used by the old scanner.
-- Read visible name text without assuming Blizzard's original border/glow layout.
-- Only names already confirmed in the rare database trigger this path.
local nameplates = {}
local function collectNameStrings(frame, depth, result)
    if depth > 3 or not frame or not frame.GetNumRegions then return end
    for i=1,frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            result[#result+1] = region
        end
    end
    if depth < 3 and frame.GetNumChildren then
        for i=1,frame:GetNumChildren() do
            local child = select(i, frame:GetChildren())
            if child and child.GetObjectType and child:GetObjectType() == "Frame" then
                collectNameStrings(child, depth+1, result)
            end
        end
    end
end
local function discoverNameplate(frame)
    if not frame or not frame.GetObjectType or frame:GetObjectType() ~= "Frame" then return end
    local frameName = frame:GetName()
    -- Accept known named plate roots, never arbitrary named WorldFrame UI.
    if frameName and not (frameName:match("^NamePlate%d+$") or frameName:match("^ElvUI_NamePlate%d+$")) then return end
    local texts = {}
    collectNameStrings(frame, 0, texts)
    if #texts > 0 then nameplates[frame] = texts end
end
local num_worldchildren = -1
local nextPlateDiscovery = 0
function addon:ScanNameplates(zone)
    if GetCVar("nameplateShowEnemies") ~= "1" then return end
    local zone_mobs = globaldb.mobs_byzone[zone]
    if not zone_mobs then return end
    local count = WorldFrame:GetNumChildren()
    if count ~= num_worldchildren or GetTime() >= nextPlateDiscovery then
        num_worldchildren = count
        nextPlateDiscovery = GetTime() + 2
        for i=1,count do discoverNameplate(select(i, WorldFrame:GetChildren())) end
    end
    for frame, texts in pairs(nameplates) do
        if frame:IsVisible() then
            for _, region in ipairs(texts) do
                local name = region:GetText()
                if name and zone_mobs[name] and region:IsVisible() and
                   (not lastseen[name] or lastseen[name] < time() - self.db.profile.delay) then
                    local x,y = GetPlayerMapPosition("player")
                    local newloc = self:SaveMob(zone, name, x, y, nil, false, nil)
                    self.events:Fire("Seen", zone, name, x, y, false, newloc, "nameplate", false, globaldb.mob_id[name])
                    lastseen[name] = time()
                    break
                end
            end
        end
    end
end

local already_cached = {}
local first_cachescan = true
local cache_tooltip = CreateFrame("GameTooltip", "SDCacheTooltip")
cache_tooltip:AddFontStrings(
	cache_tooltip:CreateFontString("$parentTextLeft1", nil, "GameTooltipText"),
	cache_tooltip:CreateFontString("$parentTextRight1", nil, "GameTooltipText")
)

local function is_cached(id)
	-- this doesn't work with just clearlines and the setowner outside of this, and I'm not sure why
	cache_tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
	cache_tooltip:SetHyperlink(("unit:0xF53000%04X000000"):format(id))
	return cache_tooltip:IsShown()
end
addon.is_cached = is_cached

addon.already_cached = already_cached

function addon:ScanCache(zone)
	if first_cachescan then
		for mob, id in pairs(globaldb.mob_id) do
			if is_cached(id) then
				already_cached[id] = true
			end
		end
		first_cachescan = false
		return
	end
	
	local zone_mobs = globaldb.mobs_byzone[zone]
	if not zone_mobs then return end
	for mob, lastseen in pairs(zone_mobs) do
		local id = globaldb.mob_id[mob]
		if id and (not globaldb.mob_tameable[mob] or self.db.profile.cache_tameable) and not already_cached[id] and is_cached(id) then
			already_cached[id] = true
			local _, x, y = self:GetPlayerLocation()
			self.events:Fire("Seen", zone, mob, x, y, false, false, "cache", false, id)
		end
	end
	first_cachescan = false
end
addon.RegisterCallback(addon, "Import", function()
	if first_cachescan then
		table.wipe(already_cached)
		first_cachescan = true
	end
end)

-- Utility:

function addon:FormatLastSeen(t)
	t = tonumber(t)
	if not t or t == 0 then return 'Never' end
	local currentTime = time()
	local minutes = math.ceil((currentTime - t) / 60)
	if minutes > 59 then
		local hours = math.ceil((currentTime - t) / 3600)
		if hours > 23 then
			return math.ceil((currentTime - t) / 86400).." day(s)"
		else
			return hours.." hour(s)"
		end
	else
		return minutes.." minute(s)"
	end
end

local continent_list = { GetMapContinents() }
local zone_to_mapfile = {}
local mapfile_to_zone = {}
for C in pairs(continent_list) do
	local zones = { GetMapZones(C) }
	continent_list[C] = zones
	for Z, Zname in ipairs(zones) do
		SetMapZoom(C, Z)
		zones[Z] = GetMapInfo()
		zone_to_mapfile[Zname] = zones[Z]
		mapfile_to_zone[zones[Z]] = Zname
	end
end
addon.continent_list = continent_list
addon.zone_to_mapfile = zone_to_mapfile
addon.mapfile_to_zone = mapfile_to_zone

function addon:GetPlayerLocation()
	-- returns mapFile (e.g. "Stormwind"), x, y
	if IsInInstance() then
		return BZR[GetRealZoneText()], 0, 0
	end
	local x, y = GetPlayerMapPosition('player')
	local C, Z = GetCurrentMapContinent(), GetCurrentMapZone()
	if x <= 0 and y <= 0 then
		if WorldMapFrame:IsVisible() then
			return
		end
		SetMapToCurrentZone()
		x, y = GetPlayerMapPosition('player')
		if x <= 0 and y <= 0 then
			SetMapZoom(GetCurrentMapContinent())
			x, y = GetPlayerMapPosition('player')
			if x <= 0 and y <= 0 then
				-- this is confusing; we're probably in an instance, but
				-- IsInInstance() returned false above.
				return BZR[GetRealZoneText()], 0, 0
			end
		end
		local C2, Z2 = GetCurrentMapContinent(), GetCurrentMapZone()
		if C2 ~= C or Z2 ~= Z then
			SetMapZoom(C, Z)
		end
		C, Z = C2, Z2
	end
	if not (continent_list[C] and continent_list[C][Z]) then
		return
	end
	return continent_list[C][Z], x, y
end

function addon:GetCoord(x, y)
	return floor(x * 10000 + 0.5) * 10000 + floor(y * 10000 + 0.5)
end

function addon:GetXY(coord)
	return floor(coord / 10000) / 10000, (coord % 10000) / 10000
end

