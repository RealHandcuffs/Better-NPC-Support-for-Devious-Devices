;
; See comment in DDNF_NpcTracker for the purpose of this script.
; We do not add properties to this script as there are a lot of instances.
; Instead properties are added to DDNF_NpcTracker.
; This is not only an optimization, it makes it easier to modify the script.
; We only need to recompile it instead of modifying properties in all instances.
;
Scriptname DDNF_NpcTracker_NPC extends ReferenceAlias

; all variables are for state of npc in ref
Bool _useUnarmedCombatPackage
Bool _helpless
Bool _ignoreNotEquippedInNextFixup
Bool _fixupLock

Bool Function ForceRefIfEmpty(ObjectReference akNewRef) ; override
    If (!parent.ForceRefIfEmpty(akNewRef))
        Return false
    EndIf
    _useUnarmedCombatPackage = false
    _helpless = false
    _ignoreNotEquippedInNextFixup = false
    _fixupLock = false
    If (akNewRef != None)
        If (akNewRef.Is3DLoaded())
            RegisterForFixup()
        Else
            RegisterForSingleUpdate(8.0)
            ; the update will stop tracking the NPC if still not loaded
        EndIf
    EndIf
    Return true
EndFunction


Function Clear() ; override
    ; reset npc state before clearing
    UnregisterForUpdate() ; may do nothing
    Actor npc = GetReference() as Actor
    If (_useUnarmedCombatPackage)
        UnregisterForAnimationEvent(npc, "BeginWeaponDraw")
        npc.RemoveFromFaction(npcTracker.UnarmedCombatants)
        npc.RemoveFromFaction(npcTracker.Helpless)
    EndIf
    DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
    Int dummyWeaponCount = npc.GetItemCount(npcTracker.DummyWeapon) ; used to restore ability to draw weapons
    If (dummyWeaponCount > 0)
        npc.RemoveItem(npcTracker.DummyWeapon, aiCount=dummyWeaponCount)
    EndIf
    parent.Clear()
EndFunction


Event OnDeath(Actor akKiller)
    ; stop tracking the NPC on death
    Clear()
EndEvent


Event OnLoad()
    ; can happen in the 8 seconds after OnUnload (NPC following player, player turning around and returning)
    RegisterForFixup()
EndEvent


Event OnUnload()
    RegisterForSingleUpdate(8.0)
    ; the update will stop tracking the NPC if still not loaded
EndEvent


Event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
    ; adding/removing equipment screws with devious devices
    Actor npc = GetReference() as Actor
    If (npc != None && npc.Is3DLoaded())
        DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
        If (akBaseItem != npcTracker.DummyWeapon)
            RegisterForFixup()
        EndIf
    EndIf
EndEvent


Event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
    ; adding/removing equipment often screws with devious devices
    Actor npc = GetReference() as Actor
    If (npc != None && npc.Is3DLoaded())
        DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
        If (akBaseItem != npcTracker.DummyWeapon)
            RegisterForFixup()
        EndIf
    EndIf
EndEvent


Event OnCombatStateChanged(Actor akTarget, Int aeCombatState)
    If (_useUnarmedCombatPackage && !_helpless)
        Actor npc = GetReference() as Actor
        If (npc != None)
            If (aeCombatState > 0)
                DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
                npc.EquipItemEx(npcTracker.DummyWeapon, equipSound=false) ; restore ability to draw weapons
            Else
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
            Utility.Wait(1.5)
            If (npc == (GetReference() as Actor) && _useUnarmedCombatPackage && (_helpless || npc.GetCombatState() != 1)) ; recheck condition after wait
                If (!_fixupLock)
                    SheatheWeaponHack(npc)
                EndIf
            EndIf
        EndIf
    Else
        Utility.Wait(0.5)
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


Function HandleGameLoaded()
    Actor npc = GetReference() as Actor
    If (npc != None && !npc.Is3DLoaded())
        RegisterForSingleUpdate(8.0) ; same as OnUnload
    EndIf
EndFunction


Function HandleOptionsChanged(Bool useBoundCombat)
    Actor npc = GetReference() as Actor
    If (npc != None && npc.Is3DLoaded() && _useUnarmedCombatPackage)
        If (_helpless && useBoundCombat || !_helpless && !useBoundCombat)
            RegisterForFixup() ; re-run fixup, helpless state might have changed
        EndIf
    EndIf
EndFunction


Event OnUpdate()
    Actor npc = GetReference() as Actor
    If (npc == None)
        Return ; race condition
    EndIf
    If (!npc.Is3DLoaded() || npc.IsDead())
        Clear()
        Return
    EndIf
    If (_fixupLock)
        RegisterForFixup() ; already running, postpone
        Return
    EndIf
    _fixupLock = true

    ; step one: find and analyze all rendered devices in the inventory of the NPC
    ; but do not manipulate them yet, we do not know for sure if manipulating devices can change their order
    DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
    zadLibs ddLibs = npcTracker.DDLibs
    Armor[] renderedDevices = new Armor[16] ; 16 should be enough as DD is only using 14 slots right now
    Int renderedDevicesCount = 0
    Bool useUnarmedCombatPackage = false
    Bool hasHeavyBondage = false
    Bool disableKick = !npcTracker.UseBoundCombat ; caching the value of ddLibs.Config.UseBoundCombat
    Bool hasAnimation = false
    Int index = 0
    Int count = npc.GetNumItems()
    Keyword zadLockable = ddLibs.zad_Lockable;
    While (index < count && renderedDevicesCount < 16)
        Armor maybeRenderedDevice = npc.GetNthForm(index) as Armor
        If (maybeRenderedDevice != None)
            If (maybeRenderedDevice.HasKeyword(zadLockable))
                ; found a rendered device
                renderedDevices[renderedDevicesCount] = maybeRenderedDevice
                renderedDevicesCount += 1
                ; use unarmed combat when wearing bondage mittens
                If (!useUnarmedCombatPackage && maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousBondageMittens))
                    useUnarmedCombatPackage = true
                EndIf
                ; use unarmed combat when wearing heavy bondage and take note of the heavy bondage
                If (!hasHeavyBondage && maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousHeavyBondage))
                    useUnarmedCombatPackage = true
                    hasHeavyBondage = true
                    hasAnimation = true
                EndIf
                ; take note if not able to kick
                If (!disableKick && maybeRenderedDevice.HasKeyword(ddLibs.zad_BoundCombatDisableKick))
                    disableKick = true
                EndIf
                ; check for devices other than heavy bondage that require animations
                If (!hasAnimation && (maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousPonyGear) || maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousHobbleSkirt) && !maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousHobbleSkirtRelaxed)))
                    hasAnimation = true ; device requires animation set
                EndIf
            EndIf
        EndIf
        index += 1
    EndWhile
    Int dummyWeaponCount = npc.GetItemCount(npcTracker.DummyWeapon) ; used to restore ability to draw weapons
    If (hasAnimation)
        If (dummyWeaponCount == 0)
            npc.AddItem(npcTracker.DummyWeapon)
        EndIf
    ElseIf (dummyWeaponCount > 0 && !_useUnarmedCombatPackage)
        npc.RemoveItem(npcTracker.DummyWeapon, aiCount=dummyWeaponCount)
    EndIf
    
    ; step two: unequip and reequip all rendered devices to restart the effects
    Bool doWait = false
    index = 0
    While (index < renderedDevicesCount)
        If (npc.IsEquipped(renderedDevices[index]))
            npc.UnequipItem(renderedDevices[index], abPreventEquip=true)
            doWait = true
        Else
            ; sometimes the problem is a conflicting "armor" from another mod preventing the rendered device
            ; from equipping - a known mod causing this issue is AllGUD with its various displayed things
            Int slotMask = renderedDevices[index].GetSlotMask()
            Armor conflictingItem = npc.GetWornForm(slotMask) as Armor
            If (conflictingItem != None)
                npc.UnequipItem(conflictingItem, abPreventEquip=true)
                doWait = true
            EndIf
        EndIf
        index += 1
    EndWhile
    If (doWait)
        Utility.Wait(0.2) ; give the game time to fully register the unequips
    EndIf
    doWait = false
    index = 0
    While (index < renderedDevicesCount)
        npc.EquipItem(renderedDevices[index], abPreventRemoval=true)
        doWait = true
        index += 1
    EndWhile
    If (doWait)
        Utility.Wait(0.2) ; give the game time to fully register the equips
    EndIf
    If (_ignoreNotEquippedInNextFixup)
        _ignoreNotEquippedInNextFixup = false
    Else
        index = 0
        While (index < renderedDevicesCount)
            If (!npc.IsEquipped(renderedDevices[index]))
                ; still not equipped, reschedule fixup but ignore the issue if it occurs again
                _ignoreNotEquippedInNextFixup = true
                RegisterForSingleUpdate(1.5) ; longer wait time than usual
            EndIf
            index += 1
        EndWhile
    EndIf
        
    ; step three: handle weapons and animation effects
    If (useUnarmedCombatPackage) ; implies hasAnimation
        UnequipWeapons(npc)
        ddLibs.BoundCombat.EvaluateAA(npc) ; will have the same effect as SheatheWeaponHack if weapons are drawn
        npc.SheatheWeapon() ; may do nothing
        RegisterForAnimationEvent(npc, "BeginWeaponDraw") ; register even if we think that we are already registered
        _useUnarmedCombatPackage = true
    Else
        Bool restoreWeaponAccess = false
        If (hasAnimation)
            restoreWeaponAccess = npc.IsWeaponDrawn()
            ddLibs.BoundCombat.EvaluateAA(npc) ; will have the same effect as SheatheWeaponHack if weapons are drawn
        EndIf
        If (_useUnarmedCombatPackage)
            UnregisterForAnimationEvent(npc, "BeginWeaponDraw")
            _useUnarmedCombatPackage = false
            restoreWeaponAccess = true
        EndIf
        If (restoreWeaponAccess)
            npc.EquipItemEx(npcTracker.DummyWeapon, equipSound=false)
        EndIf
    EndIf
    _helpless = hasHeavyBondage && disableKick
    
    ; step four: adjust factions
    If (_useUnarmedCombatPackage)
        npc.AddToFaction(npcTracker.UnarmedCombatants)
        If (_helpless)
            npc.AddToFaction(npcTracker.Helpless)
        Else
            npc.RemoveFromFaction(npcTracker.Helpless)
        EndIf
    Else
        npc.RemoveFromFaction(npcTracker.UnarmedCombatants)
        npc.RemoveFromFaction(npcTracker.Helpless)
    EndIf
    ; add/remove to device users faction, used to find npc again even if all rendered devices are unequipped
    If (renderedDevicesCount > 0)
        npc.AddToFaction(npcTracker.DeviceTargets)
    Else
        npc.RemoveFromFaction(npcTracker.DeviceTargets)
        ; actually remove from alias in that case!
        Clear()
    EndIf
    ; special handling if fixup is during combat
    If (npc.GetCombatState() > 0)
        If (_useUnarmedCombatPackage && !_helpless)
            npc.EquipItemEx(npcTracker.DummyWeapon, equipSound=false) ; restore ability to draw weapons
        EndIf
        npc.EvaluatePackage()
    EndIf
    
    ; done
    _fixupLock = false
EndEvent


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
    EndIf
    Spell rightHandSpell = npc.GetEquippedSpell(1)
    If (rightHandSpell != None)
        npc.UnequipSpell(rightHandSpell, 1)
    EndIf
    Armor shield = npc.GetEquippedShield()
    If (shield != None)
        npc.UnequipItem(shield)
    EndIf
    Weapon leftHandWeapon = npc.GetEquippedWeapon(true)
    If (leftHandWeapon != None)
        npc.UnequipItemEx(leftHandWeapon, equipSlot=0)
    EndIf
    Spell leftHandSpell = npc.GetEquippedSpell(0)
    If (leftHandSpell != None)
        npc.UnequipSpell(leftHandSpell, 0)
    EndIf
EndFunction