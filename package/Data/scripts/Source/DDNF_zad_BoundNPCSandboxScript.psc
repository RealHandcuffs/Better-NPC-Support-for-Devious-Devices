;
; The original zad_BoundNPCSandboxScript included in Devious Devices 5.1 will do an EvaluateAA on package start.
; This is not required for tracked NPCs and is actually detrimental, so DD_NPC_Fixup.esp overrides the packages
; and replace the script with this one. This solution is cleaner than just replacing the script, removing the
; esp will ensure that DD uses the original script again even if the user fails to uninstall the scripts.
;

Scriptname DDNF_zad_BoundNPCSandboxScript Extends Package Hidden

DDNF_NpcTracker Property npcTracker Auto

Function Fragment_0(Actor akActor)
    If (npcTracker.GetNpcs().Find(akActor) < 0) ; usually false, but true e.g. if mod is disabled
        npcTracker.ddLibs.BoundCombat.EvaluateAA(akActor)
    EndIf
EndFunction
