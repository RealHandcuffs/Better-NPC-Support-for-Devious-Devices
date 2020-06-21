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
for VAR in "$@"
do
  case "$VAR" in
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
      echo "Usage: $(basename "$0") [-q|--quiet] [-n|--no-clean]"
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

# clean if flag was given
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

# copy remaining files from package to build
if [[ "$QUIET" == "" ]]
then
  echo Copying files.
fi
cp -r package build

# create archive of build/package
if [[ "$QUIET" == "" ]]
then
  echo "Creating archive:"
fi
VERSION=$(cat build/package/FOMod/info.xml | sed -nr 's/.*<Version>([^<]+)<\/Version>.*/\1/p')
"$TOOL_7ZIP" a -t7z -mx=9 -mmt=off "build\Better NPC Support for Devious Devices $VERSION.7z" ".\build\package\*" > /dev/null
if [[ "$QUIET" == "" ]]
then
  echo "  build\Better NPC Support for Devious Devices $VERSION.7z ($(stat --printf="%s" "$BASE_DIR/build\Better NPC Support for Devious Devices $VERSION.7z") bytes)"
fi
