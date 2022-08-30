;
; Soft-dependency script containing global functions dealing with Paradies Halls Enhanced.
;
Scriptname DDNF_PaheShim

Bool Function IsPaheSlave(Actor npc) Global
    Faction PAHPlayerSlaveFaction = Game.GetFormFromFile(0x0047DB, "paradise_halls.esm") as Faction
    Return npc.IsInFaction(PAHPlayerSlaveFaction)
EndFunction

Bool Function IsTied(Actor slave) Global
    Faction PAHBETied = Game.GetFormFromFile(0x01EBF6, "paradise_halls_SLExtension.esp") as Faction
    Return slave.IsInFaction(PAHBETied)
EndFunction

Function RestorePoseIfNecessary(Actor slave) Global
    PAHCore pCore = Game.GetFormFromFile(0x01FAEF, "paradise_halls.esm") as PAHCore
    PAHSlave pSlave = pCore.GetSlaveAlias(slave) as PAHSlave
    If (pSlave != None && pSlave.GetState() == "tied")
        pSlave.PlayTieUpAnimation()
    EndIf
EndFunction

Function SetRestrainedInFurniture(Actor slave, ObjectReference theFurniture, Bool domInstalled) Global
    PAHCore pCore = Game.GetFormFromFile(0x01FAEF, "paradise_halls.esm") as PAHCore
    PAHSlave pSlave = pCore.GetSlaveAlias(slave) as PAHSlave
    If (pSlave != None)
        If (domInstalled)
            pSlave.SetRestrainedInFurniture(theFurniture, "", "")
        Else
            pSlave.TieUp(pCore.CuffsIron, Enter = true) ; use "tied" state for PAHE without DOM
            pSlave.ChangeTiePose("")
        EndIf
        ActorUtil.RemovePackageOverride(slave, pSlave.DoNothing)
        ActorUtil.RemovePackageOverride(slave, pSlave.PAHDoNothing)
    EndIf
EndFunction

Function RemoveDoNothingPackages(Actor slave) Global
    PAHCore pCore = Game.GetFormFromFile(0x01FAEF, "paradise_halls.esm") as PAHCore
    PAHSlave pSlave = pCore.GetSlaveAlias(slave) as PAHSlave
    If (pSlave != None)
        ActorUtil.RemovePackageOverride(slave, pSlave.DoNothing)
        ActorUtil.RemovePackageOverride(slave, pSlave.PAHDoNothing)
        slave.EvaluatePackage()
    EndIf
EndFunction

Function ClearRestrainedInFurniture(Actor slave) Global
    PAHCore pCore = Game.GetFormFromFile(0x01FAEF, "paradise_halls.esm") as PAHCore
    PAHSlave pSlave = pCore.GetSlaveAlias(slave) as PAHSlave
    If (pSlave != None)
        pSlave.TieUp(pCore.CuffsIron, Enter = false)
    EndIf
EndFunction

Bool Function StartMovingByFormula(Actor slave) Global
    PAHCore pCore = Game.GetFormFromFile(0x01FAEF, "paradise_halls.esm") as PAHCore
    PAHSlaveMind pMind = pCore.GetSlaveAlias(slave) as PAHSlaveMind
    Return pMind == None || pMind.StartMovingByFormula()
EndFunction
