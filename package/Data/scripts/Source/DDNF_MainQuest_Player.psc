;
; Script to get events from player.
;
Scriptname DDNF_MainQuest_Player extends ReferenceAlias

Formlist Property EmptyFormlist Auto


Event OnInit()
    HandleGameLoaded()
EndEvent


Event OnPlayerLoadGame()
    HandleGameLoaded()
EndEvent


Function HandleGameLoaded()
    ; refresh all event registrations
    UnregisterForAllMenus()
    RegisterForMenu("ContainerMenu")
    RegisterForMenu("Journal Menu")
    RemoveAllInventoryEventFilters()
    AddInventoryEventFilter(EmptyFormlist)
    ; tell main quest and npc tracker quest to refresh, too
    DDNF_MainQuest mainQuest = GetOwningQuest() as DDNF_MainQuest
    DDNF_NPCTracker npcTracker = mainQuest.NpcTracker
    If (npcTracker.IsRunning()) ; stopping npc tracker will disable this mod
        npcTracker.HandleGameLoaded()
    EndIf
    MainQuest.HandleGameLoaded()
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
        If (npcTracker.IsRunning())
            npcTracker.HandleJournalMenuClosed()
        EndIf
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
    If (akActor != None && !akActor.IsDead() && maybeInventoryDevice != None)
        DDNF_NPCTracker npcTracker = (GetOwningQuest() as DDNF_MainQuest).NpcTracker
        If (npcTracker.IsRunning() && maybeInventoryDevice.HasKeyword(npcTracker.DDLibs.zad_InventoryDevice))
            ; player trying to equip device on NPC, wait until container menu is closed
            Utility.Wait(0.5)
            If (npcTracker.IsRunning() && !akActor.IsDead() && akActor.GetItemCount(maybeInventoryDevice) > 0)
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
    EndIf
EndEvent