;
; This script provides an externally available API.
;
Scriptname DDNF_ExternalApi extends Quest

;
; Global function getting the instance of this API.
;
DDNF_ExternalApi Function Get() Global
    Return StorageUtil.GetFormValue(None, "DDNF_ExternalApi", None) as DDNF_ExternalApi
EndFunction


;
; Get the tracking ID of a NPC that is currently being tracked.
; Tracking IDs are stable as long as the NPC is being tracked. When the mod stops tracking a NPC, it is allowed
; to re-use the tracking ID for a different NPC, so tracking IDs should not be stored long term. Tracking IDs
; are positive integer. This function will return a negative number if the NPC is not being tracked.
;
Int Function GetTrackingId(Actor npc)
    If (npc == None)
        Return -1
    EndIf
    Form[] npcs = ((Self as Quest) as DDNF_NpcTracker).GetNpcs()
    Return npcs.Find(npc)
EndFunction


;
; Get the tracking ID of a NPC that is currently being tracked, or add the NPC to be tracked if it is not.
; Tracking IDs are stable as long as the NPC is being tracked. When the mod stops tracking a NPC, it is allowed
; to re-use the tracking ID for a different NPC, so tracking IDs should not be stored long term. Tracking IDs
; are positive integer. This function will return a negative number if the NPC cannot be tracked.
;
Int Function GetOrCreateTrackingId(Actor npc)
    If (npc == None)
        Return -1
    EndIf
    Return ((Self as Quest) as DDNF_NpcTracker).Add(npc)
EndFunction


;
; Check whether a currently tracked NPC is bound.
;
Bool Function IsBound(Int trackingId)
    If (trackingId >= 0)
        Alias[] aliases = ((Self as Quest) as DDNF_NpcTracker).GetAliases()
        If (trackingId < aliases.Length)
            DDNF_NpcTracker_NPC npcTracker = aliases[trackingId] as DDNF_NpcTracker_NPC
            Return npcTracker.IsBound()
        EndIf
    EndIf
    Return false
EndFunction

;
; Check whether a currently tracked NPC is gagged.
;
Bool Function IsGagged(Int trackingId)
    If (trackingId >= 0)
        Alias[] aliases = ((Self as Quest) as DDNF_NpcTracker).GetAliases()
        If (trackingId < aliases.Length)
            DDNF_NpcTracker_NPC npcTracker = aliases[trackingId] as DDNF_NpcTracker_NPC
            Return npcTracker.IsGagged()
        EndIf
    EndIf
    Return false
EndFunction

;
; Check whether a currently tracked NPC is blindfold.
;
Bool Function IsBlindfold(Int trackingId)
    If (trackingId >= 0)
        Alias[] aliases = ((Self as Quest) as DDNF_NpcTracker).GetAliases()
        If (trackingId < aliases.Length)
            DDNF_NpcTracker_NPC npcTracker = aliases[trackingId] as DDNF_NpcTracker_NPC
            Return npcTracker.IsBlindfold()
        EndIf
    EndIf
    Return false
EndFunction

;
; Check whether a currently tracked NPC is helpless (unable to fight).
;
Bool Function IsHelpless(Int trackingId)
    If (trackingId >= 0)
        Alias[] aliases = ((Self as Quest) as DDNF_NpcTracker).GetAliases()
        If (trackingId < aliases.Length)
            DDNF_NpcTracker_NPC npcTracker = aliases[trackingId] as DDNF_NpcTracker_NPC
            Return npcTracker.IsHelpless()
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
            Return npcTracker.HasAnimation()
        EndIf
    EndIf
    Return false
EndFunction


;
; Check whether a currently tracked NPC uses unarmed combat animations (cannot use weapons or spells).
; Note that this will be true even if the NPC is helpless and is unable to fight at all.
;
Bool Function UseUnarmedCombatAnimations(Int trackingId)
    If (trackingId >= 0)
        Alias[] aliases = ((Self as Quest) as DDNF_NpcTracker).GetAliases()
        If (trackingId < aliases.Length)
            DDNF_NpcTracker_NPC npcTracker = aliases[trackingId] as DDNF_NpcTracker_NPC
            Return npcTracker.UseUnarmedCombatAnimations()
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
Int Function GetEquippedDevices(Int trackingId, Armor[] outputArray, Keyword optionalFilterKeyword = None)
    If (trackingId >= 0)
        DDNF_NpcTracker tracker = (Self as Quest) as DDNF_NpcTracker
        Alias[] aliases = tracker.GetAliases()
        If (trackingId < aliases.Length)
            DDNF_NpcTracker_NPC npcTracker = aliases[trackingId] as DDNF_NpcTracker_NPC
            Int count = npcTracker.TryGetEquippedDevices(outputArray, optionalFilterKeyword)
            If (count >= 0)
                Return count
            EndIf
            Form[] npcs = ((Self as Quest) as DDNF_NpcTracker).GetNpcs()
            Return DDNF_NpcTracker_NPC.ScanForInventoryDevices(tracker.DDLibs, npcs[trackingId] as Actor, outputArray, true, optionalFilterKeyword)
        EndIf
    EndIf
    Return 0
EndFunction


;
; Get the rendered device for the given inventory device.
;
Armor Function GetRenderedDevice(Armor device) Global
    Return DDNF_NpcTracker.GetRenderedDevice(device, false)
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
; Try to choose a device that is a good candidate for unequipping on a currently tracked NPC.
; If unequipSelf is true then this function will assume that the NPC is trrying to unequip the device
; themselves, if false then this function will assume that somebody else is unequipping it.
; Unset respectCooldowns to ignore device cooldowns.
; This will return None if no device can be unequipped.
; WARNING: This function has to do a complex analysis of all equipped devices and is therefore slow.
;
Armor Function ChooseDeviceForUnequip(Int trackingId, Bool unequipSelf, Bool respectCooldowns = true)
    ChooseDeviceForUnequipWithIgnoredDevices(trackingId, unequipSelf, new Armor[1], 0)
EndFunction

Armor Function ChooseDeviceForUnequipWithIgnoredDevices(Int trackingId, Bool unequipSelf, Armor[] devicesToIgnore, Int devicesToIgnoreCount, Bool respectCooldowns = true)
    If (trackingId >= 0)
        Alias[] aliases = ((Self as Quest) as DDNF_NpcTracker).GetAliases()
        If (trackingId < aliases.Length)
            DDNF_NpcTracker_NPC npcTracker = aliases[trackingId] as DDNF_NpcTracker_NPC
            Return npcTracker.ChooseDeviceForUnequip(unequipSelf, devicesToIgnore, devicesToIgnoreCount, false, respectCooldowns)
        EndIf
    EndIf
    Return None
EndFunction


;
; Let a currently tracked NPC attempt to escape either one or all devices. This function can take a long time,
; up to several minutes. Set suppressNotifications to disable notifications even if enabled in MCM.
; Unset respectCooldowns to ignore device cooldowns.
; Returns -1 if the attempt was blocked (e.g. another escape attempt already ongoing), the number of removed devices otherwise.
;
Int Function PerformEscapeAttempt(Int trackingId, Bool suppressNotifications = false, Bool respectCooldowns = true)
    If (trackingId >= 0)
        Alias[] aliases = ((Self as Quest) as DDNF_NpcTracker).GetAliases()
        If (trackingId < aliases.Length)
            DDNF_NpcTracker_NPC npcTracker = aliases[trackingId] as DDNF_NpcTracker_NPC
            Return npcTracker.PerformEscapeAttempt(suppressNotifications, respectCooldowns)
        EndIf
    EndIf
    Return -1
EndFunction
