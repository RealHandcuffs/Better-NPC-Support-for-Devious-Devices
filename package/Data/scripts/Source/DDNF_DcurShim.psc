;
; Soft-dependency script containing global functions dealing with Deviously Cursed Loot.
;
Scriptname DDNF_DcurShim

Armor[] Function GetSpecialHandlingDevices() Global
    Armor[] devices = new Armor[2]
    devices[0] = Game.GetFormFromFile(0x057e25, "Deviously Cursed Loot.esp") as Armor ; Rubber Gloves with D-links
    devices[1] = Game.GetFormFromFile(0x04dbc0, "Deviously Cursed Loot.esp") as Armor ; Rubber Gloves (locked)
    Return devices
EndFunction

Function HandleDeviceSelectedInContainerMenu(DDNF_NpcTracker npcTracker, Actor npc, Armor inventoryDevice, Armor renderedDevice, Armor[] dcurSpecialHandlingDevices, Int dcurDeviceIndex) Global
    If (dcurDeviceIndex == 0)
        ; Rubber Gloves with D-links, player may want to link them (replace with Rubber Gloves (locked))
        If (npc.GetItemCount(npcTracker.DDLibs.zad_DeviousHeavyBondage) == 0) ; not possible if already wearing heavy bondage
            Message msg = Game.GetFormFromFile(0x006397, "DD_NPC_Fixup.esp") as Message
            Int selection = msg.Show()
            If (selection > 0 && npcTracker.EnsureDeviceStillEquippedAfterPlayerSelection(npc, inventoryDevice, renderedDevice))
                Int index = npcTracker.Add(npc)
                If (index >= 0)
                    npc.RemoveItem(renderedDevice)
                    npc.RemoveItem(inventoryDevice)
                    Armor[] devices = new Armor[1]
                    devices[0] = dcurSpecialHandlingDevices[1]
                    If ((npcTracker.GetAliases()[index] as DDNF_NpcTracker_NPC).QuickEquipDevices(devices, 1, true) == 0) ; not expected but handle it
                        npc.AddItem(inventoryDevice)
                    EndIf
                EndIf
            EndIf
        EndIf
    ElseIf (dcurDeviceIndex == 1)
        ; Rubber Gloves (locked), replace with Rubber Gloves with D-links if unequipped
        dcur_mastercontrollerscript mcs = Game.GetFormFromFile(0x025A23, "Deviously Cursed Loot.esp") as dcur_mastercontrollerscript
        Bool unlockReset = false
        If (mcs.UnlockRubberGloves)
            mcs.UnlockRubberGloves = False ; workaround for dcur_lockedGlovesScript assuming that they are never worn by NPCs 
            unlockReset = true
        EndIf
        Int waitCount = 0
        While (!unlockReset && waitCount < 600)
            If (npc.GetItemCount(inventoryDevice) > 0)
                Return
            EndIf
            If (mcs.UnlockRubberGloves)
                mcs.UnlockRubberGloves = False
                unlockReset = true
            EndIf
            Utility.WaitMenuMode(0.016)
            If (!unlockReset && mcs.UnlockRubberGloves)
                mcs.UnlockRubberGloves = False
                unlockReset = true
            EndIf
            waitCount += 1
        EndWhile
        If (unlockReset)
            If (npcTracker.EnablePapyrusLogging)
                Debug.Trace("[DDNF] Reset UnlockRubberGloves flag after " + waitCount + " cycles, proceeding.")
            EndIf
            npcTracker.Player.RemoveItem(inventoryDevice, aiCount=1, abSilent=true)
            Int index = npcTracker.Add(npc)
            If (index >= 0)
                Armor[] devices = new Armor[1]
                devices[0] = dcurSpecialHandlingDevices[0]
                If ((npcTracker.GetAliases()[index] as DDNF_NpcTracker_NPC).QuickEquipDevices(devices, 1, true) == 0) ; e.g. when wearing other gloves
                    npcTracker.Player.AddItem(devices[0], aiCount=1, abSilent=true)
                EndIf
            EndIf
        EndIf
    EndIf
EndFunction
