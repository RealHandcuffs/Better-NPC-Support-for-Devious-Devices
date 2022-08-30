;
; Soft-dependency script containing global functions using powerofthree's Papyrus Extender
;
Scriptname DDNF_Po3PapyrusExtenderShim

Bool Function IsAvailable() Global
    String foo = "foo"
    String[] arr = new String[1]
    arr[0] = foo
    Return PO3_SKSEfunctions.ArrayStringCount(foo, arr) == 1
EndFunction

Function AddKeywordToForm(Form akForm, Keyword keywordToAdd) Global
    PO3_SKSEfunctions.AddKeywordToForm(akForm, keywordToAdd)
EndFunction
