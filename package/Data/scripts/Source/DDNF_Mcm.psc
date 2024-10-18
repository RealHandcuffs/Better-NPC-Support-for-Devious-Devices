;
; MCM control script
;
Scriptname DDNF_Mcm extends SKI_ConfigBase

DDNF_MainQuest Property MainQuest Auto

Int Property OptionScannerFrequency Auto
Int Property OptionMaxFixupsPerThreeSeconds Auto
Int Property OptionFixInconsistentDevices Auto
Int Property OptionRestoreOriginalOutfit Auto
Int Property OptionAllowManipulationOfDevices Auto

Int Property OptionEnableEscapeSystem Auto
Int Property OptionAbortStrugglingAfterFailedDevices Auto
Int Property OptionStruggleIfPointless Auto
Int Property OptionCurrentFollowerStruggleFrequency Auto
Int Property OptionNotifyPlayerOfCurrentFollowerStruggle Auto
Int Property OptionOtherNpcStruggleFrequency Auto
Int Property OptionAllowEscapeByPickingLocks Auto

Int Property OptionNpcProcessingEnabled Auto
Int Property OptionClearCachedDataOnMenuClose Auto

Int Property OptionIgnoreNpc Auto
Int Property OptionAlwaysTreatAsCurrentFollower Auto

Int Property OptionEnablePapyrusLogging Auto
Int Property OptionShowNpcInfo Auto
Int Property OptionCursorActor Auto
Int Property OptionPackage Auto
Int Property OptionTrackingId Auto
Int Property OptionNumberOfDevices Auto
Int Property OptionFixupOnMenuClose Auto
Int Property OptionEscapeOnMenuClose Auto

Bool Property ShowNpcInfo = false Auto

String[] _npc
String[] _package
Bool _hasTrackingId
String[] _deviceNames
String[] _npcStates

Bool _disableOnMenuClose
Bool _enableOnMenuClose
Actor _fixupOnMenuClose
Bool _clearCacheOnMenuClose
Actor _escapeOnMenuClose


Event OnPageReset(string page)
    SetCursorFillMode(TOP_TO_BOTTOM)

    Bool isDeviousDevicesNG = false
    DDNF_MainQuest_Player mqp = MainQuest.GetAlias(0) as DDNF_MainQuest_Player
    If (DDNF_Game.IsSpecialEdition())
        String runningOn = ""
        Quest zadNGQuest = Game.GetFormFromFile(0xA0000D, "Devious Devices - Expansion.esm") as Quest
        If (zadNGQuest != None && zadNGQuest.GetID() == "zadNGQuest")
            isDeviousDevicesNG = true
            runningOn = " on NG"
        EndIf
        Int npcTrackerFormId = DDNF_NpcTracker.Get().GetFormID()
        If (DDNF_Game.GetModId(npcTrackerFormId) < 1000000)
            SetTitleText("Better NPC Support for Devious Devices, v " + mqp.Version + " (SE)" + runningOn)
        Else
            SetTitleText("Better NPC Support for Devious Devices, v " + mqp.Version + " (SE, ESL)" + runningOn)
        EndIf
    Else
        SetTitleText("Better NPC Support for Devious Devices, v " + mqp.Version)
    EndIf

    Bool isRunning = MainQuest.NpcTracker.IsRunning()
    Int flags = OPTION_FLAG_NONE
    If (!isRunning)
        flags = OPTION_FLAG_DISABLED
    EndIf

    AddHeaderOption("NPC Processing")
    OptionScannerFrequency = AddSliderOption("Scan for NPCs every", MainQuest.SecondsBetweenScans, a_formatString = "{0} seconds", a_flags = flags)
    OptionMaxFixupsPerThreeSeconds = AddSliderOption("NPCs to process/3 seconds", MainQuest.NpcTracker.MaxFixupsPerThreeSeconds, a_flags = flags)
    OptionFixInconsistentDevices = AddToggleOption("Fix inconsistent devices of NPCs", MainQuest.NpcTracker.FixInconsistentDevicesOfNpcs, a_flags = flags)
    If (!isDeviousDevicesNG)
        OptionRestoreOriginalOutfit = AddToggleOption("Restore original outfits", MainQuest.NpcTracker.RestoreOriginalOutfit, a_flags = flags)
    EndIf

    AddHeaderOption("Container Menu Interactions")
    OptionAllowManipulationOfDevices = AddToggleOption("Allow manipulation of devices", MainQuest.NpcTracker.AllowManipulationOfDevices, a_flags = flags)

    AddHeaderOption("Maintenance")
    OptionNpcProcessingEnabled = AddToggleOption("Process NPCs (unchecking disables mod)", MainQuest.NpcTracker.IsRunning())
    OptionClearCachedDataOnMenuClose = AddToggleOption("Clear cached data on menu close", false)

    SetCursorPosition(1)

    AddHeaderOption("Escape System")
    OptionEnableEscapeSystem = AddToggleOption("Allow NPCs to struggle", MainQuest.NpcTracker.EscapeSystemEnabled, a_flags = flags)
    Int flagsEscapeSystem = flags
    If (!MainQuest.NpcTracker.EscapeSystemEnabled)
        flagsEscapeSystem = OPTION_FLAG_DISABLED
    EndIf
    OptionAbortStrugglingAfterFailedDevices = AddMenuOption("Abort struggling after", ToAbortStrugglingString(MainQuest.NpcTracker.AbortStrugglingAfterFailedDevices, true), a_flags = flagsEscapeSystem)
    OptionAllowEscapeByPickingLocks = AddMenuOption("Allow Escape by Lockpicking", ToEscapeByLockpickingString(MainQuest.NpcTracker.AllowEscapeByPickingLocks), a_flags = flagsEscapeSystem)
    OptionStruggleIfPointless = AddToggleOption("Struggle even if pointless", MainQuest.NpcTracker.StruggleIfPointless, a_flags = flagsEscapeSystem)
    OptionCurrentFollowerStruggleFrequency = AddMenuOption("Followers: Frequency", ToStruggleFrequencyString(MainQuest.NpcTracker.CurrentFollowerStruggleFrequency), a_flags = flagsEscapeSystem)
    OptionNotifyPlayerOfCurrentFollowerStruggle = AddMenuOption("Followers: Notifications", ToNotificationString(MainQuest.NpcTracker.NotifyPlayerOfCurrentFollowerStruggle, MainQuest.NpcTracker.OnlyDisplayFinalSummaryMessage), a_flags = flagsEscapeSystem)
    OptionOtherNpcStruggleFrequency = AddMenuOption("Other NPCs: Frequency", ToStruggleFrequencyString(MainQuest.NpcTracker.OtherNpcStruggleFrequency), a_flags = flagsEscapeSystem)

    Actor cursorActor = Game.GetCurrentCrosshairRef() as Actor
    If (cursorActor != None)
        AddHeaderOption("Custom Settings for: " + cursorActor.GetDisplayName())
        Bool ignoreNpc = MainQuest.NpcTracker.IgnoreNpc(cursorActor)
        OptionIgnoreNpc = AddToggleOption("Ignore NPC", ignoreNpc, a_flags = flags)
        Int flagsCustomSettings = flags
        If (ignoreNpc)
            flagsCustomSettings = OPTION_FLAG_DISABLED
        EndIf
        OptionAlwaysTreatAsCurrentFollower = AddToggleOption("Always Treat as Current Follower", MainQuest.NpcTracker.TreatAsCurrentFollower(cursorActor), a_flags = flagsCustomSettings)
    EndIf

    AddHeaderOption("Debug Settings")
    OptionEnablePapyrusLogging = AddToggleOption("Enable payprus logging", MainQuest.NpcTracker.EnablePapyrusLogging)
    If (cursorActor != None)
        ShowNpcInfo = false
        OptionShowNpcInfo = AddToggleOption("Analyze NPC under crosshair", false)
        OptionCursorActor = AddMenuOption("NPC under crosshair", DDNF_Game.FormIdAsString(cursorActor), a_flags = OPTION_FLAG_HIDDEN)
        _npc = new String[3]
        _npc[0] = "Name: " + cursorActor.GetDisplayName()
        String cursorActorModName = DDNF_Game.GetModName(DDNF_Game.GetModId(cursorActor.GetFormID()))
        If (cursorActorModName == "")
            cursorActorModName = "(generated reference)"
        EndIf
        _npc[1] = "Mod: " + cursorActorModName
        _npc[2] = "Is current follower: " + DDNF_NpcTracker_NPC.IsCurrentFollower(cursorActor, DDNF_NpcTracker.Get())
        Package cursorActorPackage = cursorActor.GetCurrentPackage()
        If (cursorActorPackage != None)
            OptionPackage = AddMenuOption("  Current package", DDNF_Game.FormIdAsString(cursorActorPackage), a_flags = OPTION_FLAG_HIDDEN)
            _package = new string[1]
            _package[0] = "Mod: " + DDNF_Game.GetModName(DDNF_Game.GetModId(cursorActorPackage.GetFormID()))
        EndIf
        DDNF_ExternalApi api = DDNF_ExternalApi.Get()
        Int trackingId = api.GetTrackingId(cursorActor)
        If (trackingId >= 0)
            _hasTrackingId = true
            OptionTrackingId = AddMenuOption("  Tracking status", "id = " + trackingId, a_flags = OPTION_FLAG_HIDDEN)
            String[] statesArray = new String[6]
            Int statesCount = 0
            If (api.IsBound(trackingId))
                statesArray[statesCount] = "bound"
                statesCount += 1
            EndIf
            If (api.IsGagged(trackingId))
                statesArray[statesCount] = "gagged"
                statesCount += 1
            EndIf
            If (api.IsBlindfold(trackingId))
                statesArray[statesCount] = "blindfold"
                statesCount += 1
            EndIf
            If (api.IsHelpless(trackingId))
                statesArray[statesCount] = "helpless"
                statesCount += 1
            EndIf
            If (api.HasAnimation(trackingId))
                statesArray[statesCount] = "has animation"
                statesCount += 1
            EndIf
            If (api.UseUnarmedCombatAnimations(trackingId))
                statesArray[statesCount] = "unarmed combat"
                statesCount += 1
            EndIf
            If (api.IsInBondageDevice(trackingId))
                statesArray[statesCount] = "bondage device"
                statesCount += 1
            EndIf
            _npcStates = Utility.CreateStringArray(statesCount)
            Int statesIndex = 0
            While (statesIndex < statesCount)
                _npcStates[statesIndex] = statesArray[statesIndex]
                statesIndex += 1
            EndWhile
            Armor[] devices = new Armor[32]
            Int deviceCount = api.GetEquippedDevices(trackingId, devices)
            If (deviceCount == 0)
                OptionNumberOfDevices = AddTextOption("  Devices ", "0", a_flags = OPTION_FLAG_HIDDEN)
            Else
                If (_deviceNames.Length != deviceCount)
                    _deviceNames = Utility.CreateStringArray(deviceCount)
                EndIf
                Int deviceIndex = 0
                While (deviceIndex < deviceCount)
                    _deviceNames[deviceIndex] = devices[deviceIndex].GetName()
                    deviceIndex += 1
                EndWhile
                OptionNumberOfDevices = AddMenuOption("  Devices ", "" + deviceCount, a_flags = OPTION_FLAG_HIDDEN)
            EndIf
        Else
            _hasTrackingId = false
            OptionTrackingId = AddTextOption("  Tracking ID", "(not tracked)", a_flags = OPTION_FLAG_HIDDEN)
        EndIf
        OptionFixupOnMenuClose = AddToggleOption("  Queue fixup on menu close", false, a_flags = OPTION_FLAG_HIDDEN)
        OptionEscapeOnMenuClose = AddToggleOption("  Queue escape attempt on menu close", false, a_flags = OPTION_FLAG_HIDDEN)
    EndIf
    
    _fixupOnMenuClose = None
    _clearCacheOnMenuClose = False
    _escapeOnMenuClose = None
EndEvent


Event OnOptionDefault(Int option)
    If (option == OptionNpcProcessingEnabled)
        If (!MainQuest.NpcTracker.IsRunning())
            RegisterForSingleUpdate(0.016)
            SetToggleOptionValue(OptionNpcProcessingEnabled, true)
            SetOptionFlags(OptionScannerFrequency, OPTION_FLAG_NONE, false)
            SetOptionFlags(OptionMaxFixupsPerThreeSeconds, OPTION_FLAG_NONE, false)
            SetOptionFlags(OptionFixInconsistentDevices, OPTION_FLAG_NONE, false)
            SetOptionFlags(OptionRestoreOriginalOutfit, OPTION_FLAG_NONE, false)
            SetOptionFlags(OptionAllowManipulationOfDevices, OPTION_FLAG_NONE, false)
            SetOptionFlags(OptionEnableEscapeSystem, OPTION_FLAG_NONE, false)
            Int flagsEscapeSystem = OPTION_FLAG_NONE
            If (!MainQuest.NpcTracker.EscapeSystemEnabled)
                flagsEscapeSystem = OPTION_FLAG_DISABLED
            EndIf
            SetOptionFlags(OptionAbortStrugglingAfterFailedDevices, OPTION_FLAG_NONE, false)
            SetOptionFlags(OptionStruggleIfPointless, OPTION_FLAG_NONE, false)
            SetOptionFlags(OptionCurrentFollowerStruggleFrequency, flagsEscapeSystem, false)
            SetOptionFlags(OptionNotifyPlayerOfCurrentFollowerStruggle, flagsEscapeSystem, false)
            SetOptionFlags(OptionOtherNpcStruggleFrequency, flagsEscapeSystem, false)
            SetOptionFlags(OptionAllowEscapeByPickingLocks, flagsEscapeSystem, false)
            Actor cursorActor = Game.GetCurrentCrosshairRef() as Actor
            If (cursorActor != None)
                SetOptionFlags(OptionIgnoreNpc, OPTION_FLAG_NONE, false)
                Int flagsCustomSettings = OPTION_FLAG_NONE
                If (MainQuest.NpcTracker.IgnoreNpc(cursorActor))
                    flagsCustomSettings = OPTION_FLAG_DISABLED
                EndIf
                SetOptionFlags(OptionAlwaysTreatAsCurrentFollower, flagsCustomSettings, false)
            EndIf
        EndIf
    ElseIf (option == OptionScannerFrequency)
        If (MainQuest.SecondsBetweenScans != 8)
            MainQuest.SecondsBetweenScans = 8
            SetSliderOptionValue(OptionScannerFrequency, 8, "{0} seconds")
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Set scanner frequency to 8 seconds.")
            EndIf
        EndIf
    ElseIf (option == OptionMaxFixupsPerThreeSeconds)
        If (MainQuest.NpcTracker.MaxFixupsPerThreeSeconds != 3)
            MainQuest.NpcTracker.MaxFixupsPerThreeSeconds = 3
            SetSliderOptionValue(OptionMaxFixupsPerThreeSeconds, 3)
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Set max fixups/3 seconds to 3.")
            EndIf
        EndIf
    ElseIf (option == OptionFixInconsistentDevices)
        If (MainQuest.NpcTracker.FixInconsistentDevicesOfNpcs)
            MainQuest.NpcTracker.FixInconsistentDevicesOfNpcs = false
            SetToggleOptionValue(OptionFixInconsistentDevices, false)
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Enabled fixing inconsistent devices.")
            EndIf
        EndIf
    ElseIf (option == OptionRestoreOriginalOutfit)
        If (MainQuest.NpcTracker.RestoreOriginalOutfit)
            MainQuest.NpcTracker.RestoreOriginalOutfit = false
            SetToggleOptionValue(OptionRestoreOriginalOutfit, false)
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Disabled restoring original outfits.")
            EndIf
        EndIf
    ElseIf (option == OptionAllowManipulationOfDevices)
        If (!MainQuest.NpcTracker.AllowManipulationOfDevices)
            MainQuest.NpcTracker.AllowManipulationOfDevices = true
            SetToggleOptionValue(OptionAllowManipulationOfDevices, true)
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Enabled manipulation of devices.")
            EndIf
        EndIf
    ElseIf (option == OptionEnableEscapeSystem)
        If (MainQuest.NpcTracker.EscapeSystemEnabled)
            MainQuest.NpcTracker.EscapeSystemEnabled = false
            SetToggleOptionValue(OptionEnableEscapeSystem, false)
            SetOptionFlags(OptionAbortStrugglingAfterFailedDevices, OPTION_FLAG_DISABLED, false)
            SetOptionFlags(OptionStruggleIfPointless, OPTION_FLAG_DISABLED, false)
            SetOptionFlags(OptionCurrentFollowerStruggleFrequency, OPTION_FLAG_DISABLED, false)
            SetOptionFlags(OptionNotifyPlayerOfCurrentFollowerStruggle, OPTION_FLAG_DISABLED, false)
            SetOptionFlags(OptionOtherNpcStruggleFrequency, OPTION_FLAG_DISABLED, false)
            SetOptionFlags(OptionAllowEscapeByPickingLocks, OPTION_FLAG_DISABLED, false)
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Disabled escape system.")
            EndIf
        EndIf
    ElseIf (option == OptionAbortStrugglingAfterFailedDevices)
        If (MainQuest.NpcTracker.AbortStrugglingAfterFailedDevices != 3)
            MainQuest.NpcTracker.AbortStrugglingAfterFailedDevices = 3
            SetMenuOptionValue(OptionStruggleIfPointless, ToAbortStrugglingString(3, true))
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Set abort struggling to 'abort after 3 failed devices'.")
            EndIf
        EndIf
    ElseIf (option == OptionStruggleIfPointless)
        If (MainQuest.NpcTracker.StruggleIfPointless)
            MainQuest.NpcTracker.StruggleIfPointless = false
            SetToggleOptionValue(OptionStruggleIfPointless, false)
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Disable struggling if pointless.")
            EndIf
        EndIf
    ElseIf (option == OptionCurrentFollowerStruggleFrequency)
        If (MainQuest.NpcTracker.CurrentFollowerStruggleFrequency != -1)
            MainQuest.NpcTracker.CurrentFollowerStruggleFrequency = -1
            SetMenuOptionValue(OptionCurrentFollowerStruggleFrequency, ToStruggleFrequencyString(-1))
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Set current follower struggle frequency to -1.")
            EndIf
        EndIf
    ElseIf (option == OptionNotifyPlayerOfCurrentFollowerStruggle)
        If (!MainQuest.NpcTracker.NotifyPlayerOfCurrentFollowerStruggle || MainQuest.NpcTracker.OnlyDisplayFinalSummaryMessage)
            MainQuest.NpcTracker.NotifyPlayerOfCurrentFollowerStruggle = true
            MainQuest.NpcTracker.OnlyDisplayFinalSummaryMessage = true
            String notificationString = ToNotificationString(true, false)
            SetMenuOptionValue(OptionNotifyPlayerOfCurrentFollowerStruggle, notificationString)
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Set notifications for current follower struggling to " + notificationString + ".")
            EndIf
        EndIf
    ElseIf (option == OptionOtherNpcStruggleFrequency)
        If (MainQuest.NpcTracker.OtherNpcStruggleFrequency != 0)
            MainQuest.NpcTracker.OtherNpcStruggleFrequency = 0
            SetMenuOptionValue(OptionOtherNpcStruggleFrequency, ToStruggleFrequencyString(0))
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Set other npc struggle frequency to 0.")
            EndIf
        EndIf
    ElseIf (option == OptionAllowEscapeByPickingLocks)
        If (MainQuest.NpcTracker.AllowEscapeByPickingLocks != 1)
            MainQuest.NpcTracker.AllowEscapeByPickingLocks = 1
            SetMenuOptionValue(OptionAllowEscapeByPickingLocks, ToEscapeByLockpickingString(1))
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Set allow escape by lockpicking to 1.")
            EndIf
        EndIf
    ElseIf (option == OptionIgnoreNpc)
        Actor cursorActor = Game.GetCurrentCrosshairRef() as Actor
        If (cursorActor != None && MainQuest.NpcTracker.IgnoreNpc(cursorActor))
            MainQuest.NpcTracker.UpdateIgnoreNpc(cursorActor, false)
            SetToggleOptionValue(OptionIgnoreNpc, false)
            SetOptionFlags(OptionAlwaysTreatAsCurrentFollower, OPTION_FLAG_NONE, false)
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Disable ignoring " + DDNF_Game.FormIdAsString(cursorActor) + " " + cursorActor.GetDisplayName() + ".")
            EndIf
        EndIf
    ElseIf (option == OptionAlwaysTreatAsCurrentFollower)
        Actor cursorActor = Game.GetCurrentCrosshairRef() as Actor
        If (cursorActor != None && MainQuest.NpcTracker.TreatAsCurrentFollower(cursorActor))
            MainQuest.NpcTracker.UpdateTreatAsCurrentFollower(cursorActor, false)
            SetToggleOptionValue(OptionAlwaysTreatAsCurrentFollower, false)
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Disable always treating " + DDNF_Game.FormIdAsString(cursorActor) + " " + cursorActor.GetDisplayName() + " as current follower.")
            EndIf
        EndIf
    ElseIf (option == OptionEnablePapyrusLogging)
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            MainQuest.NpcTracker.EnablePapyrusLogging = false
            SetToggleOptionValue(OptionEnablePapyrusLogging, false)
            Debug.Trace("[DDNF] MCM: Disabled Papyrus logging.")
        EndIf
    ElseIf (option == OptionShowNpcInfo)
        If (ShowNpcInfo)
            ShowNpcInfo = false
            SetToggleOptionValue(OptionShowNpcInfo, false)
            SetOptionFlags(OptionCursorActor, OPTION_FLAG_HIDDEN)
            SetOptionFlags(OptionPackage, OPTION_FLAG_HIDDEN)
            SetOptionFlags(OptionTrackingId, OPTION_FLAG_HIDDEN)
            If (_hasTrackingId)
                SetOptionFlags(OptionNumberOfDevices, OPTION_FLAG_HIDDEN)
            EndIf
            SetOptionFlags(OptionFixupOnMenuClose, OPTION_FLAG_HIDDEN)
            SetOptionFlags(OptionEscapeOnMenuClose, OPTION_FLAG_HIDDEN)
        EndIf
    EndIf
EndEvent


Event OnOptionSelect(Int option)
    If (option == OptionNpcProcessingEnabled)
        Int flags = OPTION_FLAG_NONE
        If (_enableOnMenuClose)
            flags = OPTION_FLAG_DISABLED
            _enableOnMenuClose = false
        ElseIf (_disableOnMenuClose)
            _disableOnMenuClose = false
        ElseIf (MainQuest.NpcTracker.IsRunning())
            flags = OPTION_FLAG_DISABLED
            _disableOnMenuClose = true
       Else
            _enableOnMenuClose = true
        EndIf
        RegisterForSingleUpdate(0.016)
        SetToggleOptionValue(OptionNpcProcessingEnabled, flags == OPTION_FLAG_NONE)
        SetOptionFlags(OptionScannerFrequency, flags, true)
        SetOptionFlags(OptionMaxFixupsPerThreeSeconds, flags, false)
        SetOptionFlags(OptionFixInconsistentDevices, flags, false)
        SetOptionFlags(OptionRestoreOriginalOutfit, flags, false)
        SetOptionFlags(OptionAllowManipulationOfDevices, flags, false)
        SetOptionFlags(OptionEnableEscapeSystem, flags, false)
        Int flagsEscapeSystem = flags
        If (!MainQuest.NpcTracker.EscapeSystemEnabled)
            flagsEscapeSystem = OPTION_FLAG_DISABLED
        EndIf
        SetOptionFlags(OptionAbortStrugglingAfterFailedDevices, flagsEscapeSystem, false)
        SetOptionFlags(OptionStruggleIfPointless, flagsEscapeSystem, false)
        SetOptionFlags(OptionCurrentFollowerStruggleFrequency, flagsEscapeSystem, false)
        SetOptionFlags(OptionNotifyPlayerOfCurrentFollowerStruggle, flagsEscapeSystem, false)
        SetOptionFlags(OptionOtherNpcStruggleFrequency, flagsEscapeSystem, false)
        SetOptionFlags(OptionAllowEscapeByPickingLocks, flagsEscapeSystem, false)
    ElseIf (option == OptionFixInconsistentDevices)
        MainQuest.NpcTracker.FixInconsistentDevicesOfNpcs = !MainQuest.NpcTracker.FixInconsistentDevicesOfNpcs
        SetToggleOptionValue(OptionFixInconsistentDevices, MainQuest.NpcTracker.FixInconsistentDevicesOfNpcs)
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            If (MainQuest.NpcTracker.FixInconsistentDevicesOfNpcs)
                Debug.Trace("[DDNF] MCM: Enabled fixing inconsistent devices of npcs.")
            Else
                Debug.Trace("[DDNF] MCM: Disabled fixing inconsistent devices of npcs.")
            EndIf
        EndIf
    ElseIf (option == OptionRestoreOriginalOutfit)
        MainQuest.NpcTracker.RestoreOriginalOutfit = !MainQuest.NpcTracker.RestoreOriginalOutfit
        SetToggleOptionValue(OptionRestoreOriginalOutfit, MainQuest.NpcTracker.RestoreOriginalOutfit)
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            If (MainQuest.NpcTracker.RestoreOriginalOutfit)
                Debug.Trace("[DDNF] MCM: Enabled restoring original outfits.")
            Else
                Debug.Trace("[DDNF] MCM: Disabled restoring original outfits.")
            EndIf
        EndIf
    ElseIf (option == OptionAllowManipulationOfDevices)
        MainQuest.NpcTracker.AllowManipulationOfDevices = !MainQuest.NpcTracker.AllowManipulationOfDevices
        SetToggleOptionValue(OptionAllowManipulationOfDevices, MainQuest.NpcTracker.AllowManipulationOfDevices)
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            If (MainQuest.NpcTracker.AllowManipulationOfDevices)
                Debug.Trace("[DDNF] MCM: Enabled manipulation of devices.")
            Else
                Debug.Trace("[DDNF] MCM: Disabled manipulation of devices.")
            EndIf
        EndIf
    ElseIf (option == OptionEnableEscapeSystem)
        MainQuest.NpcTracker.EscapeSystemEnabled = !MainQuest.NpcTracker.EscapeSystemEnabled
        SetToggleOptionValue(OptionEnableEscapeSystem, MainQuest.NpcTracker.EscapeSystemEnabled)
        Int flagsEscapeSystem = OPTION_FLAG_NONE
        If (!MainQuest.NpcTracker.EscapeSystemEnabled)
            flagsEscapeSystem = OPTION_FLAG_DISABLED
        EndIf
        SetOptionFlags(OptionAbortStrugglingAfterFailedDevices, flagsEscapeSystem, false)
        SetOptionFlags(OptionStruggleIfPointless, flagsEscapeSystem, false)
        SetOptionFlags(OptionCurrentFollowerStruggleFrequency, flagsEscapeSystem, false)
        SetOptionFlags(OptionNotifyPlayerOfCurrentFollowerStruggle, flagsEscapeSystem, false)
        SetOptionFlags(OptionOtherNpcStruggleFrequency, flagsEscapeSystem, false)
        SetOptionFlags(OptionAllowEscapeByPickingLocks, flagsEscapeSystem, false)
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            If (MainQuest.NpcTracker.EscapeSystemEnabled)
                Debug.Trace("[DDNF] MCM: Enabled escape system.")
            Else
                Debug.Trace("[DDNF] MCM: Disabled escape system.")
            EndIf
        EndIf
    ElseIf (option == OptionStruggleIfPointless)
        MainQuest.NpcTracker.StruggleIfPointless = !MainQuest.NpcTracker.StruggleIfPointless
        SetToggleOptionValue(OptionStruggleIfPointless, MainQuest.NpcTracker.StruggleIfPointless)
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            If (MainQuest.NpcTracker.StruggleIfPointless)
                Debug.Trace("[DDNF] MCM: Enabled struggling if pointless.")
            Else
                Debug.Trace("[DDNF] MCM: Disabled struggling if pointless.")
            EndIf
        EndIf
    ElseIf (option == OptionIgnoreNpc)
        Actor cursorActor = Game.GetCurrentCrosshairRef() as Actor
        If (cursorActor != None && MainQuest.NpcTracker.IgnoreNpc(cursorActor))
            MainQuest.NpcTracker.UpdateIgnoreNpc(cursorActor, false)
            SetToggleOptionValue(OptionIgnoreNpc, false)
            SetOptionFlags(OptionAlwaysTreatAsCurrentFollower, OPTION_FLAG_NONE, false)
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Disabledignoring " + DDNF_Game.FormIdAsString(cursorActor) + " " + cursorActor.GetDisplayName() + ".")
            EndIf
        ElseIf (cursorActor != None)
            MainQuest.NpcTracker.UpdateIgnoreNpc(cursorActor, true)
            SetToggleOptionValue(OptionIgnoreNpc, true)
            SetOptionFlags(OptionAlwaysTreatAsCurrentFollower, OPTION_FLAG_DISABLED, false)
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Enable ignoring " + DDNF_Game.FormIdAsString(cursorActor) + " " + cursorActor.GetDisplayName() + ".")
            EndIf
        EndIf
    ElseIf (option == OptionAlwaysTreatAsCurrentFollower)
        Actor cursorActor = Game.GetCurrentCrosshairRef() as Actor
        If (cursorActor != None && MainQuest.NpcTracker.TreatAsCurrentFollower(cursorActor))
            MainQuest.NpcTracker.UpdateTreatAsCurrentFollower(cursorActor, false)
            SetToggleOptionValue(OptionAlwaysTreatAsCurrentFollower, false)
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Disable always treating " + DDNF_Game.FormIdAsString(cursorActor) + " " + cursorActor.GetDisplayName() + " as current follower.")
            EndIf
        ElseIf (cursorActor != None)
            MainQuest.NpcTracker.UpdateTreatAsCurrentFollower(cursorActor, true)
            SetToggleOptionValue(OptionAlwaysTreatAsCurrentFollower, true)
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Enable always treating " + DDNF_Game.FormIdAsString(cursorActor) + " " + cursorActor.GetDisplayName() + " as current follower.")
            EndIf
        EndIf
    ElseIf (option == OptionEnablePapyrusLogging)
        MainQuest.NpcTracker.EnablePapyrusLogging = !MainQuest.NpcTracker.EnablePapyrusLogging
        SetToggleOptionValue(OptionEnablePapyrusLogging, MainQuest.NpcTracker.EnablePapyrusLogging)
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] MCM: Enabled Papyrus logging.")
        Else
            Debug.Trace("[DDNF] MCM: Disabled Papyrus logging.")
        EndIf
    ElseIf (option == OptionShowNpcInfo)
        ShowNpcInfo = !ShowNpcInfo
        SetToggleOptionValue(OptionShowNpcInfo, ShowNpcInfo)
        Int flags = OPTION_FLAG_NONE
        If (!ShowNpcInfo)
            flags = OPTION_FLAG_HIDDEN
        EndIf
        SetOptionFlags(OptionCursorActor, flags)
        SetOptionFlags(OptionPackage, flags)
        SetOptionFlags(OptionTrackingId, flags)
        If (_hasTrackingId)
            SetOptionFlags(OptionNumberOfDevices, flags)
        EndIf
        SetOptionFlags(OptionFixupOnMenuClose, flags)
        SetOptionFlags(OptionEscapeOnMenuClose, flags)
    ElseIf (option == OptionClearCachedDataOnMenuClose)
        _clearCacheOnMenuClose = !_clearCacheOnMenuClose
        SetToggleOptionValue(OptionClearCachedDataOnMenuClose, _clearCacheOnMenuClose)
        If (_clearCacheOnMenuClose)
            RegisterForSingleUpdate(0.016)
        EndIf
    ElseIf (option == OptionFixupOnMenuClose)
        Actor cursorActor = Game.GetCurrentCrosshairRef() as Actor
        If (cursorActor == None || _fixupOnMenuClose != None)
            SetToggleOptionValue(OptionFixupOnMenuClose, false)
            _fixupOnMenuClose = None
        Else
            SetToggleOptionValue(OptionFixupOnMenuClose, true)
            _fixupOnMenuClose = cursorActor
            RegisterForSingleUpdate(0.016)
        EndIf
    ElseIf (option == OptionEscapeOnMenuClose)
        Actor cursorActor = Game.GetCurrentCrosshairRef() as Actor
        If (cursorActor == None || _escapeOnMenuClose != None)
            SetToggleOptionValue(OptionEscapeOnMenuClose, false)
            _escapeOnMenuClose = None
        Else
            SetToggleOptionValue(OptionEscapeOnMenuClose, true)
            _escapeOnMenuClose = cursorActor
            RegisterForSingleUpdate(0.016)
        EndIf
    EndIf
EndEvent


Event OnOptionSliderOpen(Int option)
    If (option == OptionScannerFrequency)
        SetSliderDialogRange(1, 20)
        SetSliderDialogStartValue(MainQuest.SecondsBetweenScans)
        SetSliderDialogDefaultValue(8)
        SetSliderDialogInterval(1)
    ElseIf (option == OptionMaxFixupsPerThreeSeconds)
        SetSliderDialogRange(1, 10)
        SetSliderDialogStartValue(MainQuest.NpcTracker.MaxFixupsPerThreeSeconds)
        SetSliderDialogDefaultValue(3)
        SetSliderDialogInterval(1)
    EndIf
EndEvent


Event OnOptionSliderAccept(Int option, Float value)
    If (option == OptionScannerFrequency)
        MainQuest.SecondsBetweenScans = value
        SetSliderOptionValue(OptionScannerFrequency, value, "{0} seconds")
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] MCM: Set scanner frequency to " + MainQuest.SecondsBetweenScans + ".")
        EndIf
    ElseIf (option == OptionMaxFixupsPerThreeSeconds)
        MainQuest.NpcTracker.MaxFixupsPerThreeSeconds = value
        SetSliderOptionValue(OptionMaxFixupsPerThreeSeconds, value)
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] MCM: Set max fixups/3 seconds to " + MainQuest.NpcTracker.MaxFixupsPerThreeSeconds + ".")
        EndIf
    EndIf
EndEvent


Event OnOptionMenuOpen(Int option)
    If (option == OptionAbortStrugglingAfterFailedDevices)
        SetMenuDialogOptions(GetAbortStrugglingMenuOptions(6))
        SetMenuDialogDefaultIndex(MainQuest.NpcTracker.AbortStrugglingAfterFailedDevices)
    ElseIf (option == OptionCurrentFollowerStruggleFrequency)
        SetMenuDialogOptions(GetStruggleFrequencyMenuOptions(8))
        SetMenuDialogDefaultIndex(MainQuest.NpcTracker.CurrentFollowerStruggleFrequency + 1)
    ElseIf (option == OptionNotifyPlayerOfCurrentFollowerStruggle)
        String[] notificationOptions = new String[3]
        notificationOptions[0] = "No notifications."
        notificationOptions[1] = "Final summary only."
        notificationOptions[2] = "Detailed notifications."
        SetMenuDialogOptions(notificationOptions)
        If (!MainQuest.NpcTracker.NotifyPlayerOfCurrentFollowerStruggle)
            SetMenuDialogDefaultIndex(0)
        ElseIf (MainQuest.NpcTracker.OnlyDisplayFinalSummaryMessage)
            SetMenuDialogDefaultIndex(1)
        Else
            SetMenuDialogDefaultIndex(2)
        EndIf
    ElseIf (option == OptionOtherNpcStruggleFrequency)
        SetMenuDialogOptions(GetStruggleFrequencyMenuOptions(8))
        SetMenuDialogDefaultIndex(MainQuest.NpcTracker.OtherNpcStruggleFrequency + 1)
    ElseIf (option == OptionAllowEscapeByPickingLocks)
        String[] escapeByLockpickingOptions = new String[3]
        escapeByLockpickingOptions[0] = "No"
        escapeByLockpickingOptions[1] = "Current Followers Only"
        escapeByLockpickingOptions[2] = "Yes"
        SetMenuDialogOptions(escapeByLockpickingOptions)
        SetMenuDialogDefaultIndex(MainQuest.NpcTracker.AllowEscapeByPickingLocks)
    ElseIf (option == OptionCursorActor)
        SetMenuDialogOptions(_npc)
    ElseIf (option == OptionPackage)
        SetMenuDialogOptions(_package)
    ElseIf (option == OptionTrackingId)
        SetMenuDialogOptions(_npcStates)
    ElseIf (option == OptionNumberOfDevices)
        SetMenuDialogOptions(_deviceNames)
    EndIf
EndEvent


Event OnOptionMenuAccept(Int option, Int index)
    If (option == OptionAbortStrugglingAfterFailedDevices)
        If (index >= 0 && MainQuest.NpcTracker.AbortStrugglingAfterFailedDevices != index)
            MainQuest.NpcTracker.AbortStrugglingAfterFailedDevices = index
            SetMenuOptionValue(OptionAbortStrugglingAfterFailedDevices, ToAbortStrugglingString(index, true))
            If (index == 0)
                Debug.Trace("[DDNF] MCM: Set abort struggling to 'struggle against all devices'.")
            Else
                Debug.Trace("[DDNF] MCM: Set abort struggling to 'abort after " + index + " failed devices'.")
            EndIf
        EndIf
    ElseIf (option == OptionCurrentFollowerStruggleFrequency)
        If (index >= 0 && MainQuest.NpcTracker.CurrentFollowerStruggleFrequency != (index - 1))
            MainQuest.NpcTracker.CurrentFollowerStruggleFrequency = index - 1
            SetMenuOptionValue(OptionCurrentFollowerStruggleFrequency, ToStruggleFrequencyString(index - 1))
            Debug.Trace("[DDNF] MCM: Set current follower struggle frequency to " + MainQuest.NpcTracker.CurrentFollowerStruggleFrequency + ".")
        EndIf
    ElseIf (option == OptionNotifyPlayerOfCurrentFollowerStruggle)
        Bool notifyPlayer = index > 0
        Bool onlySummary = index == 1
        If (index >= 0 && notifyPlayer != MainQuest.NpcTracker.NotifyPlayerOfCurrentFollowerStruggle || onlySummary != MainQuest.NpcTracker.OnlyDisplayFinalSummaryMessage)
            MainQuest.NpcTracker.NotifyPlayerOfCurrentFollowerStruggle = notifyPlayer
            MainQuest.NpcTracker.OnlyDisplayFinalSummaryMessage = onlySummary
            String notificationString = ToNotificationString(notifyPlayer, onlySummary)
            SetMenuOptionValue(OptionNotifyPlayerOfCurrentFollowerStruggle, notificationString)
            Debug.Trace("[DDNF] MCM: Set notifications for current follower struggling to " + notificationString + ".")
        EndIf
    ElseIf (option == OptionOtherNpcStruggleFrequency)
        If (index >= 0 && MainQuest.NpcTracker.OtherNpcStruggleFrequency != (index - 1))
            MainQuest.NpcTracker.OtherNpcStruggleFrequency = index - 1
            SetMenuOptionValue(OptionOtherNpcStruggleFrequency, ToStruggleFrequencyString(index - 1))
            Debug.Trace("[DDNF] MCM: Set other npc struggle frequency to " + MainQuest.NpcTracker.OtherNpcStruggleFrequency + ".")
        EndIf
    ElseIf (option == OptionAllowEscapeByPickingLocks)
        If (index >= 0 && MainQuest.NpcTracker.AllowEscapeByPickingLocks != index)
            MainQuest.NpcTracker.AllowEscapeByPickingLocks = index
            SetMenuOptionValue(OptionAllowEscapeByPickingLocks, ToEscapeByLockpickingString(index))
            Debug.Trace("[DDNF] MCM: Set allow escape by lockpicking to " + index + ".")
        EndIf
    EndIf
EndEvent


Event OnUpdate()
    If (_disableOnMenuClose)
        _disableOnMenuClose = false
        If (_enableOnMenuClose)
            _enableOnMenuClose = false
        Else
            MainQuest.NpcTracker.IsEnabled = false
            MainQuest.NpcTracker.Clear(true)
            MainQuest.NpcTracker.Stop()
            Debug.Notification("[BNSfDD] Stopped processing of NPCs.")
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Disabled NPC processing.")
            EndIf
        EndIf
    EndIf
    If (_enableOnMenuClose)
        _enableOnMenuClose = false
        MainQuest.NpcTracker.Reset()
        MainQuest.NpcTracker.Start()
        MainQuest.NpcTracker.IsEnabled = true
        MainQuest.RegisterForSingleUpdate(1.0) ; queue scan "soon"
        Debug.Notification("[BNSfDD] Started processing of NPCs.")
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] MCM: Enabled NPC processing.")
        EndIf
    EndIf
    If (_fixupOnMenuClose != None)
        Actor fixupActor = _fixupOnMenuClose
        _fixupOnMenuClose = None
        If (_clearCacheOnMenuClose || _escapeOnMenuClose != None)
            RegisterForSingleUpdate(0.016)
        EndIf
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] MCM: Fixup-on-close for " + DDNF_Game.FormIdAsString(fixupActor) + " " + fixupActor.GetDisplayName() + ".")
        EndIf
        MainQuest.NpcTracker.QueueForFixup(fixupActor, true)
        Return
    EndIf
    If (_clearCacheOnMenuClose)
        _clearCacheOnMenuClose = false
        If (_escapeOnMenuClose != None)
            RegisterForSingleUpdate(0.016)
        EndIf
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] MCM: Clear-cache-on-close.")
        EndIf
        MainQuest.NpcTracker.Clear(true)
        Return
    EndIf
    If (_escapeOnMenuClose != None)
        Actor escapeActor = _escapeOnMenuClose
        _escapeOnMenuClose = None
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] MCM: Escape-on-close for " + DDNF_Game.FormIdAsString(escapeActor) + " " + escapeActor.GetDisplayName() + ".")
        EndIf
        DDNF_ExternalApi api = DDNF_ExternalApi.Get()
        Int trackingId = api.GetOrCreateTrackingId(escapeActor)
        If (trackingId >= 0)
            api.PerformEscapeAttempt(trackingId, respectCooldowns = false)
        EndIf
        Return
    EndIf
EndEvent


String Function ToAbortStrugglingString(Int value, Bool shortString) Global
    If (value == 0)
        If (shortString)
            Return "(all devices)"
        EndIf
        Return "(always try to escape all devices)"
    EndIf
    If (shortString)
        Return value + " failures"
    EndIf
    Return "" + value + " failed devices"
EndFunction

String[] Function GetAbortStrugglingMenuOptions(Int maxValue) Global
    String[] options = Utility.CreateStringArray(maxValue + 1)
    Int index = 0
    While (index <= maxValue)
        options[index] = ToAbortStrugglingString(index, false)
        index += 1
    EndWhile
    Return options
EndFunction


String Function ToStruggleFrequencyString(Int value) Global
    If (value < 0)
        Return "(by device)"
    EndIf
    If (value == 0)
        Return "(never)"
    EndIf
    Return value + " game hours"
EndFunction

String[] Function GetStruggleFrequencyMenuOptions(Int maxHours) Global
    String[] options = Utility.CreateStringArray(maxHours + 2)
    Int index = -1
    While (index <= maxHours)
        options[index + 1] = ToStruggleFrequencyString(index)
        index += 1
    EndWhile
    Return options
EndFunction


String Function ToNotificationString(Bool notifyPlayer, Bool summaryOnly) Global
    If (notifyPlayer)
        If (summaryOnly)
            Return "summary only"
        EndIf
        Return "detailed"
    EndIf
    Return "(none)"
EndFunction


String Function ToEscapeByLockpickingString(Int value) Global
    If (value <= 0)
        Return "No"
    ElseIf (value == 1)
        Return "Followers"
    Else
        Return "Yes"
    EndIf
EndFunction