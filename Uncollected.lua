-- The reset ("X") button calls this directly, which would re-hide uncollected appearances.
-- C_TransmogCollection is a shared table (not mixin-copied), so wrapping it here fixes the
-- reset button everywhere it's used, not just in the Collections journal.
local Blizzard_TransmogCollection_SetDefaultFilters = C_TransmogCollection.SetDefaultFilters;
function C_TransmogCollection.SetDefaultFilters()
	Blizzard_TransmogCollection_SetDefaultFilters();
	C_TransmogCollection.SetUncollectedShown(true);
end

-- The reset X's shown/hidden state only updates on OnShow or menu interaction, never
-- automatically when we change filters from outside. Re-validate it manually so it
-- doesn't get stuck showing after we force filters on.
local function ValidateDropdownResetState(dropdown)
	if dropdown and dropdown.ValidateResetState then
		dropdown:ValidateResetState();
	end
end

-- Forever defaults onlyShowCollectedItemsInJournal to true, which makes Mounts/Toys/Pets
-- hide their FilterDropdown entirely in OnLoad. Must run before Blizzard_Collections loads.
local function ForceShowUncollected()
	if C_CVar.GetCVarBool("onlyShowCollectedItemsInJournal") then
		C_CVar.SetCVar("onlyShowCollectedItemsInJournal", "0");
	end

	C_MountJournal.SetCollectedFilterSetting(LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED, true);
	-- Forever also defaults the Pet Journal's COLLECTED filter to false, not just NOT_COLLECTED.
	C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED, true);
	C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED, true);
	-- The battle/non-combat pet type filters also default off, hiding every pet regardless of
	-- Collected/NotCollected. There's no in-game checkbox for these, so force them directly.
	C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_TYPE_BATTLE_PETS, true);
	C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_TYPE_NON_COMBAT_PETS, true);
	C_ToyBox.SetUncollectedShown(true);
	C_TransmogCollection.SetUncollectedShown(true);

	ValidateDropdownResetState(MountJournal and MountJournal.FilterDropdown);
	ValidateDropdownResetState(PetJournal and PetJournal.FilterDropdown);
	ValidateDropdownResetState(ToyBox and ToyBox.FilterDropdown);
end

-- Camelot/Blizzard_Wardrobe.lua forces uncollected items hidden and skips creating the
-- Collected/Not Collected checkboxes. Restore the standard behavior.
--
-- WardrobeCollectionFrame already exists with the mixin's functions copied in by the time
-- we load, so patching the mixin table alone wouldn't affect it - patch the frame directly.
local function InitItemsFilterButtonSetupMenu(self, dropdown, rootDescription, CreateSourceFilters)
	rootDescription:CreateCheckbox(COLLECTED, C_TransmogCollection.GetCollectedShown, function()
		C_TransmogCollection.SetCollectedShown(not C_TransmogCollection.GetCollectedShown());
	end);

	rootDescription:CreateCheckbox(NOT_COLLECTED, C_TransmogCollection.GetUncollectedShown, function()
		C_TransmogCollection.SetUncollectedShown(not C_TransmogCollection.GetUncollectedShown());
	end);

	CreateSourceFilters(rootDescription);
end

-- Forever's default filter check treats uncollected-hidden as "default", so the reset X would
-- show permanently once we force uncollected on. Redefine default as everything Forever's menu
-- actually exposes: Collected, Not Collected, and all sources checked.
local function IsUsingDefaultItemFilters()
	if not C_TransmogCollection.GetCollectedShown() or not C_TransmogCollection.GetUncollectedShown() then
		return false;
	end

	for filterIndex = 1, C_TransmogCollection.GetNumTransmogSources() do
		if C_TransmogCollection.IsValidTransmogSource(filterIndex) and not C_TransmogCollection.IsSourceTypeFilterChecked(filterIndex) then
			return false;
		end
	end

	return true;
end

local function SetDefaultItemFilters()
	C_TransmogCollection.SetCollectedShown(true);
	C_TransmogCollection.SetUncollectedShown(true);
	C_TransmogCollection.SetAllSourceTypeFilters(true);
end

-- Same mixin-copy timing issue as above: patch the instance and re-init immediately.
local function InitItemsFilterButton(self)
	local function CreateSourceFilters(description)
		description:CreateButton(CHECK_ALL, function()
			C_TransmogCollection.SetAllSourceTypeFilters(true);
			return MenuResponse.Refresh;
		end);

		description:CreateButton(UNCHECK_ALL, function()
			C_TransmogCollection.SetAllSourceTypeFilters(false);
			return MenuResponse.Refresh;
		end);

		local function IsChecked(filter)
			return C_TransmogCollection.IsSourceTypeFilterChecked(filter);
		end

		local function SetChecked(filter)
			C_TransmogCollection.SetSourceTypeFilter(filter, not IsChecked(filter));
		end

		for filterIndex = 1, C_TransmogCollection.GetNumTransmogSources() do
			if C_TransmogCollection.IsValidTransmogSource(filterIndex) then
				description:CreateCheckbox(_G["TRANSMOG_SOURCE_"..filterIndex], IsChecked, SetChecked, filterIndex);
			end
		end
	end

	self.FilterButton:SetIsDefaultCallback(IsUsingDefaultItemFilters);
	self.FilterButton:SetDefaultCallback(SetDefaultItemFilters);
	self.FilterButton:SetText(FILTER);

	self.FilterButton:SetupMenu(function(dropdown, rootDescription)
		rootDescription:SetTag("MENU_WARDROBE_FILTER");
		self:InitItemsFilterButtonSetupMenu(dropdown, rootDescription, CreateSourceFilters);
	end);
end

-- Forever only has ground mounts, but the mount Type submenu (Ground/Flying/Aquatic/...) gets
-- built anyway - IsValidTypeFilter doesn't know to exclude those for this game type.
-- MountJournal_InitFilterButton already ran once (as a bare global) before we could override it,
-- so reassign it for next time and also re-run it against the live frame now.
local function InitMountFilterButton(self)
	-- Undo OnLoad hiding this if the CVar was still true at that point.
	self.FilterDropdown:Show();
	self.FilterDropdown:SetWidth(90);

	self.FilterDropdown:SetIsDefaultCallback(function()
		return C_MountJournal.IsUsingDefaultFilters();
	end);

	self.FilterDropdown:SetDefaultCallback(function()
		C_MountJournal.SetDefaultFilters();
	end);

	local function IsSourceChecked(filterIndex)
		return C_MountJournal.IsSourceChecked(filterIndex)
	end

	local function SetSourceChecked(filterIndex)
		C_MountJournal.SetSourceFilter(filterIndex, not IsSourceChecked(filterIndex));
	end

	self.FilterDropdown:SetupMenu(function(dropdown, rootDescription)
		rootDescription:SetTag("MENU_MOUNT_COLLECTION_FILTER");

		rootDescription:CreateCheckbox(COLLECTED, MountJournal_GetCollectedFilter, function()
			MountJournal_SetCollectedFilter(not MountJournal_GetCollectedFilter());
		end);

		rootDescription:CreateCheckbox(NOT_COLLECTED, MountJournal_GetNotCollectedFilter, function()
			MountJournal_SetNotCollectedFilter(not MountJournal_GetNotCollectedFilter());
		end);

		rootDescription:CreateCheckbox(MOUNT_JOURNAL_FILTER_UNUSABLE, MountJournal_GetUnusableFilter, function()
			MountJournal_SetUnusableFilter(not MountJournal_GetUnusableFilter());
		end);

		local sourceSubmenu = rootDescription:CreateButton(SOURCES);
		sourceSubmenu:CreateButton(CHECK_ALL, MountJournal_SetAllSourceFilters, true);
		sourceSubmenu:CreateButton(UNCHECK_ALL, MountJournal_SetAllSourceFilters, false);

		for filterIndex = 1, C_PetJournal.GetNumPetSources() do
			if C_MountJournal.IsValidSourceFilter(filterIndex) then
				sourceSubmenu:CreateCheckbox(_G["BATTLE_PET_SOURCE_"..filterIndex], IsSourceChecked, SetSourceChecked, filterIndex);
			end
		end
	end);
end

local function RestoreMountFilters()
	MountJournal_InitFilterButton = InitMountFilterButton;
	InitMountFilterButton(MountJournal);
end

local function RestoreWardrobeFilters()
	WardrobeCollectionFrameMixin.InitItemsFilterButtonSetupMenu = InitItemsFilterButtonSetupMenu;
	WardrobeCollectionFrame.InitItemsFilterButtonSetupMenu = InitItemsFilterButtonSetupMenu;

	WardrobeCollectionFrameMixin.InitItemsFilterButton = InitItemsFilterButton;
	WardrobeCollectionFrame.InitItemsFilterButton = InitItemsFilterButton;
	WardrobeCollectionFrame:InitItemsFilterButton();

	C_TransmogCollection.SetUncollectedShown(true);
	C_TransmogCollection.SetCollectedShown(true);
end

local eventFrame = CreateFrame("Frame");
eventFrame:RegisterEvent("PLAYER_LOGIN");
-- Something also resets the filters on zoning/teleporting/entering instances, not just at
-- login, so PLAYER_ENTERING_WORLD is needed too.
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
eventFrame:RegisterEvent("ADDON_LOADED");
eventFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
	if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
		ForceShowUncollected();
	elseif loadedAddonName == "Blizzard_Collections" then
		ForceShowUncollected();
		RestoreMountFilters();
		RestoreWardrobeFilters();
	end
end);

if C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
	ForceShowUncollected();
	RestoreMountFilters();
	RestoreWardrobeFilters();
end
