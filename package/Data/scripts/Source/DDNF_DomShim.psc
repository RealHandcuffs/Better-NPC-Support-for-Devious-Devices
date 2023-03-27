;
; Soft-dependency script containing global functions dealing with Diary Of Mine.
;
Scriptname DDNF_DomShim

Bool Function IsDomSlave(Actor npc) Global
    Faction DOMPlayerSlaveFaction = Game.GetFormFromFile(0x56C505, "DiaryOfMine.esp") as Faction
    Return npc.IsInFaction(DOMPlayerSlaveFaction)
EndFunction

Bool Function IsTied(Actor slave) Global
    Faction DOMActionTied = Game.GetFormFromFile(0x58AB49, "DiaryOfMine.esp") as Faction
    Return slave.IsInFaction(DOMActionTied)
EndFunction

Bool Function StruggleAgainstRestraints(Actor slave) Global
    DOM_Core pCore = Game.GetFormFromFile(0x000D61, "DiaryOfMine.esp") as DOM_Core
    DOM_Actor pActor = pCore.GetActor(slave)
    If (pActor != None)
        If (!pActor.IsBreakingWait())
            Return false
        EndIf
        DOM_Mind mind = pActor.mind
        If (mind != None && mind.WillObeyBecauseWarned(7,0.5) > 0) ; "struggling"
            mind.TrainForBondage(0.5)
            mind.TrainPose(0.5)
            Return false
        EndIf
    EndIf
    Return true
EndFunction
