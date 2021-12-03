;
; The purpose of this script and its "child" script DDNF_NpcTracker_NPC is to track a
; variable number of NPCs that are in the loaded area and have devious devices equipped.
; Oh, how I long for the RefCollectionAlias that is available in Fallout 4 :-P.
;
Scriptname DDNF_NpcTracker extends Quest

DDNF_MainQuest Property MainQuest Auto
Actor Property Player Auto
Faction Property CurrentFollowerFaction Auto
Faction Property DeviceTargets Auto
Faction Property Helpless Auto
Faction Property UnarmedCombatants Auto
FormList Property WeaponDisplayArmors Auto
Keyword Property TrackingKeyword Auto
Message Property ManipulatePanelGagInstead Auto
Package Property FollowerPackageTemplate Auto
Package Property Sandbox Auto
Package Property BoundCombatNPCSandbox Auto
Package Property BoundNPCSandbox Auto
Weapon Property DummyWeapon Auto
zadLibs Property DDLibs Auto

Bool Property IsEnabled = True Auto
Bool Property UseBoundCombat Auto
Bool Property EnablePapyrusLogging = False Auto
Bool Property FixInconsistentDevices = True Auto
Bool Property RestoreOriginalOutfit = False Auto
Bool Property AllowManipulationOfDevices = True Auto
Bool Property EscapeSystemEnabled = False Auto
Bool Property StruggleIfPointless = False Auto
Int Property AbortStrugglingAfterFailedDevices = 3 Auto ; 0 disables
Int Property CurrentFollowerStruggleFrequency = 2 Auto ; 0 disables
Bool Property NotifyPlayerOfCurrentFollowerStruggle = True Auto
Bool Property OnlyDisplayFinalSummaryMessage = True Auto
Int Property OtherNpcStruggleFrequency = 0 Auto ; 0 disables

Float Property MaxFixupsPerThreeSeconds = 3.0 Auto

Int Property DeviousDevicesIntegrationModId Auto
Int Property DawnguardModId Auto
Int Property DeviouslyCursedLootModId Auto
Int Property DeviousContraptionsModId Auto

Alias[] _cachedAliases ; performance optimization
Form[] _cachedNpcs ; performance optimization
Int _attemptedFixupsInPeriod


DDNF_NpcTracker Function Get() Global
    Return Game.GetFormFromFile(0x00001827, "DD_NPC_Fixup.esp") as DDNF_NpcTracker
EndFunction


Alias[] Function GetAliases()
    If (_cachedAliases.Length == 0)
        Int count = GetNumAliases()
        Alias[] aliases = Utility.CreateAliasArray(count)
        Int index = 0
        While (index < count)
            aliases[index] = GetNthAlias(index)
            index += 1
        EndWhile
        _cachedAliases = aliases
    EndIf
    Return _cachedAliases
EndFunction


Form[] Function GetNpcs()
    If (_cachedNpcs.Length == 0)
        Alias[] aliases = GetAliases()
        Form[] npcs = Utility.CreateFormArray(aliases.Length)
        Int index = 0
        While (index < aliases.Length)
            npcs[index] = (aliases[index] as ReferenceAlias).GetReference()
            index += 1
        EndWhile
        _cachedNpcs = npcs
    EndIf
    Return _cachedNpcs
EndFunction


Function HandleGameLoaded(Bool upgrade)
    If (upgrade)
        IsEnabled = IsRunning()
        ; stop further fixups until the upgrade is done
        UnregisterForUpdate()
        _attemptedFixupsInPeriod = 9999
        ; refresh alias array/npc array if doing upgrade, number of aliases may have changed
        Alias[] emptyAliasArray
        _cachedAliases = emptyAliasArray
        Form[] emptyFormArray
        _cachedNpcs = emptyFormArray
        ; clear StorageUtil data
        ClearStorageUtilData()
    EndIf
    ; refresh soft dependencies
    RefreshWeaponDisplayArmors()
    DeviousDevicesIntegrationModId = Game.GetModByName("Devious Devices - Integration.esm")
    DawnguardModId = Game.GetModByName("Dawnguard.esm")
    DeviouslyCursedLootModId = Game.GetModByName("Deviously Cursed Loot.esp")
    DeviousContraptionsModId = Game.GetModByName("Devious Devices - Contraptions.esm")
    ; notify all alias scripts
    Int index = 0
    Alias[] aliases = GetAliases()
    Form[] npcs = GetNpcs()
    While (index < aliases.Length)
        (aliases[index] as DDNF_NpcTracker_NPC).HandleGameLoaded(upgrade)
        index += 1
    EndWhile
    ; refresh options (might notify all alias scripts again
    ValidateOptions()
    ; done
    If (upgrade)
        _attemptedFixupsInPeriod = 0
    EndIf
EndFunction

Function ClearStorageUtilData()
    StorageUtil.ClearAllPrefix("ddnf_")
    If (EnablePapyrusLogging)
        Debug.Trace("[DDNF] StorageUtil: ClearAllPrefix(ddnf_)")
    EndIf
EndFunction

Function RefreshWeaponDisplayArmors()
    WeaponDisplayArmors.Revert()
    AddWeaponDisplayArmorsFromFormList("All Geared Up Derivative.esp", 0x02E0EE)
EndFunction

Function AddWeaponDisplayArmorsFromFormList(string fileName, Int formId)
    Formlist armorList = Game.GetFormFromFile(formId, fileName) as FormList
    If (armorList != None)
        Int index = 0
        Int end = armorList.GetSize()
        While (index < end)
            Armor armorForm = armorList.GetAt(index) as Armor
            If (armorForm != None)
                WeaponDisplayArmors.AddForm(armorForm)
            EndIf
            index += 1
        EndWhile
    EndIf
EndFunction


Function HandleJournalMenuClosed()
    ValidateOptions()
EndFunction

Function ValidateOptions()
    Bool newUseBoundCombat = DDLibs.Config.UseBoundCombat
    If (useBoundCombat != newUseBoundCombat)
        UseBoundCombat = newUseBoundCombat
        If (EnablePapyrusLogging)
            Debug.Trace("[DDNF] Looping over aliases after relevant change to options.")
        EndIf
        Int index = 0
        Alias[] aliases = GetAliases()
        While (index < aliases.Length)
            (aliases[index] as DDNF_NpcTracker_NPC).HandleOptionsChanged(newUseBoundCombat)
            index += 1
        EndWhile
    EndIf
EndFunction


;
; Queue a NPC for fixup. This will add the NPC to the tracked NPCs if necessary.
;
Int Function QueueForFixup(Actor npc)
    Form[] npcs = GetNpcs()
    Int index = npcs.Find(npc)
    If (index >= 0)
        Alias[] aliases = GetAliases()
        ReferenceAlias refAlias = aliases[index] as ReferenceAlias
        (refAlias as DDNF_NpcTracker_NPC).OnCellDetach()
        (refAlias as DDNF_NpcTracker_NPC).OnCellAttach()
        Return index
    EndIf
    Return Add(npc)
EndFunction


;
; Add a NPC to the tracked NPCs.
; Caller should check that the NPC is alive and loaded; failing that will not
; cause problems though, it will just needlessly cause some script load.
; Returns the index if the actor was is tracked (either newly, or already was), -1 on failure
;
Int Function Add(Actor npc)
    If (!IsEnabled)
        Return -1
    EndIf
    ; check if the NPC is already in an alias
    If (npc == Player) ; catch api misuse
        Return -1
    EndIf
    Form[] npcs = GetNpcs()
    Int index = npcs.Find(npc)
    If (index >= 0)
        Return index
    EndIf
    ; try to find a free alias and put the NPC into the alias
    Alias[] aliases = GetAliases()
    index = npcs.Find(None)
    While (index >= 0)
        npcs[index] = npc
        If ((aliases[index] as ReferenceAlias).ForceRefIfEmpty(npc)) ; can fail if the reference has been filled in the meantime
            Return index
        EndIf
        npcs[index] = (aliases[index] as ReferenceAlias).GetReference() ; fix array
        index = npcs.Find(npc)
        If (index >= 0)
            Return index
        EndIf
        index = npcs.Find(None)
    EndWhile
    ; unable to track, all reference aliases were full :(
    ; the mod will probably misbehave but hopefully not in too bad a way
    Return -1
EndFunction


;
; Remove all tracked NPCs.
;
Function Clear(Bool clearStorageUtilData)
    If (clearStorageUtilData)
        ClearStorageUtilData()
    EndIf
    Int index = 0
    Alias[] aliases = GetAliases()
    While (index < aliases.Length)
        ReferenceAlias refAlias = aliases[index] as ReferenceAlias
        refAlias.Clear()
        index += 1
    EndWhile
EndFunction


;
; Called when a device is equipped on a NPC.
;
Function HandleDeviceEquipped(Actor akActor, Armor inventoryDevice, Bool checkForNotEquippedBug)
    Int index = GetNpcs().Find(akActor)
    If (index < 0)
        index = Add(akActor)
        If (index >= 0)
            DDNF_NpcTracker_NPC tracker = GetAliases()[index] as DDNF_NpcTracker_NPC
            tracker.KickEscapeSystem(true)
        EndIf
    EndIf
    If (index >= 0 && checkForNotEquippedBug)
        ; workaround for the OnContainerChanged event not firing, causing the device to not getting equipped
        ; this seems to be a "random" engine bug and can be fixed by dropping the object
        ; it seems to happen more often (?) if the player has multiple copies of the item, and/or if the item has recently been acquired
        Utility.WaitMenuMode(2.0)
        Armor renderedDevice = DDNF_NpcTracker.GetRenderedDevice(inventoryDevice, false)
        If (renderedDevice != None && akActor.GetItemCount(renderedDevice) == 0)
            ; it's not equipped, equip it, but first recheck if inventory device has been removed
            If (akActor.GetItemCount(inventoryDevice) > 0)
                If (EnablePapyrusLogging)
                    Debug.Trace("[DDNF] Bug workaround: Equipping " + DDNF_Game.FormIdAsString(inventoryDevice) + " " + inventoryDevice.GetName() + " on " + DDNF_Game.FormIdAsString(akActor) + " " + akActor.GetDisplayName() + ".")
                EndIf
                ; sometimes items become "corrupt" and the game will lose the script
                ; dropping the item may or may not help
                ObjectReference item = akActor.DropObject(inventoryDevice)
                If ((item as zadEquipScript) == None)
                    If (EnablePapyrusLogging)
                        Debug.Trace("[DDNF] Replacing corrupt device " + DDNF_Game.FormIdAsString(item) + ".")
                    EndIf
                    item.DisableNoWait()
                    item.Delete()
                    akActor.AddItem(inventoryDevice, 1, true)
                Else
                    akActor.AddItem(item, 1, true)
                EndIf
                DDLibs.LockDevice(akActor, inventoryDevice)
            EndIf
        EndIf
    EndIf
EndFunction


;
; Called when player selects a device that is equipped on a NPC in container menu.
;
Function HandleDeviceSelectedInContainerMenu(Actor npc, Armor inventoryDevice, Armor renderedDevice)
    If (!AllowManipulationOfDevices || inventoryDevice.HasKeyword(ddLibs.zad_BlockGeneric) || inventoryDevice.HasKeyword(ddLibs.zad_QuestItem))
        Return ; do not manipulate quest devices
    EndIf
    Int inventoryDeviceModId = DDNF_Game.GetModId(inventoryDevice.GetFormID())
    If (inventoryDeviceModId == DeviouslyCursedLootModId && DDNF_DcurShim.HandleDeviceSelectedInContainerMenu(Self, npc, inventoryDevice, renderedDevice))
        Return
    EndIf
    If (renderedDevice.HasKeyword(ddLibs.zad_DeviousGagPanel))
        ; allow player to remove/insert panel gag plug
        If (DDNF_NpcTracker_NPC.CheckIfUnequipPossible(npc, inventoryDevice, renderedDevice, DDLibs, false, false))
            Int selection = ManipulatePanelGagInstead.Show()
            If (selection > 0 && EnsureDeviceStillEquippedAfterPlayerSelection(npc, inventoryDevice, renderedDevice))
                If (selection == 1) ; remove plug
                    If (npc.GetItemCount(ddLibs.zad_gagPanelPlug) == 0)
                        npc.AddItem(ddLibs.zad_gagPanelPlug, 1)
                    EndIf
                    npc.SetFactionRank(ddLibs.zadGagPanelFaction, 0)
                Else ; insert plug
                    npc.RemoveItem(ddLibs.zad_gagPanelPlug, 1)
                    npc.SetFactionRank(ddLibs.zadGagPanelFaction, 1)
                EndIf
            EndIf
        EndIf
    EndIf
EndFunction

Bool Function EnsureDeviceStillEquippedAfterPlayerSelection(Actor npc, Armor inventoryDevice, Armor renderedDevice)
    If (npc.GetItemCount(renderedDevice) > 0)
        Return true
    EndIf
    If (Player.GetItemCount(inventoryDevice) > 0)
        Int index = Add(npc)
        If (index >= 0)
            Armor[] devices = new Armor[1]
            devices[0] = inventoryDevice
            If ((GetAliases()[index] as DDNF_NpcTracker_NPC).QuickEquipDevices(devices, 1, true) == 1)
                Player.RemoveItem(inventoryDevice, aiCount=1, abSilent=true)
                Return true
            EndIf
        EndIf
    EndIf
    Return false
EndFunction


;
; Unequip a device from an NPC, with correct handling of soft dependencies.
;
Bool Function UnlockDevice(Actor npc, Armor inventoryDevice, Armor renderedDevice, Keyword deviceKeyword)
    Int inventoryDeviceModId = DDNF_Game.GetModId(inventoryDevice.GetFormID())
    If (inventoryDeviceModId == DeviouslyCursedLootModId && DDNF_DcurShim.UnlockDevice(Self, npc, inventoryDevice, renderedDevice, deviceKeyword))
        Return true
    EndIf
    Return DDLibs.UnlockDevice(npc, inventoryDevice, renderedDevice, deviceKeyword, false, true)
EndFunction


;
; Check if a NPC is in a contraption (soft dependency).
;
ObjectReference Function TryGetCurrentContraption(Actor npc)
    If (DeviousContraptionsModId == 255)
        Return None
    EndIf
    Return DDNF_ZadcShim.TryGetCurrentContraption(npc)
EndFunction


;
; This function is called before doing a fixup to an NPC.
; It will return a value > 0 if too many fixups are running already, meaning that the mod needs to wait for
; the returned number of seconds before attempting the fixup again.
;
Float Function NeedToSlowDownBeforeFixup(Actor npc)
    ; allow up to (MaxFixupsPerThreeSeconds) fixups to start in a period of three seconds
    If (_attemptedFixupsInPeriod == 9999)
        Return 3 ; onging update
    EndIf
    _attemptedFixupsInPeriod += 1
    If (_attemptedFixupsInPeriod <= MaxFixupsPerThreeSeconds)
        If (_attemptedFixupsInPeriod == 1)
            RegisterForSingleUpdate(3.0) ; a new three-second period is starting now
        EndIf
        Return 0.0
    EndIf
    If (npc.IsPlayerTeammate())
        Return 1.0 ; retry with high priority for player teammates
    EndIf
    Return ((_attemptedFixupsInPeriod as Float) / MaxFixupsPerThreeSeconds) * 3.0 ; backoff, wait longer if more fixups have been tried
EndFunction

Event OnUpdate()
    _attemptedFixupsInPeriod = 0 ; reset to zero
EndEvent


;
; Get the rendered device for an inventory device.
;
Armor Function GetRenderedDevice(Armor maybeInventoryDevice, Bool fromCacheOnly) Global
    If (maybeInventoryDevice == None)
        Return None
    EndIf
    Armor renderedDevice = StorageUtil.GetFormValue(maybeInventoryDevice, "ddnf_r", None) as Armor
    If (renderedDevice == None && !fromCacheOnly)
        DDNF_NpcTracker tracker = Get()
        If (maybeInventoryDevice.HasKeyword(tracker.DDLibs.zad_InventoryDevice))
            renderedDevice = tracker.DDLibs.GetRenderedDevice(maybeInventoryDevice)
            If (renderedDevice != None)
                LinkInventoryDeviceAndRenderedDevice(maybeInventoryDevice, renderedDevice, tracker.EnablePapyrusLogging)
            EndIf
        EndIf
    EndIf
    Return renderedDevice
EndFunction


;
; Try to get the inventory device for a rendered device.
;
Armor Function TryGetInventoryDevice(Armor renderedDevice) Global
    If (renderedDevice == None)
        Return None
    EndIf
    Return StorageUtil.GetFormValue(renderedDevice, "ddnf_i", None) as Armor
EndFunction


;
; Cache link between rendered device and inventory device.
;
Function LinkInventoryDeviceAndRenderedDevice(Armor inventoryDevice, Armor renderedDevice, Bool enablePapyrusLogging) Global
    StorageUtil.SetFormValue(inventoryDevice, "ddnf_r", renderedDevice)
    StorageUtil.SetFormValue(renderedDevice, "ddnf_i", inventoryDevice)
    If (enablePapyrusLogging)
        String inventoryFormId = DDNF_Game.FormIdAsString(inventoryDevice)
        String renderedFormId = DDNF_Game.FormIdAsString(renderedDevice)
        Debug.Trace("[DDNF] StorageUtil: SetFormValue(" + inventoryFormId + ", ddnf_r, " + renderedFormId + ")")
        Debug.Trace("[DDNF] StorageUtil: SetFormValue(" + renderedFormId + ", ddnf_i, " + inventoryFormId + ")")
    EndIf
EndFunction
