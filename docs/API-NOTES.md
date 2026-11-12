# API notes · WoW Forever 1.60.1 (70888)

Source: `github.com/Gethe/wow-ui-source`, branch `forever`, last commit "1.60.1 (70888)" (2026-11-10). Read on 2026-11-12 as plain text, nothing executed. Signatures were pulled with `tools/extract_api.py` from `Interface/AddOns/Blizzard_APIDocumentationGenerated/*.lua` (`?` = nilable).

## Differences from the plan (PLAN-ADDON-FABLE.md)

1. **No `TransmogCollectionDocumentation.lua` exists.** `C_TransmogCollection` (84 functions) is documented in `TransmogItemsDocumentation.lua`. `AppearanceSourceInfo` lives in `AppearanceSourceDocumentation.lua`.
2. **`GetCategoryAppearances` has a third argument**: `option: TransmogOutfitSlotOption?`. Blizzard's own UI passes `transmogLocation:GetData()` (a plain table), not the mixin (`Blizzard_Collections/Mainline/Blizzard_Wardrobe.lua:1201`). We pass `nil` for armor slots.
3. **Biggest new risk: Forever hides uncollected appearances on purpose.** `Blizzard_Collections/Camelot/Blizzard_Wardrobe.lua` overrides the filter menu with `C_TransmogCollection.SetUncollectedShown(false)` and `SetCollectedShown(true)`, and hides the progress bar. If the server does not send uncollected data, the "missing" list is empty. The addon saves both flags, sets `SetUncollectedShown(true)` for its own scan and restores them in the same `pcall` (see `Collection.lua`). Self-test **E** measures both counts.
4. `GetCategoryAppearances` rows do **not** carry an `itemID`. Armor type and level come from `GetAppearanceSources(visualID, category)` → `itemID` → `C_Item.GetItemInfoInstant`.
5. `Enum.ItemTryOnReason` is referenced by the DressUpModel docs but its definition is not in the generated docs of this branch. Code only compares against it when it exists.
6. `TransmogUtil.CreateTransmogLocation` (in `Blizzard_TransmogShared/Blizzard_TransmogShared.lua:168`) now calls `C_TransmogOutfitInfo.GetTransmogOutfitSlotFromInventorySlot`. The addon does not build locations in 0.1.
7. The add-on compartment exists in Forever (`Blizzard_Minimap/Camelot/AddonCompartment.lua`), so `AddonCompartmentFunc` is a valid zero-library minimap entry.
8. `ScrollBox` is present: `CreateScrollBoxListLinearView(top, bottom, left, right, spacing)` in `Blizzard_SharedXML/Shared/Scroll/ScrollBoxLinearView.lua:246`; `ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)` in `ScrollUtil.lua:137`. No need for `FauxScrollFrame`.
9. UI templates used by the window all exist on `forever`: `BasicFrameTemplateWithInset` (`Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml`), `UIPanelButtonTemplate` (`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`), `UICheckButtonTemplate` (`Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml`), `SearchBoxTemplate` (`Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml`), `WowScrollBoxList` (`Shared/Scroll/ScrollTemplates.xml`), `MinimalScrollBar` (`Shared/Scroll/MinimalScrollBar.xml`). The title FontString key was not confirmed, so the code creates its own if `TitleText` is missing.
10. Nearly every function carries `SecretArguments = AllowedWhenUntainted`. Our calls come from untainted addon code outside combat, so this should not bite; scans still pause in combat.

## Functions used (file: `TransmogItemsDocumentation.lua` unless noted)

| Function | Signature (copied) | Flags |
|---|---|---|
| GetCategoryAppearances | `(category: TransmogCollectionType, transmogLocation: TransmogLocation?, option: TransmogOutfitSlotOption?) -> appearances: table<TransmogCategoryAppearanceInfo>` | MayReturnNothing |
| GetClassFilter | `() -> classID: number` | |
| SetClassFilter | `(classID: number) -> nil` | |
| GetUncollectedShown / SetUncollectedShown | `() -> shown: bool` / `(shown: bool) -> nil` | new in notes |
| GetCollectedShown / SetCollectedShown | `() -> shown: bool` / `(shown: bool) -> nil` | new in notes |
| GetAppearanceSources | `(appearanceID: number, categoryType: TransmogCollectionType?, transmogLocation: TransmogLocation?) -> sources: table<AppearanceSourceInfo>` | MayReturnNothing |
| GetAllAppearanceSources | `(itemAppearanceID: number) -> itemModifiedAppearanceIDs: table<number>` | |
| GetSourceInfo | `(sourceID: number) -> sourceInfo: AppearanceSourceInfo` | MayReturnNothing |
| GetValidAppearanceSourcesForClass | `(appearanceID: number, classID: number, categoryType: TransmogCollectionType?, transmogLocation: TransmogLocation?) -> sources: table<AppearanceSourceInfo>` | MayReturnNothing |
| GetCategoryInfo | `(category) -> name: cstring, isWeapon: bool, canHaveIllusions: bool, canMainHand: bool, canOffHand: bool, canRanged: bool` | MayReturnNothing |
| GetCategoryCollectedCount / GetCategoryTotal | `(category) -> count: number` / `-> total: number` | |
| PlayerHasTransmogItemModifiedAppearance | `(itemModifiedAppearanceID: number) -> hasTransmog: bool` | |
| GetSourceIcon | `(itemModifiedAppearanceID: number) -> icon: fileID` | MayReturnNothing |
| C_Item.GetItemInfoInstant (`ItemDocumentation.lua`) | `(itemInfo) -> itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID` | MayReturnNothing |
| C_Item.GetItemInfo (`ItemDocumentation.lua`) | `(itemInfo) -> itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, …, classID, subclassID, …` | async |
| C_Item.GetItemSubClassInfo | `(itemClassID, itemSubClassID) -> subClassName: cstring, subClassUsesInvType: bool` | |
| C_TransmogOutfitInfo.GetOutfitsInfo (`TransmogOutfitInfoDocumentation.lua`) | `() -> outfitsInfo: table<TransmogOutfitEntryInfo>` | MayReturnNothing |
| C_TransmogSets | 42 functions, e.g. `GetAllSets() -> sets: table<TransmogSetInfo>` (`TransmogSetsDocumentation.lua`) | not used in 0.1 |

**TransmogCategoryAppearanceInfo**: `visualID, isCollected, isFavorite, isHideVisual, canDisplayOnPlayer, uiOrder, exclusions, isUsable, hasRequiredHoliday, hasActiveRequiredHoliday, minIlvl, isValidForEquippedItem, alwaysShowItem?`

**AppearanceSourceInfo**: `visualID, sourceID, isCollected, itemID, itemModID, invType, categoryID, playerCanCollect, isValidSourceForPlayer, canDisplayOnPlayer, inventorySlot?, sourceType?, name?, quality?, useError?, useErrorType?, meetsTransmogPlayerCondition?, isHideVisual?, isValidForEquippedItem?`

**TransmogOutfitEntryInfo**: `outfitID, name, situationCategories, icon, isEventOutfit, isDisabled, playerFacingOutfitIndex` (matches the plan).

**Enum.TransmogCollectionType**: None 0, Head 1, Shoulder 2, Back 3, Chest 4, Shirt 5, Tabard 6, Wrist 7, Hands 8, Waist 9, Legs 10, Feet 11, Wand 12 … Paired 29 (matches the plan).

**Enum.TransmogUseErrorType** (`TransmogSharedDocumentation.lua`): None 0, PlayerCondition 1, Skill 2, Ability 3, Reputation 4, Holiday 5, HotRecheckFailed 6, …

## DressUpModel (`FrameAPIDressUpModelDocumentation.lua`)
`TryOn(linkOrItemModifiedAppearanceID: IDOrLink, handSlotName: cstring?, spellEnchantID: number?) -> result: ItemTryOnReason?` · `Undress()` · `UndressSlot(inventorySlot)` · `Dress()` · `SetItemTransmogInfo(itemTransmogInfo, inventorySlot?, ignoreChildItems = false) -> result` · `SetAutoDress(enabled)` · `SetUseTransmogChoices(enabled)` · `GetItemTransmogInfoList()`. `SetUnit` comes from the base model API (not in this file).

## Events
`TRANSMOG_COLLECTION_UPDATED(collectionIndex?, modID?, itemAppearanceID?, reason?)` · `TRANSMOG_COLLECTION_SOURCE_ADDED(itemModifiedAppearanceID)` · `TRANSMOG_COLLECTION_SOURCE_REMOVED(itemModifiedAppearanceID)` · `TRANSMOG_SOURCE_COLLECTABILITY_UPDATE(itemModifiedAppearanceID, collectable)` · `TRANSMOG_OUTFITS_CHANGED(newOutfitID?)` · `ITEM_DATA_LOAD_RESULT(itemID, success)` (`ItemDocumentation.lua:1857`). All match the plan.

## External libraries (checked 2026-11-12)
| Library | URL (`.pkgmeta`) | Responds | License |
|---|---|---|---|
| LibStub | `https://repos.wowace.com/wow/libstub/trunk` | 200 (with trailing slash; 301 without) | Public domain (file header) |
| CallbackHandler-1.0 | `https://repos.wowace.com/wow/callbackhandler/trunk/CallbackHandler-1.0` | 200 | Ace3 style BSD |
| LibDataBroker-1.1 | `https://github.com/tekkub/libdatabroker-1-1` | 200 | **None declared**: GitHub shows no license, the repo has only the .lua and README.textile, last push 2015 |
| LibDBIcon-1.0 | `https://repos.wowace.com/wow/libdbicon-1-0/trunk/LibDBIcon-1.0` | 200 | Ace3 style BSD |

Because LibDataBroker has no declared license, 0.1 ships **without bundled libraries**: the TOC lists none, the minimap entry is the native add-on compartment, and `UI/Minimap.lua` uses LibDBIcon only if another addon already loaded it. The externals stay commented in `.pkgmeta` until Juan decides.
