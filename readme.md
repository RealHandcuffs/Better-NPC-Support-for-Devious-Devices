 # Better NPC Support for Devious Devices
 
 The purpose of this mod is to improve support for NPCs in Devious Devices. Releases can be found at [loverslab](https://www.loverslab.com/files/file/13237-better-npc-support-for-devious-devices/).
 
 ### Building
 
 If you want to build the mod, you will need:
 - [git for window](https://git-scm.com/download/win) with git bash
 - [7zip](https://www.7-zip.org)
 - Skyrim LE and/or SE
 - (SKSE) [https://skse.silverlock.org]
 - the Skyrim creation kit (LE and/or SE, must match Skyrim)

Make sure that SKSE is installed correctly (including script sources), and that the Skyrim script sources from the creation kit are extracted (including Dawnguard script sources).

Clone the repo. If necessary, check out that branch that you wish to build. Open a git bash a the root folder of the repo. To build the mod for LE, run the script `scripts/build.sh`. If you wish to build for Skyrim SE, use `scripts/build.sh --se`instead. The script will build the mod and place the resulting .7z file in the `build` folder.
 
 