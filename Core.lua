RGO = LibStub("AceAddon-3.0"):NewAddon("RGO", "AceEvent-3.0", "AceComm-3.0")
RGO_Console = LibStub("AceConsole-3.0")

AddonCommCommands = {
	["end_transmission"] = "end_transmission",
	["request_preset"] = "request_preset",
	["start_transmission"] = "start_transmission"
}

--transmitting preset helper variables
local transmittedGroups = nil
local transmittedPresetName = nil

function RGO:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("RGO_DB")
	
	if(self.db.realm.presetIndexToGroupStructure == nil) then
		self.db.realm.presetIndexToGroupStructure = {}
	end
	
	if(self.db.realm.presetIndexToPresetName == nil) then 
		self.db.realm.presetIndexToPresetName = {}
	end
	
	self.queuedSorting = nil
	
	RGO:RegisterEvent("GROUP_ROSTER_UPDATE", "UpdateDropdownVisibility")
	RGO:RegisterEvent("PLAYER_ROLES_ASSIGNED", "UpdateDropdownVisibility")
	RGO:RegisterEvent("PARTY_LEADER_CHANGED", "UpdateDropdownVisibility")
	RGO:RegisterEvent("PLAYER_REGEN_ENABLED", "ProcessQueuedSorting")
	
	
	RGO:RegisterComm("rgo", "HandleAddonMessage")
	
	RGO:CreatePresetDropdownInRaidFrame() 
	
	RGO:UpdateDropdownVisibility() 
end

function RGO:OnEnable()
end

function RGO:OnDisable()
end

function RGO:TrimText(s)
   return s:match "^%s*(.-)%s*$"
end

function RGO:SendMessage(msg, target)
	RGO:SendCommMessage("rgo", msg, "WHISPER", target)
end

function RGO:SendPreset(presetName, target, playerNameRequestor)
	if not target or target == "" then
		return
	end
	if not presetName or presetName == "" then
		presetName = "unnamed"
	end
	--print("Sending Raid Group Organizer preset "..presetName.." to " .. target)
	RGO:SendMessage(format("%s %s", AddonCommCommands["start_transmission"], presetName), target)
	
	for i = 1, 8 do
		local message = ""
		for j = 1, 5 do
			local playerName = playerNameRequestor(i, j)
			if(playerName == nil or playerName == "") then
				playerName = "[]"
			end
			message = message .. playerName
			if j < 5 then
				message = message .. ","
			end
		end
		RGO:SendMessage(message, target)
	end
	RGO:SendMessage(AddonCommCommands["end_transmission"], target)
	--print("done")
end

function RGO:HandleAddonMessage(prefix, msg, distribution, sender)
	local command = {}
	for part in string.gmatch(msg, "[^%s]+") do
	    command[#command + 1] = part 
	end

	if command[1] == AddonCommCommands["end_transmission"] then
		if not (transmittedPresetName and transmittedGroups) then
			return --wrong message order
		end
		for key,value in pairs(transmittedGroups) do
			if value == "" then
				transmittedGroups[key] = nil
			end
		end
		RGO:addNewPreset(transmittedPresetName, transmittedGroups) 
		RgoFrameScrollBar_Update()
		
		transmittedGroups = nil
		transmittedPresetName = nil
		--print("done.")
	elseif command[1] == AddonCommCommands["start_transmission"] then
		if not command[2] then
			return
		end
		transmittedPresetName = command[2]
		transmittedGroups = {}
		--print("Receiving Raid Group Organizer preset: " .. command[2])
	elseif command[1] == AddonCommCommands["request_preset"] then
		if not command[2] then
			return
		end
		local argParts = {}
		for part in string.gmatch(command[2], "[^,]+") do
			argParts[#argParts + 1] = part 
		end
		if #argParts ~= 2 then
			return
		end
		local presetName = argParts[1]
		local index = argParts[2]
		if sender ~= UnitName("player") then
			local group =  RGO:getPresetGroup(tonumber(index))
			RGO:SendPreset(presetName, sender, function(i, j) return group[(i - 1) * 5 + j] end)
		else
			--print("Requesting own preset")
		end
	else
		for playerName in string.gmatch(msg, "([^,]+)") do
			if (playerName == "[]") then
				playerName = ""
			end
			table.insert(transmittedGroups, playerName)
		end
	end
end

function RGO:HandleAddonLoadedEvent(event, arg1)
	if arg1 == "RaidGroupOrganizer" then
		RGO:InitDraggableButtons()
	end
end

function RGO:CreatePresetDropdownInRaidFrame() 
	self.presetDropDown = CreateFrame("FRAME", "RGOChoosePreset", RaidFrame, "UIDropDownMenuTemplate")
	self.presetDropDown:SetPoint("TOPLEFT", RaidFrame, "TOPLEFT", 102, -22)
	RGOChoosePresetRight:SetAlpha(0)
	RGOChoosePresetLeft:SetAlpha(0)
	RGOChoosePresetMiddle:SetAlpha(0)
	UIDropDownMenu_SetWidth(self.presetDropDown, 7)

	UIDropDownMenu_Initialize(self.presetDropDown, RgoDropDownMenu_Initialize)
end

function RGO:PrintMissingPlayers(index)
	local sortedGRP = self.db.realm.presetIndexToGroupStructure[index]
	local indexToName = {}
	local nameToIndex = {}
	
	for i = 1, 40 do
		indexToName[i] = GetRaidRosterInfo(i)
		if(indexToName[i] ~= nil) then
			nameToIndex[indexToName[i]] = i
		end
	end  

	local missinPlayers = {}
	for i = 1, 8 do	
		for j = 1, 5 do
			local currentIndex = (i - 1) * 5 + j 
			if(nameToIndex[sortedGRP[currentIndex]] == nil) then
				local missingPlayer = sortedGRP[currentIndex]
				table.insert(missinPlayers, missingPlayer)
			end
		end
	end
	if (#missinPlayers > 0) then
		DEFAULT_CHAT_FRAME:AddMessage("Missing preset players: " .. table.concat(missinPlayers, ", " ), 1.0, 0.0, 0.0);
	end
end

function RgoDropDownMenu_Initialize (frame, level, menuList)
	local function presetDropDown_OnClick(frame, index, arg2, checked)
		if (not RGO:sortGroup(index)) then
			UIDropDownMenu_SetSelectedValue(RGO.presetDropDown, frame.value);
		else
			RGO:PrintMissingPlayers(index)
		end
	end
	
	local info = UIDropDownMenu_CreateInfo()
		
	for i = 1, #RGO.db.realm.presetIndexToPresetName do
		info.func = presetDropDown_OnClick
		info.text = RGO.db.realm.presetIndexToPresetName[i]
		info.arg1 = i
		UIDropDownMenu_AddButton(info)
		info = UIDropDownMenu_CreateInfo()
	end
end


function RGO:UpdateDropdownVisibility() 
	if UnitInRaid("player") and ((UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) and RGO:getPresetCount() > 0) then
		self.presetDropDown:Show()
	else
		self.presetDropDown:Hide()
	end
end

function RGO:ProcessQueuedSorting() 
	if(queuedSorting ~= nil) then
		RGO:sortGroup(queuedSorting)
		UIDropDownMenu_SetSelectedValue(RGO.presetDropDown, nil);
		RGO:PrintMissingPlayers(queuedSorting)
		queuedSorting = nil
	end
end

function RGO:deletePreset(index) 
	if(index ~= nil) then 
		table.remove(self.db.realm.presetIndexToPresetName, index)
		table.remove(self.db.realm.presetIndexToGroupStructure, index)
	end
	
	if(RGO:getPresetCount() == 0) then
		RGO:UpdateDropdownVisibility() 
	end
end

function RGO:addNewPreset(name, group) 
	table.insert(self.db.realm.presetIndexToPresetName, name)
	table.insert(self.db.realm.presetIndexToGroupStructure, group)
	
	if(RGO:getPresetCount() == 1) then
		RGO:UpdateDropdownVisibility()
	end
end

function RGO:updatePreset(index, name, group) 
	self.db.realm.presetIndexToPresetName[index] = name
	self.db.realm.presetIndexToGroupStructure[index] = group
end

function RGO:getPresetCount()
	return #self.db.realm.presetIndexToPresetName
end
function RGO:getPresetName(index)
	return self.db.realm.presetIndexToPresetName[index]
end

function RGO:getPresetGroup(index)
	return self.db.realm.presetIndexToGroupStructure[index]
end

function RGO:getCurrentRaidSetup()
	local raidGroupStructure = {}
	local raidGroup = {}

	for i = 1, 40 do
		name, _, subGrp = GetRaidRosterInfo(i)
		if(name ~= nil) then
			if(raidGroupStructure[subGrp] == nil) then
				raidGroupStructure[subGrp] = {}
			end
			table.insert(raidGroupStructure[subGrp], name)
		end
	end  
	
	for i = 1, 8 do	
		for j = 1, 5 do
			local index = (i - 1) * 5 + j 
			if(raidGroupStructure[i] == nil) then
				raidGroup[index] = nil
			else
				raidGroup[index] = raidGroupStructure[i][j]
			end
		end
	end
	
	return raidGroup
end

function RGO:sortGroup(index)

	if(InCombatLockdown()) then
		queuedSorting = index
		return false
	end
	
	local idToName = {}
	local idToSubGrp = {}
	local nameToId = {}
	local sortedGRP = self.db.realm.presetIndexToGroupStructure[index]
	
	for i = 1, 40 do
		idToName[i], a, idToSubGrp[i] = GetRaidRosterInfo(i)
		if(idToName[i] ~= nil) then
			nameToId[idToName[i]] = i
		else 
			idToSubGrp[i] = nil
		end
	end  
	
	local subGrpSize = {0,0,0,0,0,0,0,0}
	for i = 1, 40 do
		if idToSubGrp[i] ~= nil then
			subGrpSize[idToSubGrp[i]] = subGrpSize[idToSubGrp[i]] + 1
		end
	end  
	
	local idToSortedSubGrp = {}
	for i = 1, 8 do	
		for j = 1, 5 do
			local index = (i - 1) * 5 + j 
			if(nameToId[sortedGRP[index]] ~= nil) then
				idToSortedSubGrp[nameToId[sortedGRP[index]]] = i
			end
		end
	end

	for i = 1, 8 do	
		for j = 1, 5 do
			local indexInSortedGroup = (i - 1) * 5 + j 
			if(nameToId[sortedGRP[indexInSortedGroup]] ~= nil) then
				local idOfPlayerToSort = nameToId[sortedGRP[indexInSortedGroup]]
				
				if(idToSubGrp[idOfPlayerToSort] == i) then
					idToSubGrp[idOfPlayerToSort] = 0
				elseif(subGrpSize[i] < 5) then
					subGrpSize[idToSubGrp[idOfPlayerToSort]] = subGrpSize[idToSubGrp[idOfPlayerToSort]] -1
					
					SetRaidSubgroup(idOfPlayerToSort, i)
					
					idToSubGrp[idOfPlayerToSort] = 0
					subGrpSize[i] = subGrpSize[i] + 1
				else 
					for i2 = 1, 40 do
						if(idToSubGrp[i2] == i and idToSubGrp[i2] ~= idToSortedSubGrp[i2]) then
							SwapRaidSubgroup(i2, idOfPlayerToSort)
							idToSubGrp[i2] = idToSubGrp[idOfPlayerToSort]
							idToSubGrp[idOfPlayerToSort] = 0
							break
						end
					end
				end
			end
		end
	end
	return true
end


RGO_Console:RegisterChatCommand("rgo", "CreateRGOWindow")

function RGO_Console:CreateRGOWindow(input)
    if not RgoFrame:IsVisible() then
        RgoFrame:Show()
    end
end

--this outside of OnInitialize now because it will trigger for the own addon otherwise
RGO:RegisterEvent("ADDON_LOADED", "HandleAddonLoadedEvent")
