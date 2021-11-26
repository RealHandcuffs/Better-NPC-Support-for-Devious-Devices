;
; This file is missing in Devious Devices 5.1, adding it from "Better NPC Support for Devious Devices".
;

Scriptname TIF__0605B970 Extends TopicInfo Hidden

Function Fragment_1(ObjectReference akSpeakerRef)
    Actor akSpeaker = akSpeakerRef as Actor
    libs.Moan(akSpeaker)
EndFunction

zadlibs Property libs Auto
