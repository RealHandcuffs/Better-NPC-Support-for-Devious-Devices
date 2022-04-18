;
; Soft-dependency script containing global functions dealing with Paradies Halls Enhanced.
;
Scriptname DDNF_PaheShim

Bool Function IsPaheSlave(Actor npc) Global
    Faction PAHPlayerSlaveFaction = Game.GetFormFromFile(0x0047DB, "paradise_halls.esm") as Faction
    Return npc.IsInFaction(PAHPlayerSlaveFaction)
EndFunction

Bool Function IsAfraid(Actor slave) Global
    Faction PAHMoodAfaid = Game.GetFormFromFile(0x0565AB, "paradise_halls.esm") as Faction
    Return slave.IsInFaction(PAHMoodAfaid)
EndFunction

Bool Function IsSubmissive(Actor slave) Global
    Faction PAHSubmission = Game.GetFormFromFile(0x0047EB, "paradise_halls.esm") as Faction
    Return slave.GetFactionRank(PAHSubmission) >= 60
EndFunction

Bool Function IsTied(Actor slave) Global
    Faction PAHBETied = Game.GetFormFromFile(0x01EBF6, "paradise_halls_SLExtension.esp") as Faction
    Return slave.IsInFaction(PAHBETied)
EndFunction

Function RestorePoseIfNecessary(Actor slave) Global
    PAHCore pCore = Game.GetFormFromFile(0x01FAEF, "paradise_halls.esm") as PAHCore
    PAHSlave pSlave = pCore.GetSlave(slave)
    If (pSlave != None && pSlave.GetState() == "tied")
        pSlave.PlayTieUpAnimation()
    EndIf
EndFunction

Function SetDummyTiedUpState(Actor slave) Global
    PAHCore pCore = Game.GetFormFromFile(0x01FAEF, "paradise_halls.esm") as PAHCore
    PAHSlave pSlave = pCore.GetSlave(slave)
    If (pSlave != None)
        pSlave.TieUp(pCore.CuffsIron, Enter = true)
        pSlave.ChangeTiePose("")
        ActorUtil.RemovePackageOverride(slave, pSlave.DoNothing)
        ActorUtil.RemovePackageOverride(slave, pSlave.PAHDoNothing)
    EndIf
EndFunction

Function RemoveDoNothingPackages(Actor slave) Global
    PAHCore pCore = Game.GetFormFromFile(0x01FAEF, "paradise_halls.esm") as PAHCore
    PAHSlave pSlave = pCore.GetSlave(slave)
    If (pSlave != None)
        ActorUtil.RemovePackageOverride(slave, pSlave.DoNothing)
        ActorUtil.RemovePackageOverride(slave, pSlave.PAHDoNothing)
        slave.EvaluatePackage()
    EndIf
EndFunction

Function ClearTiedUpState(Actor slave) Global
    PAHCore pCore = Game.GetFormFromFile(0x01FAEF, "paradise_halls.esm") as PAHCore
    PAHSlave pSlave = pCore.GetSlave(slave)
    If (pSlave != None)
        pSlave.TieUp(pCore.CuffsIron, Enter = false)
    EndIf
EndFunction
