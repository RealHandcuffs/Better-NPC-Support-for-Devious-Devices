; -------------------------------------------------------------------------------------------------
; This file is a stub for the papyrus compiler. The original file is:
;   scripts/Source/zadEquipScript.psc
; Devious Devices: https://www.loverslab.com/topic/157168-devious-devices-le-51-2021-01-19/
; Devious Devices SE: https://www.loverslab.com/topic/99700-devious-devices-se-51-2021-03-24/
;--------------------------------------------------------------------------------------------------

Scriptname zadEquipScript extends ObjectReference

Bool Property AllowLockPick Auto
Form[] Property AllowedLockPicks Auto
Float Property BaseEscapeChance Auto
Float Property EscapeCooldown Auto
Float Property LockAccessDifficulty Auto
Float Property LockPickEscapeChance Auto
MiscObject Property Lockpick Auto
Int Property NumberOfKeysNeeded Auto
Float Property UnlockCooldown Auto
Armor Property deviceInventory Auto
Key Property deviceKey Auto
String Property deviceName Auto
Armor Property deviceRendered Auto
Keyword Property zad_DeviousDevice Auto

Float Function CalculateCooldownModifier(Bool operator = true)
    Return 0
EndFunction

Float Function CalculateDifficultyModifier(Bool operator = true)
   Return 0
EndFunction

String[] Function SelectStruggleArray(Actor akActor)
    String[] dummy
    Return dummy
EndFunction
