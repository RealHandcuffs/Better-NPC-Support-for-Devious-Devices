;
; Script to get events from player.
;
Scriptname DDNF_MainQuest_Player extends ReferenceAlias

Formlist Property EmptyFormlist Auto

String Property Version = "0.6" AutoReadOnly
String _lastVersion


Event OnInit()
    Debug.Notification("[BNSfDD] Installing: " + Version)
    DDNF_MainQuest mainQuest = GetOwningQuest() as DDNF_MainQuest
    Bool enablePapyrusLogging = mainQuest.NpcTracker.EnablePapyrusLogging
    If (enablePapyrusLogging)
        Debug.Trace("[DDNF] Installing version " + Version + ".")
    EndIf
    HandleGameLoaded(true)
    _lastVersion = Version
    If (enablePapyrusLogging)
        Debug.Trace("[DDNF] Installation finished.")
    EndIf
    Debug.Notification("[BNSfDD] Done.")
EndEvent


Event OnPlayerLoadGame()
    DDNF_MainQuest mainQuest = GetOwningQuest() as DDNF_MainQuest
    Bool enablePapyrusLogging = mainQuest.NpcTracker.EnablePapyrusLogging
    If (_lastVersion == Version)
        HandleGameLoaded(false)
    Else
        MainQuest.NpcTracker.IsEnabled = false ; do this as early as possible
        Debug.Notification("[BNSfDD] Upgrading to: " + Version)
        If (enablePapyrusLogging)
            Debug.Trace("[DDNF] Upgrading from version " + _lastVersion + " to version " + Version + ".")
        EndIf
        HandleGameLoaded(true) ; will enable NpcTracker again as a side effect
        _lastVersion = Version
        If (enablePapyrusLogging)
            Debug.Trace("[DDNF] Upgrade finished.")
        EndIf
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


Event OnItemAdded(Form akBaseItem, Int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
    If (!UI.IsMenuOpen("ContainerMenu")) ; not expected, fallback in case something went wrong
        RemoveAllInventoryEventFilters()
        AddInventoryEventFilter(EmptyFormlist)
        Return
    EndIf
    DDNF_NPCTracker npcTracker = (GetOwningQuest() as DDNF_MainQuest).NpcTracker
    Actor akActor = akSourceContainer as Actor
    Armor maybeInventoryDevice = akBaseItem as Armor
    Armor renderedDevice = DDNF_NPCTracker.GetRenderedDevice(maybeInventoryDevice, false)
    If (akActor != None && maybeInventoryDevice != None && renderedDevice != None && npcTracker.IsRunning() && !akActor.IsDead())
        ; player took a device from NPC, check if this is an unequip action or if a device just "bounced" when trying to put it on the NPC
        If (akActor.GetItemCount(renderedDevice) > 0 || akActor.GetItemCount(npcTracker.DDLibs.GetDeviceKeyword(maybeInventoryDevice)) == 0)
            npcTracker.HandleDeviceSelectedInContainerMenu(akActor, maybeInventoryDevice, renderedDevice)
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
    Armor renderedDevice = DDNF_NPCTracker.GetRenderedDevice(maybeInventoryDevice, false)
    DDNF_NPCTracker npcTracker = (GetOwningQuest() as DDNF_MainQuest).NpcTracker
    If (akActor != None && maybeInventoryDevice != None && renderedDevice != None && !akActor.IsDead())
        ; player trying to equip device on NPC, wait until container menu is closed
        Int waitCount = 0
        While (UI.IsMenuOpen("ContainerMenu") && waitCount < 20)
            Utility.Wait(0.016)
            waitCount += 1 ; really only to prevent endless loop in case IsMenuOpen misbehaves
        EndWhile
        If (npcTracker.IsRunning() && akActor.GetItemCount(maybeInventoryDevice) > 0 && !akActor.IsDead())
            npcTracker.HandleDeviceEquipped(akActor, maybeInventoryDevice, true)
        EndIf
    EndIf
EndEvent