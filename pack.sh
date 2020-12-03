#!/bin/bash
set -e

pyInstallDir=${HOME}/BuildBox/__install/python3.7-arm64
pyPackingDir=${HOME}/BuildBox/__install/python3.7
pyLibDynloadDir=${pyInstallDir}/lib/python3.7/lib-dynload
targetInstallDir=$HOME/BuildBox/__install/android8
zipFile=~/python_bins_android8.7z

(
	cd $pyInstallDir
	{ find -name '__pycache__'; find -name '*test*' -type d; } | xargs rm -rf

	archDir=lib/arm64-v8a
	if [ ! -f $archDir/libffi.so ]; then
		mkdir -p $archDir
		cp -vf $targetInstallDir/lib64/libffi.so $archDir/
	fi

	cd "$pyLibDynloadDir"
	file *.so | grep 'shared object, x86-64,' | awk '{print $1}' | sed 's/:$//' | xargs rm -f

	ls *.so | while read a
	do
		b=$(echo "$a" | sed 's/-x86_64-linux-gnu_failed//')
		if [ "$a" != "$b" ]; then
			cmd="mv '$a' '$b'"
			echo $cmd
			eval "$cmd"
		fi
	done

	rm -rf $pyPackingDir/ || true
	cp -v -dprf $pyInstallDir $pyPackingDir
	cd $pyPackingDir/..
	rm -f $zipFile
	7za a $zipFile $(basename "$pyPackingDir")/
)

