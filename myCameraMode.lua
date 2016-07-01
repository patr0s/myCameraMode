-- Modify the distance of the camera according to the activity of the character (fighting, taxi, in a vehicle on a mount)
--[[
		Also hide chat edit box and bubbles when in combat.
		SetView(2) > Used when on foot AND NOT in combat
		SetView(4) > Used when on mount OR on taxi OR in vehicle OR in combat
		Distances can be adjusted and saved with the following commands : /run SaveView(2) and /run SaveView(4)
]]--

------------------------------------------------------------------------------------------------
-- NAMESPACE DEFINITIONS
------------------------------------------------------------------------------------------------
local addon, engine	= ...
local funcs			= engine:unpack()

------------------------------------------------------------------------------------------------
-- LOCAL DATA
------------------------------------------------------------------------------------------------
local setCVar = funcs["cvar"].SetCVar
local activeBox
local activeView, farView, nearView = 0, 4, 2
--local timer = 0

------------------------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
------------------------------------------------------------------------------------------------
local GetCVar 			= GetCVar
local IsMounted			= IsMounted
local UnitInVehicle		= UnitInVehicle
local CanExitVehicle	= CanExitVehicle
local SetView			= SetView
local ShowHelm			= ShowHelm
local InCombatLockdown	= InCombatLockdown

local mountList 		= {}

------------------------------------------------------------------------------------------------
-- SECURE HOOK FUNCTIONS
------------------------------------------------------------------------------------------------
for i = 1, NUM_CHAT_WINDOWS do
    _G["ChatFrame" .. i .. "EditBox"]:HookScript("OnShow", function(self)
        activeBox = self
    end)
    _G["ChatFrame" .. i .. "EditBox"]:HookScript("OnHide", function(self)
        activeBox = nil
    end)
end

------------------------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
------------------------------------------------------------------------------------------------
local function updateMountList()
	for i = 1, C_MountJournal.GetNumMounts() do
		local creatureName, spellID, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfo(i)
		if isCollected then
			mountList[spellID] = true
			end
			end
		end

local function checkMountID(id)
	local index = 1
	local found = nil
	local name, _, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", index)
	while name do
		if spellID == id then
			found = true
			break
		end
		index = index + 1
		name, _, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", index)
    end

	return found
end

local function isMounted()
	return InCombatLockdown() or IsMounted() or UnitInVehicle("player") or CanExitVehicle()
end

------------------------------------------------------------------------------------------------
-- LOCAL FUNCTIONSEVENT FRAME
------------------------------------------------------------------------------------------------
local function onEvent(self, event, ...)
	local view
	local arg1, _, _, _, arg5 = ...

	-- PATROS: PLAYER ENTERING / LEAVING COMBAT
	if (event == "PLAYER_REGEN_DISABLED") then
        if activeBox then activeBox:ClearFocus() end
		if activeView ~= farView then view = farView end
		ShowHelm(1)
		setCVar("chatBubbles", "0")
		setCVar("chatBubblesParty", "0")

 	elseif (event == "PLAYER_REGEN_ENABLED") then
        if not isMounted() then view = nearView end
		ShowHelm(nil)
		setCVar("chatBubbles", "1")
		setCVar("chatBubblesParty", "1")

	-- PATROS: PLAYER ENTERING THE WORLD
    elseif (event == "PLAYER_ENTERING_WORLD") then
    	updateMountList()
    	self.mountID = checkMountID()
    	view = isMounted() and farView or nearView
		if InCombatLockdown() then
			setCVar("chatBubbles", "0")
			setCVar("chatBubblesParty", "0")
			ShowHelm(1)
		else
			setCVar("chatBubbles", "1")
			setCVar("chatBubblesParty", "1")
			ShowHelm(nil)
		end
		self:UnregisterEvent(event)

	-- PATROS: PLAYER ENTERING / LEAVING A VEHICLE
	elseif event == ("UNIT_ENTERED_VEHICLE") and (arg1 == "player") then
		if activeView ~= farView then view = farView end

	elseif event == ("UNIT_EXITED_VEHICLE") and (arg1 == "player") then
		if not InCombatLockdown() then view = nearView end

	-- PATROS: PLAYER SUMMONING / DISMISSING A MOUNT
	-- We need to check is self.mountID exists because UNIT_AURA is also send just after  UNIT_SPELLCAST_SUCCEEDED !!!
	elseif event == ("UNIT_SPELLCAST_SUCCEEDED") and (arg1 == "player") then
		if mountList[arg5] then
			if activeView ~= farView then view = farView end
			self.mountID = arg5
			self.UNIT_SPELLCAST_SUCCEEDED = true
		end

	elseif (event == "UNIT_AURA") and (arg1 == "player") then
		if self.UNIT_SPELLCAST_SUCCEEDED then
			self.UNIT_SPELLCAST_SUCCEEDED = nil
		else
			if self.mountID and not checkMountID(self.mountID) then
				self.mountID = nil
				if not InCombatLockdown() then view = nearView end
			end
		end

	elseif (event == "COMPANION_LEARNED") or (event == "COMPANION_UNLEARNED") then
		if arg1 == "MOUNT" then
			updateMountList()
		end

	-- PATROS: PLAYER SUMMONING / LEAVING TAXI
	-- UnitOnTaxi() does not immediately return true, so we need to wait for a screen update
	elseif event == "PLAYER_CONTROL_LOST" then
		if self.PLAYER_CONTROL_LOST_EVENT_DELAYED then
			self.PLAYER_CONTROL_LOST_EVENT_DELAYED = nil
			self:Hide()
			if UnitOnTaxi("player") then
				if activeView ~= farView then view = farView end
				self.UNIT_ON_TAXI = true
			end
		else
			self:Show()
		end

	elseif event == "PLAYER_CONTROL_GAINED" then
		if self.UNIT_ON_TAXI then
			self.UNIT_ON_TAXI = nil
			if not InCombatLockdown() then view = nearView end
		end

	-- PATROS: OTHERS CASES
	else
		ShowHelm(nil)
	end

	if view then
		SetView(view)
		activeView = view
	end
end

local function onUpdate(self)
	if self.PLAYER_CONTROL_LOST_EVENT_DELAYED then
		onEvent(self, "PLAYER_CONTROL_LOST")
	else
		self.PLAYER_CONTROL_LOST_EVENT_DELAYED = true
	end
end

local frame = CreateFrame("frame")
frame:Hide()

frame:RegisterEvent("COMPANION_LEARNED")
frame:RegisterEvent("COMPANION_UNLEARNED")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_CONTROL_GAINED")
frame:RegisterEvent("PLAYER_CONTROL_LOST")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("UNIT_ENTERED_VEHICLE")
frame:RegisterEvent("UNIT_EXITED_VEHICLE")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

frame:SetScript("OnEvent", onEvent)
frame:SetScript("OnUpdate", onUpdate)