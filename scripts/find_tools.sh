#!/bin/bash

# this script looks for the required tools:
# - TOOL_7ZIP points to 7z.exe
# - DIR_SKYRIM points to the Skyrim directory
# - DIR_SKYRIM_CREATION_KIT points to the Skyrim creation kit directory
# if the -g argument is passed, it will output the above variables in format KEY="VALUE"
# if not, it will just check for presence of the tools and print human-readable messages

# make sure we clean up on exit
ORIGINAL_DIR=$(pwd)
function clean_up {
  cd "$ORIGINAL_DIR"
}
trap clean_up EXIT
set -e

# check arguments
GENERATE=0
for var in "$@"
do
  case "$var" in
    "-g" )
      GENERATE=1;;
    "--generate" )
      GENERATE=1;;
    * )
      if [[ "$var" != "-h" && "$var" != "--help" ]]
      then
        echo "Invalid argument: $var"
      fi
      echo "Usage: $(basename "$0") [-g|--generate]"
      exit -1;;
  esac
done

# switch to base directory of repo
SCRIPTS_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
BASE_DIR=$(realpath "$SCRIPTS_DIR/..")
cd "$BASE_DIR"

# search for 7zip
# if 7z.exe (or symlink to it) is in tools directory, this is used
# otherwise try to find the install location in the registry
if [[ -f "tools/7z.exe" ]]
then
  [[ $GENERATE == 0 ]] && echo "7-Zip: In tools directory."
  TOOL_7ZIP="$(realpath "$BASE_DIR/tools/7z.exe")"
  if [[ "$TOOL_7ZIP" != "$BASE_DIR/tools/7z.exe" ]]
  then
    [[ $GENERATE == 0 ]] && echo "  Resolved to: $TOOL_7ZIP"
  fi
else
  REGISTRY=$(reg query "HKLM\SOFTWARE\7-Zip") || { >&2 echo "ERROR: Unable to find 7-Zip registry key."; exit 1; }
  PATH_7ZIP=$(echo "$REGISTRY" | sed -rn "s/\s*Path64\s+REG_SZ\s+(.*)/\1/p" | sed 's/\\/\//g' | sed 's/://')
  PATH_7ZIP="/${PATH_7ZIP%/}"
  if [[ -f "$PATH_7ZIP/7z.exe" ]]
  then
    TOOL_7ZIP="$PATH_7ZIP/7z.exe"
    [[ $GENERATE == 0 ]] && echo "7-Zip: $TOOL_7ZIP"
  fi
fi

if [[ -z "$TOOL_7ZIP" ]]
then
  >&2 echo "ERROR: Unable to find 7-Zip."
  exit 1
fi

# search for Skyrim
# if "Skyrim" folder is in tools directory (probably symlink), this is used
# otherwise try to find the install location in the registry
if [[ -d "tools/Skyrim" ]]
then
  [[ $GENERATE == 0 ]] && echo "Skyrim: In tools directory."
  DIR_SKYRIM="$(realpath "$BASE_DIR/tools/Skyrim")"
  if [[ "$DIR_SKYRIM" != "$BASE_DIR/tools/Skyrim" ]]
  then
    [[ $GENERATE == 0 ]] && echo "  Resolved to: $DIR_SKYRIM"
  fi
else
  REGISTRY=$(reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 72850") || { >&2 echo "ERROR: Unable to find Fallout 4 registry key."; exit 2; }
  PATH_SKYRIM=$(echo "$REGISTRY" | sed -rn "s/\s*InstallLocation\s+REG_SZ\s+(.*)/\1/p" | sed -e 's/\\/\//g' -e 's/://')
  PATH_SKYRIM="/${PATH_SKYRIM%/}"
  if [[ -d "$PATH_SKYRIM" ]]
  then
    DIR_SKYRIM="$PATH_SKYRIM"
    [[ $GENERATE == 0 ]] && echo "Skyrim: $DIR_SKYRIM"
  fi
fi

if [[ -z "$DIR_SKYRIM" ]]
then
  >&2 echo "ERROR: Unable to find Skyrim."
  exit 2
fi

# search for Skyrim creation kit
# if "Skyrim Creation Kit" folder is in tools directory (probably symlink), this is used
# otherwise try to find the install location in the registry
if [[ -d "tools/Skyrim Creation Kit" ]]
then
  [[ $GENERATE == 0 ]] && echo "Skyrim Creation Kit: In tools directory."
  DIR_SKYRIM_CREATION_KIT="$(realpath "$BASE_DIR/tools/Skyrim Creation Kit")"
  if [[ "$DIR_SKYRIM_CREATION_KIT" != "$BASE_DIR/tools/Skyrim Creation Kit" ]]
  then
    [[ $GENERATE == 0 ]] && echo "  Resolved to: $DIR_SKYRIM_CREATION_KIT"
  fi
else
  REGISTRY=$(reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 202480") || { >&2 echo "ERROR: Unable to find Fallout 4 registry key."; exit 2; }
  PATH_SKYRIM_CREATION_KIT=$(echo "$REGISTRY" | sed -rn "s/\s*InstallLocation\s+REG_SZ\s+(.*)/\1/p" | sed -e 's/\\/\//g' -e 's/://')
  PATH_SKYRIM_CREATION_KIT="/${PATH_SKYRIM_CREATION_KIT%/}"
  if [[ -d "$PATH_SKYRIM_CREATION_KIT" ]]
  then
    DIR_SKYRIM_CREATION_KIT="$PATH_SKYRIM_CREATION_KIT"
    [[ $GENERATE == 0 ]] && echo "Skyrim: $DIR_SKYRIM_CREATION_KIT"
  fi
fi

if [[ -z "$DIR_SKYRIM_CREATION_KIT" ]]
then
  >&2 echo "ERROR: Unable to find Skyrim Creation Kit."
  exit 2
fi

# done, echo commands to set environment variables if requested to do so 
if [[ $GENERATE == 1 ]]
then
    echo TOOL_7ZIP=\"$TOOL_7ZIP\"
    echo DIR_SKYRIM=\"$DIR_SKYRIM\"
    echo DIR_SKYRIM_CREATION_KIT=\"$DIR_SKYRIM_CREATION_KIT\"
fi