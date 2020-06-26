;
; Script to get events from player.
;
Scriptname DDNF_MainQuest_Player extends ReferenceAlias

Formlist Property EmptyFormlist Auto

String Property Version = "0.1 beta 4" AutoReadOnly
String _lastVersion


Event OnInit()
    Debug.Notification("[BNSfDD] Installing: " + Version)
    HandleGameLoaded(true)
    _lastVersion = Version    
    Debug.Notification("[BNSfDD] Done.")
EndEvent


Event OnPlayerLoadGame()
    DDNF_MainQuest mainQuest = GetOwningQuest() as DDNF_MainQuest    
    If (_lastVersion == Version)
        HandleGameLoaded(false)
    Else
        Debug.Notification("[BNSfDD] Upgrading to: " + Version)
        HandleGameLoaded(true)
        _lastVersion = Version
        Debug.Notification("[BNSfDD] Done.")
    EndIf
EndEvent


Function HandleGameLoaded(Bool upgrade)
    ; refresh event registrations
    UnregisterForAllMenus()
    RegisterForMenu("ContainerMenu")
    RegisterForMenu("Journal Menu")
    RemoveAllInventoryEventFilters()
    AddInventoryEventFilter(EmptyFormlist)
    ; notify main quest
    DDNF_MainQuest mainQuest = GetOwningQuest() as DDNF_MainQuest
    MainQuest.HandleGameLoaded(upgrade)
EndFunction


Event OnCellLoad()
    ; listening for OnCellLoad allows us to detect when the player changes cell by loading screen
    ; if the player enters a cell by walking to the cell (e.g. overland map), the cell is loaded
    ; before it becomes the players parent cell, and the event is not triggered
    DDNF_MainQuest mainQuest = GetOwningQuest() as DDNF_MainQuest
    MainQuest.HandleLoadingScreen()
EndEvent


Event OnMenuOpen(String menuName)
    If (menuName == "ContainerMenu")
        ; only track inventorty while container menu is open
        RemoveAllInventoryEventFilters()
    EndIf
EndEvent


Event OnMenuClose(String menuName)
    If (menuName == "ContainerMenu")
        ; only track inventorty while container menu is open
        RemoveAllInventoryEventFilters()
        AddInventoryEventFilter(EmptyFormlist)
    ElseIf (menuName == "Journal Menu")
        DDNF_NPCTracker npcTracker = (GetOwningQuest() as DDNF_MainQuest).NpcTracker
        npcTracker.HandleJournalMenuClosed()
    EndIf
EndEvent


Event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
    If (!UI.IsMenuOpen("ContainerMenu")) ; not expected, fallback in case something went wrong
        RemoveAllInventoryEventFilters()
        AddInventoryEventFilter(EmptyFormlist)
        Return
    EndIf
    Actor akActor = akDestContainer as Actor
    Armor maybeInventoryDevice = akBaseItem as Armor
    DDNF_NPCTracker npcTracker = (GetOwningQuest() as DDNF_MainQuest).NpcTracker
    If (akActor != None && maybeInventoryDevice != None && maybeInventoryDevice.HasKeyword(npcTracker.DDLibs.zad_InventoryDevice) && !akActor.IsDead())
        ; player trying to equip device on NPC, wait until container menu is closed and then some
        Utility.Wait(0.5)
        If (npcTracker.IsRunning() && akActor.GetItemCount(maybeInventoryDevice) > 0 && !akActor.IsDead())
            ; in theory this is completely unnecessary as Devious Devices should detect the item being added in OnContainerChange(),
            ; equip the device on the NPC, and call OnDDI_DeviceEquipped
            ; in practice there are multiple possible complications:
            ; - OnDDI_DeviceEquipped is not working in some versions
            ; - the OnContainerChange event may not get fired
            ;   this seems to be a "random" engine bug and can be fixed by dropping the object
            ;   it seems to happen more often (?) if the player has multiple copies of the item, and/or if the item has recently been acquired
            npcTracker.HandleDeviceEquipped(akActor, maybeInventoryDevice, true)
        EndIf
    EndIf
EndEvent