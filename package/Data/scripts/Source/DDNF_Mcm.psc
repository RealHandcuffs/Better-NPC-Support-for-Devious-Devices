;
; MCM control script
;
Scriptname DDNF_Mcm extends SKI_ConfigBase

DDNF_MainQuest Property MainQuest Auto

Int Property OptionNpcProcessingEnabled Auto
Int Property OptionScannerFrequency Auto
Int Property OptionMaxFixupsPerThreeSeconds Auto


Event OnPageReset(string page)
    SetCursorFillMode(TOP_TO_BOTTOM)

    DDNF_MainQuest_Player mqp = MainQuest.GetAlias(0) as DDNF_MainQuest_Player
    SetTitleText("Better NPC Support for Devious Devices, v " + mqp.Version)

    AddHeaderOption("NPC Processing")
    Bool isRunning = MainQuest.NpcTracker.IsRunning()
    OptionNpcProcessingEnabled = AddToggleOption("NPCs are being processed", MainQuest.NpcTracker.IsRunning())
    Int flags = OPTION_FLAG_NONE
    If (!isRunning)
        flags = OPTION_FLAG_DISABLED
    EndIf
    OptionScannerFrequency = AddSliderOption("Scan for NPCs every", MainQuest.SecondsBetweenScans, a_formatString = "{0} seconds", a_flags = flags)
    OptionMaxFixupsPerThreeSeconds = AddSliderOption("NPCs to process/3 seconds", MainQuest.NpcTracker.MaxFixupsPerThreeSeconds, a_flags = flags)
EndEvent


Event OnOptionDefault(Int option)
    If (option == OptionNpcProcessingEnabled)
        If (!MainQuest.NpcTracker.IsRunning())
            MainQuest.NpcTracker.Reset()
            MainQuest.NpcTracker.Start()
            SetToggleOptionValue(OptionNpcProcessingEnabled, true)
            SetOptionFlags(OptionScannerFrequency, OPTION_FLAG_NONE, true)
            SetOptionFlags(OptionMaxFixupsPerThreeSeconds, OPTION_FLAG_NONE, false)
        EndIf
    ElseIf (option == OptionScannerFrequency)
        MainQuest.SecondsBetweenScans = 8
        SetSliderOptionValue(OptionScannerFrequency, 8, "{0} seconds")
    ElseIf (option == OptionMaxFixupsPerThreeSeconds)
        MainQuest.NpcTracker.MaxFixupsPerThreeSeconds = 3
        SetSliderOptionValue(OptionMaxFixupsPerThreeSeconds, 3)
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
    ElseIf (option == OptionMaxFixupsPerThreeSeconds)
        MainQuest.NpcTracker.MaxFixupsPerThreeSeconds = value
        SetSliderOptionValue(OptionMaxFixupsPerThreeSeconds, value)
    EndIf
EndEvent
