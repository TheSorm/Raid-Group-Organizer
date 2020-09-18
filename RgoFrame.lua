RGO_FRAME_TAB_LIST = {}

--drag&drop helper variables
local originalPoint = {}
local dropTarget = nil

SaveValidationErrors = {["doubleName"] = nil, ["presetNameEmpty"] = false}

local requestData = {
	["presetOwner"] = nil,
	["presetName"] = nil,
	["presetIndex"] = nil
}

local origChatFrame_OnHyperlinkShow = ChatFrame_OnHyperlinkShow;

function RgoToolTipImport_OnClick(self)
	RGO:SendMessage(format("%s %s,%s", AddonCommCommands["request_preset"], requestData["presetName"], requestData["presetIndex"]), requestData["presetOwner"])
	RgoToolTipClose_OnClick(self)
end

function RgoToolTipClose_OnClick(self)
	requestData["presetOwner"] = nil
	requestData["presetName"] = nil
	requestData["presetIndex"] = nil
	self:GetParent():Hide()
end

ChatFrame_OnHyperlinkShow = function(...)
	local chatFrame, link, text, button = ...;
	if type(text) ~= "string" or IsModifiedClick() then
		origChatFrame_OnHyperlinkShow(...)
		return
	end
	local presetOwner, presetName, presetIndex  = string.match(link, "item:rgo:([^,]*),([^,]*),(.*)")
	if presetName and presetOwner and presetIndex then
		requestData["presetOwner"] = presetOwner
		requestData["presetName"] = presetName
		requestData["presetIndex"] = presetIndex
		RgoToolTipText:SetText(format("Press the import button to import the Preset %s from %s", presetName, presetOwner))
		
		local mouseX, mouseY = GetCursorPosition()
		RgoHyperLinkToolTip:ClearAllPoints()
		RgoHyperLinkToolTip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", mouseX, mouseY)
		RgoHyperLinkToolTip:Show()
	else
		origChatFrame_OnHyperlinkShow(...)
	end
end


local function modifyChatMessage(self, event, msg, sender, ...)
	msg = string.gsub(msg, "%[RGO:PresetRequest:([^,]*),([^,]*),([^%]]*)%]", "\124cff0070dd\124Hitem:rgo:%1,%2,%3\124h[%2]\124h\124r")
	return false, msg, sender, ...
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", modifyChatMessage)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER ", modifyChatMessage)
ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", modifyChatMessage)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", modifyChatMessage)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", modifyChatMessage)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", modifyChatMessage)
ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", modifyChatMessage)
ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", modifyChatMessage)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", modifyChatMessage)

local function visitPlayerInfos(visitNameAndClass)
	local numTotal = GetNumGuildMembers();
	for i = 1, numTotal do
		local name, _, _, _, _, _, _, _, _, _, classFileName = GetGuildRosterInfo(i);
		name = string.match(name, "(.+)-.+") --remove server name
		if not visitNameAndClass(name, classFileName) then
			break
		end
	end
end

function RgoFrame_OnTextChanged(editBox)
	local playerName = RGO:TrimText(editBox:GetText())
	if playerName == "" then
		editBox:SetTextColor(1, 1, 1) --white cursor blinking
		return
	end
	local found = false

	visitPlayerInfos(
		function(name, className)
			if name == playerName then
				local rPerc, gPerc, bPerc, argbHex = GetClassColor(className)
				editBox:SetTextColor(rPerc, gPerc, bPerc)
				found = true
				return false --stop visiting
			end
			return true
		end
	)	
	if not found then
		editBox:SetTextColor(1, 0, 0)
	end
end

function RgoPresetOptionMenu_OnLoad()
	local info = UIDropDownMenu_CreateInfo()
   
	info.text = "Options"
    info.isTitle  = true
	info.notCheckable = true
	UIDropDownMenu_AddButton(info)
	
	info = UIDropDownMenu_CreateInfo()
   
	info.text = "Duplicate"
	info.func = RgoOpenCurrentPresetAsNew
    info.notCheckable = true
	UIDropDownMenu_AddButton(info)
	
	info.text = "Import Raid"
	info.func = RgoImportRaidIntoUI
    info.notCheckable = true
	UIDropDownMenu_AddButton(info)
end

function RgoImportRaidIntoUI()
	if not UnitInRaid("player") then
		return
	end

	local group = RGO:getCurrentRaidSetup()
	for i = 1, 8 do
		for j = 1, 5 do
			local playerName = group[(i - 1) * 5 + j]
			if(playerName == nil) then
				playerName = "" 
			end
			getglobal("FrameGroup".. i .."Player" .. j):SetText(playerName)
		end
	end
end


function RgoPresetOptionMenuButton_OnClick() 
    ToggleDropDownMenu(1, nil, RgoPresetOptionMenu, RgoPresetOptionMenuButton, 0, 0);
end

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
	
	local group =  RGO:getPresetGroup(RgoFrameScrollBar.selection.index)
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
	
	if IsShiftKeyDown() then
		local presetOwner = UnitName("player")
		ChatEdit_InsertLink(format("[RGO:PresetRequest:%s,%s,%s]", presetOwner, RgoPresetNameEditBox:GetText(), RgoFrameScrollBar.selection.index)) 
	end
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

function RgoOpenCurrentPresetAsNew()
	if(not RgoFrameScrollBar.selection) then
		return
	end
	
	RgoPresetNameEditBox:SetText("")
	local group =  RGO:getPresetGroup(RgoFrameScrollBar.selection.index)
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

local function checkDuplicatePlayers(group)
	for i=1, 40 do
		for j=i + 1, 40 do
			if group[i] ~= nil and group[i] == group[j] then
				return group[i]
			end
		end
	end
end

local function createPresetGroupsTable()
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
	return group
end

local function createErrorMessages()
	local doubleName = SaveValidationErrors["doubleName"]
	local presetNameEmpty = SaveValidationErrors["presetNameEmpty"]
	local errorMessages = {}
	if doubleName then
		table.insert(errorMessages, format("Player %s is already set.", doubleName))
	end
	if presetNameEmpty then
		table.insert(errorMessages, "Preset name is empty.")
	end
	return errorMessages
end

function RgoFrameSave_OnClick(self, button)
	if #createErrorMessages() > 0 then
		PlaySound(SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST);
		return
	end
	local group = createPresetGroupsTable()
	
	if(not RgoFrameScrollBar.selection) then
		RGO:addNewPreset(RGO:TrimText(RgoPresetNameEditBox:GetText()), group) 
		RgoFrameScrollBar.selection = {index = RGO:getPresetCount()}
	else
		RGO:updatePreset(RgoFrameScrollBar.selection.index, RGO:TrimText(RgoPresetNameEditBox:GetText()), group) 
	end
	RgoFrameScrollBar_Update()
end

local function resetDrag(draggedFrame, fontString)
	draggedFrame:ClearAllPoints()
	draggedFrame:SetPoint(originalPoint[1],originalPoint[2],originalPoint[3],originalPoint[4],originalPoint[5])
	fontString:SetText("")
end

local function trySwap(draggedFrame)
	local parentFrame = draggedFrame:GetParent()
	parentFrame:SetAlpha(1)
	if (dropTarget == nil) then
		return
	end
	
	local draggedPlayer = RGO:TrimText(parentFrame:GetText())
	local targetPlayer = RGO:TrimText(dropTarget:GetText())
	local draggedColorR, draggedColorG, draggedColorB = parentFrame:GetTextColor()
	local targetColorR, targetColorG, targetColorB = dropTarget:GetTextColor()
	dropTarget:SetText(draggedPlayer)
	dropTarget:SetTextColor(draggedColorR, draggedColorG, draggedColorB)
	parentFrame:SetText(targetPlayer)
	parentFrame:SetTextColor(targetColorR, targetColorG, targetColorB)
	dropTarget:SetAlpha(1)
	
	dropTarget = nil
end

local function updateDropTarget(draggedFrame)
	local draggedXOff = draggedFrame:GetLeft()
	local draggedYOff = draggedFrame:GetTop() - draggedFrame:GetHeight()/ 2
	
	for i = 1, 8 do
		for j = 1, 5 do
			local editBox = _G["FrameGroup" .. i .. "Player" .. j]
			local xOff = editBox:GetLeft()
			local yOff = editBox:GetTop()
			local width = editBox:GetWidth()
			local height = editBox:GetHeight() - 2
			if editBox ~= draggedFrame:GetParent() then			
				if (draggedXOff > xOff and draggedXOff < (xOff + width) and draggedYOff < yOff and draggedYOff > (yOff - height)) then
					dropTarget = editBox
					editBox:SetAlpha(0.5)
				else
					editBox:SetAlpha(1)		
				end
			end
		end
	end
end

local function initDraggableFrame(draggedFrame, fontString)
	local tmpFrame = CreateFrame("Frame", nil, draggedFrame);
	tmpFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT");
	tmpFrame:SetPoint("TOPRIGHT", draggedFrame, "TOPLEFT");
	tmpFrame:SetScript("OnSizeChanged", function(self, w, h)
		if not draggedFrame.isMoving then
			return
		end
		updateDropTarget(draggedFrame)
	end);		
	draggedFrame:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and not self.isMoving then
			local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
			originalPoint = {point, relativeTo, relativePoint, xOfs, yOfs}
			fontString:SetText(draggedFrame:GetParent():GetText())
			fontString:SetTextColor(draggedFrame:GetParent():GetTextColor())
			draggedFrame:GetParent():SetAlpha(0)
			draggedFrame:SetIgnoreParentAlpha(true)
			fontString:SetIgnoreParentAlpha(true)
			self:StartMoving();
			self.isMoving = true;
		end
	end)
	draggedFrame:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and self.isMoving then
			trySwap(draggedFrame)
			self:StopMovingOrSizing();
			self:SetUserPlaced(false)
			self.isMoving = false;
			resetDrag(draggedFrame, fontString)
		end
	end)
	draggedFrame:SetScript("OnHide", function(self)
		if ( self.isMoving ) then
			self:StopMovingOrSizing();
			self.isMoving = false;
			resetDrag(draggedFrame, fontString)
		end
	end)
end

function RGO:InitDraggableButtons()
	for i = 1, 8 do
		for j = 1, 5 do
			local parentFrame = _G["FrameGroup" .. i .. "Player" .. j]
			local button = CreateFrame("Button", "DragAnchor" .. i .. j, parentFrame, "DragAnchorTemplate")
			local fontString = button:CreateFontString("DragFontString"..i..j, "OVERLAY")
			fontString:SetFont(parentFrame:GetFont())
			fontString:SetPoint("LEFT",button,"LEFT",-122, 0)
			initDraggableFrame(button, fontString)
		end
	end
end

local function showTooltip(self)
	local errorMessages = createErrorMessages()
	if #errorMessages > 0 then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Cannot save", 1, 0, 0)
		GameTooltip:AddLine(" ", 1, 1, 1)
		for k, msg in pairs(errorMessages) do
			GameTooltip:AddLine(msg, 1, 1, 1)
			GameTooltip:AddLine(" ", 1, 1, 1)
		end
		GameTooltip:Show()
	end
end

function RgoFrameSave_OnEnter(self)
	local group = createPresetGroupsTable()
	local duplicateName = checkDuplicatePlayers(group)
	SaveValidationErrors["doubleName"] = duplicateName

	showTooltip(self)
end

function RgoFrameSave_OnLeave(self)
	GameTooltip:Hide()
end