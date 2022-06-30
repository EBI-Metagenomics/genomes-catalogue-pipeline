#!/bin/bash

################################
# Detects the bash script directory and sets the script path
#
# pushd: Stores a directory or network path in memory so it can be returned to at any time
# popd: Returns the path stored in memory
# > /dev/null: Prevents standard output
# pwd: Print working directory
# dirname: Breaks a pathname string into directory and filename components
# readlink: Resolves symbolic links
# BASH_SOURCE: An array variable whose members are the source filenames
################################
export SCRIPT_PATH=''; pushd "$(dirname "$(readlink -f "$BASH_SOURCE")")" > /dev/null && { SCRIPT_PATH=$PWD; popd > /dev/null; }

OPTIONS="$@"
CMD="java -jar $SCRIPT_PATH/macse_v2.03.jar $OPTIONS"
echo $CMD
$CMD