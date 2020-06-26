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

Alias[] _cachedAliases ; performance optimization


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
        Alias[] emptyArray
        _cachedAliases = emptyArray ; the number of aliases might have changed
    EndIf
    Int index = 0
    Alias[] aliases = GetAliases()
    While (index < aliases.Length)
        (aliases[index] as DDNF_NpcTracker_NPC).HandleGameLoaded(upgrade)
        index += 1
    EndWhile
    ValidateOptions()
EndFunction


Function HandleJournalMenuClosed()
    ValidateOptions()
EndFunction


Function ValidateOptions()
    Bool newUseBoundCombat = ddLibs.Config.UseBoundCombat
    If (useBoundCombat != newUseBoundCombat)
        UseBoundCombat = newUseBoundCombat
        Int index = 0
        Alias[] aliases = GetAliases()
        While (index < aliases.Length)
            (aliases[index] as DDNF_NpcTracker_NPC).HandleOptionsChanged(useBoundCombat)
            index += 1
        EndWhile
    EndIf
EndFunction


;
; Add a NPC to the tracked NPCs.
; Caller should check that the NPC is alive and loaded; failing that will not
; cause problems though, it will just needlessly cause some script load.
; Must NEVER be called with the player, or with NPCs who are already tracked.
;
Bool Function Add(Actor npc)
    ; find a free alias and put the npc into the alias
    If (npc == Player) ; catch api misuse
        Return true
    EndIf
    Int index = 0
    Alias[] aliases = GetAliases()
    If (npc.HasKeyword(TrackingKeyword)) ; api misuse, too - check for this as late as possible, i.e. directly before the loop
        Return true
    EndIf
    While (index < aliases.Length)
        ReferenceAlias refAlias = aliases[index] as ReferenceAlias
        If (refAlias.ForceRefIfEmpty(npc))
            Return true
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
    If (akActor != Player && !akActor.IsDead())
        If (checkForNotEquippedBug)
            Armor renderedDevice = DDLibs.GetRenderedDevice(inventoryDevice)
            If (renderedDevice != None && akActor.GetItemCount(renderedDevice) == 0)
                ; the item is not actually equipped (bug), try to equip it
                ObjectReference droppedItem = akActor.DropObject(inventoryDevice)
                Utility.Wait(0.1)
                akActor.AddItem(droppedItem)
                zadEquipScript deviousDevice = droppedItem as zadEquipScript
                If (deviousDevice != None) ; expected to always be true
                    deviousDevice.EquipDevice(akActor)
                    Utility.Wait(0.5)
                EndIf
            EndIf
        EndIf
        Add(akActor)
    EndIf
EndFunction