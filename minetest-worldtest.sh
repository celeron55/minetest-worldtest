#!/bin/bash
dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if ! [ "$#" -eq "1" ]; then
	echo "Usage: $0 <git repository url>"
	exit 1
fi
repo=$1

workdir=$dir/work
rulesdir=$dir/rules.d

worldsdir=$workdir/worlds
clonedir=$workdir/repo
builddir=$workdir/builds

mkdir -p "$workdir"
mkdir -p "$worldsdir"
mkdir -p "$builddir"

echo "== Cloning repository from $repo to $clonedir"
rm -rf "$clonedir"
git clone "$repo" "$clonedir"

# Returns true if a built minetest already exists in $1
check_built_minetest ()
{
	mtdir=$1
	if [ -a "$mtdir/bin/minetestserver" ]; then
		return 0
	fi
	return 1
}

# Collect important results for viewing at the end
result_summary=""
result_note ()
{
	echo $1
	if [ "$result_summary" == "" ]; then
		result_summary="$1"
	else
		result_summary="$result_summary\\n$1"
	fi
}

build_minetest ()
{
	tag=$1
	ruledir=$2
	pkg=$3
	mtdir=$4
	
	rm -rf "$mtdir" || return 1
	mkdir -p "$mtdir" || return 1
	pushd "$mtdir" &>/dev/null || return 1
		# Extract package
		tar -xf "$pkg" || return 1
		
		# Patch stuff
		for patchfile in $ruledir/*.patch; do
			if ! [ -a "$patchfile" ]; then
				continue
			fi
			echo "==     Patching $tag with $patchfile"
			patch -p1 < $patchfile
			if [ "$?" != "0" ]; then
				result_note "EE     Patch `basename "$patchfile"` failed for $tag"
				return 1
			fi
		done
		
		# Build it
		cmake . -DRUN_IN_PLACE=1 -DBUILD_CLIENT=0
		if [ "$?" == "1" ]; then
			echo "EE     Error preparing build for $tag"
			return 1
		fi
		make -j2
		if [ "$?" == "1" ]; then
			echo "EE     Error building $tag"
			return 1
		else
			echo "--     Built $tag"
			rm -rf CMakeFiles src/CMakeFiles src/lua/CMakeFiles src/lua/build/CMakeFiles src/jthread/CMakeFiles
		fi
	popd &>/dev/null
	return 0
}

# Build all the versions, if not already built
for ruledir in $rulesdir/*; do
	tag=`cat "$ruledir/tag"`
	echo "== Checking build: $tag"
	mtdir=$builddir/minetest-$tag
	# Make package if doesn't already exist
	pkg="$builddir/$tag.tar"
	echo "==   Creating package for $tag"
	pushd $clonedir &>/dev/null
		git archive --format tar $tag > "$pkg"
	popd &>/dev/null
	# Build if hasn't already been built
	check_built_minetest "$mtdir"
	if [ "$?" == "0" ]; then
		echo "==   Already built: $tag"
	else
		echo "==   Building $tag"
		build_minetest "$tag" "$ruledir" "$pkg" "$mtdir"
		if ! [ "$?" == "0" ]; then
			result_note "EE   Failed to build $tag"
		fi
	fi
done

# Make a world with each version
for ruledir in $rulesdir/*; do
	tag=`cat "$ruledir/tag"`
	echo "== Testing version: $tag"
	mtdir=$builddir/minetest-$tag
	worlddir=$worldsdir/world-$tag
	resultfile=/tmp/minetest-worldtest-tmpresult.txt
	
	# Check compatibility with itself
	rm -rf "$worlddir"
	$dir/minetest-worldtest-check-and-set.sh "$mtdir" "$worlddir" "$resultfile"
	#if [ "$?" != "0" ]; then
	if [ "`grep -c GOOD: "$resultfile"`" == "0" ]; then
		result_note "== $tag returns all bad for non-existent world"
	elif [ "`grep -c BAD: "$resultfile"`" == "0" ]; then
		result_note "EE $tag returns all good for non-existent world"
	else
		result_note "EE $tag returns some good for non-existent world"
		result_note "`grep GOOD: "$resultfile"`"
	fi
	$dir/minetest-worldtest-check-and-set.sh "$mtdir" "$worlddir" "$resultfile"
	#if [ "$?" == "0" ]; then
	if [ "`grep -c BAD: "$resultfile"`" == "0" ]; then
		result_note "== $tag returns all good for self-generated world"
	elif [ "`grep -c GOOD: "$resultfile"`" == "0" ]; then
		result_note "EE $tag returns all bad for self-generated world"
	else
		result_note "EE $tag returns some bad for self-generated world"
		result_note "`grep BAD: "$resultfile"`"
	fi
	
	# Check worlds generated by previous versions
	for rule2dir in $rulesdir/*; do
		tag2=`cat "$rule2dir/tag"`
		mt2dir=$builddir/minetest-$tag2
		world2dir=$worldsdir/world-$tag2-to-$tag
		# If tag2 is our current one, stop checking for this and newer
		if [ "$tag2" == "$tag" ]; then
			break
		fi
		echo "== Using world created by $tag2, loading it with $tag"
		rm -rf "$world2dir"
		cp -r "$worldsdir/world-$tag2" "$world2dir"
		#$dir/minetest-worldtest-check-and-set.sh "$mt2dir" "$world2dir" "$resultfile"
		$dir/minetest-worldtest-check-and-set.sh "$mtdir" "$world2dir" "$resultfile"
		if [ "`grep -c BAD: "$resultfile"`" == "0" ]; then
			result_note "== $tag returns all good for world generated by $tag2"
		elif [ "`grep -c GOOD: "$resultfile"`" == "0" ]; then
			result_note "EE $tag returns all bad for world generated by $tag2"
		else
			result_note "EE $tag returns some bad for world generated by $tag2"
			result_note "`grep BAD: "$resultfile"`"
		fi
	done
done

echo ""
echo "Result summary:"
echo -e "$result_summary"

# EOF
