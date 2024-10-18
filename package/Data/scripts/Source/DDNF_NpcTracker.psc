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
Faction Property EvadeCombat Auto
Faction Property Helpless Auto
Faction Property NpcFlags Auto
Faction Property Struggling Auto
Faction Property UnarmedCombatants Auto
FormList Property MassiveRacesList Auto
FormList Property WeaponDisplayArmors Auto
Keyword Property ActorTypeDragon Auto
Keyword Property MagicInfluenceCharm Auto
Keyword Property TrackingKeyword Auto
Keyword Property VendorItemArrow Auto
Message Property ManipulatePanelGagInstead Auto
Message Property LinkGlovesInstead Auto
Package Property FollowerPackageTemplate Auto
Package Property Sandbox Auto
Package Property BoundCombatNPCSandbox Auto
Package Property BoundNPCSandbox Auto
Weapon Property DummyWeapon Auto
zadLibs Property DDLibs Auto

Bool Property IsEnabled = True Auto
Bool Property UseBoundCombat Auto
Bool Property EnablePapyrusLogging = False Auto
Bool Property FixInconsistentDevicesOfNpcs = False Auto
Bool Property RestoreOriginalOutfit = False Auto
Bool Property AllowManipulationOfDevices = True Auto
Bool Property EscapeSystemEnabled = False Auto
Bool Property StruggleIfPointless = False Auto
Int Property AbortStrugglingAfterFailedDevices = 3 Auto ; 0 disables
Int Property CurrentFollowerStruggleFrequency = -1 Auto ; 0 disables, -1 for auto
Bool Property NotifyPlayerOfCurrentFollowerStruggle = True Auto
Bool Property OnlyDisplayFinalSummaryMessage = True Auto
Int Property OtherNpcStruggleFrequency = 0 Auto ; 0 disables, -1 for auto
Int Property AllowEscapeByPickingLocks = 1 Auto ; 0 disables, 1 current followers only, 2 all NPCs

Float Property MaxFixupsPerThreeSeconds = 3.0 Auto

Int Property DeviousDevicesIntegrationModId Auto
Int Property DawnguardModId Auto
Int Property DeviouslyCursedLootModId Auto
Int Property DeviousContraptionsModId Auto
Int Property PahModId Auto
Int Property PahExtensionModId Auto
Int Property PahDomModId Auto
Int Property PamaFurnitureModId Auto
Int Property ZadFurniturePlacerModId Auto
Bool Property IsDeviousDevicesNG Auto
Bool Property Po3PapyrusExtenderAvailable Auto
Keyword Property ZbfWornGag Auto
Keyword Property ZbfWornWrist Auto

Alias[] _cachedAliases ; performance optimization
Form[] _cachedNpcs ; performance optimization
Int _attemptedFixupsInPeriod


DDNF_NpcTracker Function Get() Global
    Return StorageUtil.GetFormValue(None, "DDNF_NpcTracker", None) as DDNF_NpcTracker
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
        ; stop further fixups until the upgrade is done
        UnregisterForUpdate()
        _attemptedFixupsInPeriod = 9999
        ; refresh alias array/npc array if doing upgrade, number of aliases may have changed
        Alias[] emptyAliasArray
        _cachedAliases = emptyAliasArray
        Form[] emptyFormArray
        _cachedNpcs = emptyFormArray
        ; clear StorageUtil data (will also register npctracker/externalapi)
        ClearStorageUtilData()
    Else
        ; register npctracker/externalapi if necessary (should already be registered)
        If (StorageUtil.GetFormValue(None, "DDNF_NpcTracker", None) as DDNF_NpcTracker == None)
            StorageUtil.SetFormValue(None, "DDNF_NpcTracker", Self)
            If (EnablePapyrusLogging)
                Debug.Trace("[DDNF] StorageUtil: SetFormValue(None, DDNF_NpcTracker, " + DDNF_Game.FormIdAsString(self) + ")")
            EndIf
        EndIf
        If (StorageUtil.GetFormValue(None, "DDNF_ExternalApi", None) as DDNF_ExternalApi == None)
            StorageUtil.SetFormValue(None, "DDNF_ExternalApi", (Self as Quest) as DDNF_ExternalApi)
            If (EnablePapyrusLogging)
                Debug.Trace("[DDNF] StorageUtil: SetFormValue(None, DDNF_ExternalApi, " + DDNF_Game.FormIdAsString(self) + ")")
            EndIf
        EndIf
    EndIf
    ; refresh soft dependencies
    RefreshWeaponDisplayArmors()
    DeviousDevicesIntegrationModId = Game.GetModByName("Devious Devices - Integration.esm")
    DawnguardModId = Game.GetModByName("Dawnguard.esm")
    If (DawnguardModId != 255)
        DDNF_DLC1Shim.AddMassiveRaces(MassiveRacesList)
    EndIf
    DeviouslyCursedLootModId = Game.GetModByName("Deviously Cursed Loot.esp")
    DeviousContraptionsModId = Game.GetModByName("Devious Devices - Contraptions.esm")
    PahModId = Game.GetModByName("paradise_halls.esm")
    PahExtensionModId = Game.GetModByName("paradise_halls_SLExtension.esp")
    PahDomModId = Game.GetModByName("DiaryOfMine.esp")
    PamaFurnitureModId = Game.GetModByName("PamaFurnitureScr.esp")
    ZadFurniturePlacerModId = Game.GetModByName("ZAPFurniturePlacer.esp")
    Quest zadNGQuest = Game.GetFormFromFile(0xA0000D, "Devious Devices - Expansion.esm") as Quest
    IsDeviousDevicesNG = zadNGQuest != None && zadNGQuest.GetID() == "zadNGQuest"
    Po3PapyrusExtenderAvailable = DDNF_Po3PapyrusExtenderShim.IsAvailable()
    If (Game.GetModByName("ZaZAnimationPack.esm"))
        ZbfWornGag = Game.GetFormFromFile(0x008A4D, "ZaZAnimationPack.esm") as Keyword
        ZbfWornWrist = Game.GetFormFromFile(0x008FB9, "ZaZAnimationPack.esm") as Keyword
    EndIf
    ; notify all alias scripts
    Int index = 0
    Alias[] aliases = GetAliases()
    Form[] npcs = GetNpcs()
    While (index < aliases.Length)
        DDNF_NpcTracker_NPC tracker = (aliases[index] as DDNF_NpcTracker_NPC)
        tracker.HandleGameLoaded(upgrade)
        Actor npc = tracker.GetReference() as Actor
        If (npcs[index] != npc) ; the game seems to sometimes clear aliases when loading auto-saves created by loading doors
            If (EnablePapyrusLogging)
                Debug.Trace("[DDNF] Detected bad data at npcs[" + index + "], fixing.")
            EndIf
            If (npc == None)
                npc = npcs[index] as Actor
                npcs[index] = None
                Add(npc)
            Else
                npcs[index] = npc
            EndIf
        EndIf
        index += 1
    EndWhile
    ; refresh options (might notify all alias scripts again
    ValidateOptions()
    ; done
    If (upgrade)
        _attemptedFixupsInPeriod = 0
        IsEnabled = IsRunning()
    EndIf
EndFunction

Function ClearStorageUtilData()
    StorageUtil.ClearAllPrefix("ddnf_")
    StorageUtil.SetFormValue(None, "DDNF_NpcTracker", Self)
    StorageUtil.SetFormValue(None, "DDNF_ExternalApi", (Self as Quest) as DDNF_ExternalApi)
    If (EnablePapyrusLogging)
        Debug.Trace("[DDNF] StorageUtil: ClearAllPrefix(ddnf_)")
        String formId = DDNF_Game.FormIdAsString(self)
        Debug.Trace("[DDNF] StorageUtil: SetFormValue(None, DDNF_NpcTracker, " + formId + ")")
        Debug.Trace("[DDNF] StorageUtil: SetFormValue(None, DDNF_ExternalApi, " + formId + ")")
    EndIf
EndFunction

Function RefreshWeaponDisplayArmors()
    WeaponDisplayArmors.Revert()
    AddWeaponDisplayArmorsFromFormList("All Geared Up Derivative.esp", 0x02E0EE)
EndFunction

Function AddWeaponDisplayArmorsFromFormList(string fileName, Int formId)
    If (Game.GetModByName(fileName) != 255)
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
Int Function QueueForFixup(Actor npc, Bool scanForDevices)
    Form[] npcs = GetNpcs()
    Int index = npcs.Find(npc)
    If (index >= 0)
        Alias[] aliases = GetAliases()
        ReferenceAlias refAlias = aliases[index] as ReferenceAlias
        If (scanForDevices)
            (refAlias as DDNF_NpcTracker_NPC).RegisterForFixupWithScan()
        Else
            (refAlias as DDNF_NpcTracker_NPC).RegisterForFixup()
        EndIf
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
    Alias[] emptyAliasArray
    _cachedAliases = emptyAliasArray
    Form[] emptyFormArray
    _cachedNpcs = emptyFormArray
EndFunction


;
; Called when a device is equipped on a NPC or the player.
;
Function HandleDeviceEquipped(Actor akActor, Armor inventoryDevice, Bool checkForNotEquippedBug)
    If (akActor == Player)
        If (DDLibs.GetDeviceKeyword(inventoryDevice) == ddLibs.zad_DeviousHeavyBondage)
            Int index = 0
            Alias[] aliases = GetAliases()
            While (index < aliases.Length)
                DDNF_NpcTracker_NPC tracker = GetAliases()[index] as DDNF_NpcTracker_NPC
                Actor npc = tracker.GetReference() as Actor
                If (npc && tracker.UpdateEvadeCombat(npc, Self))
                    npc.EvaluatePackage()
                EndIf
                index += 1
            EndWhile
        EndIf
        Return
    EndIf
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
; Called when a device is unequipped from a NPC or the player.
;
Function HandleDeviceRemoved(Actor akActor, Armor inventoryDevice)
    If (akActor == Player)
        If (DDLibs.GetDeviceKeyword(inventoryDevice) == ddLibs.zad_DeviousHeavyBondage)
            Utility.WaitMenuMode(2) ; because we get the event before the device is actually removed
            Int index = 0
            Alias[] aliases = GetAliases()
            While (index < aliases.Length)
                DDNF_NpcTracker_NPC tracker = GetAliases()[index] as DDNF_NpcTracker_NPC
                Actor npc = tracker.GetReference() as Actor
                If (npc && tracker.UpdateEvadeCombat(npc, Self))
                    npc.EvaluatePackage()
                EndIf
                index += 1
            EndWhile
        EndIf
        Return
    EndIf
    Utility.Wait(2) ; allow some time for things to work
    Armor renderedDevice = GetRenderedDevice(inventoryDevice, false)
    If (akActor.GetItemCount(renderedDevice) == 0)
        String storageUtilTag = "ddnf_e_t" + DDNF_NpcTracker.GetOrCreateUniqueTag(inventoryDevice)
        If (StorageUtil.HasFloatValue(akActor, storageUtilTag))
            StorageUtil.UnsetFloatValue(akActor, storageUtilTag)
            If (EnablePapyrusLogging)
                Debug.Trace("[DDNF] StorageUtil: UnsetFloatValue(" + DDNF_Game.FormIdAsString(akActor) + ", " + storageUtilTag + ")")
            EndIf
        EndIf
    EndIf
EndFunction

;
; Called when an actor is locked into or unlocked from a devious contraption, if the contraption has SendDeviceModEvents == true.
; It is false by default but we are trying to detect locking by observing package changes and then set it to true.
;
Function HandleDeviceEvent(Actor akActor, ObjectReference deviousContraption, Bool lock)
    If (akActor != Player)
        Int index = GetNpcs().Find(akActor)
        If (index >= 0)
            DDNF_NpcTracker_NPC tracker = GetAliases()[index] as DDNF_NpcTracker_NPC
            tracker.RegisterForFixup()
        EndIf
    EndIf
EndFunction

;
; Called after each scanner run of the main quest.
;
Function HandleScannerFinished(Int counter)
    Alias[] aliases = _cachedAliases
    Form[] npcs = _cachedNpcs
    If (aliases.Length > 0 && npcs.Length > 0)
        Int offset = (counter % 268435454) * 8
        Int index = 0
        While (index < 8)
            ; detect and fix bad data in _cachedNpcs
            Int arrayIndex = (offset + index) % aliases.Length
            DDNF_NpcTracker_NPC tracker = (aliases[arrayIndex] as DDNF_NpcTracker_NPC)
            Actor npc = tracker.GetReference() as Actor
            If (npcs[arrayIndex] != npc) ; the game seems to sometimes clear aliases when loading auto-saves created by loading doors
                If (EnablePapyrusLogging)
                    Debug.Trace("[DDNF] Detected bad data at npcs[" + arrayIndex + "], fixing.")
                EndIf
                npcs[arrayIndex] = npc
            EndIf
            If (npc != None)
                ; handle missed events
                If (npc.IsDead())
                    tracker.Clear()
                ElseIf (!npc.Is3DLoaded() || npc.IsDead())
                    If (!tracker.IsWaitingForFixup())
                        tracker.RegisterForFixup(16)
                    EndIf
                EndIf
            EndIf
            index += 1
        EndWhile
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
; Get one or multiple bits of a faction rank, supported bitmap need to be in the range [1, 127].
;
Int Function GetFactionBits(Actor npc, Faction bitmapFaction, Int bitmap) Global
    Int factionRank = npc.GetFactionRank(bitmapFaction)
    If (factionRank > 0)
        Return Math.LogicalAnd(factionRank, bitmap)
    EndIf
    Return 0
EndFunction


;
; Update one or multiple bits of a faction rank, supported bitmap need to be in the range [1, 127], value needs to be subset of bitmap.
;
Function UpdateFactionBits(Actor npc, Faction bitmapFaction, Int bitmap, Int value) Global
    Int factionRank = npc.GetFactionRank(bitmapFaction)
    If (factionRank > 0)
        Int newFactionRank = Math.LogicalOr(Math.LogicalAnd(factionRank, Math.LogicalNot(bitmap)), value)
        If (newFactionRank == 0)
            npc.RemoveFromFaction(bitmapFaction)
        ElseIf (newFactionRank != factionRank)
            npc.SetFactionRank(bitmapFaction, newFactionRank)
        EndIf
    ElseIf (value > 0)
        npc.SetFactionRank(bitmapFaction, value)
    EndIf
EndFunction


;
; Check whether the NPC should be ignored by the mod.
;
Bool Function IgnoreNpc(Actor npc)
    Return GetFactionBits(npc, NpcFlags, 0x40) == 0x40
EndFunction


;
; Update whether the NPC should be ignored by the mod.
;
Function UpdateIgnoreNpc(Actor npc, Bool value)
    If (value)
        UpdateFactionBits(npc, NpcFlags, 0x40, 0x40)
        Form[] npcs = GetNpcs()
        Int index = npcs.Find(npc)
        If (index >= 0)
            Alias[] aliases = GetAliases()
            ReferenceAlias refAlias = aliases[index] as ReferenceAlias
            (refAlias as DDNF_NpcTracker_NPC).RegisterForFixup() ; will remove NPC from alias on update
        EndIf
    Else
        UpdateFactionBits(npc, NpcFlags, 0x40, 0x00)
    EndIf
EndFunction


;
; Check whether the NPC should always be treated as "current follower".
;
Bool Function TreatAsCurrentFollower(Actor npc)
    Return GetFactionBits(npc, NpcFlags, 0x01) == 0x01
EndFunction


;
; Update whether the NPC should always be treated as "current follower".
;
Function UpdateTreatAsCurrentFollower(Actor npc, Bool value)
    If (value)
        UpdateFactionBits(npc, NpcFlags, 0x01, 0x01)
    Else
        UpdateFactionBits(npc, NpcFlags, 0x01, 0x00)
    EndIf
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


;
; Get or create a unique string tag for a form.
;
String Function GetOrCreateUniqueTag(Form item) Global
    If (item == None)
        Return ""
    EndIf
    String tag = StorageUtil.GetStringValue(item, "ddnf_t", "")
    If (tag == "")
        DDNF_NpcTracker tracker = Get()
        Int seed = StorageUtil.AdjustIntValue(None, "ddnf_t", 1)
        If (tracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] StorageUtil: AdjustIntValue(None, ddnf_t, 1) -> " + seed)
        EndIf
        tag = StringUtil.GetNthChar("0123456789abcdefghijklmnopqrstuvwxyz", seed % 36)
        While (seed >= 36)
            seed = seed / 36
            tag = StringUtil.GetNthChar("0123456789abcdefghijklmnopqrstuvwxyz", seed % 36) + tag
        EndWhile
        String maybeTag = StorageUtil.GetStringValue(item, "ddnf_t", "") ; reduce chance of race condition
        If (maybeTag == "")
            StorageUtil.SetStringValue(item, "ddnf_t", tag)
            If (tracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] StorageUtil: SetStringValue(" + DDNF_Game.FormIdAsString(item) + ", ddnf_t, " + tag + ")")
            EndIf
        Else
            tag = maybeTag
        EndIf
    EndIf
    Return tag
EndFunction
