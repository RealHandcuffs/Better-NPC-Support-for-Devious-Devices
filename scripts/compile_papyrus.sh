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
for VAR in "$@"
do
  case "$VAR" in
    "-q" )
      QUIET=1;;
    "--quiet" )
      QUIET=1;;
    * )
      if [[ "$VAR" != "-h" && "$VAR" != "--help" ]]
      then
        echo "Invalid argument: $VAR"
      fi
      echo "Usage: $(basename "$0") [-q|--quiet]"
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

# find source directory for papyrus compiler (installed with creation kit)
PAPYRUS_SOURCE="$DIR_SKYRIM_CREATION_KIT/Data/Scripts/Source"
if [[ ! -f "$PAPYRUS_SOURCE/TESV_Papyrus_Flags.flg" ]]
then
    PAPYRUS_SOURCE="$DIR_SKYRIM/Data/Scripts/Source"
    if [[ ! -f "$PAPYRUS_SOURCE/TESV_Papyrus_Flags.flg" ]]
    then
      >&2 echo "ERROR: Unable to find papyrus base source dir."
      exit -1
    fi
fi

# this same directory also needs to contain SKSE sources and sources of all dependencies
if [[ ! -f "$PAPYRUS_SOURCE/SKSE.psc" ]]
then
    >&2 echo "ERROR: SKSE sources are missing."
    exit -1
fi

# set up a function to compile all scripts in a folder using parallel execution
# $1: input folder, must contain a "Source" folder
function compile_folder() {
  if [[ $QUIET == 0 ]]
  then
    echo "Compiling: $1"
  fi
  cd "$BASE_DIR/$1/Source"
  files=()
  pids=()
  # the for loops works because the script source files have no whitespace in their names
  for f in $(ls -1a *.psc)
  do
    files+=( "$f" )
    "$DIR_SKYRIM_CREATION_KIT/Papyrus Compiler/PapyrusCompiler.exe" "$f" -optimize -quiet -flags="$(cygpath -w "$PAPYRUS_SOURCE/TESV_Papyrus_Flags.flg")" -import="$(cygpath -w "$PAPYRUS_SOURCE");$(cygpath -w "$PAPYRUS_SOURCE/Dawnguard")" -output="$(cygpath -w "$BASE_DIR/build/$1")" &
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

# call the function for the package/Data/scripts folder
compile_folder "package/Data/scripts"