;
; Soft-dependency script containing global functions dealing with Devious Contraptions.
;
Scriptname DDNF_ZadcShim

ObjectReference Function TryGetCurrentContraption(Actor npc) Global
    zadclibs libs = Game.GetFormFromFile(0x0022FD, "Devious Devices - Contraptions.esm") as zadclibs
    ObjectReference maybeContraption = libs.GetDevice(npc)
    If (maybeContraption != None && libs.GetUser(maybeContraption) == npc)
        Return maybeContraption
    EndIf
    Return None
EndFunction
