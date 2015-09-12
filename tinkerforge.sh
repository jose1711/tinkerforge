#!/bin/bash
# interact with bricklets by tinkerforge using shell and socat
# based on http://www.tinkerforge.com/en/doc/Low_Level_Protocols/TCPIP.html
#
# decode58 borrowed from python's api
#                                                    jose1711 . gmail . com
#
# 
# requirements:
#  - dd
#  - od
#  - socat
#
# known issues:
#  - api is very limited, callbacks are impossible
#  - responses are not handled properly (only int16 values are expected) 
#  - authentication is not implemented
#
# notes:
#  make sure to adjust uids in main() before trying this out 
#  if you don't need response, socat can be replaced with printf "${data}" >/dev/tcp/${host}/${port}
#  if you do need it, it may still be possible with making a fd
#    exec 3<>/dev/tcp/${host}/${port}
#    printf "${data}" >&3; cat <&3 | dd bs=1 count=bytes_expected_on_output 2>/dev/null | ..
#    exec 3>&-
#
#########################################################################
# this is a default value, if you want to enable debugging at runtime
# start script with -d flag
debug=0
# how long (seconds) does socat wait for response (if you receive
# no response, try to increase this value)
socatwaittime=0.3
# hostname/ip where brickd is running (if you're unsure leave it as is )
host=localhost
# port (default: 4223)
port=4223
#
# set -x

export LANG=C
base58string="1 2 3 4 5 6 7 8 9 a b c d e f g h i j k m n o p q r s t u v w x y z A B C D E F G H J K L M N P Q R S T U V W X Y Z" 
base58=(${base58string})

function index {
	search=$1
	counter=0
	for i in "${base58[@]}"
		do
		[[ $i == "${search}" ]] && echo $counter && break
		((++counter))
		done
	}

# encode UUID to integer
function decode58 {
	encoded=$1
	value=0
        column_multiplier=1
	for charindex in $(seq $((${#encoded}-1)) -1 0)
		do
		char=$(echo $encoded | dd bs=1 count=1 skip=${charindex} 2>/dev/null)
		index=$(index $char)
		value=$((value + index * column_multiplier))
		column_multiplier=$((column_multiplier * 58))
		if [ ${debug} -eq 1 ]
			then
			echo "$char has index of ${index}" >&2
			fi
		done
	printf $value
	if [ ${debug} -eq 1 ]
		then
		echo "decoded uuid integer value is ${value}" >&2
		fi
	}

function tinkerforge {
	uuid=$1
	functionid=$2
	options=$3
	payload=$4
	if [ ${debug} -eq 1 ]
		then
		echo "invoking functionid ${functionid} of bricklet uuid ${uuid}" >&2
		fi
	uuidint=$(decode58 ${uuid})
	# uid as uint32
	data1=$(printf "%08x" ${uuidint} | sed 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/' | sed 's/../\\x&/g')
	# packet length as uint8 - data2 but this will be computed later
	data2='\x00'
	# function id as uint8
	data3=$(printf "\\\x%02x" ${functionid})
	# sequence number and response expected as uint8
	# \x18 seems to be working most of the time
	data4="${options}"
	# flags as uint8
	data5='\x00'
	# payload (optional)
	data6="$payload"
	# assemble packet
	data="${data1}${data2}${data3}${data4}${data5}${data6}"
	if [ ${debug} -eq 1 ]
		then
		echo "computing packet length.." >&2
		fi
	length=$((`printf "${data}" | wc -c`))
	if [ ${debug} -eq 1 ]
		then
		echo "length: ${length}" >&2
		fi
	data2=$(printf "\\\x%02x" ${length})
	# and again with computed packet length
	data="${data1}${data2}${data3}${data4}${data5}${data6}"

	if [ ${debug} -eq 1 ]
		then
		echo "${data}" >&2
		printf "${data}" | od -x >&2
		fi

	response="$(printf "${data}" | socat -T${socatwaittime} -,ignoreeof TCP:${host}:${port} | dd bs=1 2>/dev/null | od -An -t x1 | sed 's/ //g')"
	if [ ${debug} -eq 1 ]
		then
		echo "response raw: $response" >&2
		fi
	response=$(echo -n "$response" | cut -b 17- | sed 's/\(..\)\(..\).*/\2\1/')
	if [ ${debug} -eq 1 ]
		then
		echo "payload data: $response" >&2
		fi
	echo $((16#$response))
	}

while getopts ":d" opt
	do
	case $opt in
	d)
		echo "debug mode invoked"
		debug=1
		;;
	\?)
		echo "option not recognized"
		exit 1
		;;
	esac
	done

# main()
# example that reads values out of 3 bricklets, displays text
# on lcd display and toggles backlight

humiuid="hVS"
tempuid="gBr"
ilumuid="hZc"
lcduid="gCW"

echo "humidity: $((`tinkerforge ${humiuid} 1 '\x18'`/10)) %RH"
echo "temperature: $((`tinkerforge ${tempuid} 1 '\x18'`/10)) C"
echo "illuminance: $((`tinkerforge ${ilumuid} 1 '\x18'`/10)) lx"

# clear display then show Hello World
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
