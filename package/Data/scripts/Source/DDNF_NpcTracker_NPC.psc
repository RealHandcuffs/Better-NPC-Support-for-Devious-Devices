
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
Bool _hasPanelGag

; variables tracking state of script
; there is also a script state, so this is not the whole picture
Bool _fixupHighPriority
Bool _ignoreNotEquippedInNextFixup
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
            Clear()
        ; also do a safety check in case OnCellDetach was missed somehow
        ElseIf (!IsParentCellAttached(npc))
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
    If (npc == None)
        Clear()
    Else
        parent.ForceRefTo(npc) ; no need to set GetNpcs()[aliasIndex] in DDNF_NpcTracker, caller already has done that
        DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
        If (npcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] Start tracking " + GetFormIdAsString(npc) + " " + npc.GetDisplayName() + ".")
        EndIf
        _renderedDevicesFlags = -1
        ; no need to set _renderedDevices, it is already an empty array
        _useUnarmedCombatPackage = false
        _helpless = false
        _hasAnimation = false
        _hasPanelGag = false
        _fixupHighPriority = false
        _ignoreNotEquippedInNextFixup = false
        _fixupLock = false
        _lastFixupRealTime = 0.0
        ; we will receive OnDeath event when NPC dies from now on, but they might already be dead
        If (npc.IsDead())
            Clear()
        ElseIf (!IsParentCellAttached(npc)) ; same for OnCellDetach
            RegisterForFixup(8.0)
        ElseIf (npc.GetItemCount(npcTracker.DDLibs.zad_Lockable) == 0 && npc.GetItemCount(npcTracker.DDLibs.zad_DeviousPlug) == 0)
            _renderedDevicesFlags = 0
            If (_renderedDevices.Length != 32) ; number of slots
                _renderedDevices = new Armor[32]
            Else
                 _renderedDevices[0] = None
            EndIf
            RegisterForFixup(8.0)
        Else
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
                    UnequipWeapons(npc)
                    npc.EquipItem(npcTracker.DummyWeapon, abPreventRemoval=true, abSilent=true)
                EndIf
            EndIf
            Int dummyWeaponCount = npc.GetItemCount(npcTracker.DummyWeapon)
            If (dummyWeaponCount > 0)
                npc.UnequipItemEx(npcTracker.DummyWeapon)
                npc.RemoveItem(npcTracker.DummyWeapon, aiCount=dummyWeaponCount, abSilent=true)
            EndIf
            ; no reason to clear the state, it will be set correctly in ForceRefTo() or in the Fixup following it
            ; but clear the array with rendered devices such that the game can reclaim the memory
            Armor[] emptyArray
            _renderedDevices = emptyArray
            ; finally kick from alias
            parent.Clear() ; will cause packages to change if necessary because they are attached to the alias
            npcTracker.GetNpcs()[npcTracker.GetAliases().Find(Self)] = None ; required, parent may not be aware of the Clear call
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
    Clear()
EndEvent


Event OnCellAttach()
    RegisterForFixup()
EndEvent

Event OnAttachedToCell()
    RegisterForFixup()
EndEvent

Event OnCellDetach()
    RegisterForFixup(8.0) ; the update will call Clear() if still not loaded
EndEvent


Event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
    HandleItemAddedRemoved(akBaseItem, akSourceContainer)
EndEvent


Event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
    HandleItemAddedRemoved(akBaseItem, akDestContainer)
EndEvent


Function HandleItemAddedRemoved(Form akBaseItem, ObjectReference akSourceDestContainer)
    ; adding/removing equipment screws with devious devices
    Actor npc = GetReference() as Actor
    DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
    If (npc != None && akBaseItem != npcTracker.DummyWeapon) ; we take care to add/remove DummyWeapon only in situations where it cannot break devices
        If (akSourceDestContainer == npcTracker.Player)
            _fixupHighPriority = true ; player has inventory of NPC open and is looking at NPC directly
        EndIf
        Armor maybeArmor = akBaseItem as Armor
        Float delayOverride = -1
        If (maybeArmor != None)
            Bool isInventoryDevice = DDNF_NpcTracker.GetRenderedDevice(maybeArmor, false) != None
            If (isInventoryDevice || DDNF_NpcTracker.TryGetInventoryDevice(maybeArmor) != None || maybeArmor.HasKeyword(npcTracker.DDLibs.zad_Lockable) || maybeArmor.HasKeyword(npcTracker.DDLibs.zad_DeviousPlug))
                ; a device has been added or removed, we need to rescan for devices
                _renderedDevicesFlags = -1
                If (isInventoryDevice && !_fixupHighPriority)
                    delayOverride = 2 ; give DD library more time to process the change
                EndIf
            EndIf
        EndIf
        If (delayOverride >= 0)
            RegisterForFixup(delayOverride)
        Else
            RegisterForFixup()
        EndIf
    EndIf
EndFunction


Event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
    If (_useUnarmedCombatPackage && !_fixupLock)
        DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
        Bool doUnequip = false
        Armor equippedArmor = akBaseObject as Armor
        If (equippedArmor != None)
            If (!equippedArmor.IsShield())
                If (npcTracker.WeaponDisplayArmors.HasForm(equippedArmor))
                    Actor npc = GetReference() as Actor
                    If (npc != None && _useUnarmedCombatPackage && !_fixupLock) ; recheck conditions
                        If (npcTracker.EnablePapyrusLogging)
                            Debug.Trace("[DDNF] Unequip weapon display armor " + GetFormIdAsString(akBaseObject) + " " + akBaseObject.GetName() + " of " + GetFormIdAsString(npc) + " " + npc.GetDisplayName() + " after it was equipped.")
                        EndIf
                        npc.UnequipItem(equippedArmor, abSilent=true)
                    EndIf
                EndIf
                Return
            EndIf
            doUnequip = true
        EndIf
        If (!doUnequip)
            doUnequip = (akBaseObject as Spell) != None
        EndIf
        If (!doUnequip)
            Weapon equippiedWeapon = akBaseObject as Weapon
            doUnequip = equippiedWeapon != None && equippiedWeapon != npcTracker.DummyWeapon
        EndIf
        If (doUnequip)
            Actor npc = GetReference() as Actor
            If (npc != None && _useUnarmedCombatPackage && !_fixupLock) ; recheck conditions
                If (npcTracker.EnablePapyrusLogging)
                    Debug.Trace("[DDNF] Unequip weapons of " + GetFormIdAsString(npc) + " " + npc.GetDisplayName() + " after " + GetFormIdAsString(akBaseObject) + " " + akBaseObject.GetName() + " was equipped.")
                EndIf
                If (!(UnequipWeapons(npc, npcTracker.DummyWeapon)) && npc.GetItemCount(npcTracker.DummyWeapon) > 0)
                    npc.EquipItem(npcTracker.DummyWeapon, abPreventRemoval=true, abSilent=true)
                EndIf
            EndIf
        EndIf
    EndIf
EndEvent


Event OnObjectUnequipped(Form akBaseObject, ObjectReference akReference)
    If (!_fixupLock)
        Armor maybeArmor = akBaseObject as Armor
        If (maybeArmor != None)
            DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
            If (maybeArmor.HasKeyword(npcTracker.DDLibs.zad_Lockable) || maybeArmor.HasKeyword(npcTracker.DDLibs.zad_DeviousPlug))
                ; a device was unequipped, check if we need to re-equip it
                Actor npc = GetReference() as Actor
                If (npc != None && !npc.IsEquipped(maybeArmor) && npc.GetItemCount(maybeArmor) > 0)
                    RegisterForFixup()
                EndIf
            EndIf
        EndIf
     EndIf
EndEvent


Event OnCombatStateChanged(Actor akTarget, Int aeCombatState)
    If (_useUnarmedCombatPackage && !_helpless)
        Actor npc = GetReference() as Actor
        If (npc != None)
            DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
            If (aeCombatState == 1)
                UnequipWeapons(npc) ; combat override package will make sure NPC is only using unarmed combat
            ElseIf (!UnequipWeapons(npc, npcTracker.DummyWeapon) && npc.GetItemCount(npcTracker.DummyWeapon) > 0)
                npc.EquipItem(npcTracker.DummyWeapon, abPreventRemoval=true, abSilent=true)
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
            If (!UnequipWeapons(npc, npcTracker.DummyWeapon) && npc.GetItemCount(npcTracker.DummyWeapon) > 0) ; for some reason the game sometimes keeps equipment in the left hand even though DummyWeapon is two-handed
                npc.EquipItem(npcTracker.DummyWeapon, abPreventRemoval=true, abSilent=true)
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


Event OnPackageStart(Package akNewPackage)
    DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
    If (akNewPackage != npcTracker.BoundCombatNPCSandbox && akNewPackage != npcTracker.BoundNPCSandbox)
        Package template = akNewPackage.GetTemplate()
        If (template == npcTracker.Sandbox)
            Actor npc = GetReference() as Actor
            If (npc != None && IsParentCellAttached(npc) && (npc.WornHasKeyword(npcTracker.DDLibs.zad_DeviousHeavyBondage) || npc.WornHasKeyword(npcTracker.DDLibs.zad_DeviousHobbleSkirt)))
                ; bound npc switched to sandbox package (other than DD sandbox packages), check if we can kick them out of it again
                If (npcTracker.EnablePapyrusLogging)
                    Debug.Trace("[DDNF] Trying to kick " + GetFormIdAsString(npc) + " " + npc.GetDisplayName() + " out of sandboxing package.")
                EndIf
                ActorBase npcBase = npc.GetActorBase()
                If (npcBase == Game.GetFormFromFile(0x002B6C, "Dawnguard.esm")) ; DLC1Serana
                    ; Serana's AI is different than that of any other follower, so the DD npc slots are not working
                    DDNF_DLC1Shim.KickSeranaFromSandboxPackage(npc)
                Else
                    ; Let DD slots apply the bound sandbox package
                    npcTracker.DDLibs.RepopulateNpcs()
                EndIf
            EndIf
        EndIf
    EndIf
EndEvent


; stop handling events when reference alias is empty
Auto State AliasEmpty

Event OnDeath(Actor akKiller)
EndEvent

Event OnCellAttach()
EndEvent

Event OnAttachedToCell()
EndEvent

Event OnCellDetach()
EndEvent

Event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
EndEvent

Event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
EndEvent

Event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
EndEvent

Event OnObjectUnequipped(Form akBaseObject, ObjectReference akReference)
EndEvent

Event OnCombatStateChanged(Actor akTarget, Int aeCombatState)
EndEvent

Event OnAnimationEvent(ObjectReference akSource, string asEventName)
EndEvent

Event OnPackageStart(Package akNewPackage)
EndEvent

EndState


; handle all events when reference alias is occupied
State AliasOccupied
EndState


; handle all events when reference alias is occupied and script is waiting for fixup
State AliasOccupiedWaitingForFixup
EndState


Function RegisterForFixup(Float delay = 1.0) ; 1.0 is usually a good compromise between reactivity and collapsing multiple events into one update
    ; fixing the NPC in an update event has several important advantages:
    ; 1. if the player is currently modifying the NPCs inventory, the fixup will be done after the menu has been closed
    ; 2. if there are multiple reasons for a fixup in quick succession, the fixup will only run once
    ; 3. it is an async operation, so when the scanner calls ForceRefIfEmpty it does not have to wait for the fixup

    GotoState("AliasOccupiedWaitingForFixup")
    If (_fixupHighPriority && delay == 1.0)
        RegisterForSingleUpdate(0.016) ; override default delay if inventory modified by player
    Else
        RegisterForSingleUpdate(delay)
    EndIf
EndFunction


Event OnUpdate()
    Actor npc = GetReference() as Actor
    If (npc == None) ; race condition
        GotoState("AliasEmpty") ; may not be necessary
        Return
    EndIf
    If (!IsParentCellAttached(npc)) ; even if _fixupLock is true
        Clear()
        Return
    EndIf
    DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
    String formIdAndName = ""
    Bool enablePapyrusLogging = npcTracker.EnablePapyrusLogging
    If (enablePapyrusLogging)
        formIdAndName = GetFormIdAsString(npc) + " " + npc.GetDisplayName()
    EndIf
    If (_fixupLock)
        If (enablePapyrusLogging)
            Debug.Trace("[DDNF] Postponing fixup of " + formIdAndName + " by 5.0 s (already running).")
        EndIf
        RegisterForFixup(5.0) ; already running, postpone
        Return
    EndIf
    _fixupLock = true ; we know it is currently false
    If (npcTracker.RestoreOriginalOutfit)
        ActorBase npcBase = npc.GetActorBase()
        Outfit originalOutfit = StorageUtil.GetFormValue(npcBase, "zad_OriginalOutfit") as Outfit
        If (originalOutfit != None)
            If (enablePapyrusLogging)
                Debug.Trace("[DDNF] Restoring original outfit of " + formIdAndName + " and rescheduling fixup.")
            EndIf
            npc.SetOutfit(originalOutfit, false)
            StorageUtil.UnSetFormValue(npcBase, "zad_OriginalOutfit")
            _fixupLock = false
            RegisterForFixup()
            Return
        EndIf
    EndIf
    Float timeSinceLastFixup = Utility.GetCurrentRealTime() - _lastFixupRealTime
    If (timeSinceLastFixup < 5.0)
        ; do not run fixup on the same NPC more frequently than every 5 seconds real time
        ; this serves as a way to prevent many fixups in case a script is modifying the equipment item by item
        Float waitTime = 5.0 - timeSinceLastFixup
        If (waitTime < 0.5)
            waitTime = 0.5
        EndIf
        _fixupLock = false
        If (enablePapyrusLogging)
            Debug.Trace("[DDNF] Postponing fixup of " + formIdAndName + " by " + waitTime + " s (recent fixup).")
        EndIf
        RegisterForFixup(waitTime)
        Return
    EndIf
    Float slowDownTime = npcTracker.NeedToSlowDownBeforeFixup(npc)
    If (slowDownTime > 0.0)
        _fixupLock = false
        If (enablePapyrusLogging)
            Debug.Trace("[DDNF] Postponing fixup of " + formIdAndName + " by " + slowDownTime + " s (slowing down to reduce script load).")
        EndIf
        RegisterForFixup(slowDownTime)
        Return
    EndIf
    If (enablePapyrusLogging)
        Debug.Trace("[DDNF] Fixing up devices of " + formIdAndName + ".")
    EndIf
    GotoState("AliasOccupied") ; we know the alias is not empty
    _fixupHighPriority = false

    ; step one: find and analyze all rendered devices in the inventory of the NPC
    zadLibs ddLibs = npcTracker.DDLibs
    Int renderedDevicesFlags = _renderedDevicesFlags
    Bool scanForDevices = renderedDevicesFlags < 0
    If (scanForDevices)
        ; devices are not known, find and analyze them
        _renderedDevicesFlags = 0
        If (_renderedDevices.Length != 32) ; number of slots
            _renderedDevices = new Armor[32]
        EndIf
        renderedDevicesFlags = FindAndAnalyzeRenderedDevices(ddLibs, npcTracker.UseBoundCombat, npc, _renderedDevices, enablePapyrusLogging)
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
    ElseIf (_renderedDevices[0] == None)
        ; no devices present, remove NPC from alias
        npc.RemoveFromFaction(npcTracker.DeviceTargets)
        _fixupLock = false
        If (enablePapyrusLogging)
            Debug.Trace("[DDNF] Succeeded fixing up devices of " + formIdAndName + ", no devices found.")
        EndIf
        Clear()
        Return
    EndIf
    Int devicesWithMagicalEffectCount = Math.LogicalAnd(renderedDevicesFlags, 255)
    Bool useUnarmedCombatPackage = Math.LogicalAnd(renderedDevicesFlags, 256)
    Bool helpless = Math.LogicalAnd(renderedDevicesFlags, 512)
    Bool hasAnimation = Math.LogicalAnd(renderedDevicesFlags, 1024)
    Bool hasPanelGag = Math.LogicalAnd(renderedDevicesFlags, 2048)

    ; step two: unequip and reequip all rendered devices to restart the effects
    ; from this point on we need to abort and restart the fixup if something changes
    If (hasPanelGag != _hasPanelGag)
        ; fix panel gag factions before un/reequipping devices as it determines the visual effect
        Faction panelGagFaction = ddLibs.zadGagPanelFaction
        If (hasPanelGag && npc.GetFactionRank(panelGagFaction) <= -1)
            npc.SetFactionRank(panelGagFaction, 1) ; fix missing faction membership, caused by mods that directly manipulate devices like DDe
        ElseIf (!hasPanelGag && npc.GetFactionRank(panelGagFaction) >= 0)
            npc.RemoveFromFaction(panelGagFaction) ; dito
        EndIf
    EndIf
    Int checkBitmap = UnequipAndEquipDevices(npc, _renderedDevices, devicesWithMagicalEffectCount)
    If (checkBitmap != 0)
        npc.UpdateWeight(0) ; workaround to force the game to correctly evaluate armor addon slots
        If (enablePapyrusLogging)
            Debug.Trace("[DDNF] Updated weight of " + formIdAndName + ".")
        EndIf
    EndIf
    String currentState = GetState()
    If (_ignoreNotEquippedInNextFixup)
        _ignoreNotEquippedInNextFixup = false
    ElseIf (currentState == "AliasOccupied")
        Bool devicesEquipped = checkBitmap == 0 || CheckDevicesEquipped(npc, _renderedDevices, checkBitmap)
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
        zadBoundCombatScript boundCombat = ddLibs.BoundCombat
        Bool animationIsApplied = false
        If (!scanForDevices)
            ; use _mtidle animation to check if animations are already applied
            Int fnisAaMtIdleCrc = npc.GetAnimationVariableInt("FNISaa_mtidle_crc")
            If (fnisAaMtIdleCrc != 0 && fnisAaMtIdleCrc == fnis_aa.GetInstallationCRC())
                Int fnisAaMtIdle = npc.GetAnimationVariableInt("FNISaa_mtidle")
                animationIsApplied = IsInFnisGroup(fnisAaMtIdle, boundCombat.ABC_mtidle) || IsInFnisGroup(fnisAaMtIdle, boundCombat.HBC_mtidle) || IsInFnisGroup(fnisAaMtIdle, boundCombat.PON_mtidle)
            EndIf
        EndIf
        If (animationIsApplied)
            ; un/reequipping devices can break the current idle and replace it with the default idle, restart the bound idle
            Debug.SendAnimationEvent(npc, "IdleForceDefaultState")
        Else
            If (enablePapyrusLogging)
                Debug.Trace("[DDNF] Reevaluating animations of " + formIdAndName + ".")
            EndIf
            ; modifying animations will cause a weird state where the NPC cannot draw weapons if they are currently drawn
            ; this can be reverted by changing the equipped weapons of the npc
            Bool restoreWeaponAccess = !helpless && npc.IsWeaponDrawn()
            boundCombat.EvaluateAA(npc) ; very expensive call
            If (restoreWeaponAccess)
                ; restore ability to draw weapons by changing equipped weapons
                UnequipWeapons(npc)
            EndIf
        EndIf
    EndIf
    If (useUnarmedCombatPackage)
        If (!UnequipWeapons(npc, npcTracker.DummyWeapon))
            npc.EquipItem(npcTracker.DummyWeapon, abPreventRemoval=true, abSilent=true)
        EndIf
        RegisterForAnimationEvent(npc, "BeginWeaponDraw") ; register even if we think that we are already registered
    ElseIf (_useUnarmedCombatPackage)
        UnregisterForAnimationEvent(npc, "BeginWeaponDraw")
        Int dummyWeaponCount = npc.GetItemCount(npcTracker.DummyWeapon)
        If (dummyWeaponCount > 0)
            npc.UnequipItemEx(npcTracker.DummyWeapon)
            npc.RemoveItem(npcTracker.DummyWeapon, aiCount=dummyWeaponCount, abSilent=true)
        EndIf
    EndIf
    ; almost done, so do not abort and reschedule if another fixup is scheduled, just let things run their normal course instead

    ; step four: set state and adjust factions
    Bool factionsModified = false
    If (useUnarmedCombatPackage)
        If (!_useUnarmedCombatPackage)
            _useUnarmedCombatPackage = true
            npc.SetFactionRank(npcTracker.UnarmedCombatants, 0)
            factionsModified = true
        EndIf
    ElseIf (_useUnarmedCombatPackage)
        npc.RemoveFromFaction(npcTracker.UnarmedCombatants)
        _useUnarmedCombatPackage = false
        factionsModified = true
    EndIf
    If (helpless)
        If (!_helpless)
            _helpless = true
            npc.SetFactionRank(npcTracker.Helpless, 0)
            factionsModified = true
        EndIf
    ElseIf (_helpless)
        npc.RemoveFromFaction(npcTracker.Helpless)
        _helpless = false
        factionsModified = true
    EndIf
    If (factionsModified)
        npc.EvaluatePackage()
    EndIf
    _hasAnimation = hasAnimation
    _lastFixupRealTime = Utility.GetCurrentRealTime()
    _fixupLock = false
    _hasPanelGag = hasPanelGag

    ; done
    If (enablePapyrusLogging)
        Debug.Trace("[DDNF] Succeeded fixing up devices of " + formIdAndName + ".")
    EndIf
    If (_hasAnimation)
        OnPackageStart(npc.GetCurrentPackage())
    EndIf
    If (_useUnarmedCombatPackage)
        UnequipEquippedArmors(npc, npcTracker.WeaponDisplayArmors, true)
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
; Check if an animation variable is in the range of a FNIS group.
;
Bool Function IsInFnisGroup(Int animationVariable, Int groupBaseValue) Global
    Return animationVariable >= groupBaseValue && animationVariable <= groupBaseValue + 9
EndFunction

;
; Fills the renderedDevices array with the rendered devices of the actor, starting from index 0.
; Devices with magical effects will be added to the array before devices without magical effects.
; Returns an int composed of the following numbers and flags:
; (0 - 255) - number of devices with effects
; 256 - flag: use unarmed combat package
; 512 - flag: helpless
; 1024 - flag: has animation
; 2048 - flag: has panel gag
;
Int Function FindAndAnalyzeRenderedDevices(zadLibs ddLibs, Bool useBoundCombat, Actor npc, Armor[] renderedDevices, Bool enablePapyrusLogging) Global
    ; find devices
    Int bottomIndex = 0
    Int topIndex = renderedDevices.Length
    Int index = 0
    Keyword zadLockable = ddLibs.zad_Lockable
    Int zadLockableCount = npc.GetItemCount(zadLockable)
    Keyword zadDeviousPlug = ddLibs.zad_DeviousPlug
    Int zadDeviousPlugCount = npc.GetItemCount(zadDeviousPlug)
    Int combinedDeviceFlags = 0
    If (zadLockableCount > 0 || zadDeviousPlugCount > 0)
        Int foundDevices = 0
        ; first try to find all rendered devices by looking at the worn devices, 90% of the time this works
        Int remainingSlots = 0xffffffff
        While (remainingSlots != 0 && bottomIndex < topIndex)
            Armor maybeRenderedDevice = npc.GetWornForm(remainingSlots) as Armor
            If (maybeRenderedDevice == None)
                remainingSlots = 0
            Else
                Int slotMask = maybeRenderedDevice.GetSlotMask()
                remainingSlots = Math.LogicalAnd(remainingSlots, Math.LogicalNot(slotMask))
                Int deviceFlags = AnylyzeMaybeDevice(ddLibs, zadLockable, zadLockableCount > 0, zadDeviousPlug, zadDeviousPlugCount > 0, maybeRenderedDevice, true, enablePapyrusLogging) ; only use cached value
                If (deviceFlags > 0)
                    ; found a rendered device
                    combinedDeviceFlags = Math.LogicalOr(combinedDeviceFlags, deviceFlags)
                    If (Math.LogicalAnd(deviceFlags, 2) == 0)
                        ; put devices without magical effect temporarily at top of array
                        topIndex -= 1
                        renderedDevices[topIndex] = maybeRenderedDevice
                    Else
                        ; put devices with magical effect at bottom of array
                        renderedDevices[bottomIndex] = maybeRenderedDevice
                        bottomIndex += 1
                    EndIf
                    foundDevices += 1
                    If (foundDevices == zadLockableCount + zadDeviousPlugCount)
                        remainingSlots = 0 ; found all devices, early abort
                    EndIf
                EndIf
            EndIf
        EndWhile
        If (foundDevices < zadLockableCount + zadDeviousPlugCount)
            ; failure, probably some rendered devices are not equipped, restart and find all rendered devices by looking at the whole inventory
            bottomIndex = 0
            topIndex = renderedDevices.Length
            combinedDeviceFlags = 0
            index = npc.GetNumItems() - 1 ; start at end to increase chance of early abort
            foundDevices = 0
            While (index >= 0 && bottomIndex < topIndex)
                Armor maybeRenderedDevice = npc.GetNthForm(index) as Armor
                If (maybeRenderedDevice != None)
                    Int deviceFlags = AnylyzeMaybeDevice(ddLibs, zadLockable, zadLockableCount > 0, zadDeviousPlug, zadDeviousPlugCount > 0, maybeRenderedDevice, false, enablePapyrusLogging) ; analyze if not cached
                    If (deviceFlags > 0)
                        ; found a rendered device
                        combinedDeviceFlags = Math.LogicalOr(combinedDeviceFlags, deviceFlags)
                        If (Math.LogicalAnd(deviceFlags, 2) == 0)
                            ; put devices without magical effect temporarily at top of array
                            topIndex -= 1
                            renderedDevices[topIndex] = maybeRenderedDevice
                        Else
                            ; put devices with magical effect at bottom of array
                            renderedDevices[bottomIndex] = maybeRenderedDevice
                            bottomIndex += 1
                        EndIf
                        foundDevices += 1
                        If (foundDevices == zadLockableCount + zadDeviousPlugCount)
                            index = 0 ; found all devices, early abort
                        EndIf
                    EndIf
                EndIf
                index -= 1
            EndWhile
        EndIf
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
    EndIf
    While (index < renderedDevices.Length && renderedDevices[index] != None)
        ; clear unused array slot (reusing the array and less devices found than last time)
        renderedDevices[index] = None
        index += 1
    EndWhile
    ; assemble return value
    Bool hasHeavyBondage = Math.LogicalAnd(combinedDeviceFlags, 4) == 4
    Bool useUnarmedCombatPackage = hasHeavyBondage || Math.LogicalAnd(combinedDeviceFlags, 8) == 8
    Bool disableKick = !useBoundCombat || Math.LogicalAnd(combinedDeviceFlags, 16) == 16
    Bool hasAnimation = hasHeavyBondage || Math.LogicalAnd(combinedDeviceFlags, 32) == 32
    Bool hasPanelGag = Math.LogicalAnd(combinedDeviceFlags, 64) == 64
    Int flags = bottomIndex
    If (useUnarmedCombatPackage)
        flags += 256 ; use unarmed combat package
    EndIf
    If (hasHeavyBondage && disableKick)
        flags += 512 ; helpless
    EndIf
    If (hasAnimation)
        flags += 1024 ; has animation
    EndIf
    If (hasPanelGag)
        flags += 2048 ; has panel gag
    EndIf
    Return flags
EndFunction


; Analyze an armor that might be a rendered device.
; Returns an int composed of the following flags:
;  1 - is rendered device
; All remaining flags are only set if flag 1 is set:
;  2 - has magic effect
;  4 - is heavy bondage
;  8 - is bondage mittens
; 16 - disables kicking
; 32 - is device other than heavy bondage that requires an animation
; 64 - is panel gag
; 
Int Function AnylyzeMaybeDevice(zadLibs ddLibs, Keyword zadLockable, Bool checkZadLockable, Keyword zadDeviousPlug, Bool checkZadDeviousPlug, Armor maybeRenderedDevice, Bool useCachedValueOnly, Bool enablePapyrusLogging) Global
    Int flags = StorageUtil.GetIntValue(maybeRenderedDevice, "ddnf_a", -1)
    If (flags == -1)
        flags = 0
        If (!useCachedValueOnly && (checkZadLockable && maybeRenderedDevice.HasKeyword(zadLockable)) || (checkZadDeviousPlug && maybeRenderedDevice.HasKeyword(zadDeviousPlug)))
            flags += 1
            If (maybeRenderedDevice.GetEnchantment() != None)
                flags += 2
            EndIf
            If (maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousHeavyBondage))
                flags += 4
            EndIf
            If (maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousBondageMittens))
                flags += 8
            EndIf
            If (maybeRenderedDevice.HasKeyword(ddLibs.zad_BoundCombatDisableKick))
                flags += 16
            EndIf
            If (maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousPonyGear) || maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousHobbleSkirt) || maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousHobbleSkirtRelaxed))
                flags += 32
            EndIf
            If (maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousGagPanel))
                flags += 64
            EndIf
            StorageUtil.SetIntValue(maybeRenderedDevice, "ddnf_a", flags) ; only cache in StorageUtil if it is a device
            If (enablePapyrusLogging)
                Debug.Trace("[DDNF] StorageUtil: SetIntValue(" + GetFormIdAsString(maybeRenderedDevice) + ", ddnf_a, " + flags + ")")
            EndIf
        EndIf
    EndIf
    Return flags
EndFunction


; unequip and reequip devices, return a bitmap for the devices to check
Int Function UnequipAndEquipDevices(Actor npc, Armor[] renderedDevices, Int devicesWithMagicalEffectCount) Global
    Int currentBit = 1
    Int bitmapToCheck = 0
    Int index = 0
    While (index < renderedDevices.Length && renderedDevices[index] != None)
        Bool needsReequip = false
        If (npc.IsEquipped(renderedDevices[index]))
            ; unequip devices with magical effects
            If (index < devicesWithMagicalEffectCount)
                npc.UnequipItem(renderedDevices[index], abPreventEquip=true, abSilent=true)
                needsReequip = true
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
            needsReequip = true
        EndIf
        If (needsReequip && npc.GetItemCount(renderedDevices[index]) > 0) ; safety check
            npc.EquipItem(renderedDevices[index], abPreventRemoval=true, abSilent=true)
            bitmapToCheck = Math.LogicalOr(bitmapToCheck, currentBit)
        EndIf
        currentBit = Math.LeftShift(currentBit, 1)
        index += 1
    EndWhile
    Return bitmapToCheck
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


Function UnequipEquippedArmors(Actor npc, FormList maybeEquippedArmors, Bool ignoreShields) Global
    If (!npc.IsEquipped(maybeEquippedArmors))
        Return ; short-circuit
    EndIf
    Int ignoredSlots
    If (ignoreShields)
        ignoredSlots = 0x00000200
    Else
        ignoredSlots = 0x00000000
    EndIf
    Int remainingSlots = Math.LogicalNot(ignoredSlots)
    While (remainingSlots != 0)
        Armor wornArmor = npc.GetWornForm(remainingSlots) as Armor
        If (wornArmor == None)
            Return
        EndIf
        Int slotMask = wornArmor.GetSlotMask()
        remainingSlots = Math.LogicalAnd(remainingSlots, Math.LogicalNot(slotMask))
        If (maybeEquippedArmors.HasForm(wornArmor))
            npc.UnequipItem(wornArmor, abSilent = true)
            If (remainingSlots == 0 || !npc.IsEquipped(maybeEquippedArmors))
                Return ; all unequipped, early abort
            EndIf
        EndIf
    EndWhile
EndFunction


Int Function QuickEquipDevices(Armor[] devices, Int count, Bool equipRenderedDevices)
    DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
    ObjectReference[] tempRefs
    If (count > 1)
        Float[]	zeros = new Float[3]
        zeros[0] = 0
        zeros[1] = 0
        zeros[2] = 0
        Int handle = SpawnerTask.Create()
        Int index = 0
        While (index < devices.Length)
            If (devices[index] != None)
                SpawnerTask.AddSpawn(handle, devices[index], npcTracker.Player, zeros, zeros, bInitiallyDisabled = true)
            EndIf
            Index += 1
        EndWhile
        tempRefs = SpawnerTask.Run(handle)
    ElseIf (count == 1 && devices[0] != None)
       tempRefs = new ObjectReference[1]
       tempRefs[0] = npcTracker.Player.PlaceAtMe(devices[0], abInitiallyDisabled = true)
    EndIf
    Int equippedCount = 0
    If (tempRefs.Length > 0)
        Actor npc = GetReference() as Actor
        Int index = 0
        If (npc != None) ; race condition check
            index = 0
            While (index < tempRefs.Length)
                zadEquipScript inventoryDevice = tempRefs[index] as zadEquipScript
                If (inventoryDevice != None)
                    Keyword deviceTypeKeyword = inventoryDevice.zad_DeviousDevice
                    If (npc.GetItemCount(deviceTypeKeyword) == 0)
                        If (equippedCount == 0)
                            UnregisterForUpdate() ; prevent concurrent fixup as it is pointless
                            GotoState("AliasEmpty") ; cheating to disable events
                        EndIf
                        If (DDNF_NpcTracker.TryGetInventoryDevice(inventoryDevice.deviceRendered) == None)
                            DDNF_NpcTracker.LinkInventoryDeviceAndRenderedDevice(inventoryDevice.deviceInventory, inventoryDevice.deviceRendered, npcTracker.EnablePapyrusLogging)
                        EndIf
                        npc.AddItem(inventoryDevice.deviceRendered, 1, true)
                        npc.AddItem(inventoryDevice.deviceInventory, 1, true)
                        if (equipRenderedDevices)
                            npc.EquipItem(inventoryDevice.deviceRendered, abPreventRemoval=true, abSilent=true)
                        EndIf
                        equippedCount += 1
                    EndIf
                EndIf
                index += 1
            EndWhile
            index = 0
            If (equippedCount > 0)
                If (npcTracker.EnablePapyrusLogging)
                    Debug.Trace("[DDNF] Quick-Equipped " + equippedCount + " devices on " + GetFormIdAsString(npc) + " " + npc.GetDisplayName() + ".")
                EndIf
                _renderedDevicesFlags = -1
                _fixupHighPriority = true ; high priority to make the effects start asap
                _ignoreNotEquippedInNextFixup = 0
                RegisterForFixup() ; will re-enable events using GotoState("AliasOccupiedWaitingForFixup")
            EndIf
        EndIf
        While (index < tempRefs.Length)
            tempRefs[index].Delete()
            index += 1
        EndWhile
    EndIf
    Return equippedCount
EndFunction


Armor Function ChooseDeviceForUnequip(Bool unequipSelf)
    Actor npc = GetReference() as Actor
    If (npc == None)
        Return None
    EndIf
    DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
    Armor[] inventoryDevices = new Armor[32]
    Int deviceCount = TryGetEquippedDevices(inventoryDevices, None)
    If (deviceCount < 0)
        deviceCount = ScanForEquippedInventoryDevices(npcTracker.ddLibs, npc, inventoryDevices, None)
    EndIf
    Armor[] renderedDevices = new Armor[32]
    Int index = 0
    While (index < deviceCount)
        renderedDevices[index] = DDNF_NpcTracker.GetRenderedDevice(inventoryDevices[index], false)
        index += 1
    EndWhile
    Bool[] unequipPossible = new Bool[32]
    CheckIfUnequipPossible(npc, renderedDevices, unequipPossible, deviceCount, npcTracker.DDLibs, unequipSelf)
    Armor[] selectionArray = new Armor[128]
    Int selectionArrayIndex = 0
    index = 0
    While (index < deviceCount && selectionArrayIndex < selectionArray.Length)
        If (unequipPossible[index])
            Armor renderedDevice = renderedDevices[index]
            Int priority = GetPriorityForUnequip(npcTracker.DDLibs, renderedDevices[index])
            Int priorityIndex = 0
            While (priorityIndex < priority && selectionArrayIndex < selectionArray.Length)
                selectionArray[selectionArrayIndex] = renderedDevice
                selectionArrayIndex += 1
                priorityIndex += 1
            EndWhile
        EndIf
        index += 1
    EndWhile
    If (selectionArrayIndex == 0)
        Return None
    EndIf    
    Return selectionArray[Utility.RandomInt(0, selectionArrayIndex - 1)]
EndFunction


Function CheckIfUnequipPossible(Actor npc, Armor[] renderedDevices, Bool[] output, Int count, zadLibs ddLibs, Bool unequipSelf) GLobal
    Int[] cachedCounts = new Int[10]
    cachedCounts[0] = -1 ; zad_DeviousHeavyBondage
    cachedCounts[1] = -1 ; zad_DeviousBondageMittens
    cachedCounts[2] = -1 ; zad_DeviousHood
    cachedCounts[3] = -1 ; zad_DeviousArmbinder + zad_DeviousStraitJacket
    cachedCounts[4] = -1 ; zad_DeviousBelt
    cachedCounts[5] = -1 ; zad_DeviousSuit
    cachedCounts[6] = -1 ; zad_PermitVaginal
    cachedCounts[7] = -1 ; zad_PermitAnal
    cachedCounts[8] = -1 ; zad_DeviousBra
    cachedCounts[9] = -1 ; zad_BraNoBlockPiercings
    Int index = 0
    While (index < count)
        output[index] = CheckUnequipPossibleLoopFn(npc, renderedDevices[index], ddLibs, cachedCounts, unequipSelf)
        index += 1
    EndWhile
EndFunction


Bool Function CheckUnequipPossibleLoopFn(Actor npc, Armor renderedDevice, zadLibs ddLibs, Int[] cachedCounts, Bool unequipSelf) Global
    If (renderedDevice == None)
        Return false
    EndIf
    If (unequipSelf)
        If (cachedCounts[0] < 0)
            cachedCounts[0] = npc.GetItemCount(ddLibs.zad_DeviousHeavyBondage)
        EndIf
        If (cachedCounts[0] > 0)
            ; npc needs to get rid of heavy bondage first
            Return renderedDevice.HasKeyword(ddLibs.zad_DeviousHeavyBondage)
        EndIf
        If (cachedCounts[1] < 0)
            cachedCounts[1] = npc.GetItemCount(ddLibs.zad_DeviousBondageMittens)
        EndIf
        If (cachedCounts[1] > 0)
            ; npc needs to get rid of bondage mittens first
            Return renderedDevice.HasKeyword(ddLibs.zad_DeviousBondageMittens)
        EndIf
    EndIf
    If (renderedDevice.HasKeyword(ddLibs.zad_DeviousHood))
        Return true
    EndIf
    If (renderedDevice.HasKeyword(ddLibs.zad_DeviousGag) || renderedDevice.HasKeyword(ddLibs.zad_DeviousBlindfold))
        ; hoods block gags/blindfolds
        If (cachedCounts[2] < 0)
            cachedCounts[2] = npc.GetItemCount(ddLibs.zad_DeviousHood)
        EndIf
        Return cachedCounts[2] == 0
    EndIf
    If (renderedDevice.HasKeyword(ddLibs.zad_DeviousGloves))
        ; armbinders and strait jackets block gloves
        If (cachedCounts[3] < 0)
            cachedCounts[3] = npc.GetItemCount(ddLibs.zad_DeviousArmbinder) + npc.GetItemCount(ddLibs.zad_DeviousStraitJacket)
        EndIf
        Return cachedCounts[3] == 0
    EndIf
    If (renderedDevice.HasKeyword(ddLibs.zad_DeviousPlug))
        If (renderedDevice.HasKeyword(ddLibs.zad_DeviousPlugVaginal))
            ; belts and suit may block vaginal plugs
            If (cachedCounts[4] < 0)
                cachedCounts[4] = npc.GetItemCount(ddLibs.zad_DeviousBelt)
            EndIf
            If (cachedCounts[5] < 0)
                cachedCounts[5] = npc.GetItemCount(ddLibs.zad_DeviousSuit)
            EndIf
            If (cachedCounts[6] < 0)
                cachedCounts[6] = npc.GetItemCount(ddLibs.zad_PermitVaginal)
            EndIf
            Return (cachedCounts[4] + cachedCounts[5]) == 0 || cachedCounts[6] > 0
        EndIf
        If (renderedDevice.HasKeyword(ddLibs.zad_DeviousPlugAnal))
            ; belts and suit may block anal plugs
            If (cachedCounts[4] < 0)
                cachedCounts[4] = npc.GetItemCount(ddLibs.zad_DeviousBelt)
            EndIf
            If (cachedCounts[5] < 0)
                cachedCounts[5] = npc.GetItemCount(ddLibs.zad_DeviousSuit)
            EndIf
            If (cachedCounts[7] < 0)
                cachedCounts[7] = npc.GetItemCount(ddLibs.zad_PermitAnal)
            EndIf
            Return (cachedCounts[4] + cachedCounts[5]) == 0 || cachedCounts[7] > 0
        EndIf
    EndIf
    If (renderedDevice.HasKeyword(ddLibs.zad_DeviousPiercingsNipple))
        ; bras and suit may block nipple piercings
        If (cachedCounts[8] < 0)
            cachedCounts[8] = npc.GetItemCount(ddLibs.zad_DeviousBra)
        EndIf
        If (cachedCounts[9] < 0)
            cachedCounts[9] = npc.GetItemCount(ddLibs.zad_BraNoBlockPiercings)
        EndIf
        Return (cachedCounts[8] + cachedCounts[5]) == 0 || cachedCounts[9] > 0
    EndIf
    Return true    
EndFunction


Int Function GetPriorityForUnequip(zadLibs ddLibs, Armor renderedDevice) Global ; higher is more important
    If (renderedDevice.HasKeyword(ddLibs.zad_DeviousHeavyBondage))
        ; first heavy bondage
        Return 16
    ElseIf (renderedDevice.HasKeyword(ddLibs.zad_DeviousBondageMittens))
        ; then mittens
        Return 6
    ElseIf (renderedDevice.HasKeyword(ddLibs.zad_DeviousBlindfold) || renderedDevice.HasKeyword(ddLibs.zad_DeviousGag))
        ; then blindfolds and gags (this includes many hoods)
        Return 3
    ElseIf (renderedDevice.HasKeyword(ddLibs.zad_BoundCombatDisableKick))
        ; then fetters
        Return 2
    Else
        ; then everything else
        Return 1
    EndIf
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


;
; Support functions for ExternalApi.psc
;

Bool Property NpcIsHelpless
    Bool Function Get()
        return _helpless
    EndFunction
EndProperty

Bool Property NpcHasAnimation
    Bool Function Get()
        return _hasAnimation
    EndFunction
EndProperty

Bool Property NpcUsesUnarmedCombatAnimations
    Bool Function Get()
        return _useUnarmedCombatPackage
    EndFunction
EndProperty

Int Function TryGetEquippedDevices(Armor[] outputArray, Keyword optionalKeywordForRenderedDevice)
    If (_renderedDevicesFlags < 0)
        Return -1 ; failure, devices are not known
    EndIf
    Int index = 0
    While(index < _renderedDevices.Length && index < outputArray.Length)
        Armor renderedDevice = _renderedDevices[index]
        If (renderedDevice == None)
            Return index
        EndIf
        If (optionalKeywordForRenderedDevice == None || renderedDevice.HasKeyword(optionalKeywordForRenderedDevice))
            Armor inventoryDevice = DDNF_NpcTracker.TryGetInventoryDevice(renderedDevice)
            If (inventoryDevice == None)
                Return -1 ; failure, data is not cached
            EndIf
            outputArray[index] = inventoryDevice
            index += 1
        EndIf
    EndWhile
    Return index
EndFunction

Int Function ScanForEquippedInventoryDevices(zadLibs ddLibs, Actor npc, Armor[] outputArray, Keyword optionalKeywordForRenderedDevice) Global ; Global and slow
    If (npc == None)
        Return 0
    EndIf
    Int inventoryDeviceCount = npc.GetItemCount(ddLibs.zad_InventoryDevice)
    Int foundDevices = 0
    Int outputArrayIndex = 0
    Int index = npc.GetNumItems() - 1 ; start at end to increase chance of early abort
    While (foundDevices < inventoryDeviceCount && index >= 0 && outputArrayIndex < outputArray.Length)
        Armor maybeInventoryDevice = npc.GetNthForm(index) as Armor
        If (maybeInventoryDevice != None)
            Armor renderedDevice = DDNF_NpcTracker.GetRenderedDevice(maybeInventoryDevice, false)
            If (renderedDevice != None && npc.GetItemCount(renderedDevice) > 0 && (optionalKeywordForRenderedDevice == None || renderedDevice.HasKeyword(optionalKeywordForRenderedDevice)))
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
