#!/bin/bash

# the "unofficial bash strict mode" convention, recommended by Aaron Maxwell http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -e
set -u
set -o pipefail
# SAFE MODE NOTES:
# in safe mode the programs exits if 
# - an uninitiated variable is accessed
# - a command has a false UNTESTED exit status. This means 'false' exits, but 'false || echo failed' does not. This elevates exit statuses to behave more like exceptions do (in languages that have them - bash doesn't have them).
# - a command has a false exit status inside a pipe. So 'diff $file $differentFile | grep regex' would cause an exit because diff exits false even though grep exits 0.
#
# SAFE MODE WARNING:
# when defining a function, be careful with its exit status. 
# examples: Command 'false && true' is OK, will not exit
# If 'false && true' is the LAST command in a function then the function's return value is false and the program exits!
# This is confusing because a command 'false && true' at OTHER positions in the code would NOT result in an exit!

trap 'finally' 0 # fun function "finally" if any command causes an exit (which, in strict mode, many commands might do)
finally(){
        echo "TRAP: command $BASH_COMMAND caused an exit. Its exit status was $?";
}

readonly TRUE=TRUE # can be any unique string
readonly FALSE=FALSE # can be any unique string

#readonly ARGS=$@
readonly PROGNAME="$(basename "$0")"
readonly PROGDIR="$(readlink -m "$(dirname $0)")"
readonly DEFAULTNOOFBACKUPSTOKEEP=2

readonly HOSTLOGFILE="$HOME"/"$PROGNAME"_Log # /var/log/holdall # one doesn't always have write access to /var/log?
readonly LOGFILEMAXLENGTH=5000

# letters for user to type to make menu selections - so make them easy and intuitive
readonly YES=y
readonly CANCEL=n
readonly NOOVRD=x
readonly OVRDHOSTTORMVBL=2
readonly OVRDRMVBLTOHOST=8
readonly OVRDMERGEHOSTTORMVBL=4
readonly OVRDMERGERMVBLTOHOST=6
readonly OVRDSYNC=s
readonly OVRDERASERECORD=e
readonly OVRDERASEITEM=d
readonly OVRDDELFROMLOCSLIST=j
readonly OVRDAREYOUSUREYES=!

# unique letter codes for passing arguments (not seen by user)
readonly DIRECTIONRMVBLTOHOST=SDRTH
readonly DIRECTIONHOSTTORMVBL=SDHTR

# error messages - explain why the program quits
readonly ERRORMESSAGENoRsync="error: rsync is not installed on the system. This program uses rsync. Use your package manager to install it."
readonly ERRORMESSAGENoOfArgs="error: wrong number of arguments provided - use $PROGNAME -h for help. "
readonly ERRORMESSAGEUnreadableLocsList="error: errorPermissionsLocsList: couldn't read the locations-list file."
readonly ERRORMESSAGEUnwritableLocsList="error: errorPermissionsLocsList: couldn't write to the locations-list file."
readonly ERRORMESSAGENonexistentRmvbl="error: errorPermissionsRmvbl: removable drive directory nonexistent. "
readonly ERRORMESSAGEUnreadableRmvbl="error: errorPermissionsRmvbl: removable drive directory unreadable. "
readonly ERRORMESSAGEUnwritableRmvbl="error: errorPermissionsRmvbl: removable drive directory unwritable. "
readonly ERRORMESSAGEPermissionsSyncStatusFile="error: errorPermissionsSyncStatusFile: could not read/write syncStatusFile. "

# warning messages - explain why current item can't be synced
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

readonly MESSAGEAlreadyInSync="No changes since last synchronisation. "
readonly MESSAGESyncingRmvblToHost="Syncing removable drive >> host"
readonly MESSAGESyncingHostToRmvbl="Syncing host >> removable drive"
readonly MESSAGEMergingRmvblToHost="Merging removable drive >> host"
readonly MESSAGEMergingHostToRmvbl="Merging host >> removable drive"

# text for the summary table
summary="ITEM HOST RMVBL TYPE" # this is a non-readonly global variable! Each line of the summary is appended to this variable as we go.
readonly SUMMARYTABLEsyncHostToRmvbl=". ->| sync"
readonly SUMMARYTABLEsyncRmvblToHost="|<- . sync"
readonly SUMMARYTABLEmergeHostToRmvbl=". +>| merge"
readonly SUMMARYTABLEmergeRmvblToHost="|<+ . merge"
readonly SUMMARYTABLEerror="! ! error"
readonly SUMMARYTABLEsyncHostToRmvblError=". >x| sync_error_"
readonly SUMMARYTABLEsyncRmvblToHostError="|x< . sync_error_"
readonly SUMMARYTABLEmergeHostToRmvblError=". >x| merge_error_"
readonly SUMMARYTABLEmergeRmvblToHostError="|x< . merge_error_"

readonly SUMMARYTABLEdidNotAllowFirstTimeSyncToRmvbl=". x first-time_sync_cancelled"
readonly SUMMARYTABLEdidNotAllowFirstTimeSyncToHost="x . first-time_sync_cancelled"

readonly SUMMARYTABLEskip=". . skip"
readonly SUMMARYTABLEfork="? ? forked"



readonly LOTSOFDASHES="----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------" # variable provided for cutting dashes from in echoTitle

# ---------- TO DO ----------
# implement checking if an itemHostLoc is a subfolder of itemRmvblLoc, or vice-versa
# need to review behaviour re. sync vs. merge conflicted files (as opposed to folders) - may not be behaving in a transparent way
# add a status mode where it prints the sync status of every item on the removable drive re. hosts, etc.
# add to scanLocsList a check for items on the rmvbl that are not synced with any hosts, offer to delete them
# change the -s option's function to READLINK of the "loc|alias" or "loc" text given, because it's convenient to type a relative path, but the path entered should be an absolute path
# add option to display, in user-readable format, the current status of all hosts re. being up-to-date and their last sync time.
# add a check that disallows items and hosts that are CALLED a keyword like LASTSYNCDATE, UPTODATEHOSTS, and possibly also ...'-removed-XXXX-XX-XX~' 
# move these lines INSIDE chooseVersionDialog : echo "$itemName: status file: synced on $(readableDate $itemSyncTime)"
# consider redirect input using units, instead of getting all user input from /dev/tty, so that person running program can still choose to send it input from somewhere else should they want to, like any other program
# in fact, generally review the programs use of stdout and stderr !
# merges create a mod time that is the same as the sync time - this may be confusing - write something that deals with it
# make merges write a timestamp to destination that is ten seconds after the copy time (i.e. ten seconds in the future), so that a merge is correctly recognised as a modification
# make automatic mode require "number of backups to keep" setting be at least 1
# analyseLocsList does a check for two items being subfolders of each other. This is just comparing the strings though. It gives a false positive for subfolders if you sync e.g. $HOME/work and $HOME/work-other. Fix this.
# the way ADDEDLOCATION is used means that only one new location can be added at a time
# SED DELIMETERS: test if it can handle paths with characters in them like : when we are using those as delimeters...?!
# ---------------------------

# these getters aren't encapsulation, they're just for making the code neater elsewhere
getPretend(){ 
	if [[ $PRETEND == "on" ]]; then return 0; else return 1; fi 
}
getVerbose(){
	if [[ $VERBOSE == "on" ]]; then return 0; else return 1; fi 
}
getPermission(){
	# if we're not in interactive mode then simply return true
	if [[ $INTERACTIVEMODE != "on" ]]; then return 0; fi 
	# else we are in interactive mode so ask for permission
	local prompt="$1"
	echo "    $prompt"
	local input=""
	read -p '    (interactive mode) proceed? y/n : ' input </dev/tty
	if [[ "$input" == "y" ]]
	then
		echo "    (interactive mode) proceeding"
		return 0
	else
		echo "    (interactive mode) permission DENIED - skipping"
		return 1
	fi
}
DEBUG="off"
# DEBUG="on"
getDebug(){
	if [[ $DEBUG == "on" ]]; then return 0; else return 1; fi 
}

echoToLog(){ # echo $1 to log with a timestamp and hostname
	getPretend || echo "$(date +%F,%R), $HOSTNAME, $1" >> "$LOGFILE" # the log file on the rmvbl drive, which will contain info concerning all hosts
	getPretend || echo "$(date +%F,%R), $HOSTNAME, $1" >> "$HOSTLOGFILE" # the log file on the host, which will contain info concerning this host only
	return 0
}
echoTitle(){ # echo $1 with a line of dashes
	local title=$1
	echo -n "----"
	printf "%s%s \n" "$title" ${LOTSOFDASHES:0:(($(tput cols)-${#title}-20))}
	# (where tput cols is the width of the current terminal, ${#title} is the length of the title, and leave a gap of 20 chars at the right side of the title)
	return 0
}
readableDate(){ # convert seconds-since-epoch to human-readable
	local dateInSecondSinceEpoch=$1
	echo $(date --date=@$dateInSecondSinceEpoch +%c)
	return 0
}
appendLineToSummary(){
	summary="$summary\n$1"
	return 0
}
generateBackupName(){
	local destLoc="$1"
	local backupName=$(dirname "$destLoc")/$(basename "$destLoc")-removed-$(date +%F-%H%M)~
	echo "$backupName"
	return 0
}
noRsync(){ # deal with lack of rsync - NOT TESTED =P
	echo $ERRORMESSAGENoRsync
	exit 3
}
copyErrorExit(){
        local exitVal=$?
        echo "There was an error with the copy - exited with status $exitVal"
        echoToLog "There was an error with the copy - exited with status $exitVal"
        echo "Aborting $PROGNAME..."
        exit $exitVal
}

modTimeOf(){
	# returns the latest mod time of argument $1
	# if passed a file, it returns the mod time of the file, 
	# if passed a directory, returns the latest mod time of the directory, its subdirectories, and its contained files.
	# in the format seconds since epoch
	
	local queriedItem="$1"
	if [[ ! -e "$queriedItem" ]]; then echo "modTimeOf called on nonexistent file/folder $queriedItem - hard-coded mistake exists"; exit 103; fi
	
	# on UBUNTU 16.04 there is a BUG with du, so this function has been modified to work around it!
	# du --time --time-style=+%s has a BUG that cause it to return values wrong by one hour.
	# du --time --time-style=+%c seems to work correctly, however.
	# so must use du for human-readable time and then date to convert to seconds-since epoch
	
	# the following command is:
        # du time \
        # | last line of that, meaning overall mod time
        # | grep that line for a date in the %c format, assuming year is between 1900 and 2099
        duRecursiveModTime="$(\
        du --time --time-style=+%c "$queriedItem" \
        | tail -n 1 \
        | grep -o '[MTWTFS][a-z][a-z] [0-9][0-9] [JFMASOND][a-z][a-z] [12][90][0-9][0-9] [0-9:]* [A-Z][A-Z][A-Z]' \
        )"
        # convert to seconds-since-epoch using date
        echo $(date --date="$duRecursiveModTime" +%s)
        return 0
	
	# the following is DEPRECATED due to the BUG that exists for du in UBUNTU 16.04
	# next command and its regex mean: 
	# 1. recursively get last mod time of file/folder system - output format is [a list of entries] <size in bytes> <mod time> <file/folder name>
	# 2. use sed to remove the <size in bytes> from the start
	# 3. use grep to get the mod time
	# 4. sort and take the last number = the greatest number = the most recent mod time of those listed
	## echo "$(du --time --time-style=+%s "$queriedItem" | tail -n 1 | sed 's/^[0-9]*\s*//' | grep -o '^[0-9]*')"
	## return 0
}

showHelp(){
	cat <<- _EOF_
	$PROGNAME HELP:
	
	$PROGNAME is for synchronising files/folders between several different 
	computers privately or over an "air-gap", using a removable drive.
	e.g. files/folders on one system are synchronised with a removable drive,
	     and then the removable drive is synchronised with the second system.
	Crucially, $PROGNAME will detect problems e.g. if a file has been forked between different computers.
	
	$PROGNAME uses rsync and by default the "--backup-dir" option is used, such that $DEFAULTNOOFBACKUPSTOKEEP synchronisations can be manually reverted.
	
	USAGE: 
	$PROGNAME [OPTIONS: h,p,v,a,i,l,s,f,b] syncTargetFolder
	  - "syncTargetFolder" should be the removable drive directory, e.g. /media/USBStick
	
	OPTIONS:
	  -h	display this message and exit
	  -p	run in pretend mode - do not write to disk, only pretend to. Use to safely preview the program.
	  -v	run in verbose mode - display extra messages
	  -a	run in automatic mode - does not prompt for input (does not apply to interactive mode)
	  -i	run in interactive mode - user must approve or refuse each rsync and rm command individually
	  -l	display a list of synced/syncable items only, do not sync.
	  -s    use to append a NEW location to the locations-list file e.g. "-s work/docs/reports" or "-s work/docs/reports|accountingReports" . Then proceeds with sync.
	  -f	give this option and then a locations-list file to override the default. If not present a template will be created.
	  -b    give this option and then a custom number of backups to keep when writing (to override default = $DEFAULTNOOFBACKUPSTOKEEP). 0 is allowed.
	
	SETUP:
	On first-time run a locations-list file will be created.
	To synchronise a file/folder you will need to put its location into the locations-list file. You can edit 
	the locations-list file directly or use the -s option to add one location at a time.
	On first-time run user must approve creation of a new sync status file.

	THE LOCATIONS-LIST FILE:
	On the removable drive there is a separate locations-list file for each computer you sync with.
	(The default filename for this host is syncLocationsOn_$HOSTNAME)
	Inside the locations of folders/files to sync are listed, one per line.
	To copy a folder/file to a different name you can give the alternate name after a "|" delimiter - see example 2 below:
	TWO EXAMPLES:
	Imagine you ran
	   $PROGNAME /media/USBStick
	it would find the locations-list file and read the first location, which is:
	e.g. 1)
	   /home/quentin/documents/work
	it would read this line and sync "/home/quentin/documents/work" with "/media/USBStick/work"
	e.g. 2)
	   /home/quentin/documents/work|schoolWork
	it would read this line and sync "/home/quentin/documents/work" with "/media/USBStick/schoolWork"
	_EOF_
	return 0
}
usage(){
	echo "Usage: $PROGNAME [OPTIONS: h,p,v,a,i,l,s,f,b] syncTargetFolder"
	echo use $PROGNAME -h to see full help text
	return 0
}

cleanCommentsAndWhitespace(){
	local inputFile="$1"
	# three steps to clean the input
	# 1. remove comments - grep to keep only the parts of the line before any #
	# 2. remove leading whitespace - sed to replace leading whitespace with nothing
	# 3. remove trailing whitespace - sed to replace trailing whitespace with nothing
	local outputFile="$(\
		grep -o ^[^#]* "$inputFile" \
		| sed 's/^[[:space:]]*//' \
		| sed 's/[[:space:]]*$//' \
	)"
	echo "$outputFile"
	return 0
}
addLocationToLocsList(){
	local locationToAddRaw="$1"
	local locationToAdd="$(readlink -m "$locationToAddRaw")"
	echo appending the text "'$locationToAdd'" as a line at the end of the locations-list file.
	getPermission "Is that correct?" && (getPretend || echo "$locationToAdd" >> "$LOCSLIST")
	return $?
}
deleteLocationFromLocsList(){
	local locationToDeleteRaw="$1"
	echo "commenting out the line $locationToDeleteRaw from the locations-list file [for this host only]"
	getPermission "Is that correct?" && (getPretend || sed -ri "s:^\s*$locationToDeleteRaw\s*(|.*)?\s*(#.*)?$:#&:" "$LOCSLIST") # "-i" mean edit in place, "-r" means extended regex, (|.*)? means 0 or 1 instances of a | followed by any characters i.e. an optional itemAlias, (#.*)? means 0 or 1 instances of a hash followed by any characters i.e. an optional comment
	return $?
}
listLocsListContents(){
	echo ""
	echo "LIST MODE"
	echo "locations-list file has instructions to sync the following locations from this host:"
	echo "(the basename of these locations is used as the file/folder name on the removable drive, unless indicated)"
	echo ""
	echo -------synced files/folders-------
	cleanCommentsAndWhitespace "$LOCSLIST" \
	| sed \
		-e "s:|\(.*\):\t <- (syncs to different name '\1'):" 
		# using ":" instead of "/" as delimeter in "sed s-match-replace" because at runtime $RMVBLDIR will itself contain one or more "/"
	echo ""
	
	# LOCSLIST may contain e.g.
	# /folders/work1/
	# /folders/work2
	# /folders/work3|reports
	# and would want listOfItemNames to contain
	# work1
	# work2
	# reports
	# so need to do some regex to make it happen
	
	# regex used to create listOfItemNames:
	# 1: remove comments
	# 2: grep to get alises - keep only end of line backwards until any |
	# 3: sed to remove a possible trailing / from end of a folder address
	# 4: grep to get basenames - keep only from end of line backwards until any /
	# 5: grep to remove blank lines
	# 6: sort
	# 7: uniq to remove entries that are invalid because they clash with other entries - keep only non-repeated lines
	local listOfItemNames="$(\
	cleanCommentsAndWhitespace "$LOCSLIST" \
	| grep -o "[^|]*$" \
	| sed 's:^\(.*\)/$:\1:' \
	| grep -o "[^/]*$" \
	| grep -v "^\s*$" \
	| sort \
	| uniq --unique \
	)"
	
	local listOfItemNamesOnRmvbl="$(ls -B "$RMVBLDIR")"
	local listItemsNotSynced=$(comm -23 <(echo "$listOfItemNamesOnRmvbl") <(echo "$listOfItemNames"))
	# comm -23 is returning things appearing in $listOfItemNamesOnRmvbl but not in $listOfItemNames
	local listItemsNotSyncedButAreSyncable=$(grep -v "^syncStatus$" <<< "$listItemsNotSynced" | grep -v "^syncLocationsOn_" | grep -v "^syncLog$")
	# this last command hides this program's info files from the list
	
	echo -------other files/folders on the removable drive-------
	echo "$listItemsNotSyncedButAreSyncable"
	
	scanLocsList # exits if there are problems
	exit 0
}

scanLocsList(){
	analyseLocsList || xdgOpenLocsListDialogAndExit
}
analyseLocsList(){
	# check for repeated names/repeated locations
	
	# ---GUIDE TO THE PIPING/REGEX USED---
	# (because sed, piping and regular expressions have the same readability as ancient Chinese handwritten by a drunken doctor)
	# 
	# sed "s/^.*|\(.*\)/\1/" replaces e.g. "/file/addresses|alias" with "alias" and "file/addresses2" with "file/addresses2".
	# sed "s/^.*\/\(.*\)/\1/" then replaces any addresses left over with their basenames e.g. "file/addresses2" with "addresses2".
	# grep -v "^\s.*$" then strips out empty lines
	# sort then sorts alphabetically
	# uniq -d then finds adjacent repeated lines
	
	# check for names appearing more than once
	local listOfRepeatedNames=$(\
	cleanCommentsAndWhitespace "$LOCSLIST" \
	| sed -e "s/^.*|\(.*\)/\1/" -e "s/^.*\/\(.*\)/\1/" \
	| grep -v "^\s*$" \
	| sort \
	| uniq -d \
	)
	
	# grep -o "^[^|]*" replaces "/file/address|alias" with "/file/address" - i.e. strips out any alias from a line
	
	# check for items appearing more than once
	#local listOfRepeatedLocations=$(\
	#cleanCommentsAndWhitespace $LOCSLIST \
	#| sed "s/^\(.*\)|.*/\1/" \
	#| grep -v "^\s*$" \
	#| sort \
	#| uniq -d \
	#)
	local listOfLocations=$(\
	cleanCommentsAndWhitespace "$LOCSLIST" \
	| grep -o "^[^|]*" \
	| grep -v "^\s*$" \
	)
	local listOfRepeatedLocations=$(\
	echo "$listOfLocations" \
	| sort \
	| uniq -d \
	)
	
	if [[ ! -z "$listOfRepeatedNames" ]]; then
		echo ""
		echo "error: there are repeated names in the locations-list file. Please open it and check these names:"
		echo "$listOfRepeatedNames"
	fi
	if [[ ! -z "$listOfRepeatedLocations" ]]; then
		echo ""
		echo "error: there are repeated locations in the locations-list file. Please open it and check these locations:"
		echo "$listOfRepeatedLocations"
		echo ""
	fi
	if [[ ! -z "$listOfRepeatedNames" || ! -z "$listOfRepeatedLocations" ]]; then echo "You can view the locations-list file by running $PROGNAME with option -l"; return 9; fi # exit 9; fi
	
	# if there are no repeats then check for a presence of both a directory and its subdirectory (may malfunction if there are repeated names/locations)
	# (this doesn't read links, so it's just checking if locations are substrings of each other.)
	while read locationLine
	do
		# use sed to retrieve lines which start with $locationLine, then count them with wc -l. Sed output includes $locationLine itself so wc answer is always >= 1
		noOfAppearances=$(sed -n -e "\:^$locationLine:p" <<< "$listOfLocations" | wc -l) 
		if [[ "$noOfAppearances" -gt 1 ]]; then 
			echo "WARNING: $(($noOfAppearances-1)) subfolder(s) of $locationLine appears as a separate entry in the locations-list file, but folders are synced recursively, so this will duplicate data."
			# a directory and its subdirectory is a warning, not an error, since there are (uncommon) reasons for doing it. Program doesn't exit.
		fi
	done <<< "$listOfLocations"
	
	return 0
}
createLocsListTemplateDialog(){
	echo "The locations-list file $LOCSLIST does not exist."
	if [[ $AUTOMATIC == "on" ]]
	then
		echo "automatic mode set - skipping dialog asking to create a template locations-list file"
		return 0
	fi
	echo "   You can generate a new template locations-list file at $LOCSLIST"
	echo "   $YES to make a new template there"
	echo "   $CANCEL to not"
	local input=""
	read -p '   > ' input 
	if [[ $input == $YES ]]
	then
		createLocsListTemplate
		echo "new file created."
		echoToLog "created template locs list file $LOCSLIST"
	else
		echo "not generating a file"
	fi
	return 0
}
createLocsListTemplate(){
	getPretend && return 0
	# a here script
	cat <<- _EOF_ >"$LOCSLIST"
	# this file is for use with the synchronisation program $PROGNAME (in $PROGDIR)
	# This file supports comments on a line after a #.
	# give the locations of files and folders you wish to sync.
	# One item per line, format: 'address|name', where optional '|name' is used to sync things to a different name
	# 
	# --- help and examples ---
	# two examples:
	# /home/somewhere/correspondence             # this would sync  /home/somewhere/correspondence  with  /<location of removable drive>/correspondence
	# /home/somewhere/someOldReports|workStuff   # this would sync  /home/somewhere/someOldReports  with  /<location of removable drive>/workStuff
	# (where  /<location of removable drive>/ should be the location of your removable drive, specified as the argument to $PROGNAME)
	# for help see: $PROGNAME -h
	# 
	# ---(some more examples)---
	# /home/mike/payslips 
	# /home/mike/work/spreadsheets    # because I can't work without them!
	# /home/mike/Documents/contactsList.xml 
	# /home/mike/Documents/systemspecs.pdf|systemspecsOf$HOSTNAME.pdf 
	# /home/mike/Documents/myScripts 
	# /media/internalHDD/myScripts|myScriptsHDD 
	# /media/internalHDD/Pictures/motivationalPosters 
	# /home/mike/work/stupidReport.pdf|importantReading.pdf 
	# ---(end of examples)---
	_EOF_
	return 0
}
noSyncStatusFileDialog(){
	echo "could not find sync data file $SYNCSTATUSFILE."
	if [[ $AUTOMATIC != "on" ]]
	then
		echo "   Create the file?"
		echo "   $YES to create a new blank file and begin using it"
		echo "   $CANCEL to abort the program"
		local input=""
		read -p '   > ' input
	else
		echo "Automatic mode set - creating new sync status file $SYNCSTATUSFILE"
		local input=$YES
	fi
	if [[ $input == $YES ]]
	then
		getPretend || touch "$SYNCSTATUSFILE"
		echoToLog "created sync data file $SYNCSTATUSFILE"
	else
		echo "not generating a file"
	fi
	return 0
}
xdgOpenLocsListDialogAndExit(){
	local input=""
	if [[ $AUTOMATIC != "on" ]]
	then
		echo "   open the locations-list file for editing (in your default editor)?"
		echo "   $YES to open"
		echo "   $CANCEL to take no action"
		read -p '   > ' input </dev/tty 
	else
		echo "Automatic mode set - not opening the locations-list file in your default editor."
		input="$CANCEL" # obvs no point in opening the editor if the user doesn't want to have to interact
	fi
	if [[ $input == $YES ]]; then xdg-open "$LOCSLIST"; fi
	exit 9 # return 0
}
eraseItemFromStatusFileDialog(){
	local itemName="$1"
	if [[ $AUTOMATIC != "on" ]]
	then
		echo "   Erase the status for $itemName?"
		echo "   $YES to erase"
		echo "   $CANCEL to take no action"
		local input=""
		read -p '   > ' input </dev/tty # </dev/tty means read from keyboard, not from redirects. Since this is inside the redirected while loop it must avoid being redirected too
	else
		echo "Automatic mode set - erasing this item from the status"
		echo "creating backup of current status $SYNCSTATUSFILE in $SYNCSTATUSFILE.bckp"
		getPretend || cp "$SYNCSTATUSFILE" "$SYNCSTATUSFILE.bckp"
		local input=$YES
	fi
	if [[ $input == $YES ]]
	then
		echo erasing
		# erase this item from the log
		eraseItemFromStatusFile "$itemName"
	else
		echo not erasing
	fi
	return 0
}
eraseItemFromStatusFile(){
	getPretend && return 0
	local itemName="$1"
	sed -e "s/^$itemName $HOSTNAME LASTSYNCDATE .*//" -e "s/\(^$itemName UPTODATEHOSTS.*\) $HOSTNAME,\(.*\)/\1\2/" <"$SYNCSTATUSFILE" >"$SYNCSTATUSFILE.tmp" && mv "$SYNCSTATUSFILE.tmp" "$SYNCSTATUSFILE" # WATCH OUT for hard/soft quoting in sed here!
	grep -v '^\s*$' <"$SYNCSTATUSFILE" | sort >"$SYNCSTATUSFILE.tmp" && mv "$SYNCSTATUSFILE.tmp" "$SYNCSTATUSFILE"
	echoToLog "$itemName, erased from sync data file"
	return 0
}
chooseVersionDialog(){ # ARGS 1)itemName 2)itemHostLoc 3)itemHostModTime 4)itemRmvblLoc 5)itemRmvblModTime 6)itemSyncTime
	local itemName="$1"
	local itemHostLoc="$2"
	local itemHostModTime=$3
	local itemHostModTimeReadable=$(readableDate $itemHostModTime) # the '@' indicates the date format as the number of seconds since the epoch
	local itemRmvblLoc="$4"
	local itemRmvblModTime=$5
	local itemRmvblModTimeReadable=$(readableDate $itemRmvblModTime)
	local itemSyncTime=$6
	local itemSyncTimeReadable=$(readableDate $itemSyncTime)
	
	local input=""
	
	if [[ $AUTOMATIC == "on" ]]
	then
		echo -n "Automatic mode on > "
		if [[ -d "$itemRmvblLoc" ]] # if directories are forked, merge them. If a single file, do nothing.
		then
                    if [[ $itemRmvblModTime -gt $itemHostModTime ]]
                    then
                            echo "merging newer directory $itemRmvblLoc from $itemRmvblModTimeReadable onto $itemHostLoc from $itemHostModTimeReadable"
                            input=$OVRDRMVBLTOHOST
                    else 
                            if [[ $itemRmvblModTime -lt $itemHostModTime ]]
                            then
                                    echo "merging newer directory $itemHostLoc from $itemHostModTimeReadable onto $itemRmvblLoc from $itemRmvblModTimeReadable"
                                    input=$OVRDHOSTTORMVBL
                            else # then mod times must be equal
                                    echo "but both versions have the same modification time. Taking no action."
                                    input=$NOOVRD
                            fi
                    fi
                else
                    input=$NOOVRD
                fi
	else # print some information to help the user choose whether to write host>rmvbl or rmvbl>host
		echo "   USER INPUT REQUIRED  -  keep which version of itemName $itemName?"
		if [[ -d "$itemRmvblLoc" ]]
		then 
			echo "   listing FILES modified since last synchronisation"
		else
			echo "   using diff --side-by-side --suppress-common-lines"
		fi
		echoTitle " contents comparison "
		diff -y <(echo "Host (ls folder contents/file contents) on left") <(echo "Removable drive (ls folder contents/file contents) on right") || true
		diff -y <(echo "Host mod time $itemHostModTimeReadable") <(echo "Removable drive mod time $itemRmvblModTimeReadable") || true
		# (just using diff -y here so it lines up with listing below)
		echoTitle ""
		if [[ -d "$itemRmvblLoc" ]] # if a directory: show diff of recursive dir contents and list files that differ
		then
			# use a sed to remove the unwanted top-level directory address, leaving just the part of the file address relative to $itemHostLoc($itemRmvblLoc)
			local unsyncedModificationsHost=$(sed "s:^$itemHostLoc/::" <(find $itemHostLoc -newermt @$itemSyncTime | sort)) # WATCH OUT for hard/soft quoting in sed here!
			local unsyncedModificationsRmvbl=$(sed "s:^$itemRmvblLoc/::" <(find $itemRmvblLoc -newermt @$itemSyncTime | sort)) # WATCH OUT for hard/soft quoting in sed here!
			diff -y <(echo -e "$unsyncedModificationsHost") <(echo -e "$unsyncedModificationsRmvbl") || true
		else # if a file: show diff of the two files
			diff -y --suppress-common-lines "$itemHostLoc" "$itemRmvblLoc" || true
		fi
		echoTitle " please select "
		echo "   (blank if no difference)"
		# time for the dialog itself
		echo "   $NOOVRD to take no action this time (re-run to see this dialog again)"
		echo "   $OVRDHOSTTORMVBL to sync the host copy onto the removable drive copy"
		echo "   $OVRDRMVBLTOHOST to sync the removable drive copy onto the host copy"
		echo "   $OVRDMERGEHOSTTORMVBL to merge the host copy into the removable drive copy"
		echo "   $OVRDMERGERMVBLTOHOST to merge the removable drive copy into the host copy"
		read -p '   > ' input </dev/tty
        fi # endif [ automatic mode ]
	case $input in
		$OVRDHOSTTORMVBL)
			if ! getPermission "want to sync host >>> to >>> removable"; then return 1; fi
			synchronise "$itemName" $DIRECTIONHOSTTORMVBL "$itemHostLoc" "$itemRmvblLoc"
			writeToStatusFileLASTSYNCDATEnow "$itemName"
			writeToStatusFileUPTODATEHOSTSassignThisHost "$itemName"
			;;
		$OVRDRMVBLTOHOST)
			if ! getPermission "want to sync removable >>> to >>> host"; then return 1; fi
			synchronise "$itemName" $DIRECTIONRMVBLTOHOST "$itemHostLoc" "$itemRmvblLoc"
			writeToStatusFileLASTSYNCDATEnow "$itemName"
			writeToStatusFileUPTODATEHOSTSappendThisHost "$itemName"
			;;
		$OVRDMERGEHOSTTORMVBL)
			if ! getPermission "want to merge host >>> to >>> removable"; then return 1; fi
			merge "$itemName" $DIRECTIONHOSTTORMVBL "$itemHostLoc" "$itemRmvblLoc"
			writeToStatusFileUPTODATEHOSTSassignEmpty "$itemName"
			;;
		$OVRDMERGERMVBLTOHOST)
			if ! getPermission "want to merge removable >>> to >>> host"; then return 1; fi
			merge "$itemName" $DIRECTIONRMVBLTOHOST "$itemHostLoc" "$itemRmvblLoc"
			# do not write to status file, neither re. sync time nor re. which hosts are up-to-date
			;;
		*)
			appendLineToSummary "$itemName $SUMMARYTABLEskip"
			echo "$itemName: taking no action"
			;;
	esac
	return 0
}

hostMissingDialog(){
	local itemName="$1"
	local itemRmvblLoc="$2"
	local itemHostLoc="$3"
	local itemHostLocRaw="$4"
	
	# if there is a record of synchronisation, but the host [no longer] exists
	# give the options: propagate the deletion of this item to the removable drive OR reinstate it on host from removable drive copy OR cancel synchronisation i.e. delete from locs list
	echo "you can sync so that it is present on both the host and the removable drive, or sync so that it is absent from both, or cancel syncing."
	if [[ $AUTOMATIC == "on" ]]
	then
		echo -n "Automatic mode on > " 
		local input=$NOOVRD
	else
		# the dialog
		echo "   $OVRDSYNC to copy the removable drive copy onto this host (e.g. if the host version was deleted in error)"
		echo "   $OVRDDELFROMLOCSLIST to stop synchronising this item between this host and the removable drive (now and in the future), but to leave other hosts unaffected"
		echo "   $OVRDERASEITEM to erase the item from the removable drive - i.e. to propagate the deletion to other hosts, so that this item is deleted from ALL your computers"
		echo "   $NOOVRD to take no action"
		local input=""
		read -p '   > ' input </dev/tty
	fi
	
	# taking action
	case $input in
		$OVRDSYNC)
			getPermission "want to sync removable >>> to >>> host" && synchronise "$itemName" $DIRECTIONRMVBLTOHOST "$itemHostLoc" "$itemRmvblLoc"
			;;
		$OVRDERASEITEM)
			# ask "are you sure?" and look for answer $OVRDAREYOUSUREYES, which should be something that won't be typed by accident
			echo "are you sure you want to permanently delete $itemRmvblLoc ? Type $OVRDAREYOUSUREYES if you are."
			read -p '   > ' input </dev/tty
			[[ "$input" == "$OVRDAREYOUSUREYES" ]] && deleteItem "$itemRmvblLoc" || echo "$itemName: taking no action"
			;;
		$OVRDDELFROMLOCSLIST)
			deleteLocationFromLocsList "$itemHostLocRaw"
			;;
		*)
			echo "$itemName: taking no action"
			;;
	esac 
	return 0
}
rmvblMissingDialog(){
	local itemName="$1"
	local itemRmvblLoc="$2"
	local itemHostLoc="$3"
	local itemHostLocRaw="$4"
	
	# if there is a record of synchronisation, but the host [no longer] exists
	# give the options: propagate the deletion of this item to the removable drive OR reinstate it on host from removable drive copy OR cancel synchronisation i.e. delete from locs list
	echo "you can sync so that it is present on both the host and the removable drive, or sync so that it is absent from both, or cancel syncing."
	if [[ $AUTOMATIC == "on" ]]
	then
		echo -n "Automatic mode on > " 
		local input=$NOOVRD
	else
		# the dialog
		echo "   $OVRDSYNC to copy the host copy onto the removable drive (e.g. if the removable drive version was deleted in error)"
		echo "   $OVRDDELFROMLOCSLIST to stop synchronising this item between this host and the removable drive (now and in the future), but to leave other hosts' settings unaffected"
		echo "   $OVRDERASEITEM to erase the item from this host"
		echo "   $NOOVRD to take no action"
		local input=""
		read -p '   > ' input </dev/tty
	fi
	
	# taking action
	case $input in
		$OVRDSYNC)
			getPermission "want to sync host >>> to >>> removable" && synchronise "$itemName" $DIRECTIONHOSTTORMVBL "$itemHostLoc" "$itemRmvblLoc"
			;;
		$OVRDERASEITEM)
			# ask "are you sure?" and look for answer $OVRDAREYOUSUREYES, which should be something that won't be typed by accident
			echo "are you sure you want to permanently delete $itemHostLoc? Type $OVRDAREYOUSUREYES if you are."
			read -p '   > ' input </dev/tty
			[[ "$input" == "$OVRDAREYOUSUREYES" ]] && deleteItem "$itemHostLoc" || echo "$itemName: taking no action"
			;;
		$OVRDDELFROMLOCSLIST)
			deleteLocationFromLocsList "$itemHostLocRaw"
			;;
		*)
			echo "$itemName: taking no action"
			;;
	esac 
	return 0
}
deleteLocationFromLocsListDialog(){
	local itemName="$1"
	local itemHostLocRaw="$2"
	
	echo "$itemName: comment out the line for this item in the locations-list file, to cancel synchronisation (now and in the future)?"
	if [[ $AUTOMATIC == "on" ]]
	then
		echo -n "Automatic mode on > " 
		local input=$NOOVRD
	else
		# the dialog
		echo "   $OVRDDELFROMLOCSLIST to comment out this location from the locs list [for this host only]"
		echo "   $NOOVRD to take no action"
		local input=""
		read -p '   > ' input </dev/tty
	fi
	
	# taking action
	case $input in
		$OVRDDELFROMLOCSLIST)
			deleteLocationFromLocsList "$itemHostLocRaw"
			;;
		*)
			echo "$itemName: taking no action"
			;;
	esac 
	return 0
}

synchronise(){ # caller should have ALREADY obtained permission with getPermission or user input, but the pretend mode check getPretend is handled in syncSourceToDest
	# once the caller has decided which direction to sync, this function handles the multiple steps involved
	# 1. Synchronising with rsync in syncSourceToDest  2. removing old backups at dest  3. updating the status
	
	local itemName="$1"
	local syncDirection=$2
	local itemHostLoc="$3"
	local itemRmvblLoc="$4"
	
	# echoToLog "$itemName, difference: "
	# echoToLog "$(diffItems "$itemHostLoc" "$itemRmvblLoc")" # slow and uneccessary
	
	case $syncDirection in
		$DIRECTIONHOSTTORMVBL)
			echo "$itemName: $MESSAGESyncingHostToRmvbl"
			syncSourceToDest "$itemHostLoc" "$itemRmvblLoc"
			echoToLog "$itemName, host synced to removable drive"
			echoToLog "$itemName, $itemHostLoc, synced to, $itemRmvblLoc"
			removeOldBackups "$itemRmvblLoc"
			appendLineToSummary "$itemName $SUMMARYTABLEsyncHostToRmvbl"
			;;
		$DIRECTIONRMVBLTOHOST)
			echo "$itemName: $MESSAGESyncingRmvblToHost"
			syncSourceToDest "$itemRmvblLoc" "$itemHostLoc"
			echoToLog "$itemName, removable drive synced to host"
			echoToLog "$itemName, $itemRmvblLoc, synced to, $itemHostLoc"
			removeOldBackups "$itemHostLoc"
			appendLineToSummary "$itemName $SUMMARYTABLEsyncRmvblToHost"
			;;
		*)
			echo "synchronise was passed invalid argument $syncDirection, there is a hard-coded fault"
			echo "(synchronise expects $DIRECTIONRMVBLTOHOST or $DIRECTIONHOSTTORMVBL)"
			exit 101
			;;
	esac
	return 0
}

syncSourceToDest(){
	# has two structures for "getPretend" - one style prevents executing commands, the other style is always executing rsync but passing the "Pretend" setting forward into rsync --dry-run.
	local sourceLoc="$1"
	local destLoc="$2"
	
	# safety exit for people testing changes to the code - once while I was testing new code a broken command caused rsync to nearly delete work (retrieved the work from the --backup-dir folder though)
	if [[ (-z $sourceLoc) || (-z $destLoc) ]]; then echo "UNKNOWN ERROR: syncSourceToDest was passed a blank argument. Exiting to prevent data loss"; exit 104; fi
	
	# set the options string for rsync
	local shortOpts="-rtgop" # short options always used
	getVerbose && shortOpts="$shortOpts"v # if verbose then make rsync verbose too
	local longOpts="--delete" # long options always used
	if [[ $NOOFBACKUPSTOKEEP -gt 0 ]]
	then 
		# then have rsync use a backup - add 'b' and '--backup-dir=' options to the options string
		local backupName="$(generateBackupName "$destLoc")"
		shortOpts="$shortOpts"b 
		local longOptBackup="--backup-dir=$backupName" 
	else
		local longOptBackup="" # rsync must be passed "$longOptBackup" in quotes in case the path has a space in, but being passed an empty string in quotes (i.e. "$longOptBackup" where longOptBackup="") is interpreted as source=pwd (former BUG)
	fi
	getPretend && longOpts="$longOpts --dry-run" # if pretending make rsync pretend too    # note: rsync --dry-run may not always _entirely_ avoid writing to disk...?
	
	# rsync FILE/FOLDER BRANCHING BLOCK
	# for proper behaviour with directories need a slash after the source, but with files this syntax would be invalid
	if [[ -d "$sourceLoc" ]] # if it is a directory
	then
		if [[ $NOOFBACKUPSTOKEEP -gt 0 ]]
		then
			rsync $shortOpts $longOpts "$longOptBackup" "$sourceLoc"/ "$destLoc" || copyErrorExit
		else
			rsync $shortOpts $longOpts "$sourceLoc"/ "$destLoc" || copyErrorExit
		fi
		
		# after this routine completes, we go back down the stack to the calling routine, etc., 
		# and very few other commands are executed.
		# All of the other commands that are executed are OK to execute IMO even if this had failed.
		# Then a "continue" is reached in the main loop over the locationsListFile, i.e. this item is finished with
		# however, I see now that it would be easy for it to be otherwise, 
		# it would be easy for an innocent edit to make it so that a failure exit from rsync is not handled properly.
		# the code needs to be improved!
		# ideally, we would throw an exception...
		# ...but bash doesn't have exceptions :P
		
		# but this leaves the destination's top-level dir modification time to be 
		# NOW instead of that of the source, so sync this final datum before finishing
		getPretend || touch -m -d "$(date -r "$sourceLoc" +%c)" "$destLoc" # WHOAH. BE CAREFUL WITH QUOTES - but this works OK apparently
		
	else # if it is a file
		if [[ $NOOFBACKUPSTOKEEP -gt 0 ]]
		then
			rsync $shortOpts $longOpts "$longOptBackup" "$sourceLoc" "$destLoc" || copyErrorExit
		else
			rsync $shortOpts $longOpts "$sourceLoc" "$destLoc" || copyErrorExit
		fi
	fi # END rsync FILE/FOLDER BRANCHING BLOCK
	getVerbose && echo "copy complete"
	return 0
}
removeOldBackups(){ # not fully tested - e.g. not with pretend option set, not with strange exceptional cases
	local locationStem="$1"
	
	getVerbose && echo "checking for expired backups"
	local existingBackupsSorted="$(ls -d "$locationStem"-removed* | grep '^'"$locationStem"'-removed-2[0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]-[0-2][0-9][0-5][0-9]~$' | sort)" # this can return an empty string
	getVerbose && echo -e "backups existing:\n$existingBackupsSorted"
	local oldBackups="$(head --lines=-$NOOFBACKUPSTOKEEP <<<"$existingBackupsSorted")"
	
	if [[ -z $oldBackups ]]; then return 0; fi # quit if there are no old backups
	
	local rmOptsString="-r"
	getVerbose && rmOptsString="$rmOptsString"v # it's pretty clear that $rmOptsString contains either "-r" or "-rv", robustly
	#ls -1d "$locationStem"-removed* | grep '^'$locationStem'-removed-2[0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]-[0-2][0-9][0-5][0-9]~$' | sort | head --lines=-$NOOFBACKUPSTOKEEP | while read oldBackupName # loop over expired backups
	echo "$oldBackups" | while read oldBackupName # loop over expired backups
	do
		getVerbose && echo "removing old backup $oldBackupName"
		# for robust safety of the rm command, let's make sure the variable $oldBackupName contains "-removed-" followed by a date&time and then a "~", in the format -removed-YYYY-MM-DD-HHMM~ , before allowing the rm command to see it
		[[ "$oldBackupName" =~ ^[^*]*-removed-2[0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]-[0-2][0-9][0-5][0-9]~$ ]] &&  getPermission "want to remove old backup $oldBackupName" && (getPretend || rm $rmOptsString "$oldBackupName")
		[[ "$oldBackupName" =~ ^[^*]*-removed-2[0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]-[0-2][0-9][0-5][0-9]~$ ]] || echo "variable oldBackupName containing path to rm contained an invalid value '$oldBackupName'. Did not rm. Please report a bug to a maintainer."
	done
	return 0
}

statusFileEnsureExistenceOfDateLine(){
	local itemName="$1"
	grep -q "^$itemName $HOSTNAME LASTSYNCDATE .*" "$SYNCSTATUSFILE" && local dateLineExists=$TRUE || local dateLineExists=$FALSE
	[[ $dateLineExists == $FALSE ]] && (getPretend || echo "$itemName $HOSTNAME LASTSYNCDATE XXX">>"$SYNCSTATUSFILE")
	return 0
}
statusFileEnsureExistenceOfHostLine(){
	local itemName="$1"
	grep -q "^$itemName UPTODATEHOSTS.*$" "$SYNCSTATUSFILE" && local hostsLineExists=$TRUE || local hostsLineExists=$FALSE
	[[ $hostsLineExists == $FALSE ]] && (getPretend || echo "$itemName UPTODATEHOSTS">>"$SYNCSTATUSFILE")
	return 0
}
writeToStatusFileUPTODATEHOSTSassignEmpty(){
	local itemName="$1"
	statusFileEnsureExistenceOfHostLine "$itemName"
	getPretend || sed -i "s/^$itemName UPTODATEHOSTS.*/$itemName UPTODATEHOSTS/" "$SYNCSTATUSFILE" # WATCH OUT for hard/soft quoting in sed here!
	return 0
}
writeToStatusFileUPTODATEHOSTSassignThisHost(){
	local itemName="$1"
	statusFileEnsureExistenceOfHostLine "$itemName"
	getPretend || sed -i "s/^$itemName UPTODATEHOSTS.*/$itemName UPTODATEHOSTS $HOSTNAME,/" "$SYNCSTATUSFILE" # WATCH OUT for hard/soft quoting in sed here!
	return 0
}
writeToStatusFileUPTODATEHOSTSappendThisHost(){
	local itemName="$1"
	statusFileEnsureExistenceOfHostLine "$itemName"
	grep -q "^$itemName UPTODATEHOSTS.* $HOSTNAME,.*$" "$SYNCSTATUSFILE" && local alreadyOnUpToDateHostsList=$TRUE || local alreadyOnUpToDateHostsList=$FALSE
	[[ $alreadyOnUpToDateHostsList == $FALSE ]] && (getPretend || sed -i "s/^$itemName UPTODATEHOSTS\(.*\)$/$itemName UPTODATEHOSTS\1 $HOSTNAME,/" "$SYNCSTATUSFILE") # WATCH OUT for hard/soft quoting in sed here!
	return 0
}
writeToStatusFileLASTSYNCDATEnow(){
	local itemName="$1"
	statusFileEnsureExistenceOfDateLine "$itemName"
	local timeStampToSet=$(( $(date +%s) )) # i.e. the current time
	getPretend ||sed -i "s/^$itemName $HOSTNAME LASTSYNCDATE.*/$itemName $HOSTNAME LASTSYNCDATE $timeStampToSet/" "$SYNCSTATUSFILE" # WATCH OUT for hard/soft quoting in sed here!
	return 0
}


merge(){
	# similar to a normal sync, this function handles the multiple steps involved in a merge
	# 1. Merging with rsync in mergeSourceToDest  2. updating the status
	# NOTE: do merges make sense when talking about files, rather than folders?
	
	local itemName="$1"
	local mergeDirection=$2
	local itemHostLoc="$3"
	local itemRmvblLoc="$4"
	
	case $mergeDirection in
		$DIRECTIONHOSTTORMVBL)
			echo "$itemName: $MESSAGEMergingHostToRmvbl"
			mergeSourceToDest "$itemHostLoc" "$itemRmvblLoc"
			echoToLog "$itemName, host merged to removable drive"
			echoToLog "$itemName, $itemHostLoc, merged to, $itemRmvblLoc"
			appendLineToSummary "$itemName $SUMMARYTABLEmergeHostToRmvbl"
			;;
		$DIRECTIONRMVBLTOHOST)
			echo "$itemName: $MESSAGEMergingRmvblToHost"
			mergeSourceToDest "$itemRmvblLoc" "$itemHostLoc"
			echoToLog "$itemName, removable drive merged to host"
			echoToLog "$itemName, $itemRmvblLoc, merged to, $itemHostLoc"
			appendLineToSummary "$itemName $SUMMARYTABLEmergeRmvblToHost"
			;;
		*)
			echo merge was passed invalid argument $mergeDirection, there is a hard-coded fault
			echo "(merge expects $DIRECTIONRMVBLTOHOST or $DIRECTIONHOSTTORMVBL)"
			exit 101
			;;
	esac
	return 0
}
mergeSourceToDest(){
	# has two structures for "getPretend" - one style prevents executing commands, the other style is always executing rsync but passing the "Pretend" setting forward into rsync --dry-run.
	local sourceLoc="$1"
	local destLoc="$2"
		
	# set the options string for rsync
	local shortOpts="-rtgopb" # short options always used - note uses u (update) and b (backup)
	getVerbose && shortOpts="$shortOpts"v # if verbose then make rsync verbose too
	local longOpts="--suffix=-removed-$(date +%F-%H%M)~"
	getPretend && longOpts="$longOpts --dry-run" # if pretending make rsync pretend too    # note: rsync --dry-run does not always _entirely_ avoid writing to disk...?
	
	# rsync FILE/FOLDER BRANCHING BLOCK
	# for proper behaviour with directories need a slash after the source, but with files this syntax would be invalid
	if [[ -d "$sourceLoc" ]] # if it is a directory
	then
		rsync $shortOpts $longOpts "$sourceLoc"/ "$destLoc" || copyErrorExit
		
		# but the destination's top-level dir modification time should definitely be NOW
		getPretend || touch -m "$destLoc"
		
	else # if it is a file
		rsync $shortOpts $longOpts "$sourceLoc" "$destLoc" || copyErrorExit
	fi # END rsync FILE/FOLDER BRANCHING BLOCK
	
	getVerbose && echo "copy complete"
	
	return 0
}
deleteItem(){
	local destLoc="$1"
	# for robust safety of the rm/mv commands, make sure the variable $oldBackupName is of a suitable pattern
	echo "deleting $destLoc"
	if [[ $NOOFBACKUPSTOKEEP -gt 0 ]]
	then
		# if using backups then "delete" means mv to backup
		local backupName="$(generateBackupName "$destLoc")"
		[[ "$destLoc" =~ ^[^*][^*][^*]*$ ]] \
			&& getPermission "want to move item $destLoc to $backupName" \
			&& (getPretend || \
				if [[ $VERBOSE == "on" ]]; then mv -v "$destLoc" "$backupName"; else mv "$destLoc" "$backupName"; fi)
	else
		# if not using backups then "delete" means rm
		local optsString="-r"
		getVerbose && optsString="$optsString"v # it's pretty clear that $optsString contains either "-r" or "-rv", robustly
		[[ "$destLoc" =~ ^[^*][^*][^*]*$ ]] \
			&& getPermission "want to delete item $destLoc" \
			&& (getPretend || rm -i $optsString "$destLoc") # remove this "-i" option?
	fi
	[[ "$destLoc" =~ ^[^*][^*][^*]*$ ]] || echo "variable containing path to rm contained an invalid value \"$destLoc\". Did not mv/rm. Please report a bug to a maintainer."
	return 0
}

readOptions(){
	PRETEND="off"
	VERBOSE="off"
	AUTOMATIC="off"
	AUTOMATICFLAGPRESENT="no"
	NOOFBACKUPSTOKEEP=$DEFAULTNOOFBACKUPSTOKEEP
	CUSTOMLOCATIONSFILE=""
	ADDEDLOCATION=""
	LISTMODE="off"
	INTERACTIVEMODE="off"
	
	while getopts ":hpvaf:b:s:li" opt # the first colon suppress getopts' error messages and I substitute my own. The others indicate that an argument is taken.
	do
		case $opt in
		h)	showHelp; exit 0;;
		p)	readonly PRETEND="on"; echo PRETEND MODE;; # leaves messages unchanged but doesn't actually do any writes
		v)	readonly VERBOSE="on";; 
		a)	readonly AUTOMATICFLAGPRESENT="yes";; # readonly AUTOMATIC="on";; # automatically answers dialogs, does not require keyboard input
		f)	readonly CUSTOMLOCATIONSFILE="$OPTARG";;
		b)	readonly NOOFBACKUPSTOKEEP="$OPTARG";;
		s)	readonly ADDEDLOCATION="$OPTARG";;
		l)	readonly LISTMODE="on";; # If "on" program will branch away from main flow to show a list and exit early instead
		i)	readonly INTERACTIVEMODE="on";; # If "on" program lets user veto rsync or rm commands
		\?)	echo invalid option "$OPTARG"; exit 1;;
		esac
	done
	
	if [[ $AUTOMATICFLAGPRESENT == "yes" && $INTERACTIVEMODE != "on" ]]
	then 
		readonly AUTOMATIC="on"
	else
		readonly AUTOMATIC="off"
	fi

	if [[ $AUTOMATIC == "on" && $INTERACTIVEMODE == "on" ]]
	then 
		echo "cannot set automatic mode and interactive mode at once"
		exit 1
	fi
	
	# check that number of backups to keep is a positive integer === a string containing only digits
	if [[ "$NOOFBACKUPSTOKEEP" =~ .*[^[:digit:]].* ]]
	then
		echo "invalid number given to option '-b' : '$NOOFBACKUPSTOKEEP' "
		exit 1
	fi

	if [[ "$NOOFBACKUPSTOKEEP" -lt 1 && $AUTOMATICFLAGPRESENT == "yes" ]]
	then
		echo "cannot set automatic mode and zero backups"
		exit 1
	fi
	
	return 0
}

main(){
	if [[ $@ == *"--help"*  ]]; then showHelp; exit 0; fi
	readOptions "$@"
	shift $(($OPTIND-1)) # builtin function "getopts" (inside readOptions) is always used in conjunction with "shift"
	
	if [[ $# -ne 1 ]]
	then
		echo $# command-line arguments given, 1 expected
		usage	
		exit 2
	fi
	which rsync >/dev/null || noRsync # noRsync deals with eventuality that rsync isn't installed
	# could also use this method to detect presence of other required programs?
	
	# check the removable drive is ready
	readonly RMVBLDIR="$(readlink -m "$1")"
	if [[ ! -d "$RMVBLDIR" ]]; then echo $ERRORMESSAGENonexistentRmvbl; exit 4; fi
	if [[ ! -r "$RMVBLDIR" ]]; then echo $ERRORMESSAGEUnreadableRmvbl ; exit 5; fi
	if [[ ! -w "$RMVBLDIR" ]]; then echo $ERRORMESSAGEUnwritableRmvbl ; exit 6; fi
	echo "syncing with [removable drive] directory $RMVBLDIR"
	# name of log file
	readonly LOGFILE="$RMVBLDIR/syncLog"
	echoToLog "START SYNC"
	
	# check the locations-list file is ready
	if [[ -z "$CUSTOMLOCATIONSFILE" ]]
	then
		readonly LOCSLIST="$RMVBLDIR/syncLocationsOn_$HOSTNAME" 
	else
		readonly LOCSLIST="$(readlink -m "$CUSTOMLOCATIONSFILE")"
	fi
	if [[ ! -e "$LOCSLIST" ]]; then createLocsListTemplateDialog; fi
	if [[ ! -r "$LOCSLIST" ]]; then echo $ERRORMESSAGEUnreadableLocsList; exit 7; fi
	echo "reading locations from locations-list file $LOCSLIST"
	# optionally append a new entry to LOCSLIST
	if [[ ! -z "$ADDEDLOCATION" ]]
	then
		if [[ ! -w "$LOCSLIST" ]]; then echo $ERRORMESSAGEUnwritableLocsList; exit 8; fi
		addLocationToLocsList "$ADDEDLOCATION"
	fi
	# if we are in list mode then list the contents of LOCSLIST and exit
	if [[ $LISTMODE == "on" ]]
	then
		listLocsListContents # prints/explains contents of LOCSLIST and exits
	fi
	scanLocsList # exits if there are problems
	noOfEntriesInLocsList=$(cleanCommentsAndWhitespace "$LOCSLIST" \
	   | grep -v '^\s*$' \
	   | wc -l \
	)
	if [[ $noOfEntriesInLocsList -eq 0 ]]; then
		echo "the locations-list file is empty. You can:"
		echo " - add a single file/folder to it with the -s option (see help)"
		echo " - or edit the file directly at: $LOCSLIST"
		xdgOpenLocsListDialogAndExit
		exit 0
	fi
	getVerbose && echo "found $noOfEntriesInLocsList entries in locations-list file"
	
	# check the status file is ready
	readonly SYNCSTATUSFILE="$RMVBLDIR/syncStatus"
	if [[ ! -e "$SYNCSTATUSFILE" ]]; then noSyncStatusFileDialog; fi # noSyncStatusFileDialog will create a syncStatusFile or exit
	if [[ ! -r "$SYNCSTATUSFILE" || ! -w "$SYNCSTATUSFILE" ]]; then echo $ERRORMESSAGEPermissionsSyncStatusFile; exit 10; fi
	
	getVerbose && echo "leaving $NOOFBACKUPSTOKEEP backup(s) when writing"
	
	# begin iterating over the locations listed in LOCSLIST
	# command "while IFS='|' read ..."   stores line contents thus: (first thing on a line) > itemHostLoc [delimeter='|'] (the rest of the line) > itemAlias
	while IFS='|' read itemHostLocRaw itemAlias 
	do	
		#local old_IFS=$IFS # save the field separator
		#IFS='|' # the field separator used in the locsList
		#read itemHostLocRaw itemAlias <<<"$line"
		#IFS=$old_IFS # restore default field separator
		
		# This loop is in 4 sections. 1)Set the syncing file locations 2)retreive info from status file 3)retrieve info from disk 4)logic and syncing
		
		# ------ Step 1: get the item's name and locations ------
		
		local itemHostLoc=$(readlink -m "$itemHostLocRaw")
		if [[ -z "$itemAlias" ]]; then local itemName=$(basename "$itemHostLoc"); else local itemName="$itemAlias"; fi
		local itemRmvblLoc="$RMVBLDIR/$itemName"
		echoTitle " $itemName "
		
		echo "syncing $itemHostLoc with $itemRmvblLoc"
		
		# ------ Step 2: retrieve data about this item from SYNCSTATUSFILE ------
		
		# does a sync time for this item-this host exist in SYNCSTATUSFILE?
		local itemDateLine=$(grep -E "^$itemName $HOSTNAME LASTSYNCDATE [[:digit:]]{9,}" "$SYNCSTATUSFILE")
		grep -qE "^$itemName $HOSTNAME LASTSYNCDATE [[:digit:]]{9,}" "$SYNCSTATUSFILE" && local itemSyncedPreviously=$TRUE || local itemSyncedPreviously=$FALSE
		
		# if given, what is the sync time?
		if [[ $itemSyncedPreviously == $TRUE ]]
		then
			# extract the sync time from the file using a regular expression
			itemSyncTime=$(grep -oE "[[:digit:]]{9,}$" <<<"$itemDateLine") #date string format is seconds since epoch # WATCH OUT for hard/soft quoting in sed here!
		fi
		
		if [[ $itemSyncedPreviously == $TRUE ]]
		then
			getVerbose && echo "status file: synced previously on = $(readableDate $itemSyncTime)"
			echoToLog "$itemName, last synced on, $(readableDate $itemSyncTime)"
		else
			getVerbose && echo "status file: first-time sync"
			echoToLog "$itemName, first-time sync"
		fi
		
		# is this host shown as up to date with this item?
		grep -q "^$itemName UPTODATEHOSTS.* $HOSTNAME,.*$" "$SYNCSTATUSFILE" && local hostUpToDateWithItem=$TRUE || local hostUpToDateWithItem=$FALSE
		if [[ $hostUpToDateWithItem == $TRUE ]]
		then
			getVerbose && echo "status file: this host has latest changes"
			echoToLog "$itemName, this host has latest changes"
		else
			getVerbose && echo "status file: this host does not have latest changes"
			echoToLog "$itemName, this host does not have latest changes"
		fi
		
		# an example of an invalid state for the status 
		if [[ ($hostUpToDateWithItem == $TRUE) && ($itemSyncedPreviously == $FALSE) ]]
		then
			echo "$itemName: $WARNINGStatusInconsistent"
			echoToLog "$itemName, $WARNINGStatusInconsistent"
			# then offer to erase the log
			eraseItemFromStatusFileDialog "$itemName" # does or does not erase
			# then skip - it's best to take it from the top again after a big change like that
			echo "$itemName: Skipping synchronisation"
			appendLineToSummary "$itemName $SUMMARYTABLEerror"
			continue
		fi
		# so below here can assume UTD && !SP is excluded
		
		# ------ Step 3: retrieve data from this item from disk ------
		
		# check existence
		[[ -e "$itemHostLoc" ]] && local itemHostExists=$TRUE || local itemHostExists=$FALSE
		[[ -e "$itemRmvblLoc" ]] && local itemRmvblExists=$TRUE || local itemRmvblExists=$FALSE
		
		# ------ Step 4: logic ------
		
		# --------------------------------if neither removable drive nor host exist--------------------------------
		if [[ $itemHostExists == $FALSE && $itemRmvblExists == $FALSE ]]
		then
			if [[ $itemSyncedPreviously == $TRUE || $hostUpToDateWithItem == $TRUE ]]
			then 
				# BRANCH END
				echo "$itemName: $WARNINGSyncStatusForNonexistentItems"
				echoToLog "$itemName, $WARNINGSyncStatusForNonexistentItems"
				eraseItemFromStatusFileDialog "$itemName"
				appendLineToSummary "$itemName $SUMMARYTABLEerror"
			else 
				# BRANCH END
				echo "$itemName: $WARNINGNonexistentItems"
				echoToLog "$itemName, $WARNINGNonexistentItems"
				appendLineToSummary "$itemName $SUMMARYTABLEerror"
				deleteLocationFromLocsListDialog "$itemName" "$itemHostLocRaw"
				echo "$itemName: skipping "
			fi
			continue
		fi
		
		# --------------------------------if host exists, but removable drive doesn't--------------------------------
		if [[ $itemHostExists == $TRUE && $itemRmvblExists == $FALSE ]]
		then
			if [[ $itemSyncedPreviously == $FALSE ]]
			then 
				# BRANCH END
				# then sync Host onto the Rmvbl
				echo "$itemName: first time syncing from host to removable drive"
				if getPermission "want to sync host >>> to >>> removable"
				then
                                        synchronise "$itemName" $DIRECTIONHOSTTORMVBL "$itemHostLoc" "$itemRmvblLoc"
                                        writeToStatusFileLASTSYNCDATEnow "$itemName"
                                        writeToStatusFileUPTODATEHOSTSassignThisHost "$itemName"
                                else
                                        appendLineToSummary "$itemName $SUMMARYTABLEdidNotAllowFirstTimeSyncToRmvbl"
                                        continue
                                fi
			else 
				# BRANCH END
				# then we have an error, offer override
				echo "$itemName: $WARNINGSyncedButRmvblAbsent"
				echoToLog "$itemName, $WARNINGSyncedButRmvblAbsent"
				appendLineToSummary "$itemName $SUMMARYTABLEerror"
				# unexpectedAbsenceDialog "$itemName" "$itemHostLoc" "$itemRmvblLoc" "removable"
				rmvblMissingDialog "$itemName" "$itemRmvblLoc" "$itemHostLoc" "$itemHostLocRaw"
			fi
			continue
		fi
		
		# --------------------------------if removable drive exists, but host doesn't--------------------------------
		if [[ $itemHostExists == $FALSE && $itemRmvblExists == $TRUE ]]
		then
			if [[ $itemSyncedPreviously == $FALSE ]]
			then 
				# BRANCH END
				# then sync Rmvbl onto Host 
				echo "$itemName: first time syncing from removable drive to host"
                                if getPermission "want to sync removable >>> to >>> host" 
				then
                                        synchronise "$itemName" $DIRECTIONRMVBLTOHOST "$itemHostLoc" "$itemRmvblLoc" # in safe mode, exits if synchronise returns false?
                                        writeToStatusFileLASTSYNCDATEnow "$itemName"
                                        writeToStatusFileUPTODATEHOSTSappendThisHost "$itemName"
                                else
                                        appendLineToSummary "$itemName $SUMMARYTABLEdidNotAllowFirstTimeSyncToHost"
                                        continue
                                fi
			else 
				# BRANCH END
				# then we have an error, offer override
				echo "$itemName: $WARNINGSyncedButHostAbsent"
				echoToLog "$itemName, $WARNINGSyncedButHostAbsent"
				appendLineToSummary "$itemName $SUMMARYTABLEerror"
				hostMissingDialog "$itemName" "$itemRmvblLoc" "$itemHostLoc" "$itemHostLocRaw"
			fi
			continue
		fi
		
		# --------------------------------if both removable drive and host exist--------------------------------
		if [[ $itemHostExists == $TRUE && $itemRmvblExists == $TRUE ]]
		then
			# check for mismatched items
			if [[ ((-d "$itemHostLoc") && (! -d "$itemRmvblLoc")) || ((! -d "$itemHostLoc") && (-d "$itemRmvblLoc")) ]]
			then 
				echo "$itemName: $WARNINGMismatchedItems"
				echoToLog "$itemName, $WARNINGMismatchedItems"
				# offer override??
				echo "$itemName: skipping"
				appendLineToSummary "$itemName $SUMMARYTABLEerror"
				continue
			fi
			
			# ----- logic based on comparisons of modification times -----
			
			itemRmvblModTime=$(modTimeOf "$itemRmvblLoc")
			itemHostModTime=$(modTimeOf "$itemHostLoc")
			getVerbose && echo "from disk: mod time of version on host: $(readableDate $itemHostModTime)"
			getVerbose && echo "from disk: mod time of version on removable drive: $(readableDate $itemRmvblModTime)"
			echoToLog "$itemName, host  mod time, $(readableDate $itemHostModTime)"
			echoToLog "$itemName, rmvbl mod time, $(readableDate $itemRmvblModTime)"
			
			if [[ $itemSyncedPreviously == $FALSE ]]
			then
				# then the status in file is in contradiction with the state on disk
				# offer override to erase the status and proceed
				echo "$itemName: $WARNINGUnexpectedSyncStatusAbsence"
				echoToLog "$itemName, $WARNINGUnexpectedSyncStatusAbsence"
				appendLineToSummary "$itemName $SUMMARYTABLEerror"
				eraseItemFromStatusFileDialog "$itemName" # hmmm... the user may not see the advantage of erasing an "unexpectedly absent" status...
				chooseVersionDialog "$itemName" "$itemHostLoc" $itemHostModTime "$itemRmvblLoc" $itemRmvblModTime 0 # never synced before so pass a zero for sync time
				continue
			fi
			
			# so:
			# -------- below here $itemSyncedPreviously is true --------
			
			# -------- OK - normal circumstance where the host has unshared changes --------
			if [[ $itemHostModTime -gt $itemSyncTime && $itemSyncTime -gt $itemRmvblModTime && $hostUpToDateWithItem == $TRUE ]]
			then
                            # BRANCH END
                            # then have history: removable drive synced with host > removable drive hasn't been updated since that sync > host has been updated since that sync
                            getVerbose && echo "host has been modified since last sync (and removable drive hasn't)"
                            # so update the removable drive with the changes made on this host
                            # sync host to removable drive
                            if getPermission "want to sync host >>> to >>> removable"
                            then
                                synchronise "$itemName" $DIRECTIONHOSTTORMVBL "$itemHostLoc" "$itemRmvblLoc"
                                writeToStatusFileLASTSYNCDATEnow "$itemName"
                                writeToStatusFileUPTODATEHOSTSassignThisHost "$itemName"
                            else
                                chooseVersionDialog "$itemName" "$itemHostLoc" $itemHostModTime "$itemRmvblLoc" $itemRmvblModTime $itemSyncTime
                            fi
                        fi
                        
                        # -------- OK - normal circumstance(s) where the rmvbl has changes not yet shared with this host --------
                        if [[ ( $itemRmvblModTime -gt $itemSyncTime && $itemSyncTime -gt $itemHostModTime && $hostUpToDateWithItem != $TRUE ) \
                        || ( $itemSyncTime -gt $itemRmvblModTime && $itemRmvblModTime -gt $itemHostModTime && $hostUpToDateWithItem != $TRUE) ]]
                        then
                            # BRANCH END
                            # then have history: modded here > synced to removable drive > removable drive accepted change from elsewhere (possibly directly instead of from a host)
                            getVerbose && echo "removable drive has been modified since last sync (and host hasn't)"
                            # so update this host with that change
                            # sync removable drive onto host
                            if getPermission "want to sync removable >>> to >>> host"
                            then
                                synchronise "$itemName" $DIRECTIONRMVBLTOHOST "$itemHostLoc" "$itemRmvblLoc"
                                writeToStatusFileLASTSYNCDATEnow "$itemName"
                                writeToStatusFileUPTODATEHOSTSappendThisHost "$itemName"
                            else
                                chooseVersionDialog "$itemName" "$itemHostLoc" $itemHostModTime "$itemRmvblLoc" $itemRmvblModTime $itemSyncTime
                            fi
                        fi
                        
                        # -------- OK - normal circumstance(s) where the rmvbl has changes not yet shared with this host BECAUSE it was modified directly --------
                        if [[ ( $itemRmvblModTime -gt $itemSyncTime && $itemSyncTime -gt $itemHostModTime && $hostUpToDateWithItem == $TRUE ) ]]
                        then
                            # BRANCH END
                            # then item has been modified directly on the removable drive (instead of on a host)
                            echo "$itemName: Note: Apparently the removable drive has been modified directly (instead of recieving a change from a host) (host mod older than sync time older than removable drive mod but local host listed as up-to-date)"
                            echoToLog "$itemName, removable drive version was modified directly - change appeared not from a host"
                            # but that's fine, proceed.
                            # sync removable drive onto host
                            if getPermission "want to sync removable >>> to >>> host"
                            then
                                synchronise "$itemName" $DIRECTIONRMVBLTOHOST "$itemHostLoc" "$itemRmvblLoc"
                                writeToStatusFileLASTSYNCDATEnow "$itemName"
                                writeToStatusFileUPTODATEHOSTSassignThisHost "$itemName"
                            else
                                chooseVersionDialog "$itemName" "$itemHostLoc" $itemHostModTime "$itemRmvblLoc" $itemRmvblModTime $itemSyncTime
                            fi
                        fi
                        
                        # -------- OK - normal circumstance where there have been no changes since last sync --------
                        if [[ $itemSyncTime -gt $itemRmvblModTime && $itemSyncTime -gt $itemHostModTime && $hostUpToDateWithItem == $TRUE ]]
                        then
                            # BRANCH END
                            # then have history: host and removable drive were synced > no changes > now they are being synced again, i.e. no changes since last sync
                            echo "$itemName: $MESSAGEAlreadyInSync"
                            appendLineToSummary "$itemName $SUMMARYTABLEskip"
                            echo "$itemName: skipping"
                        fi
			
			# -------- error: forked --------
			if [[ ( $itemHostModTime -gt $itemSyncTime && $itemSyncTime -gt $itemRmvblModTime  && $hostUpToDateWithItem != $TRUE ) \
			|| ( $itemRmvblModTime -gt $itemSyncTime && $itemHostModTime -gt $itemSyncTime ) ]]
			then
                            # BRANCH END
                            # item has been forked
                            echo "$itemName: $WARNINGFork"
                            echoToLog "$itemName, $WARNINGFork"
                            appendLineToSummary "$itemName $SUMMARYTABLEfork"
                            echo "$itemName: status file: synced on $(readableDate $itemSyncTime)"
                            # offer override
                            chooseVersionDialog "$itemName" "$itemHostLoc" $itemHostModTime "$itemRmvblLoc" $itemRmvblModTime $itemSyncTime
                            continue
			fi
			
			# -------- all other states: error: state (should be) unreachable --------
			
			# BRANCH END
			echo "$itemName: $WARNINGUnreachableState"
			echoToLog "$itemName, $WARNINGUnreachableState"
			appendLineToSummary "$itemName $SUMMARYTABLEerror"
			echo "$itemName: status file: synced on $(readableDate $itemSyncTime)"
			if [[ $itemHostModTime -eq $itemSyncTime ]]; then echo "$itemName: host modification time is the same as sync time"; fi
			if [[ $itemRmvblModTime -eq $itemSyncTime ]]; then echo "$itemName: rmvbl modification time is the same as sync time"; fi
			if [[ $itemRmvblModTime -eq $itemHostModTime ]]; then echo "$itemName: host modification time is the same as rmvbl modification time"; fi
			# offer override
			chooseVersionDialog "$itemName" "$itemHostLoc" $itemHostModTime "$itemRmvblLoc" $itemRmvblModTime $itemSyncTime
			continue
			
		fi # end of the "if both exist" block
		
		# ----------------note that that's all four of the non/existence cases, this area is UNREACHABLE----------------
		exit 99 # if by some witchcraft this line is reached
		
	done < <(cleanCommentsAndWhitespace "$LOCSLIST") # end of while loop over items
	
	# trim log file to a reasonable length
	tail -n $LOGFILEMAXLENGTH "$LOGFILE" > "$LOGFILE.tmp" 2> /dev/null && mv "$LOGFILE.tmp" "$LOGFILE"
	tail -n $LOGFILEMAXLENGTH "$HOSTLOGFILE" > "$HOSTLOGFILE.tmp" 2> /dev/null && mv "$HOSTLOGFILE.tmp" "$HOSTLOGFILE"
	
	echoTitle " SUMMARY "
	echo -e "$summary" | column -t -s " "
	echo " ($(date))"
	
	getVerbose && echoTitle " end of script "
	return 0
}

main "$@"


