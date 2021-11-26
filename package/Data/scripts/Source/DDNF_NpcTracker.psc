;
; The purpose of this script and its "child" script DDNF_NpcTracker_NPC is to track a
; variable number of NPCs that are in the loaded area and have devious devices equipped.
; Oh, how I long for the RefCollectionAlias that is available in Fallout 4 :-P.
;
Scriptname DDNF_NpcTracker extends Quest

DDNF_MainQuest Property MainQuest Auto
Actor Property Player Auto
Faction Property DeviceTargets Auto
Faction Property Helpless Auto
Faction Property UnarmedCombatants Auto
FormList Property WeaponDisplayArmors Auto
Keyword Property TrackingKeyword Auto
Package Property Sandbox Auto
Package Property BoundCombatNPCSandbox Auto
Package Property BoundNPCSandbox Auto
Weapon Property DummyWeapon Auto
zadLibs Property DDLibs Auto
Message Property ManipulatePanelGagInstead Auto

Bool Property UseBoundCombat Auto
Bool Property EnablePapyrusLogging = False Auto Conditional
Bool Property RestoreOriginalOutfit = False Auto
Bool Property AllowManipulationOfDevices = True Auto

Float Property MaxFixupsPerThreeSeconds = 3.0 Auto

Alias[] _cachedAliases ; performance optimization
Form[] _cachedNpcs ; performance optimization
Int _attemptedFixupsInPeriod
Armor[] _dcurSpecialHandlingDevices


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
    RefreshWeaponDisplayArmors()
    If (Game.GetFormFromFile(0x024495, "Deviously Cursed Loot.esp") == None) ; dcur_mainlib
        _dcurSpecialHandlingDevices = new Armor[1]
    Else
        _dcurSpecialHandlingDevices = DDNF_DcurShim.GetSpecialHandlingDevices()
    EndIf
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


Function ClearStorageUtilData()
    If (EnablePapyrusLogging)
        Debug.Trace("[DDNF] StorageUtil: ClearAllPrefix(ddnf_)")
    EndIf
    StorageUtil.ClearAllPrefix("ddnf_")
EndFunction


Function HandleDeviceEquipped(Actor akActor, Armor inventoryDevice, Bool checkForNotEquippedBug)
    If (Add(akActor) >= 0 && checkForNotEquippedBug)
        ; workaround for the OnContainerChanged event not firing, causing the device to not getting equipped
        ; this seems to be a "random" engine bug and can be fixed by dropping the object
        ; it seems to happen more often (?) if the player has multiple copies of the item, and/or if the item has recently been acquired
        Utility.Wait(2.0)
        Armor renderedDevice = DDNF_NpcTracker.GetRenderedDevice(inventoryDevice, false)
        If (renderedDevice != None && akActor.GetItemCount(renderedDevice) == 0)
            ; it's not equipped, equip it, but first recheck if inventory device has been removed
            If (akActor.GetItemCount(inventoryDevice) > 0)
                If (EnablePapyrusLogging)
                    Debug.Trace("[DDNF] Bug workaround: Equipping " + DDNF_NpcTracker_NPC.GetFormIdAsString(inventoryDevice) + " " + inventoryDevice.GetName() + " on " + DDNF_NpcTracker_NPC.GetFormIdAsString(akActor) + " " + akActor.GetDisplayName() + ".")
                EndIf
                ; sometimes items become "corrupt" and the game will lose the script
                ; dropping the item may or may not help
                ObjectReference item = akActor.DropObject(inventoryDevice)
                If ((item as zadEquipScript) == None)
                    If (EnablePapyrusLogging)
                        Debug.Trace("[DDNF] Replacing corrupt device " + DDNF_NpcTracker_NPC.GetFormIdAsString(item) + ".")
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


Function HandleDeviceSelectedInContainerMenu(Actor npc, Armor inventoryDevice, Armor renderedDevice)
    If (!AllowManipulationOfDevices || inventoryDevice.HasKeyword(ddLibs.zad_BlockGeneric) || inventoryDevice.HasKeyword(ddLibs.zad_QuestItem))
        Return ; do not manipulate quest devices
    EndIf
    If (_dcurSpecialHandlingDevices[0] != None)
        Int dcurDeviceIndex = _dcurSpecialHandlingDevices.Find(inventoryDevice)
        If (dcurDeviceIndex >= 0)
            ; handle device using the cursed loot shim
            DDNF_DcurShim.HandleDeviceSelectedInContainerMenu(Self, npc, inventoryDevice, renderedDevice, _dcurSpecialHandlingDevices, dcurDeviceIndex)
            Return
        EndIf
    EndIf
    If (renderedDevice.HasKeyword(ddLibs.zad_DeviousGagPanel))
        ; allow player to remove/insert panel gag plug
        If (CheckIfUnequipPossible(npc, renderedDevice))
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


Bool Function CheckIfUnequipPossible(Actor npc, Armor renderedDevice)
    Armor[] devices = new Armor[1]
    devices[0] = renderedDevice
    Bool[] unequipPossible = new Bool[1]
    DDNF_NpcTracker_NPC.CheckIfUnequipPossible(npc, devices, unequipPossible, 1, DDLibs, false)
    Return unequipPossible[0]
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


DDNF_NpcTracker Function Get() Global
    Return Game.GetFormFromFile(0x00001827, "DD_NPC_Fixup.esp") as DDNF_NpcTracker
EndFunction


Armor Function GetRenderedDevice(Armor maybeInventoryDevice, Bool fromCacheOnly) Global
    Armor renderedDevice = StorageUtil.GetFormValue(renderedDevice, "ddnf_r", None) as Armor
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


Armor Function TryGetInventoryDevice(Armor renderedDevice) Global
    Return StorageUtil.GetFormValue(renderedDevice, "ddnf_i", None) as Armor
EndFunction


Function LinkInventoryDeviceAndRenderedDevice(Armor inventoryDevice, Armor renderedDevice, Bool enablePapyrusLogging) Global
    If (enablePapyrusLogging)
        String inventoryFormId = DDNF_NpcTracker_NPC.GetFormIdAsString(inventoryDevice)
        String renderedFormId = DDNF_NpcTracker_NPC.GetFormIdAsString(renderedDevice)
        Debug.Trace("[DDNF] StorageUtil: SetFormValue(" + inventoryFormId + ", ddnf_r, " + renderedFormId + ")")
        Debug.Trace("[DDNF] StorageUtil: SetFormValue(" + renderedFormId + ", ddnf_i, " + inventoryFormId + ")")
    EndIf
    StorageUtil.SetFormValue(inventoryDevice, "ddnf_r", renderedDevice)
    StorageUtil.SetFormValue(renderedDevice, "ddnf_i", inventoryDevice)
EndFunction
