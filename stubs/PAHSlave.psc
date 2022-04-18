; -------------------------------------------------------------------------------------------------
; This file is a stub for the papyrus compiler. The original file is:
;   scripts/source/pahslave.psc, in paradise_halls_SLExtension.bsa
; Paradise Halls Enhanced: https://www.loverslab.com/files/file/2872-paradise-halls-enhanced-pahe-repacked-with-the-customary-addons/
; Paradise Halls Enhanced SE: https://www.loverslab.com/files/file/6305-paradise-halls-enhanced-pahe-special-edition-with-the-customary-addons/
;--------------------------------------------------------------------------------------------------

Scriptname PAHSlave extends ReferenceAlias

Package Property DoNothing Auto
Package Property PAHDoNothing Auto

Bool Function TieUp(Form cuff, Actor Aggressor = None, Bool DoAnimation = False, Bool UnCalm = True, Bool Enter = True)
    Return false
EndFunction

Function PlayTieUpAnimation(Bool TieUp = True)
EndFunction

Function ChangeTiePose(String ThePose, String TheStrugglePose = "")
EndFunction
