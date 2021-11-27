;
; Soft-dependency script containing global functions dealing with Devious Contraptions.
;
Scriptname DDNF_ZadcShim

ObjectReference Function TryGetCurrentContraption(Quest zadcQuest, Actor npc) Global
    zadclibs libs = zadcQuest as zadclibs
    ObjectReference maybeContraption = libs.GetDevice(npc)
    If (maybeContraption != None && libs.GetUser(maybeContraption) == npc)
        Return maybeContraption
    EndIf
    Return None
EndFunction
