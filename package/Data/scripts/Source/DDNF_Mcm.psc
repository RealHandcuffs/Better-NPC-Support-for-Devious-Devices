;
; MCM control script
;
Scriptname DDNF_Mcm extends SKI_ConfigBase

DDNF_MainQuest Property MainQuest Auto

Int Property OptionNpcProcessingEnabled Auto
Int Property OptionScannerFrequency Auto
Int Property OptionMaxFixupsPerThreeSeconds Auto
Int Property OptionRestoreOriginalOutfit Auto

Int Property OptionClearCachedDataOnMenuClose Auto

Int Property OptionEnablePapyrusLogging Auto
Int Property OptionNumberOfDevices Auto
Int Property OptionFixupOnMenuClose Auto

String[] _deviceNames


Event OnPageReset(string page)
    SetCursorFillMode(TOP_TO_BOTTOM)

    DDNF_MainQuest_Player mqp = MainQuest.GetAlias(0) as DDNF_MainQuest_Player
    SetTitleText("Better NPC Support for Devious Devices, v " + mqp.Version)

    AddHeaderOption("NPC Processing")
    Bool isRunning = MainQuest.NpcTracker.IsRunning()
    OptionNpcProcessingEnabled = AddToggleOption("Process NPCs (unchecking disables mod)", MainQuest.NpcTracker.IsRunning())
    Int flags = OPTION_FLAG_NONE
    If (!isRunning)
        flags = OPTION_FLAG_DISABLED
    EndIf
    OptionScannerFrequency = AddSliderOption("Scan for NPCs every", MainQuest.SecondsBetweenScans, a_formatString = "{0} seconds", a_flags = flags)
    OptionMaxFixupsPerThreeSeconds = AddSliderOption("NPCs to process/3 seconds", MainQuest.NpcTracker.MaxFixupsPerThreeSeconds, a_flags = flags)
    OptionRestoreOriginalOutfit = AddToggleOption("Restore original outfits", MainQuest.NpcTracker.RestoreOriginalOutfit, a_flags = flags)

    AddHeaderOption("Maintenance")
    OptionClearCachedDataOnMenuClose = AddToggleOption("Clear cached data on menu close", false, a_flags = flags)

    AddHeaderOption("Debug Settings")
    OptionEnablePapyrusLogging = AddToggleOption("Enable payprus logging", MainQuest.NpcTracker.EnablePapyrusLogging)
    Actor cursorActor = Game.GetCurrentCrosshairRef() as Actor
    If (cursorActor != None)
        AddTextOption("NPC under crosshair", DDNF_NpcTracker_NPC.GetFormIdAsString(cursorActor))
        Package cursorActorPackage = cursorActor.GetCurrentPackage()
        If (cursorActorPackage != None)
            AddTextOption("  Current package", DDNF_NpcTracker_NPC.GetFormIdAsString(cursorActorPackage))
        EndIf
        DDNF_ExternalApi api = DDNF_ExternalApi.Get()
        Int trackingId = api.GetTrackingId(cursorActor)
        If (trackingId >= 0)
            AddTextOption("  Tracking ID", "" + trackingId)
        Else
            AddTextOption("  Tracking ID", "(not tracked)")
        EndIf
        Armor[] devices = new Armor[32]
        Int deviceCount = api.GetEquippedDevicesOfAnyNpc(cursorActor, devices)
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
        OptionFixupOnMenuClose = AddToggleOption("  Queue fixup on menu close", false, a_flags = flags)
    EndIf
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
    ElseIf (option == OptionEnablePapyrusLogging)
        MainQuest.NpcTracker.EnablePapyrusLogging = !MainQuest.NpcTracker.EnablePapyrusLogging
        SetToggleOptionValue(OptionEnablePapyrusLogging, MainQuest.NpcTracker.EnablePapyrusLogging)
        If (MainQuest.NpcTracker.EnablePapyrusLogging)
            Debug.Trace("[DDNF] MCM: Enabled Papyrus logging.")
        Else
            Debug.Trace("[DDNF] MCM: Disabled Papyrus logging.")
        EndIf
    ElseIf (option == OptionClearCachedDataOnMenuClose)
        SetToggleOptionValue(OptionClearCachedDataOnMenuClose, true)
        RegisterForSingleUpdate(0.1)
    ElseIf (option == OptionFixupOnMenuClose)
        Actor cursorActor = Game.GetCurrentCrosshairRef() as Actor
        If (cursorActor == None)
            SetToggleOptionValue(OptionFixupOnMenuClose, false)
        Else
            If (MainQuest.NpcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] MCM: Requested fixup of " + DDNF_NpcTracker_NPC.GetFormIdAsString(cursorActor) + " " + cursorActor.GetDisplayName() + ".")
            EndIf
            SetToggleOptionValue(OptionFixupOnMenuClose, true)
            MainQuest.NpcTracker.QueueForFixup(cursorActor)
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
    If (option == OptionNumberOfDevices)
        SetMenuDialogOptions(_deviceNames)
    EndIf
EndEvent


Event OnUpdate()
    MainQuest.NpcTracker.Clear(true)
EndEvent
