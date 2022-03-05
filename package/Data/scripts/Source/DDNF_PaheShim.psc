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
