#!/bin/bash
dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -ne 2 ]; then
	if [ $# -ne 3 ]; then
		echo "Usage: $0 <minetest git directory> <world directory> [<result file>]"
		exit 1
	fi
	resultfile_dst=$3
else
	resultfile_dst=""
fi
gamedir=$1
worlddir=$2

#echo "-- Making world in $worlddir using $gamedir"
echo "-- Making world `basename $worlddir`"

pushd "$gamedir" &>/dev/null
# Configuration file is the common runtime configuration method
echo -e "map-dir = $worlddir\nenable_mapgen_debug_info = true\n" > worldtest_config
mkdir -p "$worlddir"
if ! [ -a "$worlddir/world.mt" ]; then
	echo -e 'gameid = minimal' > "$worlddir/world.mt"
fi
"$gamedir/bin/minetestserver" --config worldtest_config
popd &>/dev/null
resultfile=$gamedir/worldtest_result.txt
# Copy result to wanted location
if [ "$resultfile_dst" != "" ]; then
	cp "$resultfile" "$resultfile_dst"
fi
# Return based on result
if [ "`grep -c BAD: "$resultfile"`" != "0" ]; then
	#echo `grep ERRORS: "$resultfile"`
	exit 1
else
	exit 0
fi

