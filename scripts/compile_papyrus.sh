#!/bin/bash

# this script compiles all papyrus files from the package folder
# into a matching folder structure in the build folder

# make sure we clean up on exit
ORIGINAL_DIR=$(pwd)
function clean_up {
  cd "$ORIGINAL_DIR"
}
trap clean_up EXIT
set -e

# check arguments
QUIET=0
SE=0
for VAR in "$@"
do
  case "$VAR" in
    "-q" )
      QUIET=1;;
    "--quiet" )
      QUIET=1;;
    "-s" )
      SE=1;;
    "--se" )
      SE=1;;
    * )
      if [[ "$VAR" != "-h" && "$VAR" != "--help" ]]
      then
        echo "Invalid argument: $VAR"
      fi
      echo "Usage: $(basename "$0") [-q|--quiet] [-s|--se]"
      exit -1;;
  esac
done

# switch to base directory of repo
SCRIPTS_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
BASE_DIR=$(realpath "$SCRIPTS_DIR/..")
cd "$BASE_DIR"

# find tools and set env variables pointing to them
echo "#!/bin/bash" > build/setenv.sh
if [[ $SE == 0 ]]
then
  scripts/find_tools.sh -g -c >> build/setenv.sh
else
  scripts/find_tools.sh -g -s >> build/setenv.sh
fi
. build/setenv.sh
rm ./build/setenv.sh

# find source directory for papyrus compiler (installed with creation kit)
if [[ $SE == 0 ]]
then
  PAPYRUS_SOURCE="$DIR_SKYRIM_CREATION_KIT/Data/Scripts/Source"
else
  PAPYRUS_SOURCE="$DIR_SKYRIM_SE_CREATION_KIT/Data/Source/Scripts"
fi
if [[ ! -f "$PAPYRUS_SOURCE/TESV_Papyrus_Flags.flg" ]]
then
  if [[ $SE == 0 ]]
  then
    PAPYRUS_SOURCE="$DIR_SKYRIM/Data/Scripts/Source"
  else
    PAPYRUS_SOURCE="$DIR_SKYRIM_SE/Data/Source/Scripts"
  fi
  if [[ ! -f "$PAPYRUS_SOURCE/TESV_Papyrus_Flags.flg" ]]
  then
    >&2 echo "ERROR: Unable to find papyrus base source dir."
    exit -1
  fi
fi

# also find sources for SKSE (sources of all dependencies need to be in the same place, too)
if [[ $SE == 0 ]]
then
  # in the same place for sykrim classic
  if [[ ! -f "$PAPYRUS_SOURCE/SKSE.psc" ]]
  then
    >&2 echo "ERROR: SKSE sources are missing."
    exit -1
  fi
else
  # in a different place for skyrim se
  SKSE_SOURCE="$DIR_SKYRIM_SE_CREATION_KIT/Data/Scripts/Source"
  if [[ ! -f "$SKSE_SOURCE/SKSE.psc" ]]
  then
    SKSE_SOURCE="$DIR_SKYRIM_SE/Data/Scripts/Source"
  fi
  if [[ ! -f "$SKSE_SOURCE/SKSE.psc" ]]
  then
    >&2 echo "ERROR: SKSE sources are missing."
    exit -1
  fi
fi

# set up a function to compile all scripts in a folder using parallel execution
# $1: full path to input folder
# $2: relative path to output folder (in build folder)
function compile_folder() {
  if [[ $QUIET == 0 ]]
  then
    echo "Compiling: $2"
  fi
  cd "$1"
  files=()
  pids=()
  # the for loops works because the script source files have no whitespace in their names
  for f in $(ls -1a *.psc)
  do
    files+=( "$f" )
    if [[ $SE == 0 ]]
    then
      "$DIR_SKYRIM_CREATION_KIT/Papyrus Compiler/PapyrusCompiler.exe" "$f" -optimize -quiet -flags="$(cygpath -w "$PAPYRUS_SOURCE/TESV_Papyrus_Flags.flg")" -import="$(cygpath -w "$BASE_DIR/stubs");$(cygpath -w "$BASE_DIR/3rdPartyDependencies");$(cygpath -w "$PAPYRUS_SOURCE");$(cygpath -w "$PAPYRUS_SOURCE/Dawnguard")" -output="$(cygpath -w "$BASE_DIR/build/$2")" &
    else
      "$DIR_SKYRIM_SE_CREATION_KIT/Papyrus Compiler/PapyrusCompiler.exe" "$f" -optimize -quiet -flags="$(cygpath -w "$PAPYRUS_SOURCE/TESV_Papyrus_Flags.flg")" -import="$(cygpath -w "$BASE_DIR/stubs");$(cygpath -w "$BASE_DIR/3rdPartyDependencies");$(cygpath -w "$SKSE_SOURCE");$(cygpath -w "$PAPYRUS_SOURCE")" -output="$(cygpath -w "$BASE_DIR/build/$2")" &
    fi
    pids+=( "$!" )
  done
  failures=()
  for index in ${!pids[*]}
  do 
    wait ${pids[$index]} || failures+=( "${files[$index]}" )
  done
  if [[ ${#failures[@]} > 0 ]]
  then
    for file in "${failures[@]}"
    do
      echo "ERROR: Compilation failed for: $1/Source/$file."
    done
    exit -1
  else
    if [[ $QUIET == 0 ]]
    then
      echo "  Compiled ${#pids[@]} files."
    fi
  fi
  cd "$BASE_DIR"
}

# copy sources from the package/Data/scripts folder to a temporary folder and compile them
TEMP_DIR=$(mktemp -d)
cd "$BASE_DIR/package/Data/scripts/Source"
cp *.psc "$TEMP_DIR"
if [[ $SE == 1 ]]
then
  cd "$BASE_DIR/package/Data_SE/scripts/Source"
  cp *.psc "$TEMP_DIR"
fi
cd "$BASE_DIR"
compile_folder "$TEMP_DIR" "package/Data/scripts"
rm -rf "$TEMP_DIR"