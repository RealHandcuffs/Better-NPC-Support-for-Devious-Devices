;
; Soft-dependency script containing global functions dealing with DLC1.
;
Scriptname DDNF_DLC1Shim

Bool Function IsSerana(Int maybeSeranaFormId) Global ; maybeSeranaFormId must be formId of actor defined in Dawnguard.esm
     Return DDNF_Game.GetModInternalFormId(maybeSeranaFormId) == 0x002B74
EndFunction

Function FixupSeranaAfterUpdatingWeight() Global
    Form cureSelfQuest = Game.GetFormFromFile(0x005044, "Dawnguard.esm") ; DLC1SeranaCureSelfQuest 
    DLC1SeranaCureQuestScript cq = cureSelfQuest as DLC1SeranaCureQuestScript
    If (cq.IsRunning())
        cq.SetEyes()
    EndIf
EndFunction

Function KickSeranaFromSandboxPackage(Actor serana) Global
    Form mentalModel = Game.GetFormFromFile(0x002B6E, "Dawnguard.esm") ; DLC1NPCMentalModel
    DLC1_NPCMentalModelScript mm = mentalModel as DLC1_NPCMentalModelScript
    If (mm.PlayerSettled)
        ; set PlayerSettled to false to kick her out of sandboxing
        mm.PlayerSettled = false
        serana.EvaluatePackage()
        Form monitoringPlayer = Game.GetFormFromFile(0x003BC0, "Dawnguard.esm") ; DLC1NPCMonitoringPlayer
        ; temporarily pause the player monitor script for 16 seconds to prevent her from trying to sandbox again in a second
        DLC1NPCMonitoringPlayerScript mp = monitoringPlayer as DLC1NPCMonitoringPlayerScript
        mp.RegisterForSingleUpdate(16)
    EndIf
EndFunction

Bool Function IsSeranaCurrentlyFollowing(Actor serana) Global
    Form mentalModel = Game.GetFormFromFile(0x002B6E, "Dawnguard.esm") ; DLC1NPCMentalModel
    DLC1_NPCMentalModelScript mm = mentalModel as DLC1_NPCMentalModelScript
    Return mm.IsFollowing
EndFunction

Function AddMassiveRaces(FormList list) Global
    list.AddForm(Game.GetFormFromFile(0x015c34, "Dawnguard.esm")) ; DLC1LD_ForgemasterRace
EndFunction
