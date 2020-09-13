RGO_FRAME_TAB_LIST = {}

--transmitting preset helper variables
local transmittedGroups = nil
local transmittedPresetName = nil

function RgoFrame_OnLoad(self)
	for i = 1, 8 do
		for j = 1, 5 do
			RGO_FRAME_TAB_LIST[(i - 1) * 5 + j] = "FrameGroup"..i.."Player" .. j
		end
	end
end

function RgoFrame_OnShow (self)
	RgoRaidGoupFrame:Hide()
	RgoFrameScrollBar_Update()
	RgoClearSelection(RgoFrameScrollBar, RgoFrameScrollBar.buttons);
end

function RgoClearSelection(scrollBar, buttons)
	OptionsList_ClearSelection(scrollBar, buttons);
	RemovePresetButton:Disable();
end

function RgoSelectButton(scrollBar, button)
	OptionsList_SelectButton(scrollBar, button);
	RemovePresetButton:Enable();
end

function RgoFrameScrollBar_Update()
	local offset = FauxScrollFrame_GetOffset(RgoFrameScrollBarList);
	local buttons = RgoFrameScrollBar.buttons;
	local element;
	
	local numButtons = #buttons;
	local numPresets = RGO:getPresetCount();
	
	
	if ( numPresets > numButtons and ( not RgoFrameScrollBarList:IsShown() ) ) then
		OptionsList_DisplayScrollBar(RgoFrameScrollBar);
	elseif ( numPresets <= numButtons and ( RgoFrameScrollBarList:IsShown() ) ) then
		OptionsList_HideScrollBar(RgoFrameScrollBar);
	end

	FauxScrollFrame_Update(RgoFrameScrollBarList, numPresets, numButtons, buttons[1]:GetHeight());
	
	local selection = RgoFrameScrollBar.selection;
	if ( selection ) then
		-- Store the currently selected element and clear all the buttons, we're redrawing.
		RgoClearSelection(RgoFrameScrollBar, RgoFrameScrollBar.buttons);
	end

	for i = 1, numButtons do
		element = {name = RGO:getPresetName(i + offset), index = i + offset}
		if ( not element.name ) then
			OptionsList_HideButton(buttons[i]);
		else
			OptionsList_DisplayButton(buttons[i], element);

			if ( selection ) and ( selection.index == element.index ) and ( not RgoFrameScrollBar.selection ) then
				RgoSelectButton(RgoFrameScrollBar, buttons[i]);
				
			end
		end

	end

	if ( selection ) then
		-- If there was a selected element before we cleared the button highlights, restore it, 'cause we're done.
		-- Note: This theoretically might already have been done by OptionsList_SelectButton, but in the event that the selected button hasn't been drawn, this is still necessary.
		RgoFrameScrollBar.selection = selection;
	end
end

function RgoListEntry_OnClick (self, mouseButton)
	local parent = self:GetParent();
	local buttons = parent.buttons;

	RgoClearSelection(RgoFrameScrollBar, RgoFrameScrollBar.buttons);
	RgoSelectButton(parent, self);
	
	RgoPresetNameEditBox:SetText(RGO:getPresetName(RgoFrameScrollBar.selection.index))
	
	group =  RGO:getPresetGroup(RgoFrameScrollBar.selection.index)
	for i = 1, 8 do
		for j = 1, 5 do
			local playerName = group[(i - 1) * 5 + j]
			if(playerName == nil) then
				playerName = "" 
			end
			getglobal("FrameGroup".. i .."Player" .. j):SetText(playerName)
		end
	end
	
	RgoRaidGoupFrame:Show()
end

function RgoFrameAdd_OnClick(self, button)
	RgoPresetNameEditBox:SetText("")
	for i = 1, 8 do
		for j = 1, 5 do
			getglobal("FrameGroup".. i .."Player" .. j):SetText("")
		end
	end
	RgoPresetNameEditBox:SetFocus() 

	RgoClearSelection(RgoFrameScrollBar, RgoFrameScrollBar.buttons);
	RgoRaidGoupFrame:Show()
end

function RgoFrameRemove_OnClick(self, button)
	if(RgoFrameScrollBar.selection) then
		RGO:deletePreset(RgoFrameScrollBar.selection.index) 
		RgoFrameScrollBar_Update()
	end
end

function RgoFrame_OnKeyUp(self, key)
	if(IsControlKeyDown() and key == "D" and RgoFrameScrollBar.selection) then
		RgoPresetNameEditBox:SetText("")
		group =  RGO:getPresetGroup(RgoFrameScrollBar.selection.index)
		for i = 1, 8 do
			for j = 1, 5 do
				local playerName = group[(i - 1) * 5 + j]
				if(playerName == nil) then
					playerName = "" 
				end
				getglobal("FrameGroup".. i .."Player" .. j):SetText(playerName)
			end
		end
		RgoPresetNameEditBox:SetFocus() 

		RgoClearSelection(RgoFrameScrollBar, RgoFrameScrollBar.buttons);
		RgoRaidGoupFrame:Show()
	end
end

function RgoFrameSave_OnClick(self, button)
	local group = {}
	for i = 1, 8 do
		for j = 1, 5 do
			local playerName = getglobal("FrameGroup".. i .."Player" .. j):GetText()
			if(playerName == "") then
				playerName = nil 
			end
			group[(i - 1) * 5 + j] = playerName
		end
	end
	
	if(not RgoFrameScrollBar.selection) then
		RGO:addNewPreset(RgoPresetNameEditBox:GetText(), group) 
		RgoFrameScrollBar.selection = {index = RGO:getPresetCount()}
	else
		RGO:updatePreset(RgoFrameScrollBar.selection.index, RgoPresetNameEditBox:GetText(), group) 
	end
	RgoFrameScrollBar_Update()
end

function trimText(s)
   return s:match "^%s*(.-)%s*$"
end

local function sendMessage(msg, target)
  C_ChatInfo.SendAddonMessage("rgo", msg, "WHISPER", target);
end

function RgoFrameShare_OnClick(self, button)
	local target = trimText(ShareEditBox:GetText())
	if (target == "") then
		return
	end
	local presetName = trimText(RgoPresetNameEditBox:GetText())
	if presetName == "" then
		presetName = "unnamed"
	end
	print("Sending Raid Group Organizer preset "..presetName.." to " .. target)
	sendMessage("start_transmission" .. " " .. presetName, target)
	for i = 1, 8 do
		local message = ""
		for j = 1, 5 do
			local playerName = trimText(getglobal("FrameGroup".. i .."Player" .. j):GetText())
			if(playerName == "") then
				playerName = "[]"
			end
			message = message .. playerName
			if j < 5 then
				message = message .. ","
			end
		end
		sendMessage(message, target)
	end
	sendMessage("end_transmission", target)
	print("done")
end

local function handleMessage(msg)
	if(msg == "end_transmission") then
		for key,value in pairs(transmittedGroups) do
			if value == "" then
				transmittedGroups[key] = nil
			end
		end
		RGO:addNewPreset(transmittedPresetName, transmittedGroups) 
		RgoFrameScrollBar_Update()
		
		transmittedGroups = nil
		transmittedPresetName = nil
		print("done.")
	else
		local presetName = string.match(msg, "start_transmission (.+)")
		if (presetName == nil) then
			for playerName in string.gmatch(msg, "([^,]+)") do
				if (playerName == "[]") then
					playerName = ""
				end
				table.insert(transmittedGroups, playerName)
			end
		else
			transmittedPresetName = presetName
			transmittedGroups = {}
			print("Receiving Raid Group Organizer preset: " .. presetName)
		end
	end
end

function RgoFrame_OnEvent(self, event, ...)
	if event == "PLAYER_LOGIN" then
		C_ChatInfo.RegisterAddonMessagePrefix("rgo")
	elseif event == "CHAT_MSG_ADDON" then
		local prefix, msg = ...
		if prefix == "rgo" then
			handleMessage(msg)
		end
	end
end