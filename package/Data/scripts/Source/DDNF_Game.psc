;
; A script containing static helper functions.
;
Scriptname DDNF_Game

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
    Int nibble = Math.LogicalAnd(formId, 0xf)
    String hex = StringUtil.GetNthChar("0123456789ABCDEF", nibble)
    Int shift = 4
    While (shift < 28)
        nibble = Math.LogicalAnd(Math.RightShift(formId, shift), 0xf)
        hex = StringUtil.GetNthChar("0123456789ABCDEF", nibble) + hex
        shift += 4
    EndWhile
    nibble = Math.RightShift(formId, 28)
    hex = StringUtil.GetNthChar("0123456789ABCDEF", nibble) + hex
    Return hex
EndFunction
