;
; See comment in DDNF_NpcTracker for the purpose of this script.
; We do not add properties to this script as there are a lot of instances.
; Instead properties are added to DDNF_NpcTracker.
; This is not only an optimization, it makes it easier to modify the script.
; We only need to recompile it instead of modifying properties in all instances.
;
Scriptname DDNF_NpcTracker_NPC extends ReferenceAlias

; state of npc in ref
Bool _loaded
Armor[] _renderedDevices
Int _renderedDevicesFlags ; -1 means rendered devices are not known
Bool _useUnarmedCombatPackage
Bool _helpless
Bool _hasAnimation
Bool _hasDummyWeapon

; state of script
Bool _ignoreNotEquippedInNextFixup
Bool _animationIsApplied
Bool _fixupLock


Function HandleGameLoaded(Bool upgrade)
    Actor npc = GetReference() as Actor
    If (npc != None)
        ; clear on upgrade, NPC will be re-added if found again
        ; also clear if NPC is dead (safety net in case OnDeath was missed somehow)
        If (upgrade || npc.IsDead())
            Clear() 
        ; also do a safety check in case OnUnload was missed somehow
        ElseIf (!npc.Is3DLoaded())
            _loaded = false
            RegisterForSingleUpdate(8.0)
        EndIf
    EndIf
EndFunction


Function HandleOptionsChanged(Bool useBoundCombat)
    Actor npc = GetReference() as Actor
    If (npc != None && _loaded && _useUnarmedCombatPackage)
        If (_helpless && useBoundCombat || !_helpless && !useBoundCombat)
            ; rescan devices, helpless state might have changed
            _renderedDevicesFlags = -1
            RegisterForFixup()
        EndIf
    EndIf
EndFunction


Function ForceRefTo(ObjectReference akNewRef) ; override
    Actor npc = akNewRef as Actor
    parent.ForceRefTo(npc)
    If (npc != None)
        ; we should receive OnDeath event when NPC dies, but they might already be dead
        If (npc.IsDead())
            parent.Clear()
        Else
            _loaded = npc.Is3DLoaded()
            _renderedDevicesFlags = -1
            ; no need to set _renderedDevices, it is already an empty array
            _useUnarmedCombatPackage = false
            _helpless = false
            _hasAnimation = false
            DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
            _hasDummyWeapon = npc.GetItemCount(npcTracker.DummyWeapon) > 0
            _ignoreNotEquippedInNextFixup = false
            _animationIsApplied = false
            _fixupLock = false
            RegisterForFixup()
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
            UnregisterForUpdate() ; may do nothing
            ; revert changes made to the NPC
            ; but do not revert membership in npcTracker.DeviceTargets faction, it is used to find the NPC again
            DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
            If (_useUnarmedCombatPackage)
                UnregisterForAnimationEvent(npc, "BeginWeaponDraw")
                npc.RemoveFromFaction(npcTracker.UnarmedCombatants)
            EndIf
            If (_helpless)
                npc.RemoveFromFaction(npcTracker.Helpless)
            EndIf
            If (_hasDummyWeapon)
                If (_useUnarmedCombatPackage)
                    npc.EquipItemEx(npcTracker.DummyWeapon, equipSound=false) ; restore ability to draw weapons
                    npc.UnequipItemEx(npcTracker.DummyWeapon)
                EndIf
                Int dummyWeaponCount = npc.GetItemCount(npcTracker.DummyWeapon)
                If (dummyWeaponCount > 0)
                    npc.RemoveItem(npcTracker.DummyWeapon, aiCount=dummyWeaponCount)
                EndIf
            EndIf
            ; no reason to clear the state, it will be set correctly in ForceRefTo() or in the Fixup following it
            ; but clear the array with rendered devices such that the game can reclaim the memory
            Armor[] emptyArray
            _renderedDevices = emptyArray
            ; finally kick from alias
            parent.Clear()
        EndIf
        ; done
        _fixupLock = false
    EndIf
EndFunction


Event OnDeath(Actor akKiller)
    ; stop tracking the NPC on death
    Clear()
EndEvent


Event OnLoad()
    _loaded = true
    RegisterForFixup()
EndEvent


Event OnUnload()
    _loaded = false
    _animationIsApplied = false ; unloading breaks animations
    RegisterForSingleUpdate(8.0) ; the update will call Clear() if _loaded is false
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
                If (_animationIsApplied && (maybeArmor.HasKeyword(ddLibs.zad_DeviousHeavyBondage) || maybeArmor.HasKeyword(ddLibs.zad_DeviousPonyGear) || maybeArmor.HasKeyword(ddLibs.zad_DeviousHobbleSkirt) && !maybeArmor.HasKeyword(ddLibs.zad_DeviousHobbleSkirtRelaxed)))
                    ; the added or removed device modifies animations, we need to reset animations
                    _animationIsApplied = false
                EndIf
            EndIf
        EndIf
        If (_loaded)
            RegisterForFixup()
        EndIf
    EndIf
EndFunction


Event OnCombatStateChanged(Actor akTarget, Int aeCombatState)
    If (_useUnarmedCombatPackage && !_helpless)
        Actor npc = GetReference() as Actor
        If (npc != None)
            If (aeCombatState > 0)
                DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
                npc.EquipItemEx(npcTracker.DummyWeapon, equipSound=false) ; restore ability to draw weapons
            ElseIf (!_fixupLock)
                SheatheWeaponHack(npc)
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
        If (_useUnarmedCombatPackage && (_helpless || npc.GetCombatState() == 0))
            Utility.Wait(1.2)
            If (npc == (GetReference() as Actor) && _useUnarmedCombatPackage && (_helpless || npc.GetCombatState() == 0)) ; recheck conditions after wait
                If (!_fixupLock)
                    SheatheWeaponHack(npc)
                EndIf
            EndIf
        EndIf
    Else
        Utility.Wait(0.5) ; wait before unregister, see above
        UnregisterForAnimationEvent(akSource, asEventName) ; cleanup
    EndIf
EndEvent


Function RegisterForFixup()
    ; fixing the NPC in an update event has several important advantages:
    ; 1. if the player is currently modifying the NPCs inventory, the fixup will be done after the menu has been closed
    ; 2. if there are multiple reasons for a fixup in quick succession, the fixup will only run once
    ; 3. it is an async operation, so when the scanner calls ForceRefIfEmpty it does not have to wait for the fixup
    
    ; 0.5 seconds seems to be a good compromise between quickness of reaction and the ability to collapse multiple events into one
    RegisterForSingleUpdate(0.5)
EndFunction


Event OnUpdate()
    Actor npc = GetReference() as Actor
    If (npc == None)
        Return ; race condition
    EndIf
    If (_fixupLock)
        RegisterForFixup() ; already running, postpone
        Return
    EndIf
    If (!_loaded)
        Clear()
        Return
    EndIf
    _fixupLock = true

    ; step one: find and analyze all rendered devices in the inventory of the NPC
    DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
    zadLibs ddLibs = npcTracker.DDLibs
    If (_renderedDevicesFlags < 0)
        ; devices are not known, find and analyze them
        If (_renderedDevices.Length != 32) ; number of slots
            _renderedDevices = new Armor[32] 
        EndIf
        _renderedDevicesFlags = FindAndAnalyzeRenderedDevices(ddLibs, npcTracker.UseBoundCombat, npc, _renderedDevices)
        If (_renderedDevices[0] == None)
            ; no devices found, remove NPC from alias
            npc.RemoveFromFaction(npcTracker.DeviceTargets)
            _fixupLock = false
            Clear()
            Return
        Else
            npc.SetFactionRank(npcTracker.DeviceTargets, 0)
        EndIf
    EndIf
    Bool useUnarmedCombatPackage = Math.LogicalAnd(_renderedDevicesFlags, 1)
    Bool helpless = Math.LogicalAnd(_renderedDevicesFlags, 2)
    Bool hasAnimation = Math.LogicalAnd(_renderedDevicesFlags, 4)
    ; also add dummy weapon if necessary
    ; we need to do this now, before actually fixing devices
    If (useUnarmedCombatPackage && !helpless || !useUnarmedCombatPackage && (hasAnimation || _useUnarmedCombatPackage))
        If (!_hasDummyWeapon)
            _hasDummyWeapon = true
            npc.AddItem(npcTracker.DummyWeapon)
        EndIf
    EndIf
    
    ; step two: unequip and reequip all rendered devices to restart the effects
    If (UnequipAllDevices(npc, _renderedDevices) > 0)
        Utility.Wait(0.1) ; give the game time to fully register the unequips
    EndIf
    If (EquipAllDevices(npc, _renderedDevices) > 0)
        Utility.Wait(0.1) ; give the game time to fully register the equips
    EndIf
    If (_ignoreNotEquippedInNextFixup)
        _ignoreNotEquippedInNextFixup = false
    ElseIf (!CheckAllDevicesEquipped(npc, _renderedDevices))
        ; some devices are still not equipped, it is not clear why this happens sometimes
        ; reschedule fixup but ignore the issue if it occurs again
        _ignoreNotEquippedInNextFixup = true
        RegisterForFixup()
        _fixupLock = false
        Return
    EndIf
        
    ; step three: handle weapons and animation effects
    If (useUnarmedCombatPackage) ; implies hasAnimation
        ; modifying animations will have the same effect as SheatheWeaponHack if weapons are drawn
        If (_animationIsApplied)
            ; only re-start idle as animations are already set
            Debug.SendAnimationEvent(npc, "IdleForceDefaultState")
        else
            ; use the full procuedure
            UnequipWeapons(npc)
            ddLibs.BoundCombat.EvaluateAA(npc) ; very expensive call
            npc.SheatheWeapon() ; may do nothing
            _animationIsApplied = true
        EndIf
        RegisterForAnimationEvent(npc, "BeginWeaponDraw") ; register even if we think that we are already registered
    Else
        Bool restoreWeaponAccess = false
        If (hasAnimation)
            ; modifying animations will have the same effect as SheatheWeaponHack if weapons are drawn
            restoreWeaponAccess = npc.IsWeaponDrawn()
            If (_animationIsApplied)
                ; only re-start idle as animations are already set
                Debug.SendAnimationEvent(npc, "IdleForceDefaultState") ; only re-start idle as animations are already set
            Else
                ; use the full procuedure
                ddLibs.BoundCombat.EvaluateAA(npc) ; very expensive call
                _animationIsApplied = true
            EndIf
        EndIf
        If (_useUnarmedCombatPackage)
            restoreWeaponAccess = true
            UnregisterForAnimationEvent(npc, "BeginWeaponDraw")
        EndIf
        If (restoreWeaponAccess)
            npc.EquipItemEx(npcTracker.DummyWeapon, equipSound=false)
        EndIf
    EndIf
    
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
    If (_useUnarmedCombatPackage && !_helpless && npc.GetCombatState() > 0)
        npc.EquipItemEx(npcTracker.DummyWeapon, equipSound=false) ; restore ability to draw weapons
    EndIf
    
    ; done
    _fixupLock = false
EndEvent


;
; Fills the renderedDevices array with the rendered devices of the actor, starting from index 0.
; Returns an int composed of the following flags:
; 1 - use unarmed combat package
; 2 - helpless
; 4 - has animation
;
Int Function FindAndAnalyzeRenderedDevices(zadLibs ddLibs, Bool useBoundCombat, Actor npc, Armor[] renderedDevices) Global
    Keyword zadLockable = ddLibs.zad_Lockable
    Keyword zadDeviousHeavyBondage = ddLibs.zad_DeviousHeavyBondage
    Keyword zadDeviousBondageMittens = ddLibs.zad_DeviousBondageMittens
    Keyword zadBoundCombatDisableKick = ddLibs.zad_BoundCombatDisableKick
    Keyword zadDeviousPonyGear = ddLibs.zad_DeviousPonyGear
    Keyword zadDeviousHobbleSkirt = ddLibs.zad_DeviousHobbleSkirt
    Keyword zadDeviousHobbleSkirtRelaxed = ddLibs.zad_DeviousHobbleSkirtRelaxed
    Int renderedDevicesCount = 0
    Bool useUnarmedCombatPackage = false
    Bool hasHeavyBondage = false
    Bool disableKick = !useBoundCombat
    Bool hasAnimation = false
    Int index = 0
    Int count = npc.GetNumItems()
    While (index < count && renderedDevicesCount < renderedDevices.Length)
        Armor maybeRenderedDevice = npc.GetNthForm(index) as Armor
        If (maybeRenderedDevice != None && maybeRenderedDevice.HasKeyword(zadLockable))
            ; found a rendered device
            renderedDevices[renderedDevicesCount] = maybeRenderedDevice
            renderedDevicesCount += 1
            ; use unarmed combat when wearing heavy bondage and take note of the heavy bondage
            If (!hasHeavyBondage && maybeRenderedDevice.HasKeyword(zadDeviousHeavyBondage))
                useUnarmedCombatPackage = true
                hasHeavyBondage = true
                hasAnimation = true
            EndIf
            ; use unarmed combat when wearing bondage mittens
            If (!useUnarmedCombatPackage && maybeRenderedDevice.HasKeyword(zadDeviousBondageMittens))
                useUnarmedCombatPackage = true
            EndIf
            ; take note if not able to kick
            If (!disableKick && maybeRenderedDevice.HasKeyword(zadBoundCombatDisableKick))
                disableKick = true
            EndIf
            ; check for devices other than heavy bondage that require animations
            If (!hasAnimation && (maybeRenderedDevice.HasKeyword(zadDeviousPonyGear) || maybeRenderedDevice.HasKeyword(zadDeviousHobbleSkirt) && !maybeRenderedDevice.HasKeyword(zadDeviousHobbleSkirtRelaxed)))
                hasAnimation = true
            EndIf
        EndIf
        index += 1
    EndWhile
    While (renderedDevicesCount < renderedDevices.Length && renderedDevices[renderedDevicesCount] != None)
        renderedDevices[renderedDevicesCount] = None
        renderedDevicesCount += 1
    EndWhile
    Int flags = 0
    If (useUnarmedCombatPackage)
        flags += 1 ; use unarmed combat package
    EndIf
    If (hasHeavyBondage && disableKick)
        flags += 2 ; helpless
    EndIf
    If (hasAnimation)
        flags += 4 ; has animation
    EndIf
    Return flags
EndFunction


Int Function UnequipAllDevices(Actor npc, Armor[] renderedDevices) Global
    Int unequippedCount = 0
    Int index = 0
    While (index < renderedDevices.Length && renderedDevices[index] != None)
        If (npc.IsEquipped(renderedDevices[index]))
            npc.UnequipItem(renderedDevices[index], abPreventEquip=true)
            unequippedCount += 1
        Else
            ; sometimes a conflicting "armor" from another mod is blocking the rendered device
            ; a known mod causing this issue is AllGUD with its various displayed things
            ; work around the issue by force-unequipping the conflicting armor
            Int slotMask = renderedDevices[index].GetSlotMask()
            Armor conflictingItem = npc.GetWornForm(slotMask) as Armor
            If (conflictingItem != None)
                npc.UnequipItem(conflictingItem, abPreventEquip=true)
                unequippedCount += 1
            EndIf
        EndIf
        index += 1
    EndWhile
    Return unequippedCount
EndFunction


Int Function EquipAllDevices(Actor npc, Armor[] renderedDevices) Global
    Int index = 0
    While (index < renderedDevices.Length && renderedDevices[index] != None)
        npc.EquipItem(renderedDevices[index], abPreventRemoval=true)
        index += 1
    EndWhile
    Return index
EndFunction


Bool Function CheckAllDevicesEquipped(Actor npc, Armor[] renderedDevices) Global
    Int index = 0
    While (index < renderedDevices.Length && renderedDevices[index] != None)
        If (!npc.IsEquipped(renderedDevices[index]))
            Return false
        EndIf
        index += 1
    EndWhile
    Return true
EndFunction


Function SheatheWeaponHack(Actor npc) Global
    ; only works when weapons are currently drawn
    ; will prevent the npc from drawing weapons again until equipped weapon changes
    UnequipWeapons(npc)
    Debug.SendAnimationEvent(npc, "IdleForceDefaultState") ; black magic
    npc.SheatheWeapon()
EndFunction


Function UnequipWeapons(Actor npc) Global
    Weapon rightHandWeapon = npc.GetEquippedWeapon(false)
    If (rightHandWeapon != None)
        npc.UnequipItemEx(rightHandWeapon, equipSlot=1)
    Else
        Spell rightHandSpell = npc.GetEquippedSpell(1)
        If (rightHandSpell != None)
            npc.UnequipSpell(rightHandSpell, 1)
        EndIf
    EndIf
    Armor shield = npc.GetEquippedShield()
    If (shield != None)
        npc.UnequipItem(shield)
    Else
        Spell leftHandSpell = npc.GetEquippedSpell(0)
        If (leftHandSpell != None)
            npc.UnequipSpell(leftHandSpell, 0)
        Else
            Weapon leftHandWeapon = npc.GetEquippedWeapon(true)
            If (leftHandWeapon != None)
                npc.UnequipItemEx(leftHandWeapon, equipSlot=0)
            EndIf
        EndIf
    EndIf
EndFunction