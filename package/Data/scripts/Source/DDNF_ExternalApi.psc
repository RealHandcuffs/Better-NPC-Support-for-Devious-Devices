;
; This script provides an externally available API.
;
Scriptname DDNF_ExternalApi extends Quest

;
; Global function getting the instance of this API.
;
DDNF_ExternalApi Function Get() Global
    Return Game.GetFormFromFile(0x00001827, "DD_NPC_Fixup.esp") as DDNF_ExternalApi
EndFunction


;
; Get the tracking ID of a NPC that is currently being tracked.
; Tracking IDs are stable as long as the NPC is being tracked. When the mod stops tracking a NPC, it is allowed
; to re-use the tracking ID for a different NPC, so tracking IDs should not be stored long term. Tracking IDs
; are positive integer. This function will return a negative number if the NPC is not being tracked.
; Condition functions can instead check for the keyword DDNF_Tracked (0x??001828) for a simple IsTracked check.
;
Int Function GetTrackingId(Actor npc)
    If (npc == None)
        Return -1
    EndIf
    Form[] npcs = ((Self as Quest) as DDNF_NpcTracker).GetNpcs()
    Return npcs.Find(npc)
EndFunction


;
; Check whether a currently tracked NPC is helpless (unable to fight).
; Condition functions can instead check for membership in the faction DDNF_Helpless (0x??005367).
;
Bool Function IsHelpless(Int trackingId)
    If (trackingId >= 0)
        Alias[] aliases = ((Self as Quest) as DDNF_NpcTracker).GetAliases()
        If (trackingId < aliases.Length)
            DDNF_NpcTracker_NPC npcTracker = aliases[trackingId] as DDNF_NpcTracker_NPC
            Return npcTracker.NpcIsHelpless
        EndIf
    EndIf
    Return false
EndFunction


;
; Check whether a currently tracked NPC has devices that force a special animation.
;
Bool Function HasAnimation(Int trackingId)
    If (trackingId >= 0)
        Alias[] aliases = ((Self as Quest) as DDNF_NpcTracker).GetAliases()
        If (trackingId < aliases.Length)
            DDNF_NpcTracker_NPC npcTracker = aliases[trackingId] as DDNF_NpcTracker_NPC
            Return npcTracker.NpcHasAnimation
        EndIf
    EndIf
    Return false
EndFunction


;
; Check whether a currently tracked NPC uses unarmed combat animations (cannot use weapons or spells).
; Note that this will be true even if the NPC is helpless and is unable to fight at all.
; Condition functions can instead check for membership in the faction DDNF_UnarmedCombatants (0x??00489F).
;
Bool Function UseUnarmedCombatAnimations(Int trackingId)
    If (trackingId >= 0)
        Alias[] aliases = ((Self as Quest) as DDNF_NpcTracker).GetAliases()
        If (trackingId < aliases.Length)
            DDNF_NpcTracker_NPC npcTracker = aliases[trackingId] as DDNF_NpcTracker_NPC
            Return npcTracker.NpcUsesUnarmedCombatAnimations
        EndIf
    EndIf
    Return false
EndFunction


;
; Get the equipped devious devices of a currently tracked NPC.
; This should usually be much faster than scanning the inventory for devices, though there are edge cases
; where it will need to internally fall back to scanning.
; The function will add the found devices to outputArray and return the number of devices. The output array
; needs to be large enough to hold all found devices.
;
Int Function GetEquippedDevices(Int trackingId, Armor[] outputArray)
    If (trackingId >= 0)
        Alias[] aliases = ((Self as Quest) as DDNF_NpcTracker).GetAliases()
        If (trackingId < aliases.Length)
            DDNF_NpcTracker_NPC npcTracker = aliases[trackingId] as DDNF_NpcTracker_NPC
            Int count = npcTracker.TryGetEquippedDevices(outputArray)
            If (count >= 0)
                Return count
            EndIf
            Form[] npcs = ((Self as Quest) as DDNF_NpcTracker).GetNpcs()
            Return ScanForEquippedDevices(npcs[trackingId] as Actor, outputArray)
        EndIf
    EndIf
    Return 0
EndFunction


;
; Get the equipped devious devices of any NPC, even untracked NPCs. This will be slow for untracked NPCs.
; The function will add the found devices to outputArray and return the number of devices. The output array
; needs to be large enough to hold all found devices.
;
Int Function GetEquippedDevicesOfAnyNpc(Actor npc, Armor[] outputArray)
    If (npc != None)
        Form[] npcs = ((Self as Quest) as DDNF_NpcTracker).GetNpcs()
        Int trackingId = npcs.Find(npc)
        If (trackingId >= 0)
            Return GetEquippedDevices(trackingId, outputArray)
        EndIf
    EndIf
    Return ScanForEquippedDevices(npc, outputArray)
EndFunction


;
; Get the rendered device for the given inventory device.
;
Armor Function GetRenderedDevice(Armor inventoryDevice) Global
    Armor renderedDevice = StorageUtil.GetFormValue(inventoryDevice, "ddnf_r", None) as Armor
    If (renderedDevice == None)
        DDNF_NpcTracker tracker = (DDNF_ExternalApi.Get() as Quest) as DDNF_NpcTracker
        renderedDevice = tracker.DDLibs.GetRenderedDevice(inventoryDevice)
        If (renderedDevice != None)
            If (tracker.EnablePapyrusLogging)
                String inventoryFormId = DDNF_NpcTracker_NPC.GetFormIdAsString(inventoryDevice)
                String renderedFormId = DDNF_NpcTracker_NPC.GetFormIdAsString(renderedDevice)
                Debug.Trace("[DDNF] StorageUtil: SetFormValue(" + inventoryFormId + ", ddnf_r, " + renderedFormId + ")")
                Debug.Trace("[DDNF] StorageUtil: SetFormValue(" + renderedFormId + ", ddnf_i, " + inventoryFormId + ")")
            EndIf
            StorageUtil.SetFormValue(inventoryDevice, "ddnf_r", renderedDevice)
            StorageUtil.SetFormValue(renderedDevice, "ddnf_i", inventoryDevice)
        EndIf
    EndIf
    Return renderedDevice
EndFunction


;
; Quick-equip devices on a currently tracked NPC.
; This will partially bypass the Devious Devices API; as a consequence it will be faster but less safe and not
; trigger DD events, so you need to know what you are doing. It will not equip a device if the NPC has a
; conflicting device equipped.
; Devices needs to contain the inventory devices. If devicesCount is >= 0 then this function will only equip
; the first devicesCount items of the array. If instantEquipRenderedDevices is true then the function will equip
; the rendered devices instantly instead of waiting for the next fixup, this looks better but places more load on the
; game engine. This function returns the count of the added devices.
;
Int Function QuickEquipDevices(Int trackingId, Armor[] devices, Int devicesCount = -1, Bool instantEquipRenderedDevices = false)
    Int count = devicesCount
    If (count < 0 || count > devices.Length)
        count = devices.Length
    EndIf
    If (trackingId >= 0 && count > 0)
        Alias[] aliases = ((Self as Quest) as DDNF_NpcTracker).GetAliases()
        If (trackingId < aliases.Length)
            Return (aliases[trackingId] as DDNF_NpcTracker_NPC).QuickEquipDevices(devices, count, instantEquipRenderedDevices)
        EndIf
    EndIf
    Return 0
EndFunction


;
; Quick-equip devices on any NPC, even untracked NPCs.
; This will partially bypass the Devious Devices API; as a consequence it will be faster but less safe and not
; trigger DD events, so you need to know what you are doing. It will not equip a device if the NPC has a
; conflicting device equipped.
; Devices needs to contain the inventory devices. If devicesCount is >= 0 then this function will only equip
; the first devicesCount items of the array.  If instantEquipRenderedDevices is true then the function will equip
; the rendered devices instantly instead of waiting for the next fixup, this looks better but places more load on the
; game engine.This function returns the count of the added devices.
;
Int Function QuickEquipDevicesOnAnyNpc(Actor npc, Armor[] devices, Int devicesCount = -1, Bool instantEquipRenderedDevices = false)
    Int count = devicesCount
    If (count < 0 || count > devices.Length)
        count = devices.Length
    EndIf
    If (npc == None || count == 0)
        Return 0 ; nothing to do
    EndIf
    DDNF_NpcTracker tracker = (Self as Quest) as DDNF_NpcTracker
    Int trackingId = tracker.Add(npc)
    If (trackingId < 0)
        Return 0 ; not able to track npc
    EndIf
    DDNF_NpcTracker_NPC npcTracker = tracker.GetAliases()[trackingId] as DDNF_NpcTracker_NPC
    Return npcTracker.QuickEquipDevices(devices, count, instantEquipRenderedDevices)
EndFunction


;
; Internal functions, do not call directly.
;

Int Function ScanForEquippedDevices(Actor npc, Armor[] outputArray) Global ; Global because it is slow
    If (npc == None)
        Return 0
    EndIf
    DDNF_NpcTracker tracker = (DDNF_ExternalApi.Get() as Quest) as DDNF_NpcTracker
    Keyword zadInventoryDevice = tracker.DDLibs.zad_InventoryDevice
    Int inventoryDeviceCount = npc.GetItemCount(zadInventoryDevice)
    Int foundDevices = 0
    Int outputArrayIndex = 0
    Int index = npc.GetNumItems() - 1 ; start at end to increase chance of early abort
    While (foundDevices < inventoryDeviceCount && index >= 0 && outputArrayIndex < outputArray.Length)
        Armor maybeInventoryDevice = npc.GetNthForm(index) as Armor
        If (maybeInventoryDevice != None)
            Armor renderedDevice = StorageUtil.GetFormValue(renderedDevice, "ddnf_r", None) as Armor
            If (renderedDevice == None && maybeInventoryDevice.HasKeyword(zadInventoryDevice))
                renderedDevice = tracker.DDLibs.GetRenderedDevice(maybeInventoryDevice)
                If (renderedDevice != None)
                    If (tracker.EnablePapyrusLogging)
                        String inventoryFormId = DDNF_NpcTracker_NPC.GetFormIdAsString(maybeInventoryDevice)
                        String renderedFormId = DDNF_NpcTracker_NPC.GetFormIdAsString(renderedDevice)
                        Debug.Trace("[DDNF] StorageUtil: SetFormValue(" + inventoryFormId + ", ddnf_r, " + renderedFormId + ")")
                        Debug.Trace("[DDNF] StorageUtil: SetFormValue(" + renderedFormId + ", ddnf_i, " + inventoryFormId + ")")
                    EndIf
                    StorageUtil.SetFormValue(maybeInventoryDevice, "ddnf_r", renderedDevice)
                    StorageUtil.SetFormValue(renderedDevice, "ddnf_i", maybeInventoryDevice)
                EndIf
            EndIf
            If (renderedDevice != None && npc.GetItemCount(renderedDevice) > 0)
                foundDevices += 1
                If (outputArrayIndex == 0 || outputArray.RFind(maybeInventoryDevice, outputArrayIndex - 1) < 0) ; filter out duplicates
                    outputArray[outputArrayIndex] = maybeInventoryDevice
                    outputArrayIndex += 1
                EndIf
            EndIf
        EndIf
        index -= 1
    EndWhile
    Return outputArrayIndex
EndFunction
