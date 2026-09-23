-- Forever's built-in default filters hide uncollected appearances. The FilterButton's "reset to
-- default" control (the red X) calls C_TransmogCollection.SetDefaultFilters() directly, undoing our
-- override every time it's clicked. Unlike the mixin-copied frame methods below, C_TransmogCollection
-- is a shared API table looked up fresh on every call, so wrapping it here fixes the reset button
-- everywhere it's used (the Collections journal and the in-game Transmogrifier frame alike).
local Blizzard_TransmogCollection_SetDefaultFilters = C_TransmogCollection.SetDefaultFilters;
function C_TransmogCollection.SetDefaultFilters()
	Blizzard_TransmogCollection_SetDefaultFilters();
	C_TransmogCollection.SetUncollectedShown(true);
end

-- Mounts/Pets/Toys all use the shared WowDropdownFilterBehaviorMixin for their
-- FilterDropdown's red "reset to default" X. SetIsDefaultCallback only registers a function;
-- the button's shown/hidden state is actually computed by :ValidateResetState(), which only runs
-- on OnShow, OnMenuAssigned, or after a menu interaction - never automatically when something
-- outside the dropdown (like this addon) changes the underlying filter value. If Blizzard_Collections
-- happens to load before our PLAYER_LOGIN handler runs (e.g. a Collections tab was left open across
-- a UI reload), a dropdown can validate against the stale pre-override value and never re-check it.
-- Explicitly re-validate after forcing the filters so the X can't get stuck showing.
local function ValidateDropdownResetState(dropdown)
	if dropdown and dropdown.ValidateResetState then
		dropdown:ValidateResetState();
	end
end

-- Forever hides the "onlyShowCollectedItemsInJournal" CVar's UI and defaults it to true.
-- Mounts/Toys/Pets hide their FilterDropdown entirely in OnLoad when the CVar is true,
-- and never re-check it afterward, so this must run before Blizzard_Collections loads
-- (it is LoadOnDemand, triggered the first time the player opens the Collections journal).
local function ForceShowUncollected()
	if C_CVar.GetCVarBool("onlyShowCollectedItemsInJournal") then
		C_CVar.SetCVar("onlyShowCollectedItemsInJournal", "0");
	end

	C_MountJournal.SetCollectedFilterSetting(LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED, true);
	-- Unlike the other journals, Forever's Pet Journal also defaults LE_PET_JOURNAL_FILTER_COLLECTED
	-- to false (not just NOT_COLLECTED), so its "IsDefaultCallback" (Collected AND NotCollected) can
	-- never report true without also forcing this one on.
	C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED, true);
	C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED, true);
	C_ToyBox.SetUncollectedShown(true);
	C_TransmogCollection.SetUncollectedShown(true);

	ValidateDropdownResetState(MountJournal and MountJournal.FilterDropdown);
	ValidateDropdownResetState(PetJournal and PetJournal.FilterDropdown);
	ValidateDropdownResetState(ToyBox and ToyBox.FilterDropdown);
end

-- Camelot/Blizzard_Wardrobe.lua overrides WardrobeCollectionFrameMixin:InitItemsFilterButtonSetupMenu
-- to force C_TransmogCollection.SetUncollectedShown(false) every time the filter menu opens, and
-- skips creating the Collected/Not Collected checkboxes entirely. Restore the Standard behavior.
--
-- WardrobeCollectionFrame is built from XML with mixin="WardrobeCollectionFrameMixin", which copies
-- the mixin's functions onto the frame *once* when the frame is created (during Blizzard_Collections'
-- own load), before our ADDON_LOADED handler runs. So patching the shared mixin table here is too
-- late for that already-created instance; the frame must be patched directly.
local function InitItemsFilterButtonSetupMenu(self, dropdown, rootDescription, CreateSourceFilters)
	rootDescription:CreateCheckbox(COLLECTED, C_TransmogCollection.GetCollectedShown, function()
		C_TransmogCollection.SetCollectedShown(not C_TransmogCollection.GetCollectedShown());
	end);

	rootDescription:CreateCheckbox(NOT_COLLECTED, C_TransmogCollection.GetUncollectedShown, function()
		C_TransmogCollection.SetUncollectedShown(not C_TransmogCollection.GetUncollectedShown());
	end);

	CreateSourceFilters(rootDescription);
end

-- The FilterButton's red "reset to default" X is driven by whatever SetIsDefaultCallback returns.
-- Forever's InitItemsFilterButton (untouched by us) wires this to C_TransmogCollection.IsUsingDefaultFilters,
-- whose baked-in notion of "default" is uncollected-hidden, so it never reports true once we force
-- uncollected on and the X shows permanently. Replace it with our own definition of default that is
-- scoped to exactly what Forever's menu exposes: Collected, Not Collected, and per-source checkboxes.
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

-- Same mixin-copy timing issue as InitItemsFilterButtonSetupMenu: must patch the instance, and
-- reinitialize immediately so it takes effect without requiring a tab switch.
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

-- Forever only has ground mounts, but Mainline/Blizzard_MountCollection.lua's mount-Type submenu
-- (Ground/Flying/Aquatic/Dragonriding/Ride Along) is built unconditionally in MountJournal_InitFilterButton,
-- gated only by C_MountJournal.IsValidTypeFilter, which doesn't know to exclude those for this game type.
-- MountJournal_InitFilterButton is a bare global (not mixin-copied), but it's still called once from
-- MountJournal's OnLoad before we can override it, and that already-built SetupMenu closure won't
-- change just because the global function is reassigned - so re-run it against the live frame too.
local function InitMountFilterButton(self)
	-- If ForceShowUncollected() ran after OnLoad already hid this for a stale true CVar, restore it.
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
eventFrame:RegisterEvent("ADDON_LOADED");
eventFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
	if event == "PLAYER_LOGIN" then
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
