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
Bool _isHelpless
Bool _hasAnimation
Bool _hasPanelGag
Bool _isBound
Bool _isGagged
Bool _isBlindfold
Bool _isUnableToKick
Bool _evadeCombat

; variables tracking state of script
; there is also a script state, so this is not the whole picture
Bool _fixupHighPriority
Bool _ignoreNotEquippedInNextFixup
Bool _fixupLock
Bool _waitingForFixup
Float _lastFixupRealTime
Int _quickEquipRunning
Float _lastEscapeAttemptGameTime


Function HandleGameLoaded(Bool upgrade)
    _lastFixupRealTime = 0.0 ; reset on game load
    If (upgrade)
        Actor npc = GetReference() as Actor
        If (npc == None)
            GotoState("AliasEmpty") ; may be necessary if upgrading from an old version without script states
        Else
            ; clear on upgrade, NPC will be re-added if found again
            Clear()
        EndIf
    EndIf
EndFunction


Function HandleOptionsChanged(Bool useBoundCombat)
    Actor npc = GetReference() as Actor
    If (npc != None && _useUnarmedCombatPackage && UpdateHelplessState(npc, GetOwningQuest() as DDNF_NpcTracker, true))
        UpdateEvadeCombat(npc, GetOwningQuest() as DDNF_NpcTracker)
        npc.EvaluatePackage()
    EndIf
EndFunction


Function ForceRefTo(ObjectReference akNewRef) ; override
    Actor npc = akNewRef as Actor
    If (npc == None)
        Clear()
    Else
        parent.ForceRefTo(npc) ; no need to set GetNpcs()[aliasIndex] in DDNF_NpcTracker, caller already has done that
        _fixupLock = true
        DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
        If (npcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] Start tracking " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + ".")
        EndIf
        _renderedDevicesFlags = -1
        ; no need to set _renderedDevices, it is already an empty array
        _useUnarmedCombatPackage = false
        _isHelpless = false
        _hasAnimation = false
        _hasPanelGag = false
        _isBound = false
        _isGagged = false
        _isBlindfold = false
        _isUnableToKick = false
        _evadeCombat = false
        _fixupHighPriority = false
        _ignoreNotEquippedInNextFixup = false
        _waitingForFixup = false
        _lastFixupRealTime = 0.0
        _quickEquipRunning = 0
        GotoState("AliasOccupied")
        ; we will receive OnDeath event when NPC dies from now on, but they might already be dead
        npc.RemoveFromFaction(npcTracker.Struggling) ; safety code in case something went wrong
        If (!npc.Is3DLoaded())
            RegisterForFixup(16.0)
        ElseIf (npc.GetItemCount(npcTracker.DDLibs.zad_Lockable) == 0 && npc.GetItemCount(npcTracker.DDLibs.zad_DeviousPlug) == 0)
            _renderedDevicesFlags = 0
            If (_renderedDevices.Length != 32) ; number of slots
                _renderedDevices = new Armor[32]
            Else
                 _renderedDevices[0] = None
            EndIf
            RegisterForFixup(16.0)
        Else
            RegisterForFixup()
        EndIf
        _lastEscapeAttemptGameTime = -99 ; special value
        _fixupLock = false
    EndIf
EndFunction


Function Clear() ; override
    Actor npc = GetReference() as Actor
    If (npc != None)
        ; acquire fixup lock, we do not want this to happen concurrent to a fixup
        If (_fixupLock)
            Int waitCount = 0
            While (_fixupLock && waitCount < 40) ; but do not wait forever in case something is stuck
                Utility.Wait(0.25)
                waitCount += 1
            EndWhile
            If (GetReference() == npc)
                _fixupLock = true
            EndIf
        Else
            _fixupLock = true
        EndIf
        If (_fixupLock)
            GotoState("AliasEmpty")
            UnregisterForUpdate() ; may do nothing
            _waitingForFixup = false
            UnregisterForUpdateGameTime() ; may do nothing
            ; revert changes made to the NPC
            ; but do not revert membership in npcTracker.DeviceTargets faction, it is used to find the NPC again
            DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
            If (_useUnarmedCombatPackage)
                UnregisterForAnimationEvent(npc, "BeginWeaponDraw")
                npc.RemoveFromFaction(npcTracker.UnarmedCombatants)
                If (_evadeCombat)
                    npc.RemoveFromFaction(npcTracker.EvadeCombat)
                EndIf
                If (_isHelpless)
                    npc.RemoveFromFaction(npcTracker.Helpless)
                    ; restore ability to draw weapons by changing equipped weapons
                    UnequipWeapons(npc)
                    npc.EquipItem(npcTracker.DummyWeapon, abPreventRemoval=true, abSilent=true)
                EndIf
            EndIf
            Int dummyWeaponCount = npc.GetItemCount(npcTracker.DummyWeapon)
            If (dummyWeaponCount > 0)
                npc.RemoveItem(npcTracker.DummyWeapon, aiCount=dummyWeaponCount, abSilent=true)
            EndIf
            ; no reason to clear the state, it will be set correctly in ForceRefTo() or in the Fixup following it
            ; but clear the array with rendered devices such that the game can reclaim the memory
            Armor[] emptyArray
            _renderedDevices = emptyArray
            ; finally kick from alias
            Int aliasIndex = npcTracker.GetAliases().Find(Self)
            Form[] npcs = npcTracker.GetNpcs()
            parent.Clear() ; will cause packages to change if necessary because they are attached to the alias
            npcs[aliasIndex] = None ; required, parent may not be aware of the Clear call
            If (npcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] Stop tracking " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + ".")
            EndIf
            ; done
            _fixupLock = false
        EndIf
    EndIf
EndFunction


Event OnDeath(Actor akKiller)
    ; stop tracking the NPC on death
    Clear()
EndEvent


Event OnLoad()
    RegisterForFixup()
EndEvent

Event OnUnload()
    RegisterForFixup(16.0) ; the update will call Clear() if 3D is not loaded
EndEvent

Event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
    If (!_quickEquipRunning)
        HandleItemAddedRemoved(akBaseItem, akSourceContainer)
    EndIf
EndEvent


Event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
    If (!_quickEquipRunning)
        HandleItemAddedRemoved(akBaseItem, akDestContainer)
    EndIf
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
            If (npcTracker.RestoreOriginalOutfit)
                ActorBase npcBase = npc.GetActorBase()
                Outfit originalOutfit = StorageUtil.GetFormValue(npcBase, "zad_OriginalOutfit") as Outfit
                If (originalOutfit != None && npcBase.GetOutfit() == npcTracker.DDLibs.zadEmptyOutfit) ; check current outfit to prevent race condition
                    StorageUtil.UnSetFormValue(npcBase, "zad_OriginalOutfit")
                    npc.SetOutfit(originalOutfit, false)
                    If (npcTracker.EnablePapyrusLogging)
                        Debug.Trace("[DDNF] Restored original outfit of " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + ".")
                    EndIf
                EndIf
            EndIf
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
    Actor npc = GetReference() as Actor
    If (npc != None && !_fixupLock)
        If (_isGagged)
            Shout equippedShout = akBaseObject as Shout
            If (equippedShout != None)
                npc.UnequipShout(equippedShout)
                Return
            EndIf
        EndIf
        If (_useUnarmedCombatPackage)
            DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
            If ((akBaseObject as Ammo) != None)
                npc.UnequipItem(akBaseObject, abSilent=true)
                Return
            EndIf
            Armor equippedArmor = akBaseObject as Armor
            Bool isShield = false
            If (equippedArmor != None)
                If (!equippedArmor.IsShield())
                    If (npcTracker.WeaponDisplayArmors.HasForm(equippedArmor))
                        npc.UnequipItem(akBaseObject, abSilent=true)
                    EndIf
                    Return
                EndIf
                isShield = true
            EndIf
            Bool doUnequip = isShield || (akBaseObject as Spell) != None
            If (!doUnequip)
                Weapon equippedWeapon = akBaseObject as Weapon
                doUnequip = equippedWeapon != None && equippedWeapon != npcTracker.DummyWeapon
            EndIf
            If (doUnequip)
                npc.UnequipItem(akBaseObject, abSilent=true)
                If (!isShield && npc.IsEquipped(akBaseObject)) ; possible because it can be in both hands
                    npc.UnequipItem(akBaseObject, abSilent=true)
                EndIf
                If (npc.GetItemCount(npcTracker.DummyWeapon) > 0)
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
    If (_useUnarmedCombatPackage && !_isHelpless)
        Actor npc = GetReference() as Actor
        If (npc != None)
            DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
            If (aeCombatState == 1)
                UnequipWeapons(npc) ; combat override package will make sure NPC is only using unarmed combat
            Else
                If (!UnequipWeapons(npc, npcTracker.DummyWeapon) && npc.GetItemCount(npcTracker.DummyWeapon) > 0)
                    npc.EquipItem(npcTracker.DummyWeapon, abPreventRemoval=true, abSilent=true)
                EndIf
                If (aeCombatState == 0)
                    UpdateEvadeCombat(npc, npcTracker) ; no need to EvaluatePackage() because we are out of combat
                EndIf
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
        If (_useUnarmedCombatPackage && (_isHelpless || npc.GetCombatState() != 1))
            DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
            If (!UnequipWeapons(npc, npcTracker.DummyWeapon) && npc.GetItemCount(npcTracker.DummyWeapon) > 0) ; for some reason the game sometimes keeps equipment in the left hand even though DummyWeapon is two-handed
                npc.EquipItem(npcTracker.DummyWeapon, abPreventRemoval=true, abSilent=true)
            EndIf
            If (_isHelpless)
                Debug.SendAnimationEvent(npc, "IdleForceDefaultState") ; will prevent drawing weapons again
                npc.SheatheWeapon()
            EndIf
        EndIf
    Else
        Utility.Wait(0.5) ; wait before unregister, see above
        UnregisterForAnimationEvent(akSource, asEventName) ; cleanup
    EndIf
EndEvent


Event OnPackageStart(Package akNewPackage)
    If (_hasAnimation)
        DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
        If (akNewPackage != npcTracker.BoundCombatNPCSandbox && akNewPackage != npcTracker.BoundNPCSandbox)
            Package template = akNewPackage.GetTemplate()
            If (template == npcTracker.Sandbox)
                Actor npc = GetReference() as Actor
                If (npc != None && npc.Is3DLoaded())
                    ; npc switched to sandbox package (other than DD sandbox packages), check if we can kick them out of it again
                    If (npcTracker.EnablePapyrusLogging)
                        Debug.Trace("[DDNF] Trying to kick " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + " out of sandboxing package.")
                    EndIf
                    Int npcFormId = npc.GetFormID()
                    If (DDNF_Game.GetModId(npcFormId) == npcTracker.DawnguardModId && DDNF_DLC1Shim.IsSerana(npcFormId))
                        ; Serana's AI is different than that of any other follower, so the DD npc slots are not working
                        DDNF_DLC1Shim.KickSeranaFromSandboxPackage(npc)
                    Else
                        ; Let DD slots apply the bound sandbox package
                        npcTracker.DDLibs.RepopulateNpcs()
                    EndIf
                EndIf
            EndIf
        EndIf
    EndIf
EndEvent


Event OnHit(ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked)
    HandleHitFrom(akAggressor as Actor, akSource)
EndEvent

Function HandleHitFrom(Actor attacker, Form akSource)
    If (_evadeCombat && attacker != None)
        Actor npc = GetReference() as Actor
        If (npc != None && npc.IsHostileToActor(attacker) && IsHostileHitSource(akSource))
            DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
            If (!attacker.HasKeyword(npcTracker.ActorTypeDragon) && !npcTracker.MassiveRacesList.HasForm(attacker.GetRace())) ; do not start unarmed combat with dragons, giants, mammoths or dwarven centurions
                If (_evadeCombat) ; double-check to catch race condition
                    _evadeCombat = false
                    npc.RemoveFromFaction(npcTracker.EvadeCombat)
                    npc.EvaluatePackage()
                EndIf
            EndIf
        EndIf
    EndIf
EndFunction

Bool Function IsHostileHitSource(Form akSource) Global
    If (akSource != None)
        If ((akSource as Weapon) != None)
            Return true
        EndIf
        Spell akSpell = akSource as Spell
        If (akSpell != None)
            Return akSpell.IsHostile()
        EndIf
        Ingredient akIngredient = akSource as Ingredient
        If (akIngredient != None)
            Return akIngredient.IsHostile()
        EndIf
        Potion akPotion = akSource as Potion
        If (akPotion != None)
            Return akPotion.IsHostile()
        EndIf
        Enchantment akEnchantment = akSource as Enchantment
        If (akEnchantment != None)
            return akEnchantment.IsHostile()
        EndIf
    EndIf
    Return True ; assume hostile by default
EndFunction


; state functions

Bool Function IsStruggling()
    Return false
EndFunction

Bool Function GotoStateStruggling()
    Return false
EndFunction

Function GotoStateNotStruggling()
EndFunction


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

Bool Function GotoStateStruggling()
    GotoState("AliasOccupiedStruggling")
    Return true
EndFunction

EndState


; handle all events when reference alias is occupied and npc is struggling
State AliasOccupiedStruggling

Event OnHit(ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked)
    HandleHitFrom(akAggressor as Actor, akSource)
    Bool abortStruggling = IsHostileHitSource(akSource)
    If (!abortStruggling && (akSource as Spell) != None)
        Utility.Wait(0.25) ; wait and check for calm effect instead of checking spell as spell might fail
        Actor npc = GetReference() as Actor
        DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
        abortStruggling = npc.HasMagicEffectWithKeyword(npcTracker.MagicInfluenceCharm)
    EndIf
    If (abortStruggling)
        GotoStateNotStruggling()
        DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
        If (npcTracker.EnablePapyrusLogging)
            Actor npc = GetReference() as Actor
            If (akAggressor == None)
                Debug.Trace("[DDNF] Interrupting escape attempt for " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + " because of hit.")
            Else
                Debug.Trace("[DDNF] Interrupting escape attempt for " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + " because of hit from " + DDNF_Game.FormIdAsString(akAggressor) + " " + akAggressor.GetDisplayName() + ".")
            EndIf
        EndIf
    EndIf
EndEvent

Bool Function IsStruggling()
    Return true
EndFunction

Function GotoStateNotStruggling()
    GotoState("AliasOccupied")
EndFunction

EndState


Function RegisterForFixupWithScan(Float delay = 1.0)
    _renderedDevicesFlags = -1
    RegisterForFixup(delay)
EndFunction

Function RegisterForFixup(Float delay = 1.0) ; 1.0 is usually a good compromise between reactivity and collapsing multiple events into one update
    ; fixing the NPC in an update event has several important advantages:
    ; 1. if the player is currently modifying the NPCs inventory, the fixup will be done after the menu has been closed
    ; 2. if there are multiple reasons for a fixup in quick succession, the fixup will only run once
    ; 3. it is an async operation, so when the scanner calls ForceRefIfEmpty it does not have to wait for the fixup

    If (_fixupHighPriority && delay == 1.0)
        RegisterForSingleUpdate(0.016) ; override default delay if inventory modified by player
    Else
        RegisterForSingleUpdate(delay)
    EndIf
    _waitingForFixup = true
EndFunction

Bool Function IsWaitingForFixup()
    Return _waitingForFixup
EndFunction



;
; Fixup is performed from update event.
;
Event OnUpdate()
    _waitingForFixup = false
    Actor npc = GetReference() as Actor
    If (npc == None) ; race condition
        GotoState("AliasEmpty") ; may not be necessary
        Return
    EndIf
    DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
    If (!npcTracker.IsEnabled)
        Return ; abort, concurrent update/start/stop
    EndIf
    If (!npc.Is3DLoaded() || npc.IsDead()) ; even if _fixupLock is true
        Clear()
        Return
    EndIf
    String formIdAndName = ""
    Bool enablePapyrusLogging = npcTracker.EnablePapyrusLogging
    If (enablePapyrusLogging)
        formIdAndName = DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName()
    EndIf
    If (_fixupLock)
        If (enablePapyrusLogging)
            Debug.Trace("[DDNF] Postponing fixup of " + formIdAndName + " by 5.0 s (already running).")
        EndIf
        RegisterForFixup(4.0) ; already running, postpone
        Return
    EndIf
    _fixupLock = true ; we know it is currently false
    If (npcTracker.RestoreOriginalOutfit)
        ActorBase npcBase = npc.GetActorBase()
        Outfit originalOutfit = StorageUtil.GetFormValue(npcBase, "zad_OriginalOutfit") as Outfit
        If (originalOutfit != None && npcBase.GetOutfit() == npcTracker.DDLibs.zadEmptyOutfit) ; check current outfit to prevent race condition
            StorageUtil.UnSetFormValue(npcBase, "zad_OriginalOutfit")
            npc.SetOutfit(originalOutfit, false)
            If (enablePapyrusLogging)
                Debug.Trace("[DDNF] Restored original outfit of " + formIdAndName + " and rescheduling fixup.")
            EndIf
            _fixupLock = false
            RegisterForFixup()
            Return
        EndIf
    EndIf
    Float timeSinceLastFixup = Utility.GetCurrentRealTime() - _lastFixupRealTime
    If (timeSinceLastFixup < 0)
        timeSinceLastFixup = 99 ; race condition when loading game
    EndIf
    If (timeSinceLastFixup < 4.0)
        ; do not run fixup on the same NPC more frequently than every 4 seconds real time
        ; this serves as a way to prevent many fixups in case a script is modifying the equipment item by item
        Float waitTime = 4.0 - timeSinceLastFixup
        _fixupLock = false
        If (enablePapyrusLogging)
            Debug.Trace("[DDNF] Postponing fixup of " + formIdAndName + " by " + waitTime + "s (recent fixup).")
        EndIf
        RegisterForFixup(waitTime)
        Return
    EndIf
    Float slowDownTime = npcTracker.NeedToSlowDownBeforeFixup(npc)
    If (slowDownTime > 0.0)
        _fixupLock = false
        If (enablePapyrusLogging)
            Debug.Trace("[DDNF] Postponing fixup of " + formIdAndName + " by " + slowDownTime + "s (slowing down to reduce script load).")
        EndIf
        RegisterForFixup(slowDownTime)
        Return
    EndIf
    If (enablePapyrusLogging)
        Debug.Trace("[DDNF] Fixing up devices of " + formIdAndName + ".")
    EndIf
    _fixupHighPriority = false ; only set this once we start with the actual fixup

    ; step one: find and analyze all rendered devices in the inventory of the NPC
    zadLibs ddLibs = npcTracker.DDLibs
    Int renderedDevicesFlags = _renderedDevicesFlags
    Bool scanForDevices = renderedDevicesFlags < 0
    If (scanForDevices)
        ; devices are not known, find and analyze them
        _renderedDevicesFlags = -12345 ; special tag
        Armor[] newRenderedDevices = new Armor[32]
        renderedDevicesFlags = FindAndAnalyzeRenderedDevices(ddLibs, npc, newRenderedDevices, enablePapyrusLogging)
        If (npcTracker.FixInconsistentDevices && IsCurrentFollower(npc, npcTracker) && FixInconsistentDevices(npc, newRenderedDevices, _renderedDevices, ddLibs, enablePapyrusLogging))
            _renderedDevicesFlags = -1
            RegisterForFixup() ; ignore the minimum time between fixups in this case, logically it is still "the same" fixup
            _fixupLock = false
            If (enablePapyrusLogging)
                Debug.Trace("[DDNF] Aborted fixing up devices of " + formIdAndName + " and rescheduled (fixed inconsistent devices).")
            EndIf
            Return
        EndIf
        _renderedDevices = newRenderedDevices
        If (_waitingForFixup)
            ; something has triggered a new fixup while we were finding and analysing devices
            If (_renderedDevicesFlags != -12345 || !npc.Is3DLoaded())
                ; devices have been added/removed or npc has been unloaded, abort
                If (_renderedDevicesFlags == -12345)
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
            _waitingForFixup = false
        EndIf
        If (_renderedDevicesFlags == -12345)
            _renderedDevicesFlags = renderedDevicesFlags
        EndIf
        npc.SetFactionRank(npcTracker.DeviceTargets, 0)
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
    Bool isBound = Math.LogicalAnd(renderedDevicesFlags, 256) == 256
    Bool hasBondageMittens = Math.LogicalAnd(renderedDevicesFlags, 512) == 512
    Bool isUnableToKick = Math.LogicalAnd(renderedDevicesFlags, 1024) == 1024
    Bool isGagged = Math.LogicalAnd(renderedDevicesFlags, 2048) == 2048
    Bool hasPanelGag = Math.LogicalAnd(renderedDevicesFlags, 4096) == 4096
    Bool isBlindfold = Math.LogicalAnd(renderedDevicesFlags, 8192) == 8192
    Bool hasAnimation = Math.LogicalAnd(renderedDevicesFlags, 16384) == 16384
    Bool useUnarmedCombatPackage = isBound || hasBondageMittens

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
    Int dummyWeaponCount = npc.GetItemCount(npcTracker.DummyWeapon)
    If (useUnarmedCombatPackage)
        If (dummyWeaponCount == 0)
            npc.AddItem(npcTracker.DummyWeapon, 1, true)
        ElseIf (dummyWeaponCount > 1)
            npc.RemoveItem(npcTracker.DummyWeapon, aiCount=dummyWeaponCount - 1, abSilent=true)
        EndIf
    ElseIf (dummyWeaponCount > 0)
        npc.RemoveItem(npcTracker.DummyWeapon, aiCount=dummyWeaponCount, abSilent=true)
    EndIf
    Int checkBitmap = UnequipAndEquipDevices(npc, _renderedDevices, devicesWithMagicalEffectCount, ddLibs, enablePapyrusLogging)
    If (checkBitmap != 0)
        npc.UpdateWeight(0) ; workaround to force the game to correctly evaluate armor addon slots
        If (enablePapyrusLogging)
            Debug.Trace("[DDNF] Updated weight of " + formIdAndName + ".")
        EndIf
    EndIf
    If (_ignoreNotEquippedInNextFixup)
        _ignoreNotEquippedInNextFixup = false
    ElseIf (!_waitingForFixup)
        Bool devicesEquipped = checkBitmap == 0 || CheckDevicesEquipped(npc, _renderedDevices, checkBitmap)
        If (!devicesEquipped && !_waitingForFixup)
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
    If (_waitingForFixup)
        ; another fixup has been scheduled while we were unequipping and reequipping devices, abort and let the other fixup run
        _lastFixupRealTime = Utility.GetCurrentRealTime()
        _fixupLock = false
        If (enablePapyrusLogging)
            Debug.Trace("[DDNF] Aborted fixing up devices of " + formIdAndName + " (concurrent modification while unequipping/reequipping devices).")
        EndIf
        Return
    EndIf

    ; step three: handle weapons and animation effects
    If (hasAnimation || _hasAnimation)
        zadBoundCombatScript boundCombat = ddLibs.BoundCombat
        Bool animationIsApplied = false
        If (!scanForDevices || !hasAnimation)
            ; use _mtidle animation to check if animations are applied
            Int fnisAaMtIdleCrc = npc.GetAnimationVariableInt("FNISaa_mtidle_crc")
            If (fnisAaMtIdleCrc != 0 && fnisAaMtIdleCrc == fnis_aa.GetInstallationCRC())
                Int fnisAaMtIdle = npc.GetAnimationVariableInt("FNISaa_mtidle")
                animationIsApplied = IsInFnisGroup(fnisAaMtIdle, boundCombat.ABC_mtidle) || IsInFnisGroup(fnisAaMtIdle, boundCombat.HBC_mtidle) || IsInFnisGroup(fnisAaMtIdle, boundCombat.PON_mtidle)
            EndIf
        EndIf
        If (hasAnimation && animationIsApplied)
            ; un/reequipping devices can break the current idle and replace it with the default idle, restart the bound idle
            If (npc.IsInFaction(ddLibs.zadAnimatingFaction)) ; prevent breaking struggle animations
                Debug.SendAnimationEvent(npc, "IdleForceDefaultState")
            EndIf
        ElseIf (hasAnimation != animationIsApplied)
            If (enablePapyrusLogging)
                Debug.Trace("[DDNF] Reevaluating animations of " + formIdAndName + ".")
            EndIf
            ; modifying animations will cause a weird state where the NPC cannot draw weapons if they are currently drawn
            ; this can be reverted by changing the equipped weapons of the npc
            If (useUnarmedCombatPackage && !UnequipWeapons(npc, npcTracker.DummyWeapon)) ; equipped shields during EvaluateAA can cause animation issues
                npc.EquipItem(npcTracker.DummyWeapon, abPreventRemoval=true, abSilent=true)
            EndIf
            Bool restoreWeaponAccess = npc.IsWeaponDrawn()
            boundCombat.EvaluateAA(npc) ; very expensive call
            If (restoreWeaponAccess)
                ; restore ability to draw weapons by changing equipped weapons
                UnequipWeapons(npc)
            EndIf
        EndIf
    EndIf
    If (useUnarmedCombatPackage)
        RegisterForAnimationEvent(npc, "BeginWeaponDraw") ; register even if we think that we are already registered
    ElseIf (_useUnarmedCombatPackage)
        UnregisterForAnimationEvent(npc, "BeginWeaponDraw")
    EndIf
    ; almost done, so do not abort and reschedule if another fixup is scheduled, just let things run their normal course instead

    ; step four: set state and adjust factions
    Bool oldHasAnimation = _hasAnimation
    _hasAnimation = hasAnimation
    _hasPanelGag = hasPanelGag
    _isBound = isBound
    _isGagged = isGagged
    _isBlindfold = isBlindfold
    _isUnableToKick = isUnableToKick
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
    If (UpdateHelplessState(npc, npcTracker, false))
        factionsModified = true
    EndIf
    If (UpdateEvadeCombat(npc, npcTracker))
        factionsModified = true
    EndIf
    If (factionsModified)
        npc.EvaluatePackage()
    EndIf
    _lastFixupRealTime = Utility.GetCurrentRealTime()
    If (_renderedDevicesFlags >= 0 && _renderedDevices[0] == None)
        ; no devices found, reschedule scan to remove NPC
        If (enablePapyrusLogging)
            Debug.Trace("[DDNF] No devices found for " + formIdAndName + ", rescheduling another fixup in 16 seconds.")
        EndIf
        RegisterForFixup(16.0)
    EndIf
    _fixupLock = false

    ; done
    If (enablePapyrusLogging)
        Debug.Trace("[DDNF] Succeeded fixing up devices of " + formIdAndName + ", running after-fixup actions.")
    EndIf
    If (!oldHasAnimation && _hasAnimation && !_fixupLock)
        OnPackageStart(npc.GetCurrentPackage())
    EndIf
    If (_useUnarmedCombatPackage && !_fixupLock)
        If (!UnequipWeapons(npc, npcTracker.DummyWeapon) && !_fixupLock)
            npc.EquipItem(npcTracker.DummyWeapon, abPreventRemoval=true, abSilent=true)
        EndIf
        If (!_fixupLock)
            UnequipEquippedArmors(npc, npcTracker.WeaponDisplayArmors, true)
        EndIf
        If (!_fixupLock)
            UnequipEquippedAmmo(npc, npcTracker.VendorItemArrow)
        EndIf
    EndIf
    If (_isGagged && !_fixupLock)
        Shout equippedShout = npc.GetEquippedShout()
        If (equippedShout != None && !_fixupLock)
            npc.UnequipShout(equippedShout)
        EndIf
    EndIf
    If (!_fixupLock)
        KickEscapeSystem(false)
    EndIf
    If (enablePapyrusLogging)
        Debug.Trace("[DDNF] Finished after-fixup actions for " + formIdAndName + ".")
    EndIf
EndEvent

Bool Function UpdateHelplessState(Actor npc, DDNF_NpcTracker npcTracker, Bool updateWeponState) ; returns true if factions were modified
    Bool isHelpless = _isBound && (_isUnableToKick || !npcTracker.UseBoundCombat)
    If (isHelpless)
        If (!_isHelpless)
            _isHelpless = true
            npc.SetFactionRank(npcTracker.Helpless, 0)
            If (updateWeponState && npc.IsWeaponDrawn())
                If (!UnequipWeapons(npc, npcTracker.DummyWeapon) && npc.GetItemCount(npcTracker.DummyWeapon) > 0)
                    npc.EquipItem(npcTracker.DummyWeapon, abPreventRemoval=true, abSilent=true)
                EndIf
                Debug.SendAnimationEvent(npc, "IdleForceDefaultState") ; will prevent drawing weapons again
                npc.SheatheWeapon()
            EndIf
            Return true
        EndIf
    ElseIf (_isHelpless)
        npc.RemoveFromFaction(npcTracker.Helpless)
        _isHelpless = false
        If (updateWeponState)
            UnequipWeapons(npc)
        EndIf
        Return true
    EndIf
    Return false
EndFunction

Bool Function UpdateEvadeCombat(Actor npc, DDNF_NpcTracker npcTracker)
    Bool evadeCombat = _useUnarmedCombatPackage && !_isHelpless ; try to evade combat when forced to use unarmed combat
    If (evadeCombat && IsCurrentFollower(npc, npcTracker))
        ; but do not try to evade combat when following player and player is forced to use unarmed combat, too
        If (npcTracker.Player.WornHasKeyword(npcTracker.ddLibs.zad_DeviousHeavyBondage) || npcTracker.Player.WornHasKeyword(npcTracker.ddLibs.zad_DeviousBondageMittens))
            evadeCombat = false
        EndIf
    EndIf
    If (evadeCombat)
        If (!_evadeCombat)
            _evadeCombat = true
            npc.SetFactionRank(npcTracker.EvadeCombat, 0)
            Return true
        EndIf
    ElseIf (_evadeCombat)
        _evadeCombat = false
        npc.RemoveFromFaction(npcTracker.EvadeCombat)
        Return true
    EndIf
    Return false
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
;   256 - flag: bound
;   512 - flag: bondage mittens
;  1024 - flag: unable to kick
;  2048 - flag: gagged
;  4096 - flag: has panel gag
;  8192 - flag: blindfold
; 16384 - flag: has animation
;
Int Function FindAndAnalyzeRenderedDevices(zadLibs ddLibs, Actor npc, Armor[] renderedDevices, Bool enablePapyrusLogging) Global
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
                Int deviceFlags = AnalyzeMaybeDevice(ddLibs, zadLockable, zadLockableCount > 0, zadDeviousPlug, zadDeviousPlugCount > 0, maybeRenderedDevice, true, enablePapyrusLogging) ; only use cached value
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
                    Int deviceFlags = AnalyzeMaybeDevice(ddLibs, zadLockable, zadLockableCount > 0, zadDeviousPlug, zadDeviousPlugCount > 0, maybeRenderedDevice, false, enablePapyrusLogging) ; analyze if not cached
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
    Int flags = bottomIndex
    Int combinedDeviceFlagsMasked = Math.LogicalAnd(combinedDeviceFlags, 508) ; exclude "is rendered device" and "has magic effect" flags, and all flags >= 512
    flags += combinedDeviceFlagsMasked * 64 ; shift left by 6 bits: 4 -> 256, 8 -> 512, ...
    If (Math.LogicalAnd(combinedDeviceFlagsMasked, 4) == 4)
        flags = Math.LogicalOr(flags, 16384) ; ensure "has animation" flag is set if any device had the "is heavy bondage" flag
    EndIf
    Return flags
EndFunction


;
; Analyze an armor that might be a rendered device.
; Returns an int composed of the following flags:
;    1 - is rendered device
; All remaining flags are only set if flag 1 is set:
;    2 - has magic effect
;    4 - is heavy bondage
;    8 - is bondage mittens
;   16 - disables kicking
;   32 - is gag
;   64 - is panel gag
;  128 - is blindfold 
;  256 - is device other than heavy bondage that requires an animation
;  512 - is any gloves (including bondage mittens)
; 1024 - is quest device or is block generic device
; 
Int Function AnalyzeMaybeDevice(zadLibs ddLibs, Keyword zadLockable, Bool checkZadLockable, Keyword zadDeviousPlug, Bool checkZadDeviousPlug, Armor maybeRenderedDevice, Bool useCachedValueOnly, Bool enablePapyrusLogging) Global
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
            If (maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousGag))
                flags += 32
                If (maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousGagPanel))
                    flags += 64
                EndIf
            EndIf
            If (maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousBlindfold))
                flags += 128
            EndIf
            If (maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousPonyGear) || maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousHobbleSkirt) || maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousHobbleSkirtRelaxed))
                flags += 256
            EndIf
            If (maybeRenderedDevice.HasKeyword(ddLibs.zad_DeviousGloves))
                flags += 512
            EndIf
            If (maybeRenderedDevice.HasKeyword(ddLibs.zad_QuestItem) || maybeRenderedDevice.HasKeyword(ddLibs.zad_BlockGeneric))
                flags += 1024
            EndIf
            StorageUtil.SetIntValue(maybeRenderedDevice, "ddnf_a", flags) ; only cache in StorageUtil if it is a device
            If (enablePapyrusLogging)
                Debug.Trace("[DDNF] StorageUtil: SetIntValue(" + DDNF_Game.FormIdAsString(maybeRenderedDevice) + ", ddnf_a, " + flags + ")")
            EndIf
        EndIf
    EndIf
    Return flags
EndFunction

Bool Function IsAllowedToSuppress(Int itemFlagsVisible, Int itemFlagsHidden) Global
    ; allow heavy bondage to suppress gloves
    ; sometimes the item slots are not compatible but the DD framework does not care and allows to equip both
    ; so try to handle this case gracefully and keep the heavy bondage equipped, the gloves unequipped
    Return Math.LogicalAnd(itemFlagsVisible, 5) == 5 && Math.LogicalAnd(itemFlagsHidden, 513) == 513
EndFunction


; try to fix inconsistent devices, will only fix a single one so needs to be called again on true
Bool Function FixInconsistentDevices(Actor npc, Armor[] newRenderedDevices, Armor[] oldRenderedDevices, zadLibs ddLibs, Bool enablePapyrusLogging) Global
    Int cumulatedSlotMask = 0
    Int index = 0
    While (index < newRenderedDevices.Length)
        Armor renderedDevice = newRenderedDevices[index]
        If (renderedDevice == None)
            Return false
        EndIf
        Armor inventoryDevice = DDNF_NpcTracker.TryGetInventoryDevice(renderedDevice) ; may be None
        If (!inventoryDevice)
            Armor[] inventoryDevices = new Armor[32]
            Int inventoryDeviceCount = ScanForInventoryDevices(ddLibs, npc, inventoryDevices, true, None)
            Int inventoryDeviceIndex = 0
            While (inventoryDeviceIndex < inventoryDeviceCount)
                If (DDNF_NpcTracker.GetRenderedDevice(inventoryDevices[inventoryDeviceIndex], false) == renderedDevice)
                    inventoryDevice = inventoryDevices[inventoryDeviceIndex]
                    inventoryDeviceIndex = inventoryDevices.Length
                EndIf
                inventoryDeviceIndex += 1
            EndWhile
        EndIf
        If (inventoryDevice == None || npc.GetItemCount(inventoryDevice) == 0)
            Bool isQuestDevice = Math.LogicalAnd(AnalyzeMaybeDevice(ddLibs, ddLibs.zad_Lockable, true, ddLibs.zad_DeviousPlug, true, renderedDevice, false, enablePapyrusLogging), 1024) == 1024
            If (!isQuestDevice && inventoryDevice != None)
                isQuestDevice = inventoryDevice.HasKeyword(ddLibs.zad_QuestItem) || inventoryDevice.HasKeyword(ddLibs.zad_BlockGeneric)
            EndIf
            If (!isQuestDevice)
                npc.UnequipItem(renderedDevice, abPreventEquip=true, abSilent=true)
                npc.RemoveItem(renderedDevice, aiCount=npc.GetItemCount(renderedDevice), abSilent=true)
                If (enablePapyrusLogging)
                    Debug.Trace("[DDNF] Removed rendered device " + DDNF_Game.FormIdAsString(renderedDevice) + " from " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + " because of missing inventory device.")
                EndIf
                Return true
            EndIf
        EndIf
        Int slotMask = renderedDevice.GetSlotMask()
        If (Math.LogicalAnd(cumulatedSlotMask, slotMask) != 0)
            If (newRenderedDevices.RFind(renderedDevice, index - 1) > 0)
                npc.RemoveItem(renderedDevice, aiCount=npc.GetItemCount(renderedDevice) - 1, abSilent=true)
                Debug.Trace("[DDNF] Removed duplicate rendered device " + DDNF_Game.FormIdAsString(renderedDevice) + " from " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + ".")
                Return true
            EndIf
            Int deviceFlags = AnalyzeMaybeDevice(ddLibs, ddLibs.zad_Lockable, true, ddLibs.zad_DeviousPlug, true, renderedDevice, false, enablePapyrusLogging)
            Armor deviceToRemove = None
            Int backScanIndex = index - 1
            While (backScanIndex >= 0)
                Armor backScanRenderedDevice = newRenderedDevices[backScanIndex]
                If (Math.LogicalAnd(backScanRenderedDevice.GetSlotMask(), slotMask) != 0)
                    Int backScanDeviceFlags = AnalyzeMaybeDevice(ddLibs, ddLibs.zad_Lockable, true, ddLibs.zad_DeviousPlug, true, backScanRenderedDevice, false, enablePapyrusLogging)
                    If (IsAllowedToSuppress(deviceFlags, backScanDeviceFlags) || IsAllowedToSuppress(backScanDeviceFlags, deviceFlags))
                        deviceToRemove = None
                    Else
                        Bool deviceIsQuestDevice = Math.LogicalAnd(deviceFlags, 1024) == 1024
                        If (!deviceIsQuestDevice && inventoryDevice != None)
                            deviceIsQuestDevice = inventoryDevice.HasKeyword(ddLibs.zad_QuestItem) || inventoryDevice.HasKeyword(ddLibs.zad_BlockGeneric)
                        EndIf
                        If (!deviceIsQuestDevice)
                            deviceToRemove = renderedDevice
                        EndIf
                        Bool backScanDeviceIsQuestDevice = Math.LogicalAnd(backScanDeviceFlags, 1024) == 0
                        If (!backScanDeviceIsQuestDevice)
                            Armor backScanInventoryDevice = DDNF_NpcTracker.TryGetInventoryDevice(backScanRenderedDevice) ; may be None
                            If (backScanInventoryDevice != None && (backScanInventoryDevice.HasKeyword(ddLibs.zad_QuestItem) && backScanInventoryDevice.HasKeyword(ddLibs.zad_BlockGeneric)))
                                backScanDeviceIsQuestDevice = true
                            EndIf
                        EndIf
                        If (!backScanDeviceIsQuestDevice && (deviceToRemove == None || oldRenderedDevices.Find(backScanRenderedDevice) < 0))
                            deviceToRemove = backScanRenderedDevice 
                        EndIf
                    EndIf
                EndIf
                backScanIndex -= 1
            EndWhile
            If (deviceToRemove != None)
                npc.UnequipItem(deviceToRemove, abPreventEquip=true, abSilent=true)
                npc.RemoveItem(deviceToRemove, aiCount=npc.GetItemCount(deviceToRemove), abSilent=true)
                If (enablePapyrusLogging)
                    Debug.Trace("[DDNF] Removed rendered device " + DDNF_Game.FormIdAsString(deviceToRemove) + " from " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + " to resolve slot mask conflicts.")
                EndIf
                Return true
            EndIf
        EndIf
        cumulatedSlotMask = Math.LogicalOr(cumulatedSlotMask, slotMask)
        index += 1
    EndWhile
    Return false
EndFunction


; unequip and reequip devices, return a bitmap for the devices to check
Int Function UnequipAndEquipDevices(Actor npc, Armor[] renderedDevices, Int devicesWithMagicalEffectCount, zadLibs ddLibs, Bool enablePapyrusLogging) Global
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
            needsReequip = true
            Int slotMask = renderedDevices[index].GetSlotMask()
            Armor conflictingItem = npc.GetWornForm(slotMask) as Armor
            If (conflictingItem != None)
                Int itemFlags = AnalyzeMaybeDevice(ddLibs, ddLibs.zad_Lockable, true, ddLibs.zad_DeviousPlug, true, renderedDevices[index], false, enablePapyrusLogging)
                Int conflictingItemFlags = AnalyzeMaybeDevice(ddLibs, ddLibs.zad_Lockable, true, ddLibs.zad_DeviousPlug, true, conflictingItem, false, enablePapyrusLogging)
                If (IsAllowedToSuppress(conflictingItemFlags, itemFlags))
                    If (enablePapyrusLogging)
                        Debug.Trace("[DDNF] Keeping rendered device " + DDNF_Game.FormIdAsString(renderedDevices[index]) + " unequipped on " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + " because of a valid suppression.")
                    EndIf
                    needsReequip = false
                Else
                    npc.UnequipItem(conflictingItem, abPreventEquip=true, abSilent=true)
                    If (IsAllowedToSuppress(itemFlags, conflictingItemFlags))
                        If (enablePapyrusLogging)
                            Debug.Trace("[DDNF] Unequipping rendered device " + DDNF_Game.FormIdAsString(conflictingItem) + " from " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + " because of a valid suppression.")
                        EndIf
                        Int conflictingItemIndex = renderedDevices.Find(conflictingItem)
                        If (conflictingItemIndex >= 0)
                            Int conflictingBit = Math.LeftShift(1, conflictingItemIndex)
                            If (Math.LogicalAnd(bitmapToCheck, conflictingBit) == conflictingBit)
                                bitmapToCheck = Math.LogicalXor(bitmapToCheck, conflictingBit)
                            EndIf
                        EndIf
                    EndIf
                EndIf
            EndIf
        EndIf
        If (needsReequip && npc.GetItemCount(renderedDevices[index]) > 0) ; safety check
            npc.EquipItem(renderedDevices[index], abPreventRemoval=true, abSilent=true)
            bitmapToCheck = Math.LogicalOr(bitmapToCheck, Math.LeftShift(1, index))
        EndIf
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
    Form rightHandForm = npc.GetEquippedObject(1) ; right hand
    Weapon rightHandWeapon = rightHandForm as Weapon
    Spell rightHandSpell = rightHandForm as Spell
    ; detect and unequip left-hand weapon/spell/shield
    Bool keptIgnoreWeapon = false
    Form leftHandForm = npc.GetEquippedObject(0) ; left hand
    If (leftHandForm != None)
        Spell leftHandSpell = leftHandForm as Spell
        If (leftHandSpell != None)
            npc.UnequipSpell(leftHandSpell, 0)
        Else
            Armor shield = leftHandForm as Armor
            If (shield != None)
                npc.UnequipItem(shield, abSilent=true)
            Else
                Weapon leftHandWeapon = leftHandForm as Weapon
                If (leftHandWeapon != None)
                    If (ignoreWeapon == None)
                        npc.UnequipItemEx(leftHandWeapon, equipSlot=0)
                    ElseIf (leftHandWeapon != ignoreWeapon)
                        npc.UnequipItemEx(leftHandWeapon, equipSlot=0)
                    Else
                        keptIgnoreWeapon = true
                    EndIf
                EndIf
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


;
; Unequip all armors that match the formlist.
;
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


;
; Unequip all ammo.
;
Function UnequipEquippedAmmo(Actor npc, Keyword ammoKeyword) Global
    If (!npc.WornHasKeyword(ammoKeyword))
        Return ; short-circuit
    EndIf
    Int index = npc.GetNumItems() - 1 ; start at end to increase chance of early abort
    While (index >= 0)
        Ammo maybeAmmo = npc.GetNthForm(index) as Ammo
        If (maybeAmmo != None && npc.IsEquipped(maybeAmmo))
            npc.UnequipItem(maybeAmmo, abSilent = true)
            Return ; early exit
        EndIf
        Index -= 1
    EndWhile
EndFunction


;
; Quick-equip some (inventory) devices on the npc.
;
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
                            _quickEquipRunning += 1
                            UnregisterForUpdate() ; prevent concurrent fixup as it is pointless
                            _waitingForFixup = false
                        EndIf
                        If (DDNF_NpcTracker.TryGetInventoryDevice(inventoryDevice.deviceRendered) == None)
                            DDNF_NpcTracker.LinkInventoryDeviceAndRenderedDevice(inventoryDevice.deviceInventory, inventoryDevice.deviceRendered, npcTracker.EnablePapyrusLogging)
                        EndIf
                        npc.AddItem(inventoryDevice.deviceInventory, 1, true)
                        npc.AddItem(inventoryDevice.deviceRendered, 1, true)
                        If (equipRenderedDevices)
                            npc.EquipItem(inventoryDevice.deviceRendered, abPreventRemoval=true, abSilent=true)
                        EndIf
                        _renderedDevicesFlags = -1
                        equippedCount += 1
                    EndIf
                EndIf
                index += 1
            EndWhile
            index = 0
            If (equippedCount > 0)
                If (npcTracker.EnablePapyrusLogging)
                    Debug.Trace("[DDNF] Quick-Equipped " + equippedCount + " devices on " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + ".")
                EndIf
                _quickEquipRunning -= 1
                If (_quickEquipRunning <= 0)
                    _fixupHighPriority = true ; high priority to make the effects start asap
                    _ignoreNotEquippedInNextFixup = false
                    RegisterForFixup()
                EndIf
            EndIf
        EndIf
        While (index < tempRefs.Length)
            tempRefs[index].Delete()
            index += 1
        EndWhile
    EndIf
    Return equippedCount
EndFunction


Function KickEscapeSystem(Bool highUrgencyMode)
    If (_lastEscapeAttemptGameTime == -99)
        Actor npc = GetReference() as Actor
        If (npc != None)
            DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
            If (highUrgencyMode)
                _lastEscapeAttemptGameTime = -49 ; special value
                RegisterForSingleUpdateGameTime(Utility.RandomFloat(0.1, 0.3))
                If (npcTracker.EnablePapyrusLogging)
                    Debug.Trace("[DDNF] Started escape timer for " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + " in high urgency mode.")
                EndIf
            Else
                Float timeSinceLastEscapeAttempt = 0
                If (npcTracker.EscapeSystemEnabled)
                    Float struggleFrequency
                    If (IsCurrentFollower(npc, npcTracker))
                        struggleFrequency = npcTracker.CurrentFollowerStruggleFrequency
                    Else
                        struggleFrequency = npcTracker.OtherNpcStruggleFrequency
                    EndIf
                    If (struggleFrequency > 0)
                        timeSinceLastEscapeAttempt = Utility.RandomFloat(0, struggleFrequency / 24)
                    EndIf
                EndIf
                _lastEscapeAttemptGameTime = Utility.GetCurrentGameTime() - timeSinceLastEscapeAttempt
                RegisterForSingleUpdateGameTime(Utility.RandomFloat(0.35, 0.65)) ; increase random jitter for initial update
                If (npcTracker.EnablePapyrusLogging)
                    Debug.Trace("[DDNF] Started escape timer for " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + ", time since last escape attempt set to " + timeSinceLastEscapeAttempt + ".")
                EndIf
            EndIf
        EndIf
    EndIf
EndFunction


;
; Escape system is triggered from game time update event.
;
Event OnUpdateGameTime()
    Actor npc = GetReference() as Actor
    DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
    If (npc != None && npcTracker.IsEnabled)
        Bool registerForUpdate = true
        If (npcTracker.EscapeSystemEnabled)
            Int struggleFrequency
            If (IsCurrentFollower(npc, npcTracker))
                struggleFrequency = npcTracker.CurrentFollowerStruggleFrequency
            Else
                struggleFrequency = npcTracker.OtherNpcStruggleFrequency
            EndIf
            If (struggleFrequency != 0)
                ; escape system is enabled for this NPC
                Float hoursSinceLastAttempt = (Utility.GetCurrentGameTime() - _lastEscapeAttemptGameTime) * 24.0
                If (struggleFrequency < 0 || hoursSinceLastAttempt >= struggleFrequency)
                    String rescheduleReason = ""
                    Bool isPlayerTeammate = npc.IsPlayerTeammate()
                    If (!npc.Is3DLoaded())
                        rescheduleReason = "3D is not loaded"
                    ElseIf (isPlayerTeammate && npcTracker.Player.GetCombatState() > 0)
                        rescheduleReason = "is player teammate and player in combat"
                    ElseIf (isPlayerTeammate && npcTracker.Player.IsSneaking())
                        rescheduleReason = "is player teammate and player is sneaking"
                    ElseIf (npc.IsOnMount())
                        rescheduleReason = "is on mount"
                    ElseIf (npc.IsInFaction(npcTracker.ddLibs.Sexlab.AnimatingFaction))
                        rescheduleReason = "is animated by sexlab"
                    ElseIf (npc.HasMagicEffectWithKeyword(npcTracker.MagicInfluenceCharm))
                        rescheduleReason = "is charmed"
                    ElseIf (npc.GetCurrentScene() != None)
                        rescheduleReason = "is in scene"
                    EndIf
                    If (rescheduleReason != "")
                        If (npcTracker.EnablePapyrusLogging)
                            Debug.Trace("[DDNF] Escape system: Rescheduling attempt for " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + ", " + rescheduleReason + ".")
                        EndIf
                        GlobalVariable timeScale = Game.GetFormFromFile(0x00003A, "Skyrim.esm") as GlobalVariable
                        Float delay = Utility.RandomFloat(15, 45) * timeScale.GetValueInt() / 3600 ; X seconds real time
                        If (delay < 0.03)
                            delay = 0.03 ; RegisterForSingleUpdateGameTime can crash on very small values
                        EndIf
                        RegisterForSingleUpdateGameTime(delay)
                        Return
                    EndIf
                    If (npcTracker.EnablePapyrusLogging)
                        Debug.Trace("[DDNF] Escape system: Triggering attempt for " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + " (hoursSinceLastAttempt=" + hoursSinceLastAttempt + ", struggleFrequency=" + struggleFrequency + ").")
                    EndIf
                    If (_lastEscapeAttemptGameTime >= -24 && ((struggleFrequency == -1 && hoursSinceLastAttempt >= 0.75) || (struggleFrequency > 0 && (hoursSinceLastAttempt - struggleFrequency) >= 0.75)))
                        If (npcTracker.EnablePapyrusLogging)
                            Debug.Trace("[DDNF] Escape system: Adding random delay for " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + " after suspected fast travel/wait/sleep.")
                        EndIf
                        Utility.Wait(Utility.RandomFloat(8, 32)) ; wait some time to give scripts time after fast travel/wait/sleep and to introduce additonal jitter
                    EndIf
                    PerformEscapeAttempt(false, true)
                    registerForUpdate = npc == (GetReference() as Actor) ; check for race condition
                ElseIf (npcTracker.EnablePapyrusLogging)
                    Debug.Trace("[DDNF] Escape system: Not triggering attempt for " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + " (hoursSinceLastAttempt=" + hoursSinceLastAttempt + ", struggleFrequency=" + struggleFrequency + ").")
                EndIf
            ElseIf (npcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] Escape system: Escape attempts are disabled for " + DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName() + ".")
            EndIf
        EndIf
        If (registerForUpdate)
            RegisterForSingleUpdateGameTime(Utility.RandomFloat(0.45, 0.65)) ; random jitter but bias to > 0.5
        EndIf
    EndIf
EndEvent

;
; Make the NPC attempt to escape either one or all devices. This function can take a long time,
; up to several minutes.
; Returns the number of removed devices, -1 if the attempt was aborted (e.g. another attempt ongoing).
;
Int Function PerformEscapeAttempt(Bool suppressNotifications, Bool respectCooldowns)
    ; check if escape attempt can be made
    Actor npc = GetReference() as Actor
    If (npc == None) ; check for race condition
        Return -1
    EndIf
    DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
    String npcFormIdAndName = ""
    If (npcTracker.EnablePapyrusLogging)
        npcFormIdAndName = DDNF_Game.FormIdAsString(npc) + " " + npc.GetDisplayName()
    EndIf
    Bool isCurrentFollower = IsCurrentFollower(npc, npcTracker)
    If (!isCurrentFollower)
        Int modId = DDNF_Game.GetModId(npc.GetFormID())
        If (modId == npcTracker.DeviouslyCursedLootModId && DDNF_DcurShim.IsStruggleBlocklistedCharacter(npc))
            If (npcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] Aborting escape attempt for " + npcFormIdAndName + " because npc is blocklisted for struggling.")
            EndIf
            Return -1
        EndIf
        If (HasDeviousDevicesOutfit(npc, npcTracker))
            If (npcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] Aborting escape attempt for " + npcFormIdAndName + " because npc has Devious Devices outfit.")
            EndIf
            Return -1
        EndIf
    EndIf
    If (_renderedDevicesFlags < 0 || _fixupLock)
        If (npcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] Trying to delay  escape attempt for " + npcFormIdAndName + " until after fixup.")
        EndIf
        Int waitCount = 0
        While (waitCount < 12) ; heuristic
            Utility.Wait(1.0)
            If (_renderedDevicesFlags > 0 && !_fixupLock)
                waitCount = 999
            EndIf
            waitCount += 1
        EndWhile
        If ((GetReference() as Actor) != npc) ; check for race condition
            Return -1
        EndIf
    EndIf
    If (!GotoStateStruggling())
        Return -1 ; concurrent attempt running
    EndIf
    Int struggleLimit = npcTracker.AbortStrugglingAfterFailedDevices

    ; loop over all devices and try to escape from them
    If (npcTracker.EnablePapyrusLogging)
        Debug.Trace("[DDNF] Performing escape attempt for " + npcFormIdAndName + ".")
    EndIf
    Bool displayNotifications = !suppressNotifications && npcTracker.EscapeSystemEnabled && npcTracker.NotifyPlayerOfCurrentFollowerStruggle && isCurrentFollower
    Armor[] failedDevices = new Armor[32]
    Int failedDeviceCount = 0
    Int noChanceDeviceCount = 0
    Int didNotStruggleDeviceCount = 0
    Int succeededDeviceCount = 0
    Bool abortEscapeAttempt = false
    Armor lastUnequippedDevice = None
    While (IsStruggling() && !abortEscapeAttempt)
        If (lastUnequippedDevice != None)
            Utility.Wait(1) ; short break between unequipping devices
        EndIf
        Armor deviceToUnequip = ChooseDeviceForUnequip(true, failedDevices, failedDeviceCount, true, respectCooldowns) ; allow quest devices, they will fail in TryToEscapeDevice
        If (deviceToUnequip == None)
            abortEscapeAttempt = true
        Else
            If (npcTracker.enablePapyrusLogging)
                Debug.Trace("[DDNF] Escape attempt (" + npcFormIdAndName +  "): Found device " + DDNF_Game.FormIdAsString(deviceToUnequip) + " " + deviceToUnequip.GetName() + ".")
            EndIf
            Bool[] escapeResult = TryToEscapeDevice(deviceToUnequip, displayNotifications && !npcTracker.OnlyDisplayFinalSummaryMessage, npcTracker.StruggleIfPointless, true)
            If (escapeResult[0])
               succeededDeviceCount += 1
               lastUnequippedDevice = deviceToUnequip
            Else
                failedDevices[failedDeviceCount] = deviceToUnequip
                failedDeviceCount += 1
                If (escapeResult.Length == 1)
                    If (npcTracker.enablePapyrusLogging)
                        Debug.Trace("[DDNF] Escape attempt (" + npcFormIdAndName +  "): Early abort due to unexpected failure.")
                    EndIf
                    abortEscapeAttempt = true
                Else
                    If (escapeResult[1])
                        noChanceDeviceCount += 1
                    EndIf
                    If (escapeResult[2])
                        didNotStruggleDeviceCount += 1
                    EndIf
                    If (struggleLimit > 0)
                        If ((failedDeviceCount - didNotStruggleDeviceCount) >= struggleLimit)
                            abortEscapeAttempt = true
                            If (npcTracker.enablePapyrusLogging)
                                Debug.Trace("[DDNF] Escape attempt (" + npcFormIdAndName +  "): Early abort due to reaching limit of " + npcTracker.AbortStrugglingAfterFailedDevices + ".")
                            EndIf
                        EndIf
                    EndIf
                    If (!abortEscapeAttempt && failedDeviceCount == failedDevices.Length) ; not expected but handle it
                        If (npcTracker.enablePapyrusLogging)
                           Debug.Trace("[DDNF] Escape attempt (" + npcFormIdAndName +  "): Early abort due to running out of array space.")
                        EndIf
                        abortEscapeAttempt = true
                    EndIf
                EndIf
            EndIf
        EndIf
    EndWhile
    If (npc.IsInFaction(npcTracker.Struggling))
        npc.RemoveFromFaction(npcTracker.Struggling)
        npc.EvaluatePackage()
    EndIf
    Int remainingDevicesCount = npc.GetItemCount(npcTracker.DDLibs.zad_Lockable) + npc.GetItemCount(npcTracker.DDLibs.zad_DeviousPlug)
    Bool escapeAttemptInterrupted = !IsStruggling()
    If (npc == (GetReference() as Actor))
        If (!escapeAttemptInterrupted)
            GotoStateNotStruggling()
        EndIf
        _lastEscapeAttemptGameTime = Utility.GetCurrentGameTime()
    EndIf
    If (npcTracker.EnablePapyrusLogging)
        Debug.Trace("[DDNF] Finished escape attempt for " + npcFormIdAndName + ": Succeeded " + succeededDeviceCount + ", failed " + failedDeviceCount + " (impossible " + noChanceDeviceCount + ", not struggled " + didNotStruggleDeviceCount + "). " + remainingDevicesCount + " remaining.")
    EndIf

    ; notify player about the result
    If (succeededDeviceCount + failedDeviceCount > 0)
        Bool noChanceToEscape = succeededDeviceCount == 0 && noChanceDeviceCount == failedDeviceCount
        Bool didNotStruggle = noChanceToEscape && didNotStruggleDeviceCount == failedDeviceCount
        If (didNotStruggle && npc.Is3DLoaded())
            npcTracker.DDLibs.SexlabMoan(npc)
        EndIf
        If (displayNotifications)
            String possessive = " her "
            If (npc.GetLeveledActorBase().GetSex() == 0)
                possessive = " his "
            EndIf
            If (escapeAttemptInterrupted && !didNotStruggle)
                Utility.Wait(1)
                Debug.Notification(npc.GetDisplayName() + " stops" + possessive + "attempts to escape" + possessive + "devices")
            EndIf
            Utility.Wait(1)
            If (succeededDeviceCount == 0)
                If (noChanceToEscape)
                    If (didNotStruggle)
                        String pronoun = " she "
                        If (possessive == " his ")
                            pronoun = " he "
                        EndIf
                        Debug.Notification(npc.GetDisplayName() + " is not struggling," + pronoun + "knows that it is pointless")
                    Else
                        Debug.Notification(npc.GetDisplayName() + " has no way to escape any of" + possessive + "devices")
                    EndIf
                Else
                    Debug.Notification(npc.GetDisplayName() + " failed to escape" + possessive + "devices")
                EndIf
            ElseIf (remainingDevicesCount > 0)
                Debug.Notification(npc.GetDisplayName() + " escaped some of" + possessive + "devices")
            Else
                Debug.Notification(npc.GetDisplayName() + " escaped all" + possessive + "devices")
            EndIf
            If (npc == (GetReference() as Actor))
                String status = GetStatusText(npcTracker.DDLibs, true)
                If (status != "")
                    Utility.Wait(1.0)
                    Debug.Notification(npc.GetDisplayName() + " is" + status)
                EndIf
            EndIf
        EndIf
    EndIf
    
    ; done
    Return succeededDeviceCount
EndFunction

Bool Function IsCurrentFollower(Actor npc, DDNF_NpcTracker npcTracker) Global
    Bool result = npc.GetFactionRank(npcTracker.CurrentFollowerFaction) >= 0
    If (!result)
       Package currentPackage = npc.GetCurrentPackage()
       result = currentPackage.GetTemplate() == npcTracker.FollowerPackageTemplate
    EndIf
    If (!result)
        ActorBase npcBase = npc.GetActorBase()
        If (npcBase == Game.GetFormFromFile(0x002B6C, "Dawnguard.esm")) ; DLC1Serana
            ; Serana's AI is different than that of any other follower, so CurrentFollowerFaction is not working
            result = DDNF_DLC1Shim.IsSeranaCurrentlyFollowing(npc)
        EndIf
    EndIf
    Return result
EndFunction

Bool Function HasDeviousDevicesOutfit(Actor npc, DDNF_NpcTracker npcTracker) Global
    ActorBase npcBase = npc.GetActorBase()
    Return IsDeviousDevicesOutfit(npcBase.GetOutfit(), npcTracker) || IsDeviousDevicesOutfit(StorageUtil.GetFormValue(npcBase, "zad_OriginalOutfit") as Outfit, npcTracker)
EndFunction

Bool Function IsDeviousDevicesOutfit(Outfit maybeOutfit, DDNF_NpcTracker npcTracker) Global
    If (maybeOutfit == None)
        Return false
    EndIf
    Int isDDOutfit = StorageUtil.GetIntValue(maybeOutfit, "ddnf_dd", -1)
    If (isDDOutfit < 0)
        isDDOutfit = 0
        Int count = maybeOutfit.GetNumParts()
        Int index = 0
        While (index < count)
            Armor maybeArmor = maybeOutfit.GetNthPart(index) as Armor
            If (maybeArmor != None)
                Bool isInventoryDevice = DDNF_NpcTracker.GetRenderedDevice(maybeArmor, false) != None
                If (isInventoryDevice || DDNF_NpcTracker.TryGetInventoryDevice(maybeArmor) != None || maybeArmor.HasKeyword(npcTracker.DDLibs.zad_Lockable) || maybeArmor.HasKeyword(npcTracker.DDLibs.zad_DeviousPlug))
                    isDDOutfit = 1
                    index = count ; early abort
                EndIf
            EndIf
            index += 1
        EndWhile
        StorageUtil.SetIntValue(maybeOutfit, "ddnf_dd", isDDOutfit)
        If (npcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] StorageUtil: SetIntValue(" + DDNF_Game.FormIdAsString(maybeOutfit) + ", ddnf_dd, " + isDDOutfit + ")")
        EndIf
    EndIf
    Return isDDOutfit > 0
EndFunction

String Function GetStatusText(zadLibs ddLibs, Bool includeHelpless)
    Actor npc = GetReference() as Actor
    String[] fragments = new String[10]
    Int fragmentCount = 0
    If (npc != None)
        If (IsBound())
            If (includeHelpless && IsHelpless())
                fragments[0] = " helplessly bound"
            Else
                fragments[0] = " bound"
            EndIf
            fragmentCount = 1
        EndIf
        If (IsGagged())
            fragments[fragmentCount] = " gagged"
            fragmentCount += 1
        EndIf
        If (IsBlindfold())
            fragments[fragmentCount] =  " blindfold"
            fragmentCount += 1
        EndIf
        If (npc.GetItemCount(ddLibs.zad_DeviousBelt))
            fragments[fragmentCount] = " belted"
            fragmentCount += 1
        EndIf
        If (npc.GetItemCount(ddLibs.zad_DeviousPlug))
            fragments[fragmentCount] = " plugged"
            fragmentCount += 1
        EndIf
    EndIf
    if (fragmentCount == 0)
        Return ""
    EndIf
    String status = fragments[0]
    Int index = 1
    While (index < fragmentCount)
        String fragment = fragments[index]
        index += 1
        If (index == fragmentCount)
            status += " and" + fragment
        Else
            status += "," + fragment
        EndIf
    EndWhile
    Return status
EndFunction


;
; Choose a device to be unequipped from the NPC, either when the NPC tries to free themselves,
; or when somebody else wants to free the NPC. This will respect limitations, e.g. plugs can
; only be unequipped after (most) belts, or NPCs need to get rid of heavy bondage first when
; freeing self. It also gives more relevant devices a higher chance (e.g. gags are usually
; selected before belts).
;
Armor Function ChooseDeviceForUnequip(Bool unequipSelf, Armor[] devicesToIgnore, Int devicesToIgnoreCount, Bool allowQuestDevices, Bool respectCooldowns)
    Actor npc = GetReference() as Actor
    If (npc == None)
        Return None
    EndIf
    DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
    If (unequipSelf && npcTracker.TryGetCurrentContraption(npc) != None)
        Return None ; NPC is currently held by devious contraption
    EndIf
    Armor[] inventoryDevices = new Armor[32]
    Int deviceCount = TryGetEquippedDevices(inventoryDevices, None)
    If (deviceCount < 0)
        deviceCount = ScanForInventoryDevices(npcTracker.ddLibs, npc, inventoryDevices, true, None)
    EndIf
    Armor[] renderedDevices = new Armor[32]
    Int index = 0
    While (index < deviceCount)
        Armor inventoryDevice = inventoryDevices[index]
        If (devicesToIgnoreCount == 0 || devicesToIgnore.RFind(inventoryDevice, devicesToIgnoreCount + 1) < 0)
            renderedDevices[index] = DDNF_NpcTracker.GetRenderedDevice(inventoryDevice, false)
        EndIf
        index += 1
    EndWhile
    Bool[] unequipPossible = new Bool[32]
    CheckIfUnequipPossibleArray(npc, inventoryDevices, renderedDevices, unequipPossible, deviceCount, npcTracker.DDLibs, unequipSelf, allowQuestDevices)
    If (respectCooldowns)
        Float currentGameTime = 0
        index = 0
        While (index < deviceCount)
            String storageUtilTag = "ddnf_e_t" + DDNF_NpcTracker.GetOrCreateUniqueTag(inventoryDevices[index])
            Float deviceMinGameTime = StorageUtil.GetFloatValue(npc, storageUtilTag, 0)
            If (deviceMinGameTime > 0)
                If (currentGameTime == 0)
                    currentGameTime = Utility.GetCurrentGameTime()
                EndIf
                If (currentGameTime < deviceMinGameTime)
                    unequipPossible[index] = false
                EndIf
            EndIf
            Index += 1
        EndWhile
    EndIf
    Armor[] selectionArray = new Armor[128]
    Int selectionArrayIndex = 0
    index = 0
    While (index < deviceCount && selectionArrayIndex < selectionArray.Length)
        If (unequipPossible[index])
            Armor inventoryDevice = inventoryDevices[index]
            Int weigth = GetWeigthForUnequip(npcTracker.DDLibs, renderedDevices[index], npcTracker.EnablePapyrusLogging)
            Int addedCount = 0
            While (addedCount < weigth && selectionArrayIndex < selectionArray.Length)
                selectionArray[selectionArrayIndex] = inventoryDevice
                selectionArrayIndex += 1
                addedCount += 1
            EndWhile
        EndIf
        index += 1
    EndWhile
    If (selectionArrayIndex == 0)
        Return None
    EndIf    
    Armor deviceToUnequip = selectionArray[Utility.RandomInt(0, selectionArrayIndex - 1)]
    Return deviceToUnequip
EndFunction

; check if it is possible to unequip the given device
Bool Function CheckIfUnequipPossible(Actor npc, Armor inventoryDevice, Armor renderedDevice, zadLibs ddLibs, Bool unequipSelf, Bool allowQuestDevices) Global
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
    Return CheckUnequipPossibleInternal(npc, inventoryDevice, renderedDevice, ddLibs, cachedCounts, unequipSelf, allowQuestDevices)
EndFunction

; check if it is possible to unequip the devices in the array, re-using information as much as possible
Function CheckIfUnequipPossibleArray(Actor npc, Armor[] inventoryDevices, Armor[] renderedDevices, Bool[] output, Int count, zadLibs ddLibs, Bool unequipSelf, Bool allowQuestDevices) Global
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
        output[index] = CheckUnequipPossibleInternal(npc, inventoryDevices[index], renderedDevices[index], ddLibs, cachedCounts, unequipSelf, allowQuestDevices)
        index += 1
    EndWhile
EndFunction

Bool Function CheckUnequipPossibleInternal(Actor npc, Armor inventoryDevice, Armor renderedDevice, zadLibs ddLibs, Int[] cachedCounts, Bool unequipSelf, Bool allowQuestDevices) Global
    If (inventoryDevice == None || renderedDevice == None)
        Return false
    EndIf
    If (!allowQuestDevices && (inventoryDevice.HasKeyword(ddLibs.zad_BlockGeneric) || inventoryDevice.HasKeyword(ddLibs.zad_QuestItem) || renderedDevice.HasKeyword(ddLibs.zad_BlockGeneric) || renderedDevice.HasKeyword(ddLibs.zad_QuestItem)))
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
    Bool isVaginalPiercing = renderedDevice.HasKeyword(ddLibs.zad_DeviousPiercingsVaginal)
    If (isVaginalPiercing || renderedDevice.HasKeyword(ddLibs.zad_DeviousPlug))
        If (isVaginalPiercing || renderedDevice.HasKeyword(ddLibs.zad_DeviousPlugVaginal))
            ; belts and suit may block vaginal plugs and vaginal piercings
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
    If (renderedDevice.HasKeyword(ddLibs.zad_DeviousPiercingsNipple) || renderedDevice.HasKeyword(ddLibs.zad_DeviousClamps) )
        ; bras and suit may block nipple piercings and clamps
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


;
; Get the "weight" to use when selecting a device for unequipping; this should be used as a probability.
;
Int Function GetWeigthForUnequip(zadLibs ddLibs, Armor renderedDevice, Bool enablePapyrusLogging) Global ; higher is more important
    Int flags = AnalyzeMaybeDevice(ddLibs, ddLibs.zad_Lockable, true, ddLibs.zad_DeviousPlug, true, renderedDevice, false, enablePapyrusLogging)
    If (Math.LogicalAnd(flags, 4) == 4)
        ; first heavy bondage
        Return 16
    EndIf
    If (Math.LogicalAnd(flags, 8) == 8)
        ; then mittens
        Return 12
    EndIf
    If (Math.LogicalAnd(flags, 32) == 32 || Math.LogicalAnd(flags, 128) == 128)
        ; then gags and blindfolds (this includes many hoods)
        Return 8
    EndIf
    If (Math.LogicalAnd(flags, 16) == 16)
        ; then fetters
        Return 4
    EndIf
    ; then everything else
    If (flags > 0)
        Return 1
    EndIf
    Return 0 ; not expected
EndFunction


;
; Make the NPC try to escape from a device by opening locks or struggling.
; Return values: Array with single false value on aborted attempt (quest item, blocked by another device, ...),
; otherwise array with the following values: 0 - success, 1 - failed because chance was 0%, 2 - did not struggle because chance was 0%
;
Bool[] Function TryToEscapeDevice(Armor device, Bool notifyPlayer, Bool struggleIfKnownToBePointless, Bool addToStrugglingFactionIfNecessary)
    ; check if escape attempt can be made
    Actor npc = GetReference() as Actor
    Armor renderedDevice = DDNF_NpcTracker.GetRenderedDevice(device, false)
    If (npc == None || renderedDevice == None || npc.GetItemCount(renderedDevice) == 0)
        Return new Bool[1]
    EndIf
    DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
    If (npcTracker.TryGetCurrentContraption(npc) != None)
        Return new Bool[1] ; NPC is currently held by devious contraption
    EndIf
    zadLibs ddLibs = npcTracker.DDLibs
    If (!CheckIfUnequipPossible(npc, device, renderedDevice, ddLibs, true, true)) ; allow quest devices here, we will check zad_BlockGeneric/zad_QuestItem later
        Return new Bool[1]
    EndIf

    ; analyze the device and calculate escape chances
    ObjectReference tempRef = ddLibs.PlayerRef.PlaceAtMe(device, abInitiallyDisabled = true)
    zadEquipScript equipScript = tempRef as zadEquipScript
    If (equipScript == None) ; not expected but handle it
        tempRef.Delete()
        Return new Bool[1]
    EndIf
    Int deviceFlags = AnalyzeMaybeDevice(ddLibs, ddLibs.zad_Lockable, true, ddLibs.zad_DeviousPlug, true, renderedDevice, false, npcTracker.enablePapyrusLogging)
    Bool deviceIsHeavyBondage = Math.LogicalAnd(deviceFlags, 4) == 4
    Bool deviceIsBondageMittens = Math.LogicalAnd(deviceFlags, 8) == 8
    Bool handsBlocked = deviceIsBondageMittens || npc.GetItemCount(ddLibs.zad_DeviousBondageMittens) > 0 || npc.GetItemCount(ddLibs.zad_DeviousStraitJacket) > 0
    Bool deviceIsQuestDevice = device.HasKeyword(ddLibs.zad_BlockGeneric) || device.HasKeyword(ddLibs.zad_QuestItem) || renderedDevice.HasKeyword(ddLibs.zad_BlockGeneric) || renderedDevice.HasKeyword(ddLibs.zad_QuestItem)
    Float difficultyModifier = equipScript.CalculateDifficultyModifier(true)
    Float lockAccessChance = 100
    If (equipScript.LockAccessDifficulty > 0)
        Float moddedLockAccessDifficulty = equipScript.LockAccessDifficulty * (2 - difficultyModifier) ; difficulty modifier is (1 + bonus), revert to (1 - bonus) for access difficulty
        If (moddedLockAccessDifficulty > 95 && equipScript.LockAccessDifficulty < 100)
            Float maxAllowedDifficulty = 95
            If (equipScript.LockAccessDifficulty > maxAllowedDifficulty)
                maxAllowedDifficulty = equipScript.LockAccessDifficulty
            EndIf
            if (moddedLockAccessDifficulty > maxAllowedDifficulty)
                moddedLockAccessDifficulty = maxAllowedDifficulty ; ensure lock access difficulty stays below 100 if original author intended it to be possible
            EndIf
        EndIf
        lockAccessChance = Clamp(100 - moddedLockAccessDifficulty, 0, 100)
    EndIf
    Float unlockChance = 0
    If (!handsBlocked && !deviceIsQuestDevice && lockAccessChance > 0 && (equipScript.deviceKey == None || npc.GetItemCount(equipScript.deviceKey) >= equipScript.NumberOfKeysNeeded))
        unlockChance = lockAccessChance
    EndIf
    Float struggleChance = 0
    If (!deviceIsQuestDevice)
        struggleChance = Clamp(equipScript.BaseEscapeChance * difficultyModifier, 0, 100)
    EndIf

    ; try to escape, notifying the player if the option is set
    String possessive = ""
    If (notifyPlayer)
       If (npc.GetLeveledActorBase().GetSex() == 0)
           possessive = " his "
       Else
           possessive = " her "
       EndIf
    EndIf
    Bool success
    Float cooldown
    Bool chanceZeroPercent = unlockChance == 0 && struggleChance == 0
    String storageUtilTag = "ddnf_e_t" + DDNF_NpcTracker.GetOrCreateUniqueTag(device)
    Bool doNotStruggle = false
    If (chanceZeroPercent && !struggleIfKnownToBePointless)
        Float deviceMinGameTime = StorageUtil.GetFloatValue(npc, storageUtilTag, 0)
        doNotStruggle = deviceMinGameTime > 0 && (Utility.GetCurrentGameTime() - deviceMinGameTime) < 24 ; has npc recent experience with device
    EndIf
    String npcFormId = ""
    String npcFormIdAndName = ""
    String deviceFormIdAndName = ""
    If (npcTracker.EnablePapyrusLogging)
        npcFormId = DDNF_Game.FormIdAsString(npc)
        npcFormIdAndName = npcFormId + " " + npc.GetDisplayName()
        deviceFormIdAndName = DDNF_Game.FormIdAsString(device) + " " + device.GetName()
    EndIf
    If (doNotStruggle)
        If (npcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] " + npcFormIdAndName + " not struggling to escape " + deviceFormIdAndName + " (known to be pointless).")
        EndIf
        success = false
        cooldown = equipScript.EscapeCooldown
        If (cooldown < equipScript.UnlockCooldown)
            cooldown = equipScript.UnlockCooldown ; use the worse value if chance is zero percent
        EndIf
    Else
        If (npcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] " + npcFormIdAndName + " trying to escape " + deviceFormIdAndName + ": unlockChance=" + unlockChance + ", struggleChance=" + struggleChance + ".")
        EndIf
        Faction strugglingFaction = None
        If (addToStrugglingFactionIfNecessary)
            strugglingFaction = npcTracker.Struggling
        EndIf
        Bool useUnlockAction = unlockChance > 0 && unlockChance >= struggleChance
        Float successChance
        If (useUnlockAction)
            successChance = unlockChance
            If (unlockChance == 100 && !deviceIsHeavyBondage && !deviceIsBondageMittens)
                String struggleMessage = ""
                If (notifyPlayer)
                    If (equipScript.deviceKey == None)
                        struggleMessage = npc.GetDisplayName() + " is removing" + possessive + equipScript.deviceName
                    Else
                        struggleMessage = npc.GetDisplayName() + " is unlocking" + possessive + equipScript.deviceName
                    EndIf
                EndIf
                success = PlayStruggleAnimation(npcTracker, ddLibs, equipScript, npc, struggleMessage, strugglingFaction, true) ; only play short animation
            Else
                String struggleMessage = ""
                If (notifyPlayer)
                    If (equipScript.deviceKey == None)
                        struggleMessage = npc.GetDisplayName() + " is strugging to remove" + possessive + equipScript.deviceName
                    Else
                        struggleMessage = npc.GetDisplayName() + " is strugging to unlock" + possessive + equipScript.deviceName
                    EndIf
                EndIf
                success = PlayStruggleAnimation(npcTracker, ddLibs, equipScript, npc, struggleMessage, strugglingFaction, false)
            EndIf
            cooldown = equipScript.UnlockCooldown
        Else
            successChance = struggleChance
            String struggleMessage = ""
            If (notifyPlayer)
                struggleMessage = npc.GetDisplayName() + " is strugging to escape" + possessive + equipScript.deviceName
            EndIf
            success = PlayStruggleAnimation(npcTracker, ddLibs, equipScript, npc, struggleMessage, strugglingFaction, false)
            cooldown = equipScript.EscapeCooldown
            If (chanceZeroPercent && cooldown < equipScript.UnlockCooldown)
                cooldown = equipScript.UnlockCooldown ; use the worse value if chance is zero percent
            EndIf
        EndIf
        Float randomRollResult = -1 ; special value for "no roll was made"
        If (success && successChance < 100)
            If (successChance <= 0)
                success = false
            Else
                randomRollResult = Utility.RandomFloat(0, 99.9)
                success = randomRollResult < successChance
            EndIf
        EndIf
        If (success)
            Bool recheckConditions = CheckIfUnequipPossible(npc, device, renderedDevice, ddLibs, true, false)
            If (recheckConditions && useUnlockAction)
                recheckConditions = equipScript.deviceKey == None || npc.GetItemCount(equipScript.deviceKey) >= equipScript.NumberOfKeysNeeded
                If (recheckConditions)
                    recheckConditions = npc.GetItemCount(ddLibs.zad_DeviousBondageMittens) == 0 && npc.GetItemCount(ddLibs.zad_DeviousStraitJacket) == 0
                EndIf
            EndIf
            If (!recheckConditions)
                tempRef.Delete()
                Return new Bool[1] ; abort because of inventory change
            EndIf
            success = npcTracker.UnlockDevice(npc, equipScript.deviceInventory, equipScript.deviceRendered, equipScript.zad_DeviousDevice)
        EndIf
        If (success)
            If (notifyPlayer)
                If (useUnlockAction)
                    If (equipScript.deviceKey == None)
                        Debug.Notification(npc.GetDisplayName() + " removed" + possessive + equipScript.deviceName)
                    Else
                        Debug.Notification(npc.GetDisplayName() + " unlocked" + possessive + equipScript.deviceName)
                    EndIf
                Else
                    Debug.Notification(npc.GetDisplayName() + " escaped " + possessive + equipScript.deviceName)
                EndIf
            EndIf
            If (npcTracker.EnablePapyrusLogging)
                If (randomRollResult >= 0)
                    Debug.Trace("[DDNF] " + npcFormIdAndName + " escaped " + deviceFormIdAndName + " (" + randomRollResult + " < " + successChance +").")
                Else
                    Debug.Trace("[DDNF] " + npcFormIdAndName + " escaped " + deviceFormIdAndName + " (auto-success).")
                EndIf
            EndIf
        Else
            If (notifyPlayer && IsStruggling()) ; do not notify if interrupdted
                If (useUnlockAction)
                    If (equipScript.deviceKey == None)
                        Debug.Notification(npc.GetDisplayName() + " failed to remove " + possessive + equipScript.deviceName)
                    Else
                        Debug.Notification(npc.GetDisplayName() + " failed to reach the lock of" + possessive + equipScript.deviceName)
                    EndIf
                ElseIf (chanceZeroPercent)
                    Debug.Notification(npc.GetDisplayName() + " has no way to escape" + possessive + equipScript.deviceName)
                Else
                    Debug.Notification(npc.GetDisplayName() + " failed to escape" + possessive + equipScript.deviceName)
                EndIf
            EndIf
            If (npcTracker.EnablePapyrusLogging)
                If (randomRollResult >= 0)
                    Debug.Trace("[DDNF] " + npcFormIdAndName + " failed to escape " + deviceFormIdAndName + " (" + randomRollResult + " >= " + successChance +").")
                Else
                    Debug.Trace("[DDNF] " + npcFormIdAndName + " failed to escape " + deviceFormIdAndName + " (auto-failure).")
                EndIf
            EndIf
        EndIf
    EndIf

    ; store min game time of next attempt
    If (success)
        If (StorageUtil.HasFloatValue(npc, storageUtilTag))
            StorageUtil.UnsetFloatValue(npc, storageUtilTag)
            If (npcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] StorageUtil: UnsetFloatValue(" + npcFormId + ", " + storageUtilTag + ")")
            EndIf
        EndIf
    Else
        Float cooldownGameTime = Utility.GetCurrentGameTime() + cooldown / 24
        StorageUtil.SetFloatValue(npc, storageUtilTag, cooldownGameTime)
        If (npcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] StorageUtil: SetFloatValue(" + npcFormId + ", " + storageUtilTag + ", " + cooldownGameTime + ") [" + cooldown + "h]")
        EndIf
    EndIf

    ; done
    tempRef.Delete()
    Bool[] result = new Bool[3]
    result[0] = success
    result[1] = chanceZeroPercent && IsStruggling()
    result[2] = result[1] && doNotStruggle
    Return result
EndFunction 


Float Function Clamp(Float value, Float min, Float max) Global
    If (value < min)
        Return min
    ElseIf (value > max)
        Return max
    Else
        Return value
    EndIf
EndFunction

Bool Function PlayStruggleAnimation(DDNF_NpcTracker npcTracker, zadLibs ddLibs, zadEquipScript deviceInstance, Actor npc, String struggleMessage, Faction strugglingFaction, Bool shortAnimationOnly)
    Bool addedToFaction = false
    If (strugglingFaction != None && npc.GetFactionRank(strugglingFaction) < 1)
        npc.SetFactionRank(strugglingFaction, 1)
        addedToFaction = true
    EndIf
    npc.EvaluatePackage()
    String struggleAnimation = TryGetStruggleAnimation(ddLibs, deviceInstance, npc)
    Bool playAnimation = struggleAnimation != "" && IsStruggling() && npc.Is3DLoaded()
    Bool[] cameraState
    Int waitCount = 4
    While (addedToFaction && waitCount > 0 && playAnimation && ddLibs.IsAnimating(npc))
        Utility.Wait(1)
        playAnimation = playAnimation && IsStruggling() && npc.Is3DLoaded()
        waitCount -= 1
    EndWhile
    UnequipWeapons(npc, npcTracker.DummyWeapon)
    If (playAnimation)
        ddLibs.SetAnimating(npc, true)
        Debug.SendAnimationEvent(npc, struggleAnimation)
    EndIf
    If (struggleMessage)
        Debug.Notification(struggleMessage)
    EndIf
    If (shortAnimationOnly)
        waitCount = 4
    Else
        waitCount = 10
    EndIf
    While (waitCount > 0 && IsStruggling())
        Utility.Wait(1)
        waitCount -= 1
    EndWhile
    If (!shortAnimationOnly && IsStruggling() && npc.Is3DLoaded())
        ddLibs.Pant(npc)
    EndIf
    If (playAnimation)
        If (!shortAnimationOnly && deviceInstance.zad_DeviousDevice == ddLibs.zad_DeviousHeavyBondage)
            waitCount = 5 ; reduced from 10 for player
            While (waitCount > 0 && IsStruggling())
                Utility.Wait(1)
                waitCount -= 1
            EndWhile
            If (IsStruggling() && npc.Is3DLoaded())
                ddLibs.Pant(npc)
            EndIf
            If (Utility.RandomInt() < 50)
                waitCount = 5 ; reduced from 10 for player
                While (waitCount > 0 && IsStruggling())
                    Utility.Wait(1)
                    waitCount -= 1
                EndWhile
            EndIf
        EndIf
        ddLibs.SetAnimating(npc, false)
        Debug.SendAnimationEvent(npc, "IdleForceDefaultState")
    EndIf
    If (!shortAnimationOnly && npc.Is3DLoaded())
        ddLibs.SexlabMoan(npc)
    EndIf
    Return IsStruggling()
EndFunction

String Function TryGetStruggleAnimation(zadLibs ddLibs, zadEquipScript deviceInstance, Actor npc) Global
    String[] struggleArray = deviceInstance.SelectStruggleArray(npc)
    If (struggleArray.Length > 0)
        Return struggleArray[Utility.RandomInt(0, struggleArray.Length - 1)]
    EndIf
    ; try to select for device type in case struggle array is missing
    ; this was created by looking at: meshes/actors/character/animations/DD/FNIS_DD_List.txt
    If (deviceInstance.zad_DeviousDevice == ddLibs.zad_DeviousHeavyBondage)
        If (deviceInstance.deviceRendered.HasKeyword(ddLibs.zad_DeviousElbowTie)) ; special case, has no hobbled anims
            Int select = Utility.RandomInt(1, 3)
            If (select == 1)
                Return "DDElbowTie_struggleone"
            ElseIf (select == 2)
                Return "DDElbowTie_struggletwo"
            Else
                Return "DDElbowTie_strugglethree"
            EndIf
        EndIf
        If (npc.GetItemCount(ddLibs.zad_DeviousHobbleSkirt) > 0 && npc.GetItemCount(ddLibs.zad_DeviousHobbleSkirtRelaxed) == 0)
            If (deviceInstance.deviceRendered.HasKeyword(ddLibs.zad_DeviousArmbinderElbow))
                Return "DDHobElbStruggle0" + Utility.RandomInt(1, 2)
            ElseIf (deviceInstance.deviceRendered.HasKeyword(ddLibs.zad_DeviousCuffsFront))
                Return "DDHobCuffsFrontStruggle0" + Utility.RandomInt(1, 2)
            ElseIf (deviceInstance.deviceRendered.HasKeyword(ddLibs.zad_DeviousYoke))
                Return "DDHobYokeStruggle0" + Utility.RandomInt(1, 2)
            ElseIf (deviceInstance.deviceRendered.HasKeyword(ddLibs.zad_DeviousYokeBB))
                Return "DDHobBBYokeStruggle0" + Utility.RandomInt(1, 2)
            Else
                Return "DDHobArmbStruggle0" + Utility.RandomInt(1, 2) ; fall back to armbinder
            EndIf
        Else
            If (deviceInstance.deviceRendered.HasKeyword(ddLibs.zad_DeviousArmbinderElbow))
                Return "DDRegElbStruggle0" + Utility.RandomInt(1, 5)
            ElseIf (deviceInstance.deviceRendered.HasKeyword(ddLibs.zad_DeviousCuffsFront))
                Return "DDRegCuffsFrontStruggle0" + Utility.RandomInt(2, 3)
            ElseIf (deviceInstance.deviceRendered.HasKeyword(ddLibs.zad_DeviousYoke))
                Return "DDRegYokeStruggle0" + Utility.RandomInt(1, 5)
            ElseIf (deviceInstance.deviceRendered.HasKeyword(ddLibs.zad_DeviousYokeBB))
                Return "DDRegBBYokeStruggle0" + Utility.RandomInt(1, 5)
            Else
                Return "DDRegArmbStruggle0" + Utility.RandomInt(1, 5) ; fall back to armbinder
            EndIf
        EndIf
    ElseIf (deviceInstance.zad_DeviousDevice == ddLibs.zad_DeviousBlindfold)
        Return "ft_struggle_blindfold_1"
    ElseIf (deviceInstance.zad_DeviousDevice == ddLibs.zad_DeviousBelt || deviceInstance.zad_DeviousDevice == ddLibs.zad_DeviousPlug)
        Return "FT_DD_Chastity_Struggle_" + Utility.RandomInt(1, 2) ; not originally meant for zad_DeviousPlug
    ElseIf (deviceInstance.zad_DeviousDevice == ddLibs.zad_DeviousBoots)
        Return "ft_struggle_boots_1"
    ElseIf (deviceInstance.zad_DeviousDevice == ddLibs.zad_DeviousGag)
        Return "ft_struggle_gag_1"
    ElseIf (deviceInstance.zad_DeviousDevice == ddLibs.zad_DeviousGloves || deviceInstance.zad_DeviousDevice == ddLibs.zad_DeviousArmCuffs)
        Return "ft_struggle_gloves_1" ; not originally meant for zad_DeviousArmCuffs
    ElseIf (deviceInstance.zad_DeviousDevice == ddLibs.zad_DeviousHood)
        Return "ft_struggle_head_1"
    EndIf
    Return "" ; no animation available    
EndFunction


;
; Support functions for ExternalApi.psc
;

Bool Function IsBound()
    If (_renderedDevicesFlags < 0)
        DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
        Actor npc = GetReference() as Actor
        Return npc != None && npc.GetItemCount(npcTracker.DDLibs.zad_DeviousHeavyBondage) > 0
    EndIf
    Return _isBound
EndFunction

Bool Function IsGagged()
    If (_renderedDevicesFlags < 0)
        DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
        Actor npc = GetReference() as Actor
        Return npc != None && npc.GetItemCount(npcTracker.DDLibs.zad_DeviousGag) > 0
    EndIf
    Return _isGagged
EndFunction

Bool Function IsBlindfold()
    If (_renderedDevicesFlags < 0)
        DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
        Actor npc = GetReference() as Actor
        Return npc != None && npc.GetItemCount(npcTracker.DDLibs.zad_DeviousBlindfold) > 0
    EndIf
    Return _isBlindfold
EndFunction

Bool Function IsHelpless()
    If (_renderedDevicesFlags < 0)
        DDNF_NpcTracker npcTracker = GetOwningQuest() as DDNF_NpcTracker
        zadLibs ddLibs = npcTracker.DDLibs
        Actor npc = GetReference() as Actor
        Return npc != None && npc.GetItemCount(ddLibs.zad_DeviousHeavyBondage) > 0 && (!npcTracker.UseBoundCombat || npc.GetItemCount(ddLibs.zad_BoundCombatDisableKick) > 0)
    EndIf
    Return _isHelpless
EndFunction

Bool Function HasAnimation()
    If (_renderedDevicesFlags < 0)
        zadLibs ddLibs = (GetOwningQuest() as DDNF_NpcTracker).DDLibs
        Actor npc = GetReference() as Actor
        Return npc != None && (npc.GetItemCount(ddLibs.zad_DeviousHeavyBondage) > 0 || npc.GetItemCount(ddLibs.zad_DeviousPonyGear) > 0 || npc.GetItemCount(ddLibs.zad_DeviousHobbleSkirt) > 0 || npc.GetItemCount(ddLibs.zad_DeviousHobbleSkirtRelaxed) > 0)
    EndIf
    Return _hasAnimation
EndFunction

Bool Function UseUnarmedCombatAnimations()
    If (_renderedDevicesFlags < 0)
        zadLibs ddLibs = (GetOwningQuest() as DDNF_NpcTracker).DDLibs
        Actor npc = GetReference() as Actor
        Return npc != None && (npc.GetItemCount(ddLibs.zad_DeviousHeavyBondage) > 0 || npc.GetItemCount(ddLibs.zad_DeviousBondageMittens) > 0)
    EndIf
    Return _useUnarmedCombatPackage
EndFunction

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

Int Function ScanForInventoryDevices(zadLibs ddLibs, Actor npc, Armor[] outputArray, Bool equippedOnly, Keyword optionalKeywordForRenderedDevice) Global ; Global and slow
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
            If (renderedDevice != None && (!equippedOnly || npc.GetItemCount(renderedDevice) > 0) && (optionalKeywordForRenderedDevice == None || renderedDevice.HasKeyword(optionalKeywordForRenderedDevice)))
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
