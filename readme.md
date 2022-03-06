 # Better NPC Support for Devious Devices
 
 The purpose of this mod is to improve support for NPCs in Devious Devices. Releases can be found at [loverslab](https://www.loverslab.com/files/file/13237-better-npc-support-for-devious-devices/).
 
 ### Building
 
 If you want to build the mod, you will need:
 - [git for window](https://git-scm.com/download/win) with git bash
 - [7zip](https://www.7-zip.org)
 - Skyrim LE and/or SE
 - [SKSE](https://skse.silverlock.org)
 - the Skyrim creation kit (LE and/or SE, must match Skyrim)

Make sure that SKSE is installed correctly (including script sources), and that the Skyrim script sources from the creation kit are extracted (including Dawnguard script sources).

- open git bash and `cd` to the folder where you want to have the repo
- clone the repo using `git clone https://github.com/RealHandcuffs/Better-NPC-Support-for-Devious-Devices.git`
- change to the repo root (e.g. `cd Better\ NPC\ Support\ for\ Devious\ Devices/`)
- if you want to build a branch other than `master`, check out that branch using `git switch branch-name`
- build the mod using `scripts/build.sh` for LE, or `scripts/build.sh --se` for SE

The build script will create a .7z file and place it in the `build` folder. Install that file with your mod manager. 
 