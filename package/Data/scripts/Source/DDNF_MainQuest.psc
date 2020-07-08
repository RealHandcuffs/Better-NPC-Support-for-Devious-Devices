;
; Mod main loop.
;
Scriptname DDNF_MainQuest extends Quest

;
; The scanner is used to find NPCs that are loaded, alive, have devious devices equipped and are not yet in the tracker.
; We add them to the tracker, depending on the tracker to fix them up. The tracker defines a keyword in the reference alias,
; preventing them from being found again while they are in the tracker. When they are unloaded or die, the tracker removes
; them automatically.
; Basically the whole machinery serves as an alternative to OnLoad/OnUnload events. The "nice" thing (if there is something
; nice about this complicated machinery) is that the NPCs are not referenced when they are not loaded, so the game is free
; to clean them up if they are transient NPCs that should get deleted automatically.
;
Quest Property NpcScanner Auto
DDNF_NpcTracker Property NpcTracker Auto

Float Property SecondsBetweenScans = 10.0 AutoReadOnly ; could also live in a config menu...

Alias[] _cachedScannerAliases ; performance optimization


Alias[] Function GetScannerAliases()
    If (_cachedScannerAliases.Length == 0)
        Int count = NpcScanner.GetNumAliases()
        Alias[] aliases = Utility.CreateAliasArray(count)
        Int index = 0
        While (index < count)
            aliases[index] = NpcScanner.GetNthAlias(index)
            index += 1
        EndWhile
        _cachedScannerAliases = aliases
    EndIf
    Return _cachedScannerAliases
EndFunction


Function HandleGameLoaded(Bool upgrade)
    UnregisterForUpdate()
    ; notify npc tracker quest
    NpcTracker.HandleGameLoaded(upgrade)
    ; refresh alias array if doing upgrade, aliases may have been added or removed
    If (upgrade)
        Alias[] emptyArray
        _cachedScannerAliases = emptyArray
    EndIf
    ; refresh event registrations
    RegisterForModEvent("DDI_DeviceEquipped", "OnDDI_DeviceEquipped")
    ; queue scan "soon"
    RegisterForSingleUpdate(1.0)
EndFunction


Function HandleLoadingScreen()
    ; scan for nearby NPCs soon after the loading screen instead of waiting for the queued event
    RegisterForSingleUpdate(1.0)
EndFunction


Event OnDDI_DeviceEquipped(Form inventoryDevice, Form deviceKeyword, Form akActor)
    ; DDi event when device is equipped
    If (NpcTracker.IsRunning() && akActor != NpcTracker.Player)
        NpcTracker.HandleDeviceEquipped(akActor as Actor, inventoryDevice as Armor, false)
    EndIf
EndEvent


Event OnUpdate()
    ; update event, scan for and fix all nearby NPCs and then queue another update event
    ; stopping the NPC tracker will temporarily disable this mod
    ; starting it again will re-enable this mod
    Bool runInFastMode
    If (NpcTracker.IsRunning())
        Bool allFoundNpcsAdded = true
        If (!NpcScanner.IsStopped())
            ; not really expected but might happen when loading screen is triggered while scan is ongoing
            ; bail out
            RegisterForSingleUpdate(SecondsBetweenScans) ; will probably get overwritten by code at the end of this function
            Return
        EndIf
        NpcScanner.Start() ; latent function, will wait and return after the quest has finished starting
        Int addedNpcCount = 0
        Int index = 0
        Alias[] aliases = GetScannerAliases()
        While (index < aliases.Length)
            Actor maybeFoundNpc = (aliases[index] as ReferenceAlias).GetReference() as Actor
            If (maybeFoundNpc != None)
                If (NpcTracker.Add(maybeFoundNpc))
                    addedNpcCount += 1
                EndIf
            EndIf
            index += 1
        EndWhile
        NpcScanner.Reset()
        NpcScanner.Stop()
        ; i.e. run again quickly if all scanner reference aliases were occupied, and all found NPCs are tracked
        ; otherwise slow down
        runInFastMode = index == addedNpcCount && addedNpcCount > 0
    Else
        NpcTracker.Clear()
        runInFastMode = false
    EndIf
    If (runInFastMode)
        RegisterForSingleUpdate(1.0)
    Else
        RegisterForSingleUpdate(SecondsBetweenScans)
    EndIf
EndEvent