#!/bin/bash
dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -ne 2 ]; then
	echo "Usage: $0 <minetest git directory> <world directory>"
	exit 1
fi
gamedir=$1
worlddir=$2

#echo "-- Making world in $worlddir using $gamedir"
echo "-- Making world `basename $worlddir`"

pushd "$gamedir" &>/dev/null
# Configuration file is the common runtime configuration method
echo -e "map-dir = $worlddir\nenable_mapgen_debug_info = true\n" > worldtest_config
mkdir -p "$worlddir"
echo -e 'gameid = minimal' > "$worlddir/world.mt"
"$gamedir/bin/minetestserver" --config worldtest_config
popd &>/dev/null
resultfile=$gamedir/worldtest_result.txt
if [ "`grep -c BAD: "$resultfile"`" != "0" ]; then
	#echo `grep ERRORS: "$resultfile"`
	return 1
else
	return 0
fi

