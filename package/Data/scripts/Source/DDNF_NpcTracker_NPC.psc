;
; See comment in DDNF_NpcTracker for the purpose of this script.
; We do not add properties to this script as there are a lot of instances.
; Instead properties are added to DDNF_NpcTracker.
; This is not only an optimization, it makes it easier to modify the script.
; We only need to recompile it instead of modifying properties in all instances.
;
Scriptname DDNF_NpcTracker_NPC extends ReferenceAlias

; state of npc in ref
Armor[] _renderedDevices
Int _renderedDevicesFlags ; -1 means rendered devices are not known
Bool _useUnarmedCombatPackage
Bool _helpless
Bool _hasAnimation
Bool _hasDummyWeapon

; variables tracking state of script
; there is also a script state, so this is not the whole picture
Bool _ignoreNotEquippedInNextFixup
Bool _animationIsApplied
Bool _animationNeedsRefresh
Bool _fixupLock
Float _lastFixupRealTime


Function HandleGameLoaded(Bool upgrade)
    Actor npc = GetReference() as Actor
    If (npc == None)
        If (upgrade)
            GotoState("AliasEmpty") ; may be necessary if upgrading from an old version without script states
        EndIf
    Else
        ; clear on upgrade, NPC will be re-added if found again
        ; also clear if NPC is dead (safety check in case OnDeath was missed somehow)
        If (upgrade || npc.IsDead())
            _animationIsApplied = false ; cheap trick to prevent EvaluateAA call
            Clear()
        ; also do a safety check in case OnUnload was missed somehow
        ElseIf (!IsParentCellAttached(npc))
            _animationIsApplied = false ; detaching breaks animations
            RegisterForFixup(8.0)
        EndIf
        _lastFixupRealTime = 0.0 ; reset on game load
    EndIf
EndFunction


Function HandleOptionsChanged(Bool useBoundCombat)
    Actor npc = GetReference() as Actor
    If (npc != None && _useUnarmedCombatPackage && (_helpless && useBoundCombat || !_helpless && !useBoundCombat))
        ; rescan devices, helpless state might have changed
        _renderedDevicesFlags = -1
        If (GetState() == "AliasOccupied")
            RegisterForFixup()
        EndIf
    EndIf
EndFunction


Function ForceRefTo(ObjectReference akNewRef) ; override
    Actor npc = akNewRef as Actor
    parent.ForceRefTo(npc)
    If (npc != None)
        DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
        If (npcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] Start tracking " + GetFormIdAsString(npc) + " " + npc.GetDisplayName() + ".")
        EndIf
        _renderedDevicesFlags = -1
        ; no need to set _renderedDevices, it is already an empty array
        _useUnarmedCombatPackage = false
        _helpless = false
        _hasAnimation = false
        _hasDummyWeapon = npc.GetItemCount(npcTracker.DummyWeapon) > 0
        _ignoreNotEquippedInNextFixup = false
        _animationIsApplied = false
        _animationNeedsRefresh = false
        _fixupLock = false
        _lastFixupRealTime = 0.0
        RegisterForFixup()
        ; we will receive OnDeath event when NPC dies from now on, but they might already be dead
        If (npc.IsDead())
            Clear()
        ElseIf (!IsParentCellAttached(npc)) ; same for OnCellDetach
            RegisterForFixup(8.0) ; reschedule
        EndIf
    EndIf
EndFunction


Function Clear() ; override
    Actor npc = GetReference() as Actor
    If (npc != None)
        ; acquire fixup lock, we do not want this to happen concurrent to a fixup
        Int waitCount = 0
        While (_fixupLock && waitCount < 40) ; but do not wait forever in case something is stuck
            Utility.Wait(0.25)
            waitCount += 1
        EndWhile
        _fixupLock = true
        If (GetReference() == npc)
            GotoState("AliasEmpty")
            UnregisterForUpdate() ; may do nothing
            ; revert changes made to the NPC
            ; but do not revert membership in npcTracker.DeviceTargets faction, it is used to find the NPC again
            DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
            If (_useUnarmedCombatPackage)
                UnregisterForAnimationEvent(npc, "BeginWeaponDraw")
                npc.RemoveFromFaction(npcTracker.UnarmedCombatants)
                If (_helpless)
                    npc.RemoveFromFaction(npcTracker.Helpless)
                    ; restore ability to draw weapons by changing equipped weapons
                    npc.EquipItem(npcTracker.DummyWeapon, abPreventRemoval=true, abSilent=true)
                    _hasDummyWeapon = true ; should already be true, but set it to be sure
                EndIf
                npc.UnequipItemEx(npcTracker.DummyWeapon)
            EndIf
            If (_hasAnimation && _animationIsApplied)
                npcTracker.DDLibs.BoundCombat.EvaluateAA(npc) ; very expensive call
            EndIf
            If (_hasDummyWeapon)
                Int dummyWeaponCount = npc.GetItemCount(npcTracker.DummyWeapon)
                If (dummyWeaponCount > 0)
                    npc.RemoveItem(npcTracker.DummyWeapon, aiCount=dummyWeaponCount, abSilent=true)
                EndIf
            EndIf
            ; no reason to clear the state, it will be set correctly in ForceRefTo() or in the Fixup following it
            ; but clear the array with rendered devices such that the game can reclaim the memory
            Armor[] emptyArray
            _renderedDevices = emptyArray
            ; finally kick from alias
            parent.Clear()
            If (npcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] Stop tracking " + GetFormIdAsString(npc) + " " + npc.GetDisplayName() + ".")
            EndIf
        EndIf
        ; done
        _fixupLock = false
    EndIf
EndFunction


Event OnDeath(Actor akKiller)
    ; stop tracking the NPC on death
    _animationIsApplied = false
    Clear()
EndEvent


Event OnCellAttach()
    RegisterForFixup(0.25) ; high priority
EndEvent


Event OnCellDetach()
    _animationIsApplied = false ; detaching breaks animations
    RegisterForFixup(8.0) ; the update will call Clear() if still not loaded
EndEvent


Event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
    HandleItemAddedRemoved(akBaseItem)
EndEvent


Event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
    HandleItemAddedRemoved(akBaseItem)
EndEvent


Function HandleItemAddedRemoved(Form akBaseItem)
    ; adding/removing equipment screws with devious devices
    Actor npc = GetReference() as Actor
    DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
    If (npc != None && akBaseItem != npcTracker.DummyWeapon) ; we take care to add/remove DummyWeapon only in situations where it cannot break devices
        Armor maybeArmor = akBaseItem as Armor
        If (maybeArmor != None)
            zadLibs ddLibs = npcTracker.DDLibs
            If (maybeArmor.HasKeyword(ddLibs.zad_Lockable))
                ; a device has been added or removed, we need to rescan for devices
                _renderedDevicesFlags = -1
                If (_animationIsApplied && !_animationNeedsRefresh && ModifiesAnimation(ddLibs, maybeArmor))
                    ; the device also changes the animation
                    _animationNeedsRefresh = true
                EndIf
            EndIf
        EndIf
        RegisterForFixup()
    EndIf
EndFunction


Bool Function ModifiesAnimation(zadLibs ddLibs, Armor renderedDevice) Global
    ; basically the same logic as the one used to set the hasHeavyBondage/hasAnimation flags in FindAndAnalyzeRenderedDevices
    If (renderedDevice.GetEnchantment() != None)
        If (renderedDevice.HasKeyword(ddLibs.zad_DeviousHeavyBondage))
			; heavy bondage device
            Return true
        EndIf
        If (renderedDevice.HasKeyword(ddLibs.zad_DeviousPonyGear) || renderedDevice.HasKeyword(ddLibs.zad_DeviousHobbleSkirt) && !renderedDevice.HasKeyword(ddLibs.zad_DeviousHobbleSkirtRelaxed))
			; device other than heavy bondage that requires animation
            Return true
        EndIf
    EndIf
    Return false
EndFunction


Event OnCombatStateChanged(Actor akTarget, Int aeCombatState)
    If (_useUnarmedCombatPackage && !_helpless)
        Actor npc = GetReference() as Actor
        If (npc != None)
            DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
            If (aeCombatState == 1)
				UnequipWeapons(npc) ; combat override package will make sure NPC is only using unarmed combat
            Else
                npc.EquipItem(npcTracker.DummyWeapon, abPreventRemoval=true, abSilent=true)
                _hasDummyWeapon = true ; should already be true, but set it to be sure
            EndIf
        EndIf
    EndIf
EndEvent


Event OnAnimationEvent(ObjectReference akSource, string asEventName)
    Actor npc = GetReference() as Actor
    If (npc != akSource) ; not expected but handle it
        Utility.Wait(0.5) ; according to the documentation we need to wait to get out of the event before we can unregister
        UnregisterForAnimationEvent(akSource, asEventName) ; cleanup
        Return
    EndIf
    If (asEventName == "BeginWeaponDraw")
        If (_useUnarmedCombatPackage && (_helpless || npc.GetCombatState() != 1))
            DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
            If (!UnequipWeapons(npc, npcTracker.DummyWeapon)) ; for some reason the game sometimes keeps equipment in the left hand even though DummyWeapon is two-handed
                npc.EquipItem(npcTracker.DummyWeapon, abPreventRemoval=true, abSilent=true)
                _hasDummyWeapon = true ; should already be true, but set it to be sure
            EndIf
            If (_helpless)
                Debug.SendAnimationEvent(npc, "IdleForceDefaultState") ; black magic
                npc.SheatheWeapon()
            EndIf
        EndIf
    Else
        Utility.Wait(0.5) ; wait before unregister, see above
        UnregisterForAnimationEvent(akSource, asEventName) ; cleanup
    EndIf
EndEvent


; stop handling events when reference alias is empty
Auto State AliasEmpty

Event OnDeath(Actor akKiller)
EndEvent

Event OnLoad()
EndEvent

Event OnUnload()
EndEvent

Event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
EndEvent

Event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
EndEvent

Event OnCombatStateChanged(Actor akTarget, Int aeCombatState)
EndEvent

Event OnAnimationEvent(ObjectReference akSource, string asEventName)
EndEvent

EndState


; handle all events when reference alias is occupied
State AliasOccupied
EndState


; change handling of some events when reference alias is occupied and script is waiting for quick fixup
State AliasOccupiedWaitingForQuickFixup

Function HandleItemAddedRemoved(Form akBaseItem)
    Actor npc = GetReference() as Actor
    Armor maybeArmor = akBaseItem as Armor
    If (npc != None && maybeArmor != None)
        DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
        zadLibs ddLibs = npcTracker.DDLibs
        If (maybeArmor.HasKeyword(ddLibs.zad_Lockable))
            ; a device has been added or removed, we need to rescan for devices
            _renderedDevicesFlags = -1
            If (_animationIsApplied && !_animationNeedsRefresh && ModifiesAnimation(ddLibs, maybeArmor))
                ; the device also changes the animation
                _animationNeedsRefresh = true
            EndIf
            ; switch state
            String currentState = GetState() ; might have changed since start of call
			If ((!_animationIsApplied || _animationNeedsRefresh) && currentState == "AliasOccupiedWaitingForQuickFixup")
                GotoState("AliasOccupiedWaitingForFullFixup") ; like RegisterForFixup but without changing the registered update
			ElseIf (currentState == "AliasOccupied")
                RegisterForFixup()
            EndIf
        EndIf
    EndIf
EndFunction

EndState


; change handling of some events when reference alias is occupied and script is waiting for full fixup
State AliasOccupiedWaitingForFullFixup

Event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
EndEvent

Event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
EndEvent

Function HandleItemAddedRemoved(Form akBaseItem)
EndFunction

EndState


Function RegisterForFixup(Float delay = 1.0) ; 1.0 is usually a good compromise between reactivity and collapsing multiple events into one update
    ; fixing the NPC in an update event has several important advantages:
    ; 1. if the player is currently modifying the NPCs inventory, the fixup will be done after the menu has been closed
    ; 2. if there are multiple reasons for a fixup in quick succession, the fixup will only run once
    ; 3. it is an async operation, so when the scanner calls ForceRefIfEmpty it does not have to wait for the fixup
    
    If (_renderedDevicesFlags < 0 && (!_animationIsApplied || _animationNeedsRefresh))
        GotoState("AliasOccupiedWaitingForFullFixup")
    Else
        GotoState("AliasOccupiedWaitingForQuickFixup")
    EndIf
    RegisterForSingleUpdate(delay)
EndFunction


Event OnUpdate()
    Actor npc = GetReference() as Actor
    If (npc == None) ; race condition
        GotoState("AliasEmpty") ; may not be necessary
        Return
    EndIf
    If (_fixupLock)
        RegisterForFixup(5.0) ; already running, postpone
        Return
    EndIf
    _fixupLock = true ; we know it is currently false
    If (!IsParentCellAttached(npc))
        _fixupLock = false
        _animationIsApplied = false ; probably already false from OnCellDetach()
        Clear()
        Return
    EndIf
    Float timeSinceLastFixup = Utility.GetCurrentRealTime() - _lastFixupRealTime
    If (timeSinceLastFixup < 5.0)
        ; do not run fixup on the same NPC more frequently than every 5 seconds real time
        ; this serves as a way to prevent many fixups in case a script is modifying the equipment item by item
        Float waitTime = 5.0 - timeSinceLastFixup
        If (waitTime < 1.0)
            waitTime = 1.0
        EndIf
        _fixupLock = false
        RegisterForFixup(waitTime)
        Return
    EndIf
    DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
    Float slowDownTime = npcTracker.NeedToSlowDownBeforeFixup(npc)
    If (slowDownTime > 0.0)
        _fixupLock = false
        RegisterForFixup(slowDownTime)
        Return
    EndIf
    Bool enablePapyrusLogging = npcTracker.EnablePapyrusLogging
    String formIdAndName = ""
    If (enablePapyrusLogging)
        formIdAndName = GetFormIdAsString(npc) + " " + npc.GetDisplayName()
        Debug.Trace("[DDNF] Fixing up devices of " + formIdAndName + ".")
    EndIf
    GotoState("AliasOccupied") ; we know the alias is not empty

    ; step one: find and analyze all rendered devices in the inventory of the NPC
    zadLibs ddLibs = npcTracker.DDLibs
    Int renderedDevicesFlags = _renderedDevicesFlags
    If (renderedDevicesFlags < 0)
        ; devices are not known, find and analyze them
        _renderedDevicesFlags = 0
        If (_renderedDevices.Length != 32) ; number of slots
            _renderedDevices = new Armor[32] 
        EndIf
        renderedDevicesFlags = FindAndAnalyzeRenderedDevices(ddLibs, npcTracker.UseBoundCombat, npc, _renderedDevices)
        If (GetState() != "AliasOccupied")
            ; something has triggered a new fixup while we were finding and analysing devices
            If (_renderedDevicesFlags != 0 || !IsParentCellAttached(npc))
                ; devices have been added/removed or npc has been unloaded, abort
                If (_renderedDevicesFlags == 0)
                    _renderedDevicesFlags = renderedDevicesFlags
                EndIf
                _lastFixupRealTime = Utility.GetCurrentRealTime()
                _fixupLock = false
                If (enablePapyrusLogging)
                    Debug.Trace("[DDNF] Aborted fixing up devices of " + formIdAndName + " (concurrent modification while scanning devices).")
                EndIf
                Return
            EndIf
            ; something else has changed (e.g. item added/removed that is not a device)
            ; we can continue as we have not yet started with the real fixup procedure
            UnregisterForUpdate()
            GotoState("AliasOccupied")
        EndIf
        If (_renderedDevicesFlags == 0)
            _renderedDevicesFlags = renderedDevicesFlags
        EndIf
        If (_renderedDevices[0] == None)
            ; no devices found, remove NPC from alias
            npc.RemoveFromFaction(npcTracker.DeviceTargets)
            _fixupLock = false
            If (enablePapyrusLogging)
                Debug.Trace("[DDNF] Succeeded fixing up devices of " + formIdAndName + ", no devices found.")
            EndIf
            If (_renderedDevicesFlags == renderedDevicesFlags)
                Clear()
            EndIf
            Return
        Else
            npc.SetFactionRank(npcTracker.DeviceTargets, 0)
        EndIf
    EndIf
    Int devicesWithMagicalEffectCount = Math.LogicalAnd(renderedDevicesFlags, 255)
    Bool useUnarmedCombatPackage = Math.LogicalAnd(renderedDevicesFlags, 256)
    Bool helpless = Math.LogicalAnd(renderedDevicesFlags, 512)
    Bool hasAnimation = Math.LogicalAnd(renderedDevicesFlags, 1024)
    ; also add/remove dummy weapon if necessary
    ; we need to do this now, before actually fixing devices
    If (useUnarmedCombatPackage)
        If (!_hasDummyWeapon)
            _hasDummyWeapon = true
            npc.AddItem(npcTracker.DummyWeapon, abSilent=true)
        EndIf
    Else
        If (_hasDummyWeapon)
            Int dummyWeaponCount = npc.GetItemCount(npcTracker.DummyWeapon)
            _hasDummyWeapon = false
            If (dummyWeaponCount > 0)
                npc.RemoveItem(npcTracker.DummyWeapon, aiCount=dummyWeaponCount, abSilent=true)
            EndIf
        EndIf
        If (_hasAnimation && npc.IsWeaponDrawn())
            npc.SheatheWeapon()
        EndIf
    EndIf        
    
    ; step two: unequip and reequip all rendered devices to restart the effects
    ; from this point on we need to abort and restart the fixup if something changes
    Int reequipBitmap = UnequipDevices(npc, _renderedDevices, devicesWithMagicalEffectCount)
    If (reequipBitmap != 0)
        Utility.Wait(0.017) ; give the game time to fully register the unequips
        ReequipDevices(npc, _renderedDevices, reequipBitmap) ; even do this if current state has changed during UnequipDevices!
        Utility.Wait(0.017) ; give the game time to fully register the equips
        npc.UpdateWeight(0) ; workaround to force the game to correctly evaluate armor addon slots
        If (enablePapyrusLogging)
            Debug.Trace("[DDNF] Updated weight of " + formIdAndName + ".")
        EndIf
    EndIf
    String currentState = GetState()
    If (_ignoreNotEquippedInNextFixup)
        _ignoreNotEquippedInNextFixup = false
    ElseIf (currentState == "AliasOccupied")
        Bool devicesEquipped = reequipBitmap == 0 || CheckDevicesEquipped(npc, _renderedDevices, reequipBitmap)
        currentState = GetState()
        If (!devicesEquipped && currentState == "AliasOccupied")
            ; some devices are still not equipped, it is not clear why this happens sometimes
            ; reschedule fixup but ignore the issue if it occurs again
            _ignoreNotEquippedInNextFixup = true
            RegisterForFixup() ; ignore the minimum time between fixups in this case, logically it is still "the same" fixup
            _fixupLock = false
            If (enablePapyrusLogging)
                Debug.Trace("[DDNF] Aborted fixing up devices of " + formIdAndName + " and rescheduled (unable to equip device).")
            EndIf
            Return
        EndIf
    EndIf
    If (currentState != "AliasOccupied")
        ; another fixup has been scheduled while we were unequipping and reequipping devices, abort and let the other fixup run
        _lastFixupRealTime = Utility.GetCurrentRealTime()
        _fixupLock = false
        If (enablePapyrusLogging)
            Debug.Trace("[DDNF] Aborted fixing up devices of " + formIdAndName + " (concurrent modification while unequipping/reequipping devices).")
        EndIf
        Return
    EndIf
        
    ; step three: handle weapons and animation effects
    If (hasAnimation)
        ; modifying animations will cause a weird state where the NPC cannot draw weapons if they are currently drawn
        ; this can be reverted by changing the equipped weapons of the npc
        Bool restoreWeaponAccess = !helpless && npc.IsWeaponDrawn()
        If (_animationIsApplied && !_animationNeedsRefresh)
            ; only re-start idle as animations are already set
            Debug.SendAnimationEvent(npc, "IdleForceDefaultState") ; only re-start idle as animations are already set
        Else
            ; use the full procuedure
            _animationIsApplied = true
            _animationNeedsRefresh = false
            If (enablePapyrusLogging)
                Debug.Trace("[DDNF] Reevaluating animations of " + formIdAndName + ".")
            EndIf
            ddLibs.BoundCombat.EvaluateAA(npc) ; very expensive call
        EndIf
        If (restoreWeaponAccess)
            ; restore ability to draw weapons by changing equipped weapons
            UnequipWeapons(npc)
        EndIf
    ElseIf (_hasAnimation && _animationIsApplied)
        ddLibs.BoundCombat.EvaluateAA(npc) ; very expensive call
        _animationIsApplied = false
        _animationNeedsRefresh = false
    EndIf
    If (useUnarmedCombatPackage)
        If (!UnequipWeapons(npc, npcTracker.DummyWeapon))
            npc.EquipItem(npcTracker.DummyWeapon, abPreventRemoval=true, abSilent=true)
            _hasDummyWeapon = true ; should already be true, but set it to be sure
        EndIf
        RegisterForAnimationEvent(npc, "BeginWeaponDraw") ; register even if we think that we are already registered
    ElseIf (_useUnarmedCombatPackage)
        UnregisterForAnimationEvent(npc, "BeginWeaponDraw")
    EndIf
    ; almost done, so do not abort and reschedule if another fixup is scheduled, just let things run their normal course instead

    ; step four: set state and adjust factions
    If (useUnarmedCombatPackage)
        If (!_useUnarmedCombatPackage)
            _useUnarmedCombatPackage = true
            npc.SetFactionRank(npcTracker.UnarmedCombatants, 0)
        EndIf
    ElseIf (_useUnarmedCombatPackage)
        npc.RemoveFromFaction(npcTracker.UnarmedCombatants)
        _useUnarmedCombatPackage = false
    EndIf
    If (helpless)
        If (!_helpless)
            _helpless = true
            npc.SetFactionRank(npcTracker.Helpless, 0)
        EndIf
    ElseIf (_helpless)
        npc.RemoveFromFaction(npcTracker.Helpless)
        _helpless = false
    EndIf
    _hasAnimation = hasAnimation
    _lastFixupRealTime = Utility.GetCurrentRealTime()
    _fixupLock = false

    ; done
    If (enablePapyrusLogging)
        Debug.Trace("[DDNF] Succeeded fixing up devices of " + formIdAndName + ".")
    EndIf
EndEvent


;
; Check if the parent cell of an actor is currently attached.
;
Bool Function IsParentCellAttached(Actor npc) Global
    Cell parentCell = npc.GetParentCell()
    Return parentCell != None && parentCell.IsAttached()
EndFunction


;
; Fills the renderedDevices array with the rendered devices of the actor, starting from index 0.
; Devices with magical effects will be added to the array before devices without magical effects.
; Returns an int composed of the following numbers and flags:
; (0 - 255) - number of devices with effects
; 256 - flag: use unarmed combat package
; 512 - flag: helpless
; 1024 - flag: has animation
;
Int Function FindAndAnalyzeRenderedDevices(zadLibs ddLibs, Bool useBoundCombat, Actor npc, Armor[] renderedDevices) Global
    ; find devices
    Keyword zadLockable = ddLibs.zad_Lockable
    Int bottomIndex = 0
    Int topIndex = renderedDevices.Length
    Int index = 0
    Int count = npc.GetNumItems()
    While (index < count && bottomIndex < topIndex)
        Armor maybeRenderedDevice = npc.GetNthForm(index) as Armor
        If (maybeRenderedDevice != None && maybeRenderedDevice.HasKeyword(zadLockable))
            ; found a rendered device
            If (maybeRenderedDevice.GetEnchantment() == None)
                ; put devices without magical effect temporarily at top of array
                topIndex -= 1
                renderedDevices[topIndex] = maybeRenderedDevice
            Else
                ; put devices with magical effect at bottom of array
                renderedDevices[bottomIndex] = maybeRenderedDevice
                bottomIndex += 1
            EndIf
        EndIf
        index += 1
    EndWhile
    index = bottomIndex
    If (index < topIndex)
        ; move devices without magical effect to bottom of array, just after devices with magical effect
        While (topIndex < renderedDevices.Length)
            renderedDevices[index] = renderedDevices[topIndex]
            index += 1
            renderedDevices[topIndex] = None
            topIndex += 1
        EndWhile
    EndIf
    While (index < renderedDevices.Length && renderedDevices[index] != None)
        ; clear unused array slot (reusing the array and less devices found than last time)
        renderedDevices[index] = None
        index += 1
    EndWhile
    ; analyze devices, but only the ones with magical effect
    ; (assumption: devices without magical effects have none of the special effect DD keywords that we are interested in)
    Bool useUnarmedCombatPackage = false
    Bool hasHeavyBondage = false
    Bool disableKick = !useBoundCombat
    Bool hasAnimation = false
    If (bottomIndex > 0)
        Keyword zadDeviousHeavyBondage = ddLibs.zad_DeviousHeavyBondage
        index = 0
        While (index < bottomIndex)
            If (renderedDevices[index].HasKeyword(zadDeviousHeavyBondage))
                ; use unarmed combat when wearing heavy bondage and take note of the heavy bondage
                useUnarmedCombatPackage = true
                hasHeavyBondage = true
                hasAnimation = true
                index = 999
            Else
                index += 1
            EndIf
        EndWhile
        If (!useUnarmedCombatPackage)
            Keyword zadDeviousBondageMittens = ddLibs.zad_DeviousBondageMittens
            index = 0
            While (index < bottomIndex)
                If (renderedDevices[index].HasKeyword(zadDeviousBondageMittens))
                    ; use unarmed combat when wearing bondage mittens
                    useUnarmedCombatPackage = true
                    index = 999
                Else
                    index += 1
                EndIf
            EndWhile
        EndIf
        If (hasHeavyBondage && !disableKick)
            Keyword zadBoundCombatDisableKick = ddLibs.zad_BoundCombatDisableKick
            index = 0
            While (index < bottomIndex)
                If (renderedDevices[index].HasKeyword(zadBoundCombatDisableKick))
                    ; take note if not able to kick
                    disableKick = true
                    index = 999
                Else
                    index += 1
                EndIf
            EndWhile
        EndIf
        If (!hasAnimation)
            Keyword zadDeviousPonyGear = ddLibs.zad_DeviousPonyGear
            Keyword zadDeviousHobbleSkirt = ddLibs.zad_DeviousHobbleSkirt
            Keyword zadDeviousHobbleSkirtRelaxed = ddLibs.zad_DeviousHobbleSkirtRelaxed
            index = 0
            While (index < bottomIndex)
                If (renderedDevices[index].HasKeyword(zadDeviousPonyGear) || renderedDevices[index].HasKeyword(zadDeviousHobbleSkirt) && !renderedDevices[index].HasKeyword(zadDeviousHobbleSkirtRelaxed))
                    ; found a device other than heavy bondage that requires animations
                    hasAnimation = true
                    index = 999
                Else
                    index += 1
                EndIf
            EndWhile
        EndIf
    EndIf
    ; assemble return value
    Int flags = bottomIndex ; number of devices with magical effect
    If (useUnarmedCombatPackage)
        flags += 256 ; use unarmed combat package
    EndIf
    If (hasHeavyBondage && disableKick)
        flags += 512 ; helpless
    EndIf
    If (hasAnimation)
        flags += 1024 ; has animation
    EndIf
    Return flags
EndFunction


; unequip devices and return a bitmap for the devices to reequip
Int Function UnequipDevices(Actor npc, Armor[] renderedDevices, Int devicesWithMagicalEffectCount) Global
    Int currentBit = 1
    Int bitmapToEquip = 0
    Int index = 0
    While (index < renderedDevices.Length && renderedDevices[index] != None)
        If (npc.IsEquipped(renderedDevices[index]))
            ; unequip devices with magical effects
            If (index < devicesWithMagicalEffectCount)
                npc.UnequipItem(renderedDevices[index], abPreventEquip=true, abSilent=true)
                bitmapToEquip = Math.LogicalOr(bitmapToEquip, currentBit)
            EndIf
        Else
            ; sometimes a conflicting "armor" from another mod is blocking the rendered device
            ; a known mod causing this issue is AllGUD with its various displayed things
            ; work around the issue by force-unequipping the conflicting armor
            Int slotMask = renderedDevices[index].GetSlotMask()
            Armor conflictingItem = npc.GetWornForm(slotMask) as Armor
            If (conflictingItem != None)
                npc.UnequipItem(conflictingItem, abPreventEquip=true, abSilent=true)
            EndIf
            bitmapToEquip = Math.LogicalOr(bitmapToEquip, currentBit)
        EndIf
        currentBit = Math.LeftShift(currentBit, 1)
        index += 1
    EndWhile
    Return bitmapToEquip
EndFunction


; reequip devices according to the bitmap
Function ReequipDevices(Actor npc, Armor[] renderedDevices, int bitmapToEquip) Global
    Int currentBit = 1
    Int equippedBitmap = 0
    Int index = 0
    While (equippedBitmap != bitmapToEquip)
        If (Math.LogicalAnd(bitmapToEquip, currentBit) != 0)
            npc.EquipItem(renderedDevices[index], abPreventRemoval=true, abSilent=true)
            equippedBitmap = Math.LogicalOr(equippedBitmap, currentBit)
        EndIf
        currentBit = Math.LeftShift(currentBit, 1)
        index += 1
    EndWhile
EndFunction


; check that devices are equipped according to the bitmap
Bool Function CheckDevicesEquipped(Actor npc, Armor[] renderedDevices, int bitmapToCheck) Global
    Int currentBit = 1
    Int checkedBitmap = 0
    Int index = 0
    While (checkedBitmap != bitmapToCheck)
        If (Math.LogicalAnd(bitmapToCheck, currentBit) != 0)
            If (!npc.IsEquipped(renderedDevices[index]))
                Return false
            EndIf
            checkedBitmap = Math.LogicalOr(checkedBitmap, currentBit)
        EndIf
        currentBit = Math.LeftShift(currentBit, 1)
        index += 1
    EndWhile
    Return true
EndFunction


; returns true if ignoreWeapon was kept equipped
Bool Function UnequipWeapons(Actor npc, Weapon ignoreWeapon = None) Global
    ; detect right hand weapon/spell (two-handed weapon counts as right hand)
    Int itemType
    Weapon rightHandWeapon = None
    Spell rightHandSpell = None
    itemType = npc.GetEquippedItemType(1)
    If (itemType == 9)
        rightHandSpell = npc.GetEquippedSpell(1)
    Else
        rightHandWeapon = npc.GetEquippedWeapon(false)
    EndIf
    ; detect and unequip left-hand weapon/spell/shield
    Bool keptIgnoreWeapon = false
    itemType = npc.GetEquippedItemType(0)
    If (itemType != 0)
        If (itemType == 9)
            Spell leftHandSpell = npc.GetEquippedSpell(0)
            npc.UnequipSpell(leftHandSpell, 0)
        ElseIf (itemType == 10)
            Armor shield = npc.GetEquippedShield()
            npc.UnequipItem(shield, abSilent=true)
        Else
            Weapon leftHandWeapon = npc.GetEquippedWeapon(true)
            If (ignoreWeapon == None)
                npc.UnequipItemEx(leftHandWeapon, equipSlot=0)
            ElseIf (leftHandWeapon != ignoreWeapon)
                npc.UnequipItemEx(leftHandWeapon, equipSlot=0)
            Else
                keptIgnoreWeapon = true
            EndIf
        EndIf
    EndIf
    ; unequip right-hand weapon/spell
    If (rightHandSpell != None)
        npc.UnequipSpell(rightHandSpell, 1)
    ElseIf (rightHandWeapon != None)
        If (ignoreWeapon == None)
            npc.UnequipItemEx(rightHandWeapon, equipSlot=1)
        ElseIf (rightHandWeapon != ignoreWeapon)
            npc.UnequipItemEx(rightHandWeapon, equipSlot=1)
        Else
            keptIgnoreWeapon = true
        EndIf
    EndIf
    Return keptIgnoreWeapon
EndFunction


String Function GetFormIdAsString(Form item) Global
    Int modId
    Int baseId
    Int formId = item.GetFormID()
    If (formId >= 0)
        modId = formId / 0x01000000
        baseId = formId - modId * 0x1000000
    Else
        modId = 255 + (formId / 0x01000000)
        baseId = (256 - modId) * 0x1000000 + formId
    EndIf
    String hex = GetHexDigit(modId / 0x10) + GetHexDigit(modId % 0x10)
    hex += GetHexDigit(baseId / 0x00100000) + GetHexDigit((baseId / 0x00010000) % 0x10)
    hex += GetHexDigit((baseId / 0x00001000) % 0x10) + GetHexDigit((baseId / 0x00000100) % 0x10)
    hex += GetHexDigit((baseId / 0x00000010) % 0x10) + GetHexDigit(baseId % 0x10)
    Return hex
EndFunction


String Function GetHexDigit(Int nibble) Global
    If (nibble < 8)
        If (nibble < 4)
            If (nibble < 2)
                If (nibble == 0)
                    Return "0"
                Else
                    Return "1"
                EndIf
            ElseIf (nibble == 2)
                Return "2"
            Else
                Return "3"
            EndIf
        ElseIf (nibble < 6)
            If (nibble == 4)
                Return "4"
            Else
                Return "5"
            EndIf
        ElseIf (nibble == 6)
            Return "6"
        Else
            Return "7"
        EndIf
    ElseIf (nibble < 12)
        If (nibble < 10)
            If (nibble == 8)
                Return "8"
            Else
                Return "9"
            EndIf
        ElseIf (nibble == 10)
            Return "A"
        Else
            Return "B"
        EndIf
    ElseIf (nibble < 14)
        If (nibble == 12)
            Return "C"
        Else
            Return "D"
        EndIf
    ElseIf (nibble == 14)
        Return "E"
    Else
        Return "F"
    EndIf
EndFunction