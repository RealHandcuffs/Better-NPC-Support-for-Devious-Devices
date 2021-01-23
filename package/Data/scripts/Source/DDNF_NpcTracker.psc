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
Keyword Property TrackingKeyword Auto
Weapon Property DummyWeapon Auto
zadLibs Property DDLibs Auto

Bool Property UseBoundCombat Auto
Bool Property EnablePapyrusLogging Auto Conditional

Float Property MaxFixupsPerThreeSeconds = 3.0 Auto

Alias[] _cachedAliases ; performance optimization
Int _attemptedFixupsInPeriod


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


Function HandleGameLoaded(Bool upgrade)
    If (upgrade)
        ; stop further fixups until the upgrade is done
        UnregisterForUpdate()
        _attemptedFixupsInPeriod = 9999
        ; refresh alias array if doing upgrade, number of aliases may have changed
        Alias[] emptyArray
        _cachedAliases = emptyArray
    EndIf
    ; notify all alias scripts
    Int index = 0
    Alias[] aliases = GetAliases()
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
; Add a NPC to the tracked NPCs.
; Caller should check that the NPC is alive and loaded; failing that will not
; cause problems though, it will just needlessly cause some script load.
; Returns true if the actor was is tracked (either newly, or already was).
;
Bool Function Add(Actor npc)
    ; find a free alias and put the npc into the alias
    If (npc == Player) ; catch api misuse
        Return false
    EndIf
    Int index = 0
    Alias[] aliases = GetAliases()
    While (index < aliases.Length)
        ReferenceAlias refAlias = aliases[index] as ReferenceAlias
        If (refAlias.GetReference() == None)
            If (npc.HasKeyword(TrackingKeyword)) ; check for this as late as possible, i.e. directly before ForceRefIfEmpty
                Return true
            EndIf
            If (refAlias.ForceRefIfEmpty(npc)) ; can fail if the reference has been filled in the meantime
                Return true
            EndIf
        EndIf
        index += 1
    EndWhile
    ; unable to track, all reference aliases were full :(
    ; the mod will probably misbehave but hopefully not in too bad a way
    Return false
EndFunction


;
; Remove all tracked NPCs.
;
Function Clear()
    Int index = 0
    Alias[] aliases = GetAliases()
    While (index < aliases.Length)
        ReferenceAlias refAlias = aliases[index] as ReferenceAlias
        refAlias.Clear()
        index += 1
    EndWhile
EndFunction


Function HandleDeviceEquipped(Actor akActor, Armor inventoryDevice, Bool checkForNotEquippedBug)
    If (Add(akActor) && checkForNotEquippedBug)
        ; workaround for the OnContainerChanged event not firing, causing the device to not getting equipped
        ; this seems to be a "random" engine bug and can be fixed by dropping the object
        ; it seems to happen more often (?) if the player has multiple copies of the item, and/or if the item has recently been acquired
        Utility.Wait(2.0)
        ObjectReference tempRef = Player.PlaceAtMe(inventoryDevice, abInitiallyDisabled = true)
        zadEquipScript tempDevice = tempRef as zadEquipScript
        If (tempDevice != None)
            Armor renderedDevice = tempDevice.deviceRendered
            Keyword deviceKeyword = tempDevice.zad_DeviousDevice
            If (renderedDevice != None && deviceKeyword != None && akActor.GetItemCount(renderedDevice) == 0)
                ; it's not equipped, equip it, but first recheck if inventory device has been removed
                If (akActor.GetItemCount(inventoryDevice) > 0)
                    If (EnablePapyrusLogging)
                        Debug.Trace("[DDNF] Bug workaround: Equipping " + DDNF_NpcTracker_NPC.GetFormIdAsString(inventoryDevice) + " " + inventoryDevice.GetName() + " on " + DDNF_NpcTracker_NPC.GetFormIdAsString(akActor) + " " + akActor.GetDisplayName() + ".")
                    EndIf
                    DDLibs.LockDevice(akActor, inventoryDevice)
                EndIf
            EndIf
        EndIf
        tempDevice.Delete()
    EndIf
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