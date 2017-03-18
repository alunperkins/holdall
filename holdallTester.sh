#!/bin/bash

# the "unofficial bash strict mode" convention, recommended by Aaron Maxwell http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -e
set -u
set -o pipefail

readonly PROGNAME=$(basename $0)

# this tests the logic of holdall for different mod time/history configurations, to see if it does the sync in the correct direction
# it tests files only, not folders

readonly HOST="holdAllTester SimulatedHost"
readonly RMVBL="holdAllTester SimulatedRmvbl"
readonly LOCSLIST=$RMVBL/syncLocationsOn_$HOSTNAME
readonly STATUSFILE=$RMVBL/syncStatus

# some dates in seconds since epoch
readonly MON=1388966400 # Mon 06 Jan 2014
readonly TUE=1389052800
readonly WED=1389139200
readonly THU=1389225600
readonly FRI=1389312000 # Fri 10 Jan 2014
# a time between those days and the current time
readonly SAT=1483197947 

report="UNIT@RESULT@DESCRIPTION" # global, but not readonly!

# the warning messages of the program
readonly WARNINGSyncStatusForNonexistentItems="Warning: This item does not exist on this host or the removable drive but the status file says it should."
readonly WARNINGNonexistentItems="Warning: This item does not exist on this host or the removable drive. "
readonly WARNINGStatusInconsistent="Warning: The sync status for this item is invalid: This host is stated as being up-to-date with changes but there is no synchronisation date. "
readonly WARNINGSyncedButRmvblAbsent="Warning: There is a record of synchronising this item but it is not present on the removable drive. "
readonly WARNINGSyncedButHostAbsent="Warning: There is a record of synchronising this item but it is not present on the local host. "
readonly WARNINGMismatchedItems="Warning: The items on disk have conflicting types - one is a folder but one is a file. "
readonly WARNINGUnexpectedSyncStatusAbsence="Warning: The items both exist but there is no record of a synchronisation date. "
readonly WARNINGFork="Warning: The item has been forked - the removable drive and host version have independent changes. "
readonly WARNINGUnexpectedlyNotOnUpToDateList="Warning: The item is showing no changes since last recorded sync but this host is not listed as having the latest changes. "
readonly WARNINGUnexpectedDifference="Warning: The items differ even though the items' last modifications are dated before their last sync"
readonly WARNINGUnreachableState="Warning: The items' states and sync record are in a state that should be unreachable." 

appendLineToReport(){
	report="$report\n$1"
}

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
	echo $(date -r "$RMVBL/$itemName" +%s)
}
getHostTime(){
	local itemName="$1"
	echo $(date -r "$HOST/$itemName" +%s)
}

writeToRmvbl(){
	local itemName="$1"
	local message="$2"
	echo "$message" >> "$RMVBL/$itemName"
}
writeToHost(){
	local itemName="$1"
	local message="$2"
	echo "$message" >> "$HOST/$itemName"
}

setSyncTime(){
	local itemName="$1"
	local time="$2"
	echo "$itemName $HOSTNAME LASTSYNCDATE $time" >> "$STATUSFILE"
}
getSyncTime(){
	local itemName="$1"
	local lastSyncTime=$(sed -n "s/$itemName $HOSTNAME LASTSYNCDATE \([0-9]*\)/\1/p" "$STATUSFILE")
	echo $lastSyncTime
}
setUTDTrue(){
	local itemName="$1"
	echo "$itemName UPTODATEHOSTS someOtherHost, $HOSTNAME," >> "$STATUSFILE"
}
setUTDFalse(){
	local itemName="$1"
	echo "$itemName UPTODATEHOSTS someOtherHost," >> "$STATUSFILE"
}
addToLocsList(){
	local itemName="$1"
	echo "$HOST/$itemName" >> "$LOCSLIST"
}

checkLastSyncTimeHasBeenUpdated(){
	local itemName="$1"
	local lastSyncTime=$(sed -n "s/$itemName $HOSTNAME LASTSYNCDATE \([0-9]*\)/\1/p" "$STATUSFILE")
	[[ $lastSyncTime -gt $SAT ]] && return 0 || return 1
}
checkLastSyncTimeAbsent(){
	local itemName="$1"
	grep "$itemName $HOSTNAME LASTSYNCDATE" "$STATUSFILE" && return 1 || return 0
}
checkUTDisJustThisHost(){
	local itemName="$1"
	grep -q "^$itemName UPTODATEHOSTS $HOSTNAME," "$STATUSFILE" && local hostUTD="true" || local hostUTD="false"
	grep -q "^$itemName UPTODATEHOSTS.* someOtherHost,.*$" "$STATUSFILE" && local someOtherHostUTD="true" || local someOtherHostUTD="false"
	[[ $hostUTD == true && $someOtherHostUTD == false ]] && return 0 || return 1
}
checkUTDisJustSomeOtherHost(){
	local itemName="$1"
	grep -q "^$itemName UPTODATEHOSTS someOtherHost," "$STATUSFILE" && local someOtherHostUTD="true" || local someOtherHostUTD="false"
	grep -q "^$itemName UPTODATEHOSTS.* $HOSTNAME,.*$" "$STATUSFILE" && local hostUTD="true" || local hostUTD="false"
	[[ $hostUTD == false && $someOtherHostUTD == true ]] && return 0 || return 1
}
checkUTDisThisHostAndSomeOtherHost(){
	local itemName="$1"
	grep -q "^$itemName UPTODATEHOSTS.* $HOSTNAME,.*$" "$STATUSFILE" && local hostUTD="true" || local hostUTD="false"
	grep -q "^$itemName UPTODATEHOSTS.* someOtherHost,.*$" "$STATUSFILE" && local someOtherHostUTD="true" || local someOtherHostUTD="false"
	[[ $hostUTD == true && $someOtherHostUTD == true ]] && return 0 || return 1
}
checkUTDisNoHosts(){
	local itemName="$1"
	grep -q "^$itemName UPTODATEHOSTS.* $HOSTNAME,.*$" "$STATUSFILE" && local hostUTD="true" || local hostUTD="false"
	grep -q "^$itemName UPTODATEHOSTS.* someOtherHost,.*$" "$STATUSFILE" && local someOtherHostUTD="true" || local someOtherHostUTD="false"
	[[ $hostUTD == false && $someOtherHostUTD == false ]] && return 0 || return 1
}



# NOTATION
# HE = item exists on host
# NHE = item doesn't exist on host
# RE = item exists on rmvbl
# NRE = item doesn't exist on rmvbl
# SP = items have been synced previously (i.e. a LASTSYNCDATE line exists in the syncRecord)
# NSP = items have not been sync previously
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
	local itemName="unit 001"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "old"
	writeToHost "$itemName" "new"
	
	setRmvblTime "$itemName" $MON
	setSyncTime "$itemName" $WED
	setHostTime "$itemName" $FRI
	setUTDTrue "$itemName"
}
unit001Check(){
	local itemName="unit 001"	
	[[ $(cat "$HOST/$itemName") == "new" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "new" ]] || return 2
	[[ $(cat "$RMVBL/$itemName"-removed*/*) == "old" ]] || return 3
	[[ $(getHostTime "$itemName") -eq $FRI ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $FRI ]] || return 5
	checkLastSyncTimeHasBeenUpdated "$itemName" || return 10
	checkUTDisJustThisHost "$itemName" || return 11
	return 0
}
# unit002 DESCRIPTION:  RT < ST < HT, NUTD, should say fork and merge host>rmvbl 
unit002Initialise(){
	local itemName="unit 002"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "old"
	writeToHost "$itemName" "new"
	
	setRmvblTime "$itemName" $MON
	setSyncTime "$itemName" $WED
	setHostTime "$itemName" $FRI
	setUTDFalse "$itemName"
}
unit002Check(){
	local itemName="unit 002"
	[[ $(cat "$HOST/$itemName") == "new" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "new" ]] || return 2
	[[ $(cat "$RMVBL/$itemName"-removed*) == "old" ]] || return 3
	[[ $(getHostTime "$itemName") -eq $FRI ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $FRI ]] || return 5
	grep "$itemName: $WARNINGFork"<<<"$holdallOutput" >/dev/null || return 6
	checkLastSyncTimeHasBeenUpdated "$itemName" || return 10
	checkUTDisNoHosts "$itemName" || return 11
	return 0
}
# unit003 DESCRIPTION:  HT < ST < RT, UTD, should say DMD and sync rmvbl>host 
unit003Initialise(){
	local itemName="unit 003"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "new"
	writeToHost "$itemName" "old"
	
	setHostTime "$itemName" $MON
	setSyncTime "$itemName" $WED
	setRmvblTime "$itemName" $FRI
	setUTDTrue "$itemName"
}
unit003Check(){
	local itemName="unit 003"
	[[ $(cat "$HOST/$itemName") == "new" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "new" ]] || return 2
	[[ $(cat "$HOST/$itemName"-removed*/*) == "old" ]] || return 3
	[[ $(getHostTime "$itemName") -eq $FRI ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $FRI ]] || return 5
	grep "$itemName.*removable drive.*modified directly"<<<"$holdallOutput" >/dev/null || return 6
	checkLastSyncTimeHasBeenUpdated "$itemName" || return 10
	checkUTDisJustThisHost "$itemName" || return 11
	return 0
}
# unit004 DESCRIPTION:  HT < ST < RT, NUTD, should sync rmvbl>host 
unit004Initialise(){
	local itemName="unit 004"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "new"
	writeToHost "$itemName" "old"
	
	setHostTime "$itemName" $MON
	setSyncTime "$itemName" $WED
	setRmvblTime "$itemName" $FRI
	setUTDFalse "$itemName"
}
unit004Check(){
	local itemName="unit 004"
	[[ $(cat "$HOST/$itemName") == "new" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "new" ]] || return 2
	[[ $(cat "$HOST/$itemName"-removed*/*) == "old" ]] || return 3
	[[ $(getHostTime "$itemName") -eq $FRI ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $FRI ]] || return 5
	checkLastSyncTimeHasBeenUpdated "$itemName" || return 10
	checkUTDisThisHostAndSomeOtherHost "$itemName" || return 11
	return 0
}

# units with sync time before both host time and mod time
# unit020 DESCRIPTION:  ST < HT < RT, UTD, should say fork and merge rmvbl>host 
unit020Initialise(){
	local itemName="unit 020"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "new"
	writeToHost "$itemName" "old"
	
	setSyncTime "$itemName" $MON
	setHostTime "$itemName" $WED
	setRmvblTime "$itemName" $FRI
	setUTDTrue "$itemName"
}
unit020Check(){
	local itemName="unit 020"
	[[ $(cat "$HOST/$itemName") == "new" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "new" ]] || return 2
	[[ $(cat "$HOST/$itemName"-removed*) == "old" ]] || return 3
	[[ $(getHostTime "$itemName") -eq $FRI ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $FRI ]] || return 5
	grep "$itemName: $WARNINGFork"<<<"$holdallOutput" >/dev/null || return 6
	checkLastSyncTimeHasBeenUpdated "$itemName" || return 10
	checkUTDisJustThisHost "$itemName" || return 11
	return 0
}
# unit021 DESCRIPTION:  ST < HT < RT, NUTD, should say fork and merge rmvbl>host 
unit021Initialise(){
	local itemName="unit 021"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "new"
	writeToHost "$itemName" "old"
	
	setSyncTime "$itemName" $MON
	setHostTime "$itemName" $WED
	setRmvblTime "$itemName" $FRI
	setUTDFalse "$itemName"
}
unit021Check(){
	local itemName="unit 021"
	[[ $(cat "$HOST/$itemName") == "new" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "new" ]] || return 2
	[[ $(cat "$HOST/$itemName"-removed*) == "old" ]] || return 3
	[[ $(getHostTime "$itemName") -eq $FRI ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $FRI ]] || return 5
	grep "$itemName: $WARNINGFork"<<<"$holdallOutput" >/dev/null || return 6
	checkLastSyncTimeHasBeenUpdated "$itemName" || return 10
	checkUTDisJustThisHost "$itemName" || return 11
	return 0
}
# unit022 DESCRIPTION:  ST < RT < HT, UTD, should say fork and merge host>rmvbl 
unit022Initialise(){
	local itemName="unit 022"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "old"
	writeToHost "$itemName" "new"
	
	setSyncTime "$itemName" $MON
	setRmvblTime "$itemName" $WED
	setHostTime "$itemName" $FRI
	setUTDTrue "$itemName"
}
unit022Check(){
	local itemName="unit 022"
	[[ $(cat "$HOST/$itemName") == "new" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "new" ]] || return 2
	[[ $(cat "$RMVBL/$itemName"-removed*) == "old" ]] || return 3
	[[ $(getHostTime "$itemName") -eq $FRI ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $FRI ]] || return 5
	grep "$itemName: $WARNINGFork"<<<"$holdallOutput" >/dev/null || return 6
	checkLastSyncTimeHasBeenUpdated "$itemName" || return 10
	checkUTDisNoHosts "$itemName" || return 11
	return 0
}
# unit023 DESCRIPTION:  ST < RT < HT, NUTD, should say fork and merge host>rmvbl 
unit023Initialise(){
	local itemName="unit 023"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "old"
	writeToHost "$itemName" "new"
	
	setSyncTime "$itemName" $MON
	setRmvblTime "$itemName" $WED
	setHostTime "$itemName" $FRI
	setUTDFalse "$itemName"
}
unit023Check(){
	local itemName="unit 023"
	[[ $(cat "$HOST/$itemName") == "new" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "new" ]] || return 2
	[[ $(cat "$RMVBL/$itemName"-removed*) == "old" ]] || return 3
	[[ $(getHostTime "$itemName") -eq $FRI ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $FRI ]] || return 5
	grep "$itemName: $WARNINGFork"<<<"$holdallOutput" >/dev/null || return 6
	checkLastSyncTimeHasBeenUpdated "$itemName" || return 10
	checkUTDisNoHosts "$itemName" || return 11
	return 0
}
# unit024 DESCRIPTION:  ST < RT = HT, UTD, should say fork and do nothing 
unit024Initialise(){
	local itemName="unit 024"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "new"
	writeToHost "$itemName" "also new"
	
	setSyncTime "$itemName" $MON
	setRmvblTime "$itemName" $FRI
	setHostTime "$itemName" $FRI
	setUTDTrue "$itemName"
}
unit024Check(){
	local itemName="unit 024"
	[[ $(cat "$HOST/$itemName") == "also new" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "new" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $FRI ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $FRI ]] || return 5
	grep "$itemName: $WARNINGFork"<<<"$holdallOutput" >/dev/null || return 6
	[[ $(getSyncTime "$itemName") -eq $MON ]] || return 10
	checkUTDisThisHostAndSomeOtherHost "$itemName" || return 11
	return 0
}
# unit025 DESCRIPTION:  ST < RT = HT, NUTD, should say fork and do nothing 
unit025Initialise(){
	local itemName="unit 025"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "new"
	writeToHost "$itemName" "also new"
	
	setSyncTime "$itemName" $MON
	setRmvblTime "$itemName" $FRI
	setHostTime "$itemName" $FRI
	setUTDFalse "$itemName"
}
unit025Check(){
	local itemName="unit 025"
	[[ $(cat "$HOST/$itemName") == "also new" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "new" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $FRI ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $FRI ]] || return 5
	grep "$itemName: $WARNINGFork"<<<"$holdallOutput" >/dev/null || return 6
	[[ $(getSyncTime "$itemName") -eq $MON ]] || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}

# units with sync time after both host time and rmvbl time
# unit030 DESCRIPTION:  HT < RT < ST, UTD, should say unreachable error and do nothing 
unit030Initialise(){
	local itemName="unit 030"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "new"
	writeToHost "$itemName" "old"
	
	setHostTime "$itemName" $MON
	setRmvblTime "$itemName" $WED
	setSyncTime "$itemName" $FRI
	setUTDTrue "$itemName"
}
unit030Check(){
	local itemName="unit 030"
	[[ $(cat "$HOST/$itemName") == "old" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "new" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $MON ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $WED ]] || return 5
	grep "$itemName: $WARNINGUnreachableState"<<<"$holdallOutput" >/dev/null || return 6
	[[ $(getSyncTime "$itemName") -eq $FRI ]] || return 10
	checkUTDisThisHostAndSomeOtherHost "$itemName" || return 11
	return 0
}
# unit031 DESCRIPTION:  HT < RT < ST, NUTD, should sync rmvbl>host 
unit031Initialise(){
	local itemName="unit 031"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "new"
	writeToHost "$itemName" "old"
	
	setHostTime "$itemName" $MON
	setRmvblTime "$itemName" $WED
	setSyncTime "$itemName" $FRI
	setUTDFalse "$itemName"
}
unit031Check(){
	local itemName="unit 031"
	[[ $(cat "$HOST/$itemName") == "new" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "new" ]] || return 2
	[[ $(cat "$HOST/$itemName"-removed*/*) == "old" ]] || return 3
	[[ $(getHostTime "$itemName") -eq $WED ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $WED ]] || return 5
	checkLastSyncTimeHasBeenUpdated "$itemName" || return 10
	checkUTDisThisHostAndSomeOtherHost "$itemName" || return 11
	return 0
}
# unit032 DESCRIPTION:  RT < HT < ST, UTD, should say unreachable error and do nothing 
unit032Initialise(){
	local itemName="unit 032"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "old"
	writeToHost "$itemName" "new"
	
	setRmvblTime "$itemName" $MON
	setHostTime "$itemName" $WED
	setSyncTime "$itemName" $FRI
	setUTDTrue "$itemName"
}
unit032Check(){
	local itemName="unit 032"
	[[ $(cat "$HOST/$itemName") == "new" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "old" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $WED ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $MON ]] || return 5
	grep "$itemName: $WARNINGUnreachableState"<<<"$holdallOutput" >/dev/null || return 6
	[[ $(getSyncTime "$itemName") -eq $FRI ]] || return 10
	checkUTDisThisHostAndSomeOtherHost "$itemName" || return 11
	return 0
}
# unit033 DESCRIPTION:  RT < HT < ST, NUTD, should say error and do nothing 
unit033Initialise(){
	local itemName="unit 033"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "old"
	writeToHost "$itemName" "new"
	
	setRmvblTime "$itemName" $MON
	setHostTime "$itemName" $WED
	setSyncTime "$itemName" $FRI
	setUTDFalse "$itemName"
}
unit033Check(){
	local itemName="unit 033"
	[[ $(cat "$HOST/$itemName") == "new" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "old" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $WED ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $MON ]] || return 5
	[[ $(getSyncTime "$itemName") -eq $FRI ]] || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}
# unit034 DESCRIPTION:  RT = HT < ST, UTD, this is the "no changes" state, should do nothing 
unit034Initialise(){
	local itemName="unit 034"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "old"
	writeToHost "$itemName" "also old"
	
	setRmvblTime "$itemName" $MON
	setHostTime "$itemName" $MON
	setSyncTime "$itemName" $FRI
	setUTDTrue "$itemName"
}
unit034Check(){
	local itemName="unit 034"
	[[ $(cat "$HOST/$itemName") == "also old" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "old" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $MON ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $MON ]] || return 5
	[[ $(getSyncTime "$itemName") -eq $FRI ]] || return 10
	checkUTDisThisHostAndSomeOtherHost "$itemName" || return 11
	return 0
}
# unit035 DESCRIPTION:  RT = HT < ST, NUTD, should say unreachable error and do nothing 
unit035Initialise(){
	local itemName="unit 035"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "old"
	writeToHost "$itemName" "also old"
	
	setRmvblTime "$itemName" $MON
	setHostTime "$itemName" $MON
	setSyncTime "$itemName" $FRI
	setUTDFalse "$itemName"
}
unit035Check(){
	local itemName="unit 035"
	[[ $(cat "$HOST/$itemName") == "also old" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "old" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $MON ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $MON ]] || return 5
	grep "$itemName: $WARNINGUnreachableState"<<<"$holdallOutput" >/dev/null || return 6
	[[ $(getSyncTime "$itemName") -eq $FRI ]] || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}

# units with sync time simulataneous with either host time or rmvbl time
# unit040 DESCRIPTION:  RT < HT = ST, UTD, should say error and do nothing 
unit040Initialise(){
	local itemName="unit 040"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "old"
	writeToHost "$itemName" "also old"
	
	setRmvblTime "$itemName" $MON
	setHostTime "$itemName" $FRI
	setSyncTime "$itemName" $FRI
	setUTDTrue "$itemName"
}
unit040Check(){
	local itemName="unit 040"
	[[ $(cat "$HOST/$itemName") == "also old" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "old" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $FRI ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $MON ]] || return 5
	grep "$itemName: $WARNINGUnreachableState"<<<"$holdallOutput" >/dev/null || return 6
	[[ $(getSyncTime "$itemName") -eq $FRI ]] || return 10
	checkUTDisThisHostAndSomeOtherHost "$itemName" || return 11
	return 0
}
# unit041 DESCRIPTION:  RT < HT = ST, NUTD, should say error and do nothing 
unit041Initialise(){
	local itemName="unit 041"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "old"
	writeToHost "$itemName" "also old"
	
	setRmvblTime "$itemName" $MON
	setHostTime "$itemName" $FRI
	setSyncTime "$itemName" $FRI
	setUTDFalse "$itemName"
}
unit041Check(){
	local itemName="unit 041"
	[[ $(cat "$HOST/$itemName") == "also old" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "old" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $FRI ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $MON ]] || return 5
	grep "$itemName: $WARNINGUnreachableState"<<<"$holdallOutput" >/dev/null || return 6
	[[ $(getSyncTime "$itemName") -eq $FRI ]] || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}
# unit042 DESCRIPTION:  HT = ST < RT, UTD, should say error and do nothing 
unit042Initialise(){
	local itemName="unit 042"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "new"
	writeToHost "$itemName" "old"
	
	setHostTime "$itemName" $MON
	setSyncTime "$itemName" $MON
	setRmvblTime "$itemName" $FRI
	setUTDTrue "$itemName"
}
unit042Check(){
	local itemName="unit 042"
	[[ $(cat "$HOST/$itemName") == "old" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "new" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $MON ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $FRI ]] || return 5
	grep "$itemName: $WARNINGUnreachableState"<<<"$holdallOutput" >/dev/null || return 6
	[[ $(getSyncTime "$itemName") -eq $MON ]] || return 10
	checkUTDisThisHostAndSomeOtherHost "$itemName" || return 11
	return 0
}
# unit043 DESCRIPTION:  HT = ST < RT, NUTD, should say error and do nothing 
unit043Initialise(){
	local itemName="unit 043"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "new"
	writeToHost "$itemName" "old"
	
	setHostTime "$itemName" $MON
	setSyncTime "$itemName" $MON
	setRmvblTime "$itemName" $FRI
	setUTDFalse "$itemName"
}
unit043Check(){
	local itemName="unit 043"
	[[ $(cat "$HOST/$itemName") == "old" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "new" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $MON ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $FRI ]] || return 5
	grep "$itemName: $WARNINGUnreachableState"<<<"$holdallOutput" >/dev/null || return 6
	[[ $(getSyncTime "$itemName") -eq $MON ]] || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}
# unit044 DESCRIPTION:  HT < ST = RT, UTD, should say error and do nothing 
unit044Initialise(){
	local itemName="unit 044"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "new"
	writeToHost "$itemName" "old"
	
	setHostTime "$itemName" $MON
	setSyncTime "$itemName" $FRI
	setRmvblTime "$itemName" $FRI
	setUTDTrue "$itemName"
}
unit044Check(){
	local itemName="unit 044"
	[[ $(cat "$HOST/$itemName") == "old" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "new" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $MON ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $FRI ]] || return 5
	grep "$itemName: $WARNINGUnreachableState"<<<"$holdallOutput" >/dev/null || return 6
	[[ $(getSyncTime "$itemName") -eq $FRI ]] || return 10
	checkUTDisThisHostAndSomeOtherHost "$itemName" || return 11
	return 0
}
# unit045 DESCRIPTION:  HT < ST = RT, NUTD, should say error and do nothing 
unit045Initialise(){
	local itemName="unit 045"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "new"
	writeToHost "$itemName" "old"
	
	setHostTime "$itemName" $MON
	setSyncTime "$itemName" $FRI
	setRmvblTime "$itemName" $FRI
	setUTDFalse "$itemName"
}
unit045Check(){
	local itemName="unit 045"
	[[ $(cat "$HOST/$itemName") == "old" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "new" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $MON ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $FRI ]] || return 5
	grep "$itemName: $WARNINGUnreachableState"<<<"$holdallOutput" >/dev/null || return 6
	[[ $(getSyncTime "$itemName") -eq $FRI ]] || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}
# unit046 DESCRIPTION:  RT = ST < HT, UTD, should say error and do nothing 
unit046Initialise(){
	local itemName="unit 046"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "old"
	writeToHost "$itemName" "new"
	
	setSyncTime "$itemName" $MON
	setRmvblTime "$itemName" $MON
	setHostTime "$itemName" $FRI
	setUTDTrue "$itemName"
}
unit046Check(){
	local itemName="unit 046"
	[[ $(cat "$HOST/$itemName") == "new" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "old" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $FRI ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $MON ]] || return 5
	grep "$itemName: $WARNINGUnreachableState"<<<"$holdallOutput" >/dev/null || return 6
	[[ $(getSyncTime "$itemName") -eq $MON ]] || return 10
	checkUTDisThisHostAndSomeOtherHost "$itemName" || return 11
	return 0
}
# unit047 DESCRIPTION:  RT = ST < HT, NUTD, should say error and do nothing 
unit047Initialise(){
	local itemName="unit 047"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "old"
	writeToHost "$itemName" "new"
	
	setSyncTime "$itemName" $MON
	setRmvblTime "$itemName" $MON
	setHostTime "$itemName" $FRI
	setUTDFalse "$itemName"
}
unit047Check(){
	local itemName="unit 047"
	[[ $(cat "$HOST/$itemName") == "new" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "old" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $FRI ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $MON ]] || return 5
	grep "$itemName: $WARNINGUnreachableState"<<<"$holdallOutput" >/dev/null || return 6
	[[ $(getSyncTime "$itemName") -eq $MON ]] || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}
# unit048 DESCRIPTION:  RT = ST = HT, UTD, should say error and do nothing 
unit048Initialise(){
	local itemName="unit 048"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "old"
	writeToHost "$itemName" "also old"
	
	setSyncTime "$itemName" $WED
	setRmvblTime "$itemName" $WED
	setHostTime "$itemName" $WED
	setUTDTrue "$itemName"
}
unit048Check(){
	local itemName="unit 048"
	[[ $(cat "$HOST/$itemName") == "also old" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "old" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $WED ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $WED ]] || return 5
	grep "$itemName: $WARNINGUnreachableState"<<<"$holdallOutput" >/dev/null || return 6
	[[ $(getSyncTime "$itemName") -eq $WED ]] || return 10
	checkUTDisThisHostAndSomeOtherHost "$itemName" || return 11
	return 0
}
# unit049 DESCRIPTION:  RT = ST = HT, NUTD, should say error and do nothing 
unit049Initialise(){
	local itemName="unit 049"
	addToLocsList "$itemName"
	
	writeToRmvbl "$itemName" "old"
	writeToHost "$itemName" "also old"
	
	setSyncTime "$itemName" $WED
	setRmvblTime "$itemName" $WED
	setHostTime "$itemName" $WED
	setUTDFalse "$itemName"
}
unit049Check(){
	local itemName="unit 049"
	[[ $(cat "$HOST/$itemName") == "also old" ]] || return 1
	[[ $(cat "$RMVBL/$itemName") == "old" ]] || return 2
	[[ $(getHostTime "$itemName") -eq $WED ]] || return 4
	[[ $(getRmvblTime "$itemName") -eq $WED ]] || return 5
	grep "$itemName: $WARNINGUnreachableState"<<<"$holdallOutput" >/dev/null || return 6
	[[ $(getSyncTime "$itemName") -eq $WED ]] || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}

# units 50-99 deal with cases of incomplete sync record and/or missing files/folders

# units where there is no record of a previous sync time, but the host is listed as up to date (this is unreachable)
# unit050 DESCRIPTION:  NSP, UTD, HE, RE, should say sync status is inconsistent, erase record
unit050Initialise(){
	local itemName="unit 050"
	addToLocsList "$itemName"
	writeToRmvbl "$itemName" "rmvbl content"
	setRmvblTime "$itemName" $WED
	writeToHost "$itemName" "host content"
	setHostTime "$itemName" $TUE
	setUTDTrue "$itemName"
}
unit050Check(){
	local itemName="unit 050"
	[[ $(cat "$RMVBL/$itemName") == "rmvbl content" ]] || return 2
	[[ $(getRmvblTime "$itemName") -eq $WED ]] || return 5
	[[ $(cat "$HOST/$itemName") == "host content" ]] || return 1
	[[ $(getHostTime "$itemName") -eq $TUE ]] || return 4
	grep "$itemName: $WARNINGStatusInconsistent"<<<"$holdallOutput" >/dev/null || return 6
	checkLastSyncTimeAbsent "$itemName" || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}
# unit051 DESCRIPTION:  NSP, UTD, HE, NRE, should say sync record is missing, erase record
unit051Initialise(){
	local itemName="unit 051"
	addToLocsList "$itemName"
	writeToHost "$itemName" "host content"
	setHostTime "$itemName" $TUE
	setUTDTrue "$itemName"
}
unit051Check(){
	local itemName="unit 051"
	[[ $(cat "$HOST/$itemName") == "host content" ]] || return 1
	[[ $(getHostTime "$itemName") -eq $TUE ]] || return 4
	grep "$itemName: $WARNINGStatusInconsistent"<<<"$holdallOutput" >/dev/null || return 6
	[[ -e "$RMVBL/$itemName" ]] && return 7
	checkLastSyncTimeAbsent "$itemName" || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}
# unit052 DESCRIPTION:  NSP, UTD, NHE, RE, should say sync record is missing, erase record
unit052Initialise(){
	local itemName="unit 052"
	addToLocsList "$itemName"
	writeToRmvbl "$itemName" "rmvbl content"
	setRmvblTime "$itemName" $WED
	setUTDTrue "$itemName"
}
unit052Check(){
	local itemName="unit 052"
	[[ $(cat "$RMVBL/$itemName") == "rmvbl content" ]] || return 2
	[[ $(getRmvblTime "$itemName") -eq $WED ]] || return 5
	grep "$itemName: $WARNINGStatusInconsistent"<<<"$holdallOutput" >/dev/null || return 6
	[[ -e "$HOST/$itemName" ]] && return 7
	checkLastSyncTimeAbsent "$itemName" || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}
# unit053 DESCRIPTION:  NSP, UTD, NHE, NRE, should say sync record is missing, erase record
unit053Initialise(){
	local itemName="unit 053"
	addToLocsList "$itemName"
	setUTDTrue "$itemName"
}
unit053Check(){
	local itemName="unit 053"
	grep "$itemName: $WARNINGStatusInconsistent"<<<"$holdallOutput" >/dev/null || return 6
	checkLastSyncTimeAbsent "$itemName" || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}

# units where neither item is not on host nor removable
# unit060 DESCRIPTION: SP, UTD, NHE, NRE, should say sync record for missing items, erase record
unit060Initialise(){
	local itemName="unit 060"
	addToLocsList "$itemName"
	setSyncTime "$itemName" $THU
	setUTDTrue "$itemName"
}
unit060Check(){
	local itemName="unit 060"
	grep "$itemName: $WARNINGSyncStatusForNonexistentItems"<<<"$holdallOutput" >/dev/null || return 6
	checkLastSyncTimeAbsent "$itemName" || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}
# unit061 DESCRIPTION: SP, NUTD, NHE, NRE, should say sync record for missing items, erase record
unit061Initialise(){
	local itemName="unit 061"
	addToLocsList "$itemName"
	setSyncTime "$itemName" $THU
	setUTDFalse "$itemName"
}
unit061Check(){
	local itemName="unit 061"
	grep "$itemName: $WARNINGSyncStatusForNonexistentItems"<<<"$holdallOutput" >/dev/null || return 6
	checkLastSyncTimeAbsent "$itemName" || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}
# unit062 DESCRIPTION: NSP, NUTD, NHE, NRE, should say nonexistent items
unit062Initialise(){
	local itemName="unit 062"
	addToLocsList "$itemName"
	setUTDFalse "$itemName"
}
unit062Check(){
	local itemName="unit 062"
	grep "$itemName: $WARNINGNonexistentItems"<<<"$holdallOutput" >/dev/null || return 6
	checkLastSyncTimeAbsent "$itemName" || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}

# units where the item is on the host but not the removable drive
# unit070 DESCRIPTION: SP, UTD, HE, NRE, should say rmvbl is missing
unit070Initialise(){
	local itemName="unit 070"
	addToLocsList "$itemName"
	writeToHost "$itemName" "host content"
	setHostTime "$itemName" $TUE
	setSyncTime "$itemName" $THU
	setUTDTrue "$itemName"
}
unit070Check(){
	local itemName="unit 070"
	[[ $(cat "$HOST/$itemName") == "host content" ]] || return 1
	[[ $(getHostTime "$itemName") -eq $TUE ]] || return 4
	grep "$itemName: $WARNINGSyncedButRmvblAbsent"<<<"$holdallOutput" >/dev/null || return 6
	[[ -e "$RMVBL/$itemName" ]] && return 7
	[[ $(getSyncTime "$itemName") -eq $THU ]] || return 10
	checkUTDisThisHostAndSomeOtherHost "$itemName" || return 11
	return 0
}
# unit071 DESCRIPTION: SP, NUTD, HE, NRE, should say rmvbl is missing
unit071Initialise(){
	local itemName="unit 071"
	addToLocsList "$itemName"
	writeToHost "$itemName" "host content"
	setHostTime "$itemName" $TUE
	setSyncTime "$itemName" $THU
	setUTDFalse "$itemName"
}
unit071Check(){
	local itemName="unit 071"
	[[ $(cat "$HOST/$itemName") == "host content" ]] || return 1
	[[ $(getHostTime "$itemName") -eq $TUE ]] || return 4
	grep "$itemName: $WARNINGSyncedButRmvblAbsent"<<<"$holdallOutput" >/dev/null || return 6
	[[ -e "$RMVBL/$itemName" ]] && return 7
	[[ $(getSyncTime "$itemName") -eq $THU ]] || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}
# unit072 DESCRIPTION: NSP, NUTD, HE, NRE, should sync host>rmvbl
unit072Initialise(){
	local itemName="unit 072"
	addToLocsList "$itemName"
	writeToHost "$itemName" "host content"
	setHostTime "$itemName" $TUE
	setUTDFalse "$itemName"
}
unit072Check(){
	local itemName="unit 072"
	[[ $(cat "$HOST/$itemName") == "host content" ]] || return 1
	[[ $(getHostTime "$itemName") -eq $TUE ]] || return 4
	[[ $(cat "$RMVBL/$itemName") == "host content" ]] || return 2
	[[ $(getRmvblTime "$itemName") -eq $TUE ]] || return 5
	grep "$itemName: first time syncing from host to removable drive"<<<"$holdallOutput" >/dev/null || return 6
	checkLastSyncTimeHasBeenUpdated "$itemName" || return 10
	checkUTDisJustThisHost "$itemName" || return 11
	return 0
}

# units where the item is on the removable drive but not the host
# unit080 DESCRIPTION: SP, UTD, NHE, RE, should say host is missing
unit080Initialise(){
	local itemName="unit 080"
	addToLocsList "$itemName"
	writeToRmvbl "$itemName" "rmvbl content"
	setRmvblTime "$itemName" $WED
	setSyncTime "$itemName" $THU
	setUTDTrue "$itemName"
}
unit080Check(){
	local itemName="unit 080"
	[[ $(cat "$RMVBL/$itemName") == "rmvbl content" ]] || return 2
	[[ $(getRmvblTime "$itemName") -eq $WED ]] || return 5
	grep "$itemName: $WARNINGSyncedButHostAbsent"<<<"$holdallOutput" >/dev/null || return 6
	[[ -e "$HOST/$itemName" ]] && return 7
	[[ $(getSyncTime "$itemName") -eq $THU ]] || return 10
	checkUTDisThisHostAndSomeOtherHost "$itemName" || return 11
	return 0
}
# unit081 DESCRIPTION: SP, NUTD, NHE, RE, should say host is missing
unit081Initialise(){
	local itemName="unit 081"
	addToLocsList "$itemName"
	writeToRmvbl "$itemName" "rmvbl content"
	setRmvblTime "$itemName" $WED
	setSyncTime "$itemName" $THU
	setUTDFalse "$itemName"
}
unit081Check(){
	local itemName="unit 081"
	[[ $(cat "$RMVBL/$itemName") == "rmvbl content" ]] || return 2
	[[ $(getRmvblTime "$itemName") -eq $WED ]] || return 5
	grep "$itemName: $WARNINGSyncedButHostAbsent"<<<"$holdallOutput" >/dev/null || return 6
	[[ -e "$HOST/$itemName" ]] && return 7
	[[ $(getSyncTime "$itemName") -eq $THU ]] || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}
# unit082 DESCRIPTION: NSP, NUTD, NHE, RE, should sync rmvbl>host
unit082Initialise(){
	local itemName="unit 082"
	addToLocsList "$itemName"
	writeToRmvbl "$itemName" "rmvbl content"
	setRmvblTime "$itemName" $WED
	setUTDFalse "$itemName"
}
unit082Check(){
	local itemName="unit 082"
	[[ $(cat "$HOST/$itemName") == "rmvbl content" ]] || return 1
	[[ $(getHostTime "$itemName") -eq $WED ]] || return 4
	[[ $(cat "$RMVBL/$itemName") == "rmvbl content" ]] || return 2
	[[ $(getRmvblTime "$itemName") -eq $WED ]] || return 5
	grep "$itemName: first time syncing from removable drive to host"<<<"$holdallOutput" >/dev/null || return 6
	checkLastSyncTimeHasBeenUpdated "$itemName" || return 10
	checkUTDisThisHostAndSomeOtherHost "$itemName" || return 11
	return 0
}

# unit where the host and rvmbl are both present, but there is no sync record
# unit090 DESCRIPTION: NSP, NUTD, HE, RE, HT < RT, should say sync record is missing, merge rmvbl>host
unit090Initialise(){
	local itemName="unit 090"
	addToLocsList "$itemName"
	writeToRmvbl "$itemName" "rmvbl content"
	setRmvblTime "$itemName" $WED
	writeToHost "$itemName" "host content"
	setHostTime "$itemName" $TUE
	setUTDFalse "$itemName"
}
unit090Check(){
	local itemName="unit 090"
	[[ $(cat "$HOST/$itemName") == "rmvbl content" ]] || return 1
	[[ $(getHostTime "$itemName") -eq $WED ]] || return 4
	[[ $(cat "$HOST/$itemName"-removed*) == "host content" ]] || return 3
	[[ $(cat "$RMVBL/$itemName") == "rmvbl content" ]] || return 2
	[[ $(getRmvblTime "$itemName") -eq $WED ]] || return 5
	grep "$itemName: $WARNINGUnexpectedSyncStatusAbsence"<<<"$holdallOutput" >/dev/null || return 6
	checkLastSyncTimeHasBeenUpdated "$itemName" || return 10
	checkUTDisJustThisHost "$itemName" || return 11
	return 0
}
# unit091 DESCRIPTION: NSP, NUTD, HE, RE, RT < HT, should say sync record is missing, merge host>rmvbl
unit091Initialise(){
	local itemName="unit 091"
	addToLocsList "$itemName"
	writeToRmvbl "$itemName" "rmvbl content"
	setRmvblTime "$itemName" $TUE
	writeToHost "$itemName" "host content"
	setHostTime "$itemName" $WED
	setUTDFalse "$itemName"
}
unit091Check(){
	local itemName="unit 091"
	[[ $(cat "$HOST/$itemName") == "host content" ]] || return 1
	[[ $(getHostTime "$itemName") -eq $WED ]] || return 4
	[[ $(cat "$RMVBL/$itemName"-removed*) == "rmvbl content" ]] || return 3
	[[ $(cat "$RMVBL/$itemName") == "host content" ]] || return 2
	[[ $(getRmvblTime "$itemName") -eq $WED ]] || return 5
	grep "$itemName: $WARNINGUnexpectedSyncStatusAbsence"<<<"$holdallOutput" >/dev/null || return 6
	checkLastSyncTimeHasBeenUpdated "$itemName" || return 10
	checkUTDisNoHosts "$itemName" || return 11
	return 0
}
# unit092 DESCRIPTION: NSP, NUTD, HE, RE, HT = RT, should say sync record is missing, do no merge
unit092Initialise(){
	local itemName="unit 092"
	addToLocsList "$itemName"
	writeToRmvbl "$itemName" "rmvbl content"
	setRmvblTime "$itemName" $TUE
	writeToHost "$itemName" "host content"
	setHostTime "$itemName" $TUE
	setUTDFalse "$itemName"
}
unit092Check(){
	local itemName="unit 092"
	[[ $(cat "$HOST/$itemName") == "host content" ]] || return 1
	[[ $(getHostTime "$itemName") -eq $TUE ]] || return 4
	[[ $(cat "$RMVBL/$itemName") == "rmvbl content" ]] || return 2
	[[ $(getRmvblTime "$itemName") -eq $TUE ]] || return 5
	grep "$itemName: $WARNINGUnexpectedSyncStatusAbsence"<<<"$holdallOutput" >/dev/null || return 6
	checkLastSyncTimeAbsent "$itemName" || return 10
	checkUTDisJustSomeOtherHost "$itemName" || return 11
	return 0
}




main(){
	[[ -f $HOST ]] && (echo "there is a file with the name $HOST that I wanted to use as a folder name"; exit 1)
	[[ -f $RMVBL ]] && (echo "there is a file with the name $RMVBL that I wanted to use as a folder name"; exit 2)

	local holdallCustomOptions="$@"
	if [[ ! -z $holdallCustomOptions ]]; then echo "custom options are being used - the tests are not designed for any custom options!"; fi
	
	echo	
	[[ -d "$HOST" ]] && (echo "deleting $HOST"; rm -Ir "$HOST")
	mkdir "$HOST"
	[[ -d "$RMVBL" ]] && (echo "deleting $RMVBL"; rm -Ir "$RMVBL")
	mkdir "$RMVBL"
	echo
	
	# get a list of all the unit functions that have been declared above by self-grepping (!)
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
	#readonly holdallOutput="$(bash holdall.sh $holdallCustomOptions -b 1 -a holdAllTesterSimulatedRmvbl)" # store output in GLOBAL VARIABLE!
	echo "_________________________________________________________________________________"
	bash holdall.sh $holdallCustomOptions -b 1 -a "$RMVBL" | tee holdallTesterHoldallSavedOutput
	echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
	readonly holdallOutput="$(cat holdallTesterHoldallSavedOutput)" # global variable!
	
	# run all the checkers
	echo 
	echo "evaluating tests..."
	# local failures=0
	for unit in $listOfUnits
	do
                echo "evaluating tests $unit"
		local unitDesc="$(sed -n "s/# $unit DESCRIPTION: \(.*\)/\1/p" $PROGNAME )" # save the description comment for this unit
		set +e
		${unit}Check # run this unit's checker
		unitExitVal=$?
		set -e
		[[ $unitExitVal -eq 0 ]] && appendLineToReport "$unit@OK@$unitDesc" || appendLineToReport "$unit@fail state $unitExitVal@$unitDesc" #; failures=$((failures+1)); echo "failures=$failures" )
	done
	
	echo -e "$report" | column -t -s "@"
	
	# echo "there were $failures failures"
	echo 
	if [[ ! -z $holdallCustomOptions ]]; then echo "BUT custom options were used"; fi
	echo
	echo "end of script"
}

main $@






