;
; A script containing static helper functions.
; This script is different for classic Skyrim and for Special Edition.
; This file contains the script for Special Edition.
;
Scriptname DDNF_Game

;
; Return false if the game is classic Skyrim, true if it is Special Edition (including Anniversary Edition).
;
Bool Function IsSpecialEdition() Global
    Return true
EndFunction

;
; Get the mod-internal id part of a form id.
;
Int Function GetModInternalFormId(Int formId) Global
    Int modId = Math.RightShift(formId, 24)
    If (modId >= 0xfe)
        If (modId == 0xfe) ; esl
            Return Math.LogicalAnd(formId, 0xfff)
        EndIf
        return formId
    EndIf
    Return Math.LogicalAnd(formId, 0xffffff)
EndFunction

;
; Get the mod id part of a form id, or -1 for dynamically created object references.
; Mod ids are [0..254] for classic Skyrim, [0..253] and [1040384..1044479] for Special Edition.
;
Int Function GetModId(Int formId) Global
    Int modId = Math.RightShift(formId, 24)
    If (modId >= 0xfe)
        If (modId == 0xfe) ; esl
            Return Math.RightShift(formId, 12)
        EndIf
        Return -1 ; modId == 0xff
    EndIf
    Return modId
EndFunction

;
; Get the name of a mod from a mod id.
;
String Function GetModName(Int modId) Global
    If (modId >= 0 && modId <= 0xfe)
        Return Game.GetModName(modId)
    EndIf
    If (modId >= 0xfe000 && modId <= 0xfefff) ; esl
        Int eslId = Math.LogicalAnd(modId, 0xfff)
        Return Game.GetLightModName(eslId)
    EndIf
    Return ""
EndFunction

;
; Get the form id of a form as a string, or "(none)" if the form is None.
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
