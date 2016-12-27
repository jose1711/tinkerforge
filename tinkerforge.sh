#!/bin/bash
# a simple script showing how to use tinkerforge_functions.sh
# in your script
#
# make sure you adjust uids before trying this out
#
#######################################################################
# this is a default value, if you want to enable debugging at runtime
# start script with -d flag
brickd_debug=0
# set -x

cd $(dirname `readlink -f $0`)
# feel free to change the two lines below to your needs
brickd_debug=0
brickd_host="localhost"

. tinkerforge_functions.sh

while getopts ":d" opt
	do
	case $opt in
	d)
		echo "debug mode invoked"
		brickd_debug=1
		;;
	\?)
		echo "option not recognized"
		exit 1
		;;
	esac
	done

# example that reads values out of 3 bricklets, displays text
# on lcd display and toggles backlight

humiuid="hVS"
tempuid="gBr"
ilumuid="hZc"
lcduid="gCW"

echo "humidity: `tinkerforge ${humiuid} 1 '\x18' | sed 's/.$/.&/'` %RH"
echo "temperature: `tinkerforge ${tempuid} 1 '\x18' | sed 's/.$/.&/'` C"
echo "illuminance: `tinkerforge ${ilumuid} 1 '\x18' | sed 's/.$/.&/'` lx"

# clear display then print Hello World
tinkerforge ${lcduid} 2 '\x18' >/dev/null
tinkerforge ${lcduid} 1 '\x18\x00\x00\x00Hello' >/dev/null
tinkerforge ${lcduid} 1 '\x18\x00\x01\x00World' >/dev/null

echo "turning backlight on"
tinkerforge ${lcduid} 3 '\x18' >/dev/null
echo "is backlight on? $(tinkerforge ${lcduid} 5 '\x18')"
sleep 5
echo "turning backlight off"
tinkerforge ${lcduid} 4 '\x18' >/dev/null
echo "is backlight off? $(tinkerforge ${lcduid} 5 '\x18')"
