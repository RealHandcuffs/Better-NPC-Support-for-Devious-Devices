#!/bin/bash

# this script builds the mod from the package folder
# the final result is a .7z file in the build folder
# this script calls most of the other scripts, so it is not necessary to call them before

# make sure we clean up on exit
ORIGINAL_DIR=$(pwd)
function clean_up {
  cd "$ORIGINAL_DIR"
}
trap clean_up EXIT
set -e

# check arguments
CLEAN=1
QUIET=""
LOOSE=0
for VAR in "$@"
do
  case "$VAR" in
    "-l" )
      LOOSE=1;;
    "--loose" )
      LOOSE=0;;
    "-n" )
      CLEAN=0;;
    "--no-clean" )
      CLEAN=0;;
    "-q" )
      QUIET="-q";;
    "--quiet" )
      QUIET="q";;
    * )
      if [[ "$VAR" != "-h" && "$VAR" != "--help" ]]
      then
        echo "Invalid argument: $VAR"
      fi
      echo "Usage: $(basename "$0") [-q|--quiet] [-n|--no-clean] [-l|--loose]"
      exit -1;;
  esac
done

# switch to base directory of repo
SCRIPTS_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
BASE_DIR=$(realpath "$SCRIPTS_DIR/..")
cd "$BASE_DIR"

# find tools and set env variables pointing to them
echo "#!/bin/bash" > build/setenv.sh
scripts/find_tools.sh -g >> build/setenv.sh
. build/setenv.sh
rm ./build/setenv.sh

# clean if not told otherwise using the -n flag
if [[ $CLEAN == 1 ]]
then
  if [[ "$QUIET" == "" ]]
  then
    echo Cleaning.
  fi
  scripts/clean.sh $QUIET
fi

# compile papyrus scripts
scripts/compile_papyrus.sh $QUIET

# copy remaining files to build directory
if [[ "$QUIET" == "" ]]
then
  echo Copying files.
fi
cp -r -p package build
cp -p changelog.txt build/package
cp -p LICENSE.txt build/package
VERSION=$(cat build/package/Data/scripts/Source/DDNF_MainQuest_Player.psc | sed -nr 's/^\s*String\s+Property\s+Version\s*=\s*"([^"]+)"\s+AutoReadOnly\s*$/\1/p')
if [[ "$QUIET" == "" ]]
then
  echo "  Version: $VERSION"
fi
mv build/package/FOMod/info.xml build/package/FOMod/info.xml.old
VERSION=$VERSION envsubst < build/package/FOMod/info.xml.old > build/package/FOMod/info.xml
rm build/package/FOMod/info.xml.old

# set up function to build bsa archive
# $1: folder (must be folder in build/package, without the "build" part
# $2: name of the archive to create
function build_bsa() {
  if [[ "$QUIET" == "" ]]
  then
     echo "Packing files in $1:"
  fi
  cd "$BASE_DIR/build/$1"
  ROOT=$(pwd | sed -e 's/\///' -e 's/\//:\\/' -e 's/\//\\/g')
  find . -type f ! -name '*.esp' | sed -e 's/.\///' > "$BASE_DIR/build/$2.lst"
  if [[ "$QUIET" == "" ]]
  then
     echo "  $(wc -l < "$BASE_DIR/build/$2.lst") files found."
  fi
  if [[ -s "$BASE_DIR/build/$2.lst" ]]
  then
    TEMP_DIR=$(mktemp -d)
    tar -c -O -T "$BASE_DIR/build/$2.lst" | tar -x -C "$TEMP_DIR"
    cd "$TEMP_DIR"
    echo "Log: archive.log" > archive.txt
    echo "New Archive" >> archive.txt
    echo "Check: Retain Directory Names" >> archive.txt
    echo "Check: Retain File Names" >> archive.txt
    echo "Check: Compress Archive" >> archive.txt
    for DIR in $(ls -1 -d */ | sed 's:/*$::')
    do
        case "$DIR" in
            "scripts" )
                echo "Check: Misc" >> archive.txt ;;
            * )
                echo Unknown directory: "$DIR"
                exit -1;;
        esac
    done
    ls -1 -d */ | sed 's:/*$::' | xargs -i{} echo "Add Directory: {}" >> archive.txt
    echo "Save Archive: $2" >> archive.txt
    "$DIR_SKYRIM_CREATION_KIT/Archive.exe" archive.txt
    mv "$2" "$BASE_DIR/build/$1"
    mv archive.log "$BASE_DIR/build/$2.log"
    cd "$BASE_DIR/build/$1"
    rm -r "$TEMP_DIR"
    xargs -a "$BASE_DIR/build/$2.lst" -d '\n' rm
    find . -type d -empty -delete
    if [[ "$QUIET" == "" ]]
    then
      echo "  $2 ($(stat --printf="%s" "$2") bytes)"
    fi
  fi
  cd "$BASE_DIR"
}

# call the function for the package/Data folder
if [[ $LOOSE == 0 ]]
then
  build_bsa "package/Data" "DD_NPC_Fixup.bsa"
fi

# create archive of build/package folder
if [[ "$QUIET" == "" ]]
then
  echo "Creating archive:"
fi
"$TOOL_7ZIP" a -t7z -mx=9 -myx=9 -mmt=off "build\Better NPC Support for Devious Devices $VERSION.7z" ".\build\package\*" > /dev/null
if [[ "$QUIET" == "" ]]
then
  echo "  build\Better NPC Support for Devious Devices $VERSION.7z ($(stat --printf="%s" "$BASE_DIR/build\Better NPC Support for Devious Devices $VERSION.7z") bytes)"
fi
