;
; A script containing static helper functions.
;
Scriptname DDNF_Game

;
; Check if a mod is a master of another mod. This function can be slow.
;
Bool Function IsMasterOf(Int masterModId, Int maybeUsingModId) Global
    Int dependencyCount = Game.GetModDependencyCount(maybeUsingModId)
    Int index = 0
    While (index < dependencyCount)
        Int dependencyModId = Game. GetNthModDependency(maybeUsingModId, index)
        If (dependencyModId == masterModId)
            Return true
        EndIf
        index += 1
    EndWhile
    Return false
EndFunction

;
; Get the name of the mod that defined a form.
;
String Function GetModName(Form item) Global
    If (item != None)
        Int modId = GetModId(item.GetFormID())
        If (modId >= 0)
            String modName = Game.GetModName(modId)
            If (modName != "")
                Return modName
            EndIf
        EndIf
    EndIf
    Return ""
EndFunction

;
; Get the mod-internal id part of a form id.
;
Int Function GetModInternalFormId(Int formId) Global
    Return Math.LogicalAnd(formId, 0xffffff)
EndFunction

;
; Get the mod id part of a form id.
;
Int Function GetModId(Int formId) Global
    Int modId = Math.RightShift(formId, 24)
    If (modId == 0xff)
        Return -1
    EndIf
    Return modId
EndFunction

;
; Get the form id of a form as a string.
;
String Function FormIdAsString(Form item) Global
    If (item == None)
        Return "(none)"
    EndIf
    Return FormIdToString(item.GetFormID())
EndFunction

;
; Convert a form id to a string.
;
String Function FormIdToString(Int formId) Global
    String hex
    Int nibble = Math.LogicalAnd(formId, 0xf)
    If (nibble <= 9)
        hex = StringUtil.AsChar(48 + nibble)
    Else
        hex = StringUtil.AsChar(55 + nibble)
    EndIf
    Int shift = 4
    While (shift < 28)
        nibble = Math.LogicalAnd(Math.RightShift(formId, shift), 0xf)
        If (nibble <= 9)
            hex = StringUtil.AsChar(48 + nibble) + hex
        Else
            hex = StringUtil.AsChar(55 + nibble) + hex
        EndIf
        shift += 4
    EndWhile
    nibble = Math.RightShift(formId, 28)
    If (nibble <= 9)
        hex = StringUtil.AsChar(48 + nibble) + hex
    Else
        hex = StringUtil.AsChar(55 + nibble) + hex
    EndIf
    Return hex
EndFunction
