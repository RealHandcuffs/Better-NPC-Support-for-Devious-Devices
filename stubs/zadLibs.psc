; -------------------------------------------------------------------------------------------------
; This file is a stub for the papyrus compiler. The original file is:
;   scripts/Source/zadLibs.psc
; Devious Devices: https://www.loverslab.com/topic/157168-devious-devices-le-51-2021-01-19/
; Devious Devices SE: https://www.loverslab.com/topic/99700-devious-devices-se-51-2021-03-24/
;--------------------------------------------------------------------------------------------------

Scriptname zadLibs extends Quest

zadBoundCombatScript Property BoundCombat Auto
zadConfig Property Config Auto
SexLabFramework property SexLab auto
Faction Property zadAnimatingFaction Auto
Outfit Property zadEmptyOutfit Auto
Faction Property zadGagPanelFaction Auto
Keyword Property zad_BlockGeneric Auto
Keyword Property zad_BraNoBlockPiercings Auto
Keyword Property zad_BoundCombatDisableKick Auto
Keyword Property zad_DeviousArmbinder Auto
Keyword Property zad_DeviousArmbinderElbow Auto
Keyword Property zad_DeviousArmCuffs Auto
Keyword Property zad_DeviousBelt Auto
Keyword Property zad_DeviousBlindfold Auto
Keyword Property zad_DeviousBondageMittens Auto
Keyword Property zad_DeviousBoots Auto
Keyword Property zad_DeviousBra Auto
Keyword Property zad_DeviousClamps Auto
Keyword Property zad_DeviousCuffsFront Auto
Keyword Property zad_DeviousElbowTie Auto
Keyword Property zad_DeviousGag Auto
Keyword Property zad_DeviousGagPanel Auto
Keyword Property zad_DeviousGloves Auto
Keyword Property zad_DeviousHeavyBondage Auto
Keyword Property zad_DeviousHobbleSkirt Auto
Keyword Property zad_DeviousHobbleSkirtRelaxed Auto
Keyword Property zad_DeviousHood Auto
Keyword Property zad_DeviousPiercingsNipple Auto
Keyword Property zad_DeviousPiercingsVaginal Auto
Keyword Property zad_DeviousPlug Auto
Keyword Property zad_DeviousPlugAnal Auto
Keyword Property zad_DeviousPlugVaginal Auto
Keyword Property zad_DeviousPonyGear Auto
Keyword Property zad_DeviousSuit Auto
Keyword Property zad_DeviousStraitJacket Auto
Keyword Property zad_DeviousYoke Auto
Keyword Property zad_DeviousYokeBB Auto
Keyword Property zad_InventoryDevice Auto
Keyword Property zad_Lockable Auto
Keyword Property zad_PermitAnal Auto
Keyword Property zad_PermitVaginal Auto
Keyword Property zad_QuestItem Auto
MiscObject Property zad_gagPanelPlug Auto

Keyword Function GetDeviceKeyword(Armor device)
    Return None
EndFunction

Armor Function GetRenderedDevice(Armor device)
    Return None
EndFunction

Bool Function IsAnimating(Actor akActor)
    Return false
EndFunction

Bool Function LockDevice(Actor akActor, Armor deviceInventory, Bool force = false)
    Return false
EndFunction

Function Moan(Actor akActor, int arousal=-1, sslBaseVoice voice = none)
EndFunction

Function Pant(Actor akActor)
EndFunction

Function RepopulateNpcs()
EndFunction

Function SetAnimating(Actor akActor, Bool isAnimating=true)
EndFunction

Function SexlabMoan(Actor akActor, int arousal=-1, sslBaseVoice voice = none)
EndFunction

Bool Function UnlockDevice(actor akActor, Armor deviceInventory, Armor deviceRendered = none, Keyword zad_DeviousDevice = none, Bool destroyDevice = false, Bool genericonly = false)
    Return false
EndFunction
