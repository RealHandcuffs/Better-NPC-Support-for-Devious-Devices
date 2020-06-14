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

; could also live in a config menu...
Float Property SecondsBetweenScans = 10.0 AutoReadOnly


Event HandleGameLoaded()
    ; refresh all event registrations
    RegisterForModEvent("DDI_DeviceEquipped", "OnDDI_DeviceEquipped") 
   ; scan "soon" after loading game
    RegisterForSingleUpdate(1.0)
EndEvent


Function HandleLoadingScreen()
    ; scan for nearby NPCs directly after the loading screen instead of waiting for the queued event
    RegisterForSingleUpdate(0.1)
EndFunction


Event OnDDI_DeviceEquipped(Form inventoryDevice, Form deviceKeyword, Form akActor)
    If (NpcTracker.IsRunning() && akActor != NpcTracker.Player)
        NpcTracker.HandleDeviceEquipped(akActor as Actor, inventoryDevice as Armor, false)
    EndIf
EndEvent


Event OnUpdate()
    ; update event, scan for and fix all nearby NPCs and then queue another update event
    ; stopping the NPC tracker will temporarily disable this mod
    ; starting it again will re-enable this mod
    Bool runAgainVerySoon
    If (NpcTracker.IsRunning())
        Bool allFoundNpcsAdded = true
        If (!NpcScanner.IsStopped())
            ; not really expected but might happen when loading screen is triggered while scan is ongoing
            ; bail out
            RegisterForSingleUpdate(SecondsBetweenScans)
            Return
        EndIf
        NpcScanner.Start() ; latent function, will wait and return after the quest has finished starting
        Int foundNpcCount = 0
        Int index = 0
        Int count = NpcScanner.GetNumAliases()
        While (index < count)
            Actor maybeFoundNpc = (NpcScanner.GetNthAlias(index) as ReferenceAlias).GetActorRef()
            If (maybeFoundNpc != None)
                If (!NpcTracker.Add(maybeFoundNpc))
                    ; we ran out of space in the tracker, abort after this loop even if all scanner reference aliases were occupied
                    allFoundNpcsAdded = false
                EndIf
                foundNpcCount += 1
            EndIf
            index += 1
        EndWhile
        NpcScanner.Reset()
        NpcScanner.Stop()
        ; i.e. run again quickly if all scanner reference aliases were occupied, and all all found NPCs are tracked
        ; otherwise slow down
        runAgainVerySoon = foundNpcCount == count && allFoundNpcsAdded
    EndIf
    If (runAgainVerySoon)
        RegisterForSingleUpdate(1.0)
    Else
        ; slow down
        RegisterForSingleUpdate(SecondsBetweenScans)
    EndIf
EndEvent