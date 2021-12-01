;
; MCM control script
;
Scriptname DDNF_Mcm extends SKI_ConfigBase

DDNF_MainQuest Property MainQuest Auto

Int Property OptionScannerFrequency Auto
Int Property OptionMaxFixupsPerThreeSeconds Auto
Int Property OptionRestoreOriginalOutfit Auto
Int Property OptionAllowManipulationOfDevices Auto

Int Property OptionEnableEscapeSystem Auto
Int Property OptionCurrentFollowerStruggleFrequency Auto
Int Property OptionNotifyPlayerOfCurrentFollowerStruggle Auto
Int Property OptionOtherNpcStruggleFrequency Auto

Int Property OptionNpcProcessingEnabled Auto
Int Property OptionClearCachedDataOnMenuClose Auto

Int Property OptionEnablePapyrusLogging Auto
Int Property OptionCursorActor Auto
Int Property OptionPackage Auto
Int Property OptionTrackingId Auto
Int Property OptionNumberOfDevices Auto
Int Property OptionFixupOnMenuClose Auto
Int Property OptionEscapeOnMenuClose Auto

String[] _npc
String[] _package
String[] _deviceNames
String[] _npcStates

Actor _fixupOnMenuClose
Bool _clearCacheOnMenuClose
Actor _escapeOnMenuClose


Event OnPageReset(string page)
    SetCursorFillMode(TOP_TO_BOTTOM)

    DDNF_MainQuest_Player mqp = MainQuest.GetAlias(0) as DDNF_MainQuest_Player
    SetTitleText("Better NPC Support for Devious Devices, v " + mqp.Version)

    Bool isRunning = MainQuest.NpcTracker.IsRunning()
    Int flags = OPTION_FLAG_NONE
    If (!isRunning)
        flags = OPTION_FLAG_DISABLED
    EndIf
    AddHeaderOption("NPC Processing", a_flags = flags)
    OptionScannerFrequency = AddSliderOption("Scan for NPCs every", MainQuest.SecondsBetweenScans, a_formatString = "{0} seconds", a_flags = flags)
    OptionMaxFixupsPerThreeSeconds = AddSliderOption("NPCs to process/3 seconds", MainQuest.NpcTracker.MaxFixupsPerThreeSeconds, a_flags = flags)
    OptionRestoreOriginalOutfit = AddToggleOption("Restore original outfits", MainQuest.NpcTracker.RestoreOriginalOutfit, a_flags = flags)
    OptionAllowManipulationOfDevices = AddToggleOption("Allow manipulation of devices", MainQuest.NpcTracker.AllowManipulationOfDevices, a_flags = flags)
    
    AddHeaderOption("Escape System", a_flags = flags)
    Bool isEscapeSystemEnabed = MainQuest.NpcTracker.EscapeSystemEnabled
    OptionEnableEscapeSystem = AddToggleOption("Allow NPCs to struggle", MainQuest.NpcTracker.EscapeSystemEnabled, a_flags = flags)
    Int flagsEscapeSystem = flags
    If (!isEscapeSystemEnabed)
        flagsEscapeSystem = OPTION_FLAG_DISABLED
    EndIf
    OptionCurrentFollowerStruggleFrequency = AddMenuOption("Followers: Frequency", ToStruggleFrequencyString(MainQuest.NpcTracker.CurrentFollowerStruggleFrequency), a_flags = flagsEscapeSystem)
    OptionNotifyPlayerOfCurrentFollowerStruggle = AddMenuOption("Followers: Notifications", ToNotificationString(MainQuest.NpcTracker.NotifyPlayerOfCurrentFollowerStruggle, MainQuest.NpcTracker.OnlyDisplayFinalSummaryMessage), a_flags = flagsEscapeSystem)
    OptionOtherNpcStruggleFrequency = AddMenuOption("Other NPCs: Frequency", ToStruggleFrequencyString(MainQuest.NpcTracker.OtherNpcStruggleFrequency), a_flags = flagsEscapeSystem)

    SetCursorPosition(1)

    AddHeaderOption("Maintenance")
    OptionNpcProcessingEnabled = AddToggleOption("Process NPCs (unchecking disables mod)", MainQuest.NpcTracker.IsRunning())
    OptionClearCachedDataOnMenuClose = AddToggleOption("Clear cached data on menu close", false)

    AddHeaderOption("Debug Settings")
    OptionEnablePapyrusLogging = AddToggleOption("Enable payprus logging", MainQuest.NpcTracker.EnablePapyrusLogging)
    Actor cursorActor = Game.GetCurrentCrosshairRef() as Actor
    If (cursorActor != None)
        OptionCursorActor = AddMenuOption("NPC under crosshair", DDNF_Game.FormIdAsString(cursorActor))
        _npc = new String[3]
        _npc[0] = "Name: " + cursorActor.GetDisplayName()
        String cursorActorModName = DDNF_Game.GetModName(cursorActor)
        If (cursorActorModName == "")
            cursorActorModName = "(generated reference)"
        EndIf
        _npc[1] = "Mod: " + cursorActorModName
        _npc[2] = "Is current follower: " + DDNF_NpcTracker_NPC.IsCurrentFollower(cursorActor, DDNF_NpcTracker.Get())
        Package cursorActorPackage = cursorActor.GetCurrentPackage()
        If (cursorActorPackage != None)
            OptionPackage = AddMenuOption("  Current package", DDNF_Game.FormIdAsString(cursorActorPackage))
            _package = new string[1]
            _package[0] = "Mod: " + DDNF_Game.GetModName(cursorActorPackage)
        EndIf
        DDNF_ExternalApi api = DDNF_ExternalApi.Get()
        Int trackingId = api.GetTrackingId(cursorActor)
        If (trackingId >= 0)
            OptionTrackingId = AddMenuOption("  Tracking status", "id = " + trackingId)
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
            _npcStates = Utility.CreateStringArray(statesCount)
            Int statesIndex = 0
            While (statesIndex < statesCount)
                _npcStates[statesIndex] = statesArray[statesIndex]
                statesIndex += 1
            EndWhile
            Armor[] devices = new Armor[32]
            Int deviceCount = api.GetEquippedDevices(trackingId, devices)
            If (deviceCount == 0)
                OptionNumberOfDevices = AddTextOption("  Devices ", "0")
            Else
                If (_deviceNames.Length != deviceCount)
                    _deviceNames = Utility.CreateStringArray(deviceCount)
                EndIf
                Int deviceIndex = 0
                While (deviceIndex < deviceCount)
                    _deviceNames[deviceIndex] = devices[deviceIndex].GetName()
                    deviceIndex += 1
                EndWhile
                OptionNumberOfDevices = AddMenuOption("  Devices ", "" + deviceCount)
            EndIf
        Else
            OptionTrackingId = AddTextOption("  Tracking ID", "(not tracked)")
        EndIf
        OptionFixupOnMenuClose = AddToggleOption("  Queue fixup on menu close", false)
        OptionEscapeOnMenuClose = AddToggleOption("  Queue escape attempt on menu close", false)
    EndIf
    
    _fixupOnMenuClose = None
    _clearCacheOnMenuClose = False
    _escapeOnMenuClose = None
EndEvent


Event OnOptionDefault(Int option)
    If (option == OptionNpcProcessingEnabled)
        If (!MainQuest.NpcTracker.IsRunning())
            MainQuest.NpcTracker.Reset()
            MainQuest.NpcTracker.Start()
            SetToggleOptionValue(OptionNpcProcessingEnabled, true)
            SetOptionFlags(OptionScannerFrequency, OPTION_FLAG_NONE, true)
            SetOptionFlags(OptionMaxFixupsPerThreeSeconds, OPTION_FLAG_NONE, false)
            SetOptionFlags(OptionRestoreOriginalOutfit, OPTION_FLAG_NONE, false)
            SetOptionFlags(OptionAllowManipulationOfDevices, OPTION_FLAG_NONE, false)
            SetOptionFlags(OptionEnableEscapeSystem, OPTION_FLAG_NONE, false)
            Int flagsEscapeSystem = OPTION_FLAG_NONE
            If (!MainQuest.NpcTracker.EscapeSystemEnabled)
                flagsEscapeSystem = OPTION_FLAG_DISABLED
            EndIf
            SetOptionFlags(OptionCurrentFollowerStruggleFrequency, flagsEscapeSystem, false)
            SetOptionFlags(OptionNotifyPlayerOfCurrentFollowerStruggle, flagsEscapeSystem, false)
            SetOptionFlags(OptionOtherNpcStruggleFrequency, flagsEscapeSystem, false)
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Enabled NPC processing.")
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
    ElseIf (option == OptionRestoreOriginalOutfit)
        If (MainQuest.NpcTracker.RestoreOriginalOutfit)
            MainQuest.NpcTracker.RestoreOriginalOutfit = false
            SetToggleOptionValue(OptionRestoreOriginalOutfit, false)
            Debug.Trace("[DDNF] MCM: Disabled restoring original outfits.")
        EndIf
    ElseIf (option == OptionAllowManipulationOfDevices)
        If (!MainQuest.NpcTracker.AllowManipulationOfDevices)
            MainQuest.NpcTracker.AllowManipulationOfDevices = true
            SetToggleOptionValue(OptionAllowManipulationOfDevices, true)
            Debug.Trace("[DDNF] MCM: Enabled manipulation of devices.")
        EndIf
    ElseIf (option == OptionEnableEscapeSystem)
        If (MainQuest.NpcTracker.EscapeSystemEnabled)
            MainQuest.NpcTracker.EscapeSystemEnabled = false
            SetToggleOptionValue(OptionEnableEscapeSystem, false)
            SetOptionFlags(OptionCurrentFollowerStruggleFrequency, OPTION_FLAG_DISABLED, false)
            SetOptionFlags(OptionNotifyPlayerOfCurrentFollowerStruggle, OPTION_FLAG_DISABLED, false)
            SetOptionFlags(OptionOtherNpcStruggleFrequency, OPTION_FLAG_DISABLED, false)
            Debug.Trace("[DDNF] MCM: Disabled escape system.")
        EndIf
    ElseIf (option == OptionCurrentFollowerStruggleFrequency)
        If (MainQuest.NpcTracker.CurrentFollowerStruggleFrequency != 2)
            MainQuest.NpcTracker.CurrentFollowerStruggleFrequency = 2
            SetMenuOptionValue(OptionCurrentFollowerStruggleFrequency, ToStruggleFrequencyString(2))
            Debug.Trace("[DDNF] MCM: Set current follower struggle frequency to 2.")
        EndIf
    ElseIf (option == OptionNotifyPlayerOfCurrentFollowerStruggle)
        If (!MainQuest.NpcTracker.NotifyPlayerOfCurrentFollowerStruggle || MainQuest.NpcTracker.OnlyDisplayFinalSummaryMessage)
            MainQuest.NpcTracker.NotifyPlayerOfCurrentFollowerStruggle = true
            MainQuest.NpcTracker.OnlyDisplayFinalSummaryMessage = true
            String notificationString = ToNotificationString(true, false)
            SetMenuOptionValue(OptionNotifyPlayerOfCurrentFollowerStruggle, notificationString)
            Debug.Trace("[DDNF] MCM: Set notifications for current follower struggling to " + notificationString + ".")
        EndIf
    ElseIf (option == OptionOtherNpcStruggleFrequency)
        If (MainQuest.NpcTracker.OtherNpcStruggleFrequency != 0)
            MainQuest.NpcTracker.OtherNpcStruggleFrequency = 0
            SetMenuOptionValue(OptionOtherNpcStruggleFrequency, ToStruggleFrequencyString(0))
            Debug.Trace("[DDNF] MCM: Set other npc struggle frequency to 0.")
        EndIf
    ElseIf (option == OptionEnablePapyrusLogging)
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            MainQuest.NpcTracker.EnablePapyrusLogging = false
            SetToggleOptionValue(OptionEnablePapyrusLogging, false)
            Debug.Trace("[DDNF] MCM: Disabled Papyrus logging.")
        EndIf
    EndIf
EndEvent


Event OnOptionSelect(Int option)
    If (option == OptionNpcProcessingEnabled)
        Bool isRunning = MainQuest.NpcTracker.IsRunning()
        Int flags = OPTION_FLAG_NONE
        If (isRunning)
            MainQuest.NpcTracker.Stop()
            flags = OPTION_FLAG_DISABLED
        Else
            MainQuest.NpcTracker.Reset()
            MainQuest.NpcTracker.Start()
        EndIf
        SetToggleOptionValue(OptionNpcProcessingEnabled, !isRunning)
        SetOptionFlags(OptionScannerFrequency, flags, true)
        SetOptionFlags(OptionMaxFixupsPerThreeSeconds, flags, false)
        SetOptionFlags(OptionRestoreOriginalOutfit, flags, false)
        SetOptionFlags(OptionAllowManipulationOfDevices, flags, false)
        SetOptionFlags(OptionEnableEscapeSystem, flags, false)
        Int flagsEscapeSystem = flags
        If (!MainQuest.NpcTracker.EscapeSystemEnabled)
            flagsEscapeSystem = OPTION_FLAG_DISABLED
        EndIf
        SetOptionFlags(OptionCurrentFollowerStruggleFrequency, flagsEscapeSystem, false)
        SetOptionFlags(OptionNotifyPlayerOfCurrentFollowerStruggle, flagsEscapeSystem, false)
        SetOptionFlags(OptionOtherNpcStruggleFrequency, flagsEscapeSystem, false)
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            If (isRunning)
                Debug.Trace("[DDNF] MCM: Disabled NPC processing.")
            Else
                Debug.Trace("[DDNF] MCM: Enabled NPC processing.")
            EndIf
        EndIf
    ElseIf (option == OptionRestoreOriginalOutfit)
        MainQuest.NpcTracker.RestoreOriginalOutfit = !MainQuest.NpcTracker.RestoreOriginalOutfit
        SetToggleOptionValue(OptionRestoreOriginalOutfit, MainQuest.NpcTracker.RestoreOriginalOutfit)
        If (MainQuest.NpcTracker.RestoreOriginalOutfit)
            Debug.Trace("[DDNF] MCM: Enabled restoring original outfits.")
        Else
            Debug.Trace("[DDNF] MCM: Disabled restoring original outfits.")
        EndIf
    ElseIf (option == OptionAllowManipulationOfDevices)
        MainQuest.NpcTracker.AllowManipulationOfDevices = !MainQuest.NpcTracker.AllowManipulationOfDevices
        SetToggleOptionValue(OptionAllowManipulationOfDevices, MainQuest.NpcTracker.AllowManipulationOfDevices)
        If (MainQuest.NpcTracker.AllowManipulationOfDevices)
            Debug.Trace("[DDNF] MCM: Enabled manipulation of devices.")
        Else
            Debug.Trace("[DDNF] MCM: Disabled manipulation of devices.")
        EndIf
    ElseIf (option == OptionEnableEscapeSystem)
        MainQuest.NpcTracker.EscapeSystemEnabled = !MainQuest.NpcTracker.EscapeSystemEnabled
        SetToggleOptionValue(OptionEnableEscapeSystem, MainQuest.NpcTracker.EscapeSystemEnabled)
        Int flagsEscapeSystem = OPTION_FLAG_NONE
        If (!MainQuest.NpcTracker.EscapeSystemEnabled)
            flagsEscapeSystem = OPTION_FLAG_DISABLED
        EndIf
        SetOptionFlags(OptionCurrentFollowerStruggleFrequency, flagsEscapeSystem, false)
        SetOptionFlags(OptionNotifyPlayerOfCurrentFollowerStruggle, flagsEscapeSystem, false)
        SetOptionFlags(OptionOtherNpcStruggleFrequency, flagsEscapeSystem, false)
        If (MainQuest.NpcTracker.EscapeSystemEnabled)
            Debug.Trace("[DDNF] MCM: Enabled escape system.")
        Else
            Debug.Trace("[DDNF] MCM: Disabled escape system.")
        EndIf
    ElseIf (option == OptionEnablePapyrusLogging)
        MainQuest.NpcTracker.EnablePapyrusLogging = !MainQuest.NpcTracker.EnablePapyrusLogging
        SetToggleOptionValue(OptionEnablePapyrusLogging, MainQuest.NpcTracker.EnablePapyrusLogging)
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] MCM: Enabled Papyrus logging.")
        Else
            Debug.Trace("[DDNF] MCM: Disabled Papyrus logging.")
        EndIf
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
    If (option == OptionCurrentFollowerStruggleFrequency)
        SetMenuDialogOptions(GetStruggleFrequencyMenuOptions(6))
        SetMenuDialogDefaultIndex(3)
    ElseIf (option == OptionNotifyPlayerOfCurrentFollowerStruggle)
        String[] notificationOptions = new String[3]
        notificationOptions[0] = "No notifications."
        notificationOptions[1] = "Final summary only."
        notificationOptions[2] = "Detailed notifications."
        SetMenuDialogDefaultIndex(1)
        SetMenuDialogOptions(notificationOptions)
    ElseIf (option == OptionOtherNpcStruggleFrequency)
        SetMenuDialogOptions(GetStruggleFrequencyMenuOptions(6))
        SetMenuDialogDefaultIndex(0)
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
    If (option == OptionCurrentFollowerStruggleFrequency)
        If (index >= 0 && MainQuest.NpcTracker.CurrentFollowerStruggleFrequency != index)
            MainQuest.NpcTracker.CurrentFollowerStruggleFrequency = index
            SetMenuOptionValue(OptionCurrentFollowerStruggleFrequency, ToStruggleFrequencyString(index))
            Debug.Trace("[DDNF] MCM: Set current follower struggle frequency to " + index + ".")
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
        If (index >= 0 && MainQuest.NpcTracker.OtherNpcStruggleFrequency != index)
            MainQuest.NpcTracker.OtherNpcStruggleFrequency = index
            SetMenuOptionValue(OptionOtherNpcStruggleFrequency, ToStruggleFrequencyString(index))
            Debug.Trace("[DDNF] MCM: Set other npc struggle frequency to " + index + ".")
        EndIf
    EndIf
EndEvent


Event OnUpdate()
    If (_fixupOnMenuClose != None)
        Actor fixupActor = _fixupOnMenuClose
        _fixupOnMenuClose = None
        If (_clearCacheOnMenuClose || _escapeOnMenuClose != None)
            RegisterForSingleUpdate(0.016)
        EndIf
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] MCM: Fixup-on-close for " + DDNF_Game.FormIdAsString(fixupActor) + " " + fixupActor.GetDisplayName() + ".")
        EndIf
        MainQuest.NpcTracker.QueueForFixup(fixupActor)
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
            api.PerformEscapeAttempt(trackingId)
        EndIf
        Return
    EndIf
EndEvent


String Function ToStruggleFrequencyString(Int value) Global
    If (value == 0)
        Return "(never)"
    EndIf
    Return value + " game hours"
EndFunction


String[] Function GetStruggleFrequencyMenuOptions(Int maxHours) Global
    String[] options = Utility.CreateStringArray(maxHours + 1)
    Int index = 0
    While (index <= maxHours)
        options[index] = ToStruggleFrequencyString(index)
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
