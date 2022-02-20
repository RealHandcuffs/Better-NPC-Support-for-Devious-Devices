;
; Soft-dependency script containing global functions dealing with Devious Contraptions.
;
Scriptname DDNF_ZadcShim

ObjectReference Function TryGetCurrentContraption(Actor npc) Global
    ObjectReference maybeContraption = StorageUtil.GetFormValue(npc, "DDC_DeviceUsed") As ObjectReference
    If (maybeContraption != None)
        ; double-check with zadclibs to be on the safe side
        zadclibs libs = Game.GetFormFromFile(0x0022FD, "Devious Devices - Contraptions.esm") as zadclibs
        If (libs.GetUser(maybeContraption) == npc)
            Return maybeContraption
        EndIf
    EndIf
    Return None
EndFunction

Bool Function HideRenderedDeviceForContraption(Armor renderedDevice, ObjectReference contraption) Global
    zadcFurnitureScript furn = contraption as zadcFurnitureScript
    If (furn != None)
        If (furn.HideAllDevices)
            Return true
        EndIf
        Keyword[] keywordsToHide = furn.InvalidDevices
        Int index = 0
        While (index < keywordsToHide.Length)
            If (renderedDevice.HasKeyword(keywordsToHide[index]))
                Return true
            EndIf
            index += 1
        EndWhile
    EndIf
    Return False
EndFunction

Function RestoreContraptionPositionAndIdle(Actor npc, ObjectReference contraption) Global
    zadcFurnitureScript furn = contraption as zadcFurnitureScript
    If (furn != None)
        If (DDNF_Game.IsSpecialEdition())
            ; ActorUtil package overrides will not survive unload/load cycles on SE
            ; Check if the package override was lost and restore it if necessary
            If (ActorUtil.CountPackageOverride(npc) == 0)
                npc.MoveTo(furn)
                ActorUtil.AddPackageOverride(npc, furn.PickRandomPose(), 99)
                npc.EvaluatePackage()
            EndIf
        EndIf
        npc.MoveTo(furn)
    EndIf
EndFunction

Bool Function TryRestoreOutfit(Actor npc) Global
    zadclibs libs = Game.GetFormFromFile(0x0022FD, "Devious Devices - Contraptions.esm") as zadclibs
    If (npc.GetLeveledActorBase().GetOutfit() == libs.zadc_outfit_naked)
        libs.RestoreOutfit(npc)
        Return true
    EndIf
    Return false
EndFunction
