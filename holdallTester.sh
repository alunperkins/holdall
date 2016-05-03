#!/bin/bash

readonly PROGNAME=$(basename $0)

# this tests the logic of holdall for different mod time/history configurations, to see if it does the sync in the correct direction
# it tests files only, not folders

readonly HOST=holdAllTesterSimulatedHost
readonly RMVBL=holdAllTesterSimulatedRmvbl
readonly LOCSLIST=$RMVBL/syncLocationsOn_$HOSTNAME
readonly STATUSFILE=$RMVBL/syncStatus

readonly MON=1388966400 # a date in seconds since epoch
readonly TUE=1389052800
readonly WED=1389139200
readonly THU=1389225600
readonly FRI=1389312000

setRmvblTime(){
	local itemName="$1"
	local time="$2"
	touch -m -d "$(date --date=@$time +%c)" "$RMVBL/$itemName"
}
setHostTime(){
	local itemName="$1"
	local time="$2"
	touch -m -d "$(date --date=@$time +%c)" "$HOST/$itemName"
}
getRmvblTime(){
	local itemName="$1"
	local time="$2"
	echo $(date -r "$RMVBL/$itemName" +%s)
}
getHostTime(){
	local itemName="$1"
	local time="$2"
	echo $(date -r "$HOST/$itemName" +%s)
}

writeToRmvbl(){
	local itemName="$1"
	local message="$2"
	echo "$message" >> $RMVBL/$itemName
}
writeToHost(){
	local itemName="$1"
	local message="$2"
	echo "$message" >> $HOST/$itemName
}

setSyncTime(){
	local itemName="$1"
	local time="$2"
	echo "$itemName $HOSTNAME LASTSYNCDATE $time" >> $STATUSFILE
}
setUTDTrue(){
	local itemName="$1"
	echo "$itemName UPTODATEHOSTS $HOSTNAME," >> $STATUSFILE
}
addToLocsList(){
	local itemName="$1"
	echo "$HOST/$itemName" >> $LOCSLIST
}

# NOTATION
# RT = removable drive modification time
# HT = host modification time
# ST = last sync time
# < = is older than, e.g. ST < HT means ST is older than HT
# UTD = this host is on the up-to-date hosts list
# NUTD = this host is not on the up-to-date hosts list
# DMD = drive modified directly, as opposed to the usual situation of a modification being pushed to it from a host

# units with sync time inbetween host time and rmvbl time
# unit001 DESCRIPTION:  RT < ST < HT, UTD, should sync host>rmvbl 
unit001Initialise(){
	local itemName=unit001
	addToLocsList $itemName
	
	writeToRmvbl $itemName "old"
	writeToHost $itemName "new"
	
	setRmvblTime $itemName $MON
	setSyncTime $itemName $WED
	setHostTime $itemName $FRI
	setUTDTrue $itemName
}
unit001Check(){
	local itemName=unit001	
	[[ $(cat $HOST/$itemName) == "new" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "new" ]] || return 2
	[[ $(cat $RMVBL/$itemName-removed*/*) == "old" ]] || return 3
	[[ $(getHostTime $itemName) -eq $FRI ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $FRI ]] || return 5
	return 0
}
# unit002 DESCRIPTION:  RT < ST < HT, NUTD, should say fork and merge host>rmvbl 
unit002Initialise(){
	local itemName=unit002
	addToLocsList $itemName
	
	writeToRmvbl $itemName "old"
	writeToHost $itemName "new"
	
	setRmvblTime $itemName $MON
	setSyncTime $itemName $WED
	setHostTime $itemName $FRI
}
unit002Check(){
	local itemName=unit002
	[[ $(cat $HOST/$itemName) == "new" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "new" ]] || return 2
	[[ $(cat $RMVBL/$itemName-removed*) == "old" ]] || return 3
	[[ $(getHostTime $itemName) -eq $FRI ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $FRI ]] || return 5
	grep "$itemName.*fork"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit003 DESCRIPTION:  HT < ST < RT, UTD, should say DMD and sync rmvbl>host 
unit003Initialise(){
	local itemName=unit003
	addToLocsList $itemName
	
	writeToRmvbl $itemName "new"
	writeToHost $itemName "old"
	
	setHostTime $itemName $MON
	setSyncTime $itemName $WED
	setRmvblTime $itemName $FRI
	setUTDTrue $itemName
}
unit003Check(){
	local itemName=unit003
	[[ $(cat $HOST/$itemName) == "new" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "new" ]] || return 2
	[[ $(cat $HOST/$itemName-removed*/*) == "old" ]] || return 3
	[[ $(getHostTime $itemName) -eq $FRI ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $FRI ]] || return 5
	grep "$itemName.*removable drive.*modified directly"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit004 DESCRIPTION:  HT < ST < RT, NUTD, should sync rmvbl>host 
unit004Initialise(){
	local itemName=unit004
	addToLocsList $itemName
	
	writeToRmvbl $itemName "new"
	writeToHost $itemName "old"
	
	setHostTime $itemName $MON
	setSyncTime $itemName $WED
	setRmvblTime $itemName $FRI
}
unit004Check(){
	local itemName=unit004
	[[ $(cat $HOST/$itemName) == "new" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "new" ]] || return 2
	[[ $(cat $HOST/$itemName-removed*/*) == "old" ]] || return 3
	[[ $(getHostTime $itemName) -eq $FRI ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $FRI ]] || return 5
	return 0
}

# units with sync time before both host time and mod time
# unit020 DESCRIPTION:  ST < HT < RT, UTD, should say fork and merge rmvbl>host 
unit020Initialise(){
	local itemName=unit020
	addToLocsList $itemName
	
	writeToRmvbl $itemName "new"
	writeToHost $itemName "old"
	
	setSyncTime $itemName $MON
	setHostTime $itemName $WED
	setRmvblTime $itemName $FRI
	setUTDTrue $itemName
}
unit020Check(){
	local itemName=unit020
	[[ $(cat $HOST/$itemName) == "new" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "new" ]] || return 2
	[[ $(cat $HOST/$itemName-removed*) == "old" ]] || return 3
	[[ $(getHostTime $itemName) -eq $FRI ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $FRI ]] || return 5
	grep "$itemName.*fork"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit021 DESCRIPTION:  ST < HT < RT, NUTD, should say fork and merge rmvbl>host 
unit021Initialise(){
	local itemName=unit021
	addToLocsList $itemName
	
	writeToRmvbl $itemName "new"
	writeToHost $itemName "old"
	
	setSyncTime $itemName $MON
	setHostTime $itemName $WED
	setRmvblTime $itemName $FRI
}
unit021Check(){
	local itemName=unit021
	[[ $(cat $HOST/$itemName) == "new" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "new" ]] || return 2
	[[ $(cat $HOST/$itemName-removed*) == "old" ]] || return 3
	[[ $(getHostTime $itemName) -eq $FRI ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $FRI ]] || return 5
	grep "$itemName.*fork"<<<"$holdallOutput" > /dev/null || return 6
	return 0
}
# unit022 DESCRIPTION:  ST < RT < HT, UTD, should say fork and merge host>rmvbl 
unit022Initialise(){
	local itemName=unit022
	addToLocsList $itemName
	
	writeToRmvbl $itemName "old"
	writeToHost $itemName "new"
	
	setSyncTime $itemName $MON
	setRmvblTime $itemName $WED
	setHostTime $itemName $FRI
	setUTDTrue $itemName
}
unit022Check(){
	local itemName=unit022
	[[ $(cat $HOST/$itemName) == "new" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "new" ]] || return 2
	[[ $(cat $RMVBL/$itemName-removed*) == "old" ]] || return 3
	[[ $(getHostTime $itemName) -eq $FRI ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $FRI ]] || return 5
	grep "$itemName.*fork"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit023 DESCRIPTION:  ST < RT < HT, NUTD, should say fork and merge host>rmvbl 
unit023Initialise(){
	local itemName=unit023
	addToLocsList $itemName
	
	writeToRmvbl $itemName "old"
	writeToHost $itemName "new"
	
	setSyncTime $itemName $MON
	setRmvblTime $itemName $WED
	setHostTime $itemName $FRI
}
unit023Check(){
	local itemName=unit023
	[[ $(cat $HOST/$itemName) == "new" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "new" ]] || return 2
	[[ $(cat $RMVBL/$itemName-removed*) == "old" ]] || return 3
	[[ $(getHostTime $itemName) -eq $FRI ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $FRI ]] || return 5
	grep "$itemName.*fork"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit024 DESCRIPTION:  ST < RT = HT, UTD, should say fork and do nothing 
unit024Initialise(){
	local itemName=unit024
	addToLocsList $itemName
	
	writeToRmvbl $itemName "new"
	writeToHost $itemName "also new"
	
	setSyncTime $itemName $MON
	setRmvblTime $itemName $FRI
	setHostTime $itemName $FRI
	setUTDTrue $itemName
}
unit024Check(){
	local itemName=unit024
	[[ $(cat $HOST/$itemName) == "also new" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "new" ]] || return 2
	[[ $(getHostTime $itemName) -eq $FRI ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $FRI ]] || return 5
	grep "$itemName.*fork"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit025 DESCRIPTION:  ST < RT = HT, NUTD, should say fork and do nothing 
unit025Initialise(){
	local itemName=unit025
	addToLocsList $itemName
	
	writeToRmvbl $itemName "new"
	writeToHost $itemName "also new"
	
	setSyncTime $itemName $MON
	setRmvblTime $itemName $FRI
	setHostTime $itemName $FRI
}
unit025Check(){
	local itemName=unit025
	[[ $(cat $HOST/$itemName) == "also new" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "new" ]] || return 2
	[[ $(getHostTime $itemName) -eq $FRI ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $FRI ]] || return 5
	grep "$itemName.*fork"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
																								  
# units with sync time after both host time and rmvbl time
# unit030 DESCRIPTION:  HT < RT < ST, UTD, should say error and do nothing 
unit030Initialise(){
	local itemName=unit030
	addToLocsList $itemName
	
	writeToRmvbl $itemName "new"
	writeToHost $itemName "old"
	
	setHostTime $itemName $MON
	setRmvblTime $itemName $WED
	setSyncTime $itemName $FRI
	setUTDTrue $itemName
}
unit030Check(){
	local itemName=unit030
	[[ $(cat $HOST/$itemName) == "old" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "new" ]] || return 2
	[[ $(getHostTime $itemName) -eq $MON ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $WED ]] || return 5
	grep "$itemName.*[Ww]arning"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit031 DESCRIPTION:  HT < RT < ST, NUTD, should sync rmvbl>host 
unit031Initialise(){
	local itemName=unit031
	addToLocsList $itemName
	
	writeToRmvbl $itemName "new"
	writeToHost $itemName "old"
	
	setHostTime $itemName $MON
	setRmvblTime $itemName $WED
	setSyncTime $itemName $FRI
}
unit031Check(){
	local itemName=unit031
	[[ $(cat $HOST/$itemName) == "new" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "new" ]] || return 2
	[[ $(cat $HOST/$itemName-removed*/*) == "old" ]] || return 3
	[[ $(getHostTime $itemName) -eq $WED ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $WED ]] || return 5
	return 0
}
# unit032 DESCRIPTION:  RT < HT < ST, UTD, should say error and do nothing 
unit032Initialise(){
	local itemName=unit032
	addToLocsList $itemName
	
	writeToRmvbl $itemName "old"
	writeToHost $itemName "new"
	
	setRmvblTime $itemName $MON
	setHostTime $itemName $WED
	setSyncTime $itemName $FRI
	setUTDTrue $itemName
}
unit032Check(){
	local itemName=unit032
	[[ $(cat $HOST/$itemName) == "new" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "old" ]] || return 2
	[[ $(getHostTime $itemName) -eq $WED ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $MON ]] || return 5
	grep "$itemName.*[Ww]arning"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit033 DESCRIPTION:  RT < HT < ST, NUTD, should say error and do nothing 
unit033Initialise(){
	local itemName=unit033
	addToLocsList $itemName
	
	writeToRmvbl $itemName "old"
	writeToHost $itemName "new"
	
	setRmvblTime $itemName $MON
	setHostTime $itemName $WED
	setSyncTime $itemName $FRI
}
unit033Check(){
	local itemName=unit033
	[[ $(cat $HOST/$itemName) == "new" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "old" ]] || return 2
	[[ $(getHostTime $itemName) -eq $WED ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $MON ]] || return 5
	return 0
}
# unit034 DESCRIPTION:  RT = HT < ST, UTD, this is the "no changes" state, should do nothing 
unit034Initialise(){
	local itemName=unit034
	addToLocsList $itemName
	
	writeToRmvbl $itemName "old"
	writeToHost $itemName "also old"
	
	setRmvblTime $itemName $MON
	setHostTime $itemName $MON
	setSyncTime $itemName $FRI
	setUTDTrue $itemName
}
unit034Check(){
	local itemName=unit034
	[[ $(cat $HOST/$itemName) == "also old" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "old" ]] || return 2
	[[ $(getHostTime $itemName) -eq $MON ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $MON ]] || return 5
	return 0
}
# unit035 DESCRIPTION:  RT = HT < ST, NUTD, should say error and do nothing 
unit035Initialise(){
	local itemName=unit035
	addToLocsList $itemName
	
	writeToRmvbl $itemName "old"
	writeToHost $itemName "also old"
	
	setRmvblTime $itemName $MON
	setHostTime $itemName $MON
	setSyncTime $itemName $FRI
}
unit035Check(){
	local itemName=unit035
	[[ $(cat $HOST/$itemName) == "also old" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "old" ]] || return 2
	[[ $(getHostTime $itemName) -eq $MON ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $MON ]] || return 5
	grep "$itemName.*[Ww]arning"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}

# units with sync time simulataneous with either host time or rmvbl time
# unit040 DESCRIPTION:  RT < HT = ST, UTD, should say error and do nothing 
unit040Initialise(){
	local itemName=unit040
	addToLocsList $itemName
	
	writeToRmvbl $itemName "old"
	writeToHost $itemName "also old"
	
	setRmvblTime $itemName $MON
	setHostTime $itemName $FRI
	setSyncTime $itemName $FRI
	setUTDTrue $itemName
}
unit040Check(){
	local itemName=unit040
	[[ $(cat $HOST/$itemName) == "also old" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "old" ]] || return 2
	[[ $(getHostTime $itemName) -eq $FRI ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $MON ]] || return 5
	grep "$itemName.*[Ww]arning"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit041 DESCRIPTION:  RT < HT = ST, NUTD, should say error and do nothing 
unit041Initialise(){
	local itemName=unit041
	addToLocsList $itemName
	
	writeToRmvbl $itemName "old"
	writeToHost $itemName "also old"
	
	setRmvblTime $itemName $MON
	setHostTime $itemName $FRI
	setSyncTime $itemName $FRI
}
unit041Check(){
	local itemName=unit041
	[[ $(cat $HOST/$itemName) == "also old" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "old" ]] || return 2
	[[ $(getHostTime $itemName) -eq $FRI ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $MON ]] || return 5
	grep "$itemName.*[Ww]arning"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit042 DESCRIPTION:  HT = ST < RT, UTD, should say error and do nothing 
unit042Initialise(){
	local itemName=unit042
	addToLocsList $itemName
	
	writeToRmvbl $itemName "new"
	writeToHost $itemName "old"
	
	setHostTime $itemName $MON
	setSyncTime $itemName $MON
	setRmvblTime $itemName $FRI
	setUTDTrue $itemName
}
unit042Check(){
	local itemName=unit042
	[[ $(cat $HOST/$itemName) == "old" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "new" ]] || return 2
	[[ $(getHostTime $itemName) -eq $MON ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $FRI ]] || return 5
	grep "$itemName.*[Ww]arning"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit043 DESCRIPTION:  HT = ST < RT, NUTD, should say error and do nothing 
unit043Initialise(){
	local itemName=unit043
	addToLocsList $itemName
	
	writeToRmvbl $itemName "new"
	writeToHost $itemName "old"
	
	setHostTime $itemName $MON
	setSyncTime $itemName $MON
	setRmvblTime $itemName $FRI
}
unit043Check(){
	local itemName=unit043
	[[ $(cat $HOST/$itemName) == "old" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "new" ]] || return 2
	[[ $(getHostTime $itemName) -eq $MON ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $FRI ]] || return 5
	grep "$itemName.*[Ww]arning"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit044 DESCRIPTION:  HT < ST = RT, UTD, should say error and do nothing 
unit044Initialise(){
	local itemName=unit044
	addToLocsList $itemName
	
	writeToRmvbl $itemName "new"
	writeToHost $itemName "old"
	
	setHostTime $itemName $MON
	setSyncTime $itemName $FRI
	setRmvblTime $itemName $FRI
	setUTDTrue $itemName
}
unit044Check(){
	local itemName=unit044
	[[ $(cat $HOST/$itemName) == "old" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "new" ]] || return 2
	[[ $(getHostTime $itemName) -eq $MON ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $FRI ]] || return 5
	grep "$itemName.*[Ww]arning"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit045 DESCRIPTION:  HT < ST = RT, NUTD, should say error and do nothing 
unit045Initialise(){
	local itemName=unit045
	addToLocsList $itemName
	
	writeToRmvbl $itemName "new"
	writeToHost $itemName "old"
	
	setHostTime $itemName $MON
	setSyncTime $itemName $FRI
	setRmvblTime $itemName $FRI
}
unit045Check(){
	local itemName=unit045
	[[ $(cat $HOST/$itemName) == "old" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "new" ]] || return 2
	[[ $(getHostTime $itemName) -eq $MON ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $FRI ]] || return 5
	grep "$itemName.*[Ww]arning"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit046 DESCRIPTION:  RT = ST < HT, UTD, should say error and do nothing 
unit046Initialise(){
	local itemName=unit046
	addToLocsList $itemName
	
	writeToRmvbl $itemName "old"
	writeToHost $itemName "new"
	
	setSyncTime $itemName $MON
	setRmvblTime $itemName $MON
	setHostTime $itemName $FRI
	setUTDTrue $itemName
}
unit046Check(){
	local itemName=unit046
	[[ $(cat $HOST/$itemName) == "new" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "old" ]] || return 2
	[[ $(getHostTime $itemName) -eq $FRI ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $MON ]] || return 5
	grep "$itemName.*[Ww]arning"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit047 DESCRIPTION:  RT = ST < HT, NUTD, should say error and do nothing 
unit047Initialise(){
	local itemName=unit047
	addToLocsList $itemName
	
	writeToRmvbl $itemName "old"
	writeToHost $itemName "new"
	
	setSyncTime $itemName $MON
	setRmvblTime $itemName $MON
	setHostTime $itemName $FRI
}
unit047Check(){
	local itemName=unit047
	[[ $(cat $HOST/$itemName) == "new" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "old" ]] || return 2
	[[ $(getHostTime $itemName) -eq $FRI ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $MON ]] || return 5
	grep "$itemName.*[Ww]arning"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit048 DESCRIPTION:  RT = ST = HT, UTD, should say error and do nothing 
unit048Initialise(){
	local itemName=unit048
	addToLocsList $itemName
	
	writeToRmvbl $itemName "old"
	writeToHost $itemName "also old"
	
	setSyncTime $itemName $WED
	setRmvblTime $itemName $WED
	setHostTime $itemName $WED
	setUTDTrue $itemName
}
unit048Check(){
	local itemName=unit048
	[[ $(cat $HOST/$itemName) == "also old" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "old" ]] || return 2
	[[ $(getHostTime $itemName) -eq $WED ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $WED ]] || return 5
	grep "$itemName.*[Ww]arning"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}
# unit048 DESCRIPTION:  RT = ST = HT, NUTD, should say error and do nothing 
unit048Initialise(){
	local itemName=unit048
	addToLocsList $itemName
	
	writeToRmvbl $itemName "old"
	writeToHost $itemName "also old"
	
	setSyncTime $itemName $WED
	setRmvblTime $itemName $WED
	setHostTime $itemName $WED
}
unit048Check(){
	local itemName=unit048
	[[ $(cat $HOST/$itemName) == "also old" ]] || return 1
	[[ $(cat $RMVBL/$itemName) == "old" ]] || return 2
	[[ $(getHostTime $itemName) -eq $WED ]] || return 4
	[[ $(getRmvblTime $itemName) -eq $WED ]] || return 5
	grep "$itemName.*[Ww]arning"<<<"$holdallOutput" >/dev/null || return 6
	return 0
}









main(){
	[[ -f $HOST ]] && (echo "there is a file with the name $HOST that I wanted to use as a folder name"; exit 1)
	[[ -f $RMVBL ]] && (echo "there is a file with the name $RMVBL that I wanted to use as a folder name"; exit 2)
	
	echo
	# delete contents of $HOST and $RMVBL
	echo "deleting $HOST"
	# ls $HOST
	rm -Ir $HOST
	echo "deleting $RMVBL"
	# ls $RMVBL
	rm -Ir $RMVBL
	echo
	
	[[ -d $HOST ]] || mkdir $HOST
	[[ -d $RMVBL ]] || mkdir $RMVBL
	
	# get a list of all the units that have been declared above by self-grepping (!)
	listOfUnits="$(grep -o '^unit[0-9][0-9][0-9][a-zA-Z0-9]*(){\s*$' $PROGNAME | grep -o '^unit[0-9]*' | sort | uniq)"
	
	# run all the initialisers
	echo "initialising..."
	for unit in $listOfUnits
	do
		${unit}Initialise
	done
	echo "initialised"
	
	echo
	echo "running holdall"
	# run holdall
	readonly holdallOutput="$(bash holdall.sh -b 1 -a holdAllTesterSimulatedRmvbl)" # store output in GLOBAL VARIABLE!
	echo "_________________________________________________________________________________"
	echo "$holdallOutput"
	echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
	
	# run all the checkers
	echo 
	echo "evaluating tests..."
	# local failures=0
	for unit in $listOfUnits
	do
		${unit}Check
		unitExitVal=$?
		[[ $unitExitVal -eq 0 ]] && echo "$unit OK" || echo "$unit fail state $unitExitVal" #; failures=$((failures+1)); echo "failures=$failures" )
	done
	# echo "there were $failures failures"
	echo
	echo "end of script"
}

main $@






