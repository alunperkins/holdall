# holdall
linux bash script to synchronise computers over an air-gap.
Makes synchronising your computers easy, flexible and safe.


QUICK START
=======
Holdall works in a simple way: run it on your computer to synchronise selected files/folders to your removable drive. Carry the drive to your other computer and run the program again to sync with that computer. Your two computers are now in sync. Repeat with other computers, and remember to sync before and after working.

Holdall requires no install. Just run Holdall with one argument - the path to the syncing directory on the removable drive.
On a new computer you should run holdall once to initialise some files. For example let's say you're using the folder mounted at /media/thumbdrive/holdallFolder. First run:

$ bash holdall.sh /media/thumbdrive/holdallFolder

Holdall will prompt you to create a template locations-list file and tell you where it is (default is e.g. at /media/thumbdrive/holdallFolder/syncLocationsOn_thisPC). There will be some instructions inside, but it's very simple, just type locations in, one per line. For example:

/home/mike/work/expenseReports2016

/home/mike/work/performanceReviews

Now it's configured for this computer and in future you can sync all your files/folders simply by running:

$ bash holdall.sh /media/thumbdrive/holdallFolder

It will find the locations you gave it, ("/home/mike/work/performanceReviews" and "/home/mike/work/expenseReports2016") and synchronise them to the removable drive (default is to use the same names e.g. synchronises them to "/media/thumbdrive/holdallFolder/expenseReports2016" and "/media/thumbdrive/holdallFolder/performanceReviews").

Carry to your other computers and repeat. By default it uses the basename as unique names (see the comments in the locations-list file for instructions on changing names), so if the locations-list file for your other computer contains e.g. "/media/storeMasterHDD/expenseReports2016" then this has the same basename as the removable-drive folder "/media/thumbdrive/holdallFolder/expenseReports2016" and synchronises them.

Take a look at usingLocationsListFile_MikeExample.png for a diagram explaining locations-list files.


INTRODUCTION
=======

Holdall is a smart bash script for synchronising computers over an air gap.
You give a list of files/folders and it automates the process of synchronising them with a removable drive.
Then you carry your removable drive to your other computer(s), synchronise with it, and continue working.
It is designed to be more flexible than other syncing solutions.

Advantages
 - It's robust. It detects forked versions and handles every mistake, error and edge case I found or I could think of.
 - It's flexible. It syncs any set of files/folders you like, instead of watching a single folder as some alternatives do.
 - You control it. You control and own both the removable drive "server" and the connection to it.
 - Very simple to use
 - No install

If you're new to holdall, you may not feel you can trust it with your important data straight away. Try using these options:
 - with option -i it has an interactive mode. It gets permission with "y/n?" before every rsync or rm.
 - with option -p it has a pretend mode. Writes nothing to disk at all.
 - by default it keeps two backups to every sync, using rsync's -b --backup-dir options. Use -b X to keep X backups.
 - with option -v it has a verbose mode

and of course you can check the code yourself.
I always use the latest version of holdall to synchronise all my work, with no problems. I use it on Ubuntu and Debian. New users should take care when first trying holdall, especially if they have other hardware/distributions.


USING HOLDALL
=======

Basics
-----------

Syncing with a removable drive works in the usual way. You modify your file/folder on a computer and when you're done you sync to the removable drive. It knows that you were working from the latest version, and it detects that you've made a change. It then copies the host version onto the removable drive. Then you move to another computer and sync again.

Holdall checks that you haven't forked the file/folder between this computer and the previous one (let's say you haven't), and then copies the removable drive version onto the host. Then your two computers  have identical versions of the data, and you resume working.

Of course, you could just do this yourself, but if you have a lot of different things you want to sync then that could get cumbersome and error-prone. Holdall will help by automating things and by automatically detecting if you have conflicting changes, etc.


Running holdall
-----------

Holdall takes one argument - the path to the syncing directory on the removable drive.
For example let's say you're using the folder mounted at /media/thumbdrive/holdallFolder.
$ bash holdall.sh /media/thumbdrive/holdallFolder
If you're running for the first time, or a new host, it will initialise some files and print some simple instructions for editing your locations-list file.

It has command-line options for showing the help
 - -h
 - --help

and options for dealing with the location-list file
 - -l	list mode: show what you're syncing and what's on the drive (does not synchronise)
 - -s	(takes an argument) appends its argument to your locations-list file, e.g. "-s /home/docs" appends "/home/docs" to your locations-list file.
 - -f	(takes an argument) specify a locations-list file to use other than the default one.

and options for supervising the program if there's a problem or if you're being cautious
 - -i	run in interactive mode - user approves or refuses each rsync and rm command individually with "y/n?" dialogs.
 - -p	run in pretend mode - do not write to disk, only pretend to. Use to preview the program.
 - -v	run in verbose mode - display extra messages.
 - -b   (takes an argument) after copying with rsync keep a custom number of backups (default is 2). Accepts "0" as instruction to keep no backups (and delete existing backups).

and an option to force it to run
 - -a	run in automatic mode - no dialogs (interactive mode overrides this).

When handling errors such as a forked file/folder, or missing data the default behaviour is always to ask/confirm with the user before acting. These dialogs should be rare, but you can use automatic mode to make sure execution isn't interrupted.



Understanding the locations-list file(s) with an example
-----------

How does holdall know which files/folders on your computer you want to sync with the removable drive? It gets the list of files/folders you want synced from a "locations-list" file. You have to save your list of files/folders in this file so it can read them. Here's how it works: When you run the program for the first time on a new host it will create a blank locations-list file called "syncLocationsOn_HOSTNAME" (where HOSTNAME is the computer's name). Of course, the file starts off empty. You open it (with any text editor) and write in the locations of the files/folders you want synced. From then on your list is saved there. 

Now everything is set up, so when you run holdall on a host, it finds the appropriate locations-list file (the one with your hostname), and works its way down the list of locations. For each one it looks on your computer for the file/folder and in the removable drive's sync folder for a file/folder with the same name. Then it decides which one has the latest work (or if they have been forked, etc.), and then uses rsync to copy the recent version to the older version.

Using locations-list files lets you sync folders to different locations, if your computers have different directory structures, and lets you choose what to sync, if you're sharing some things across some computers but not others. You can also sync files/folders to have the same data but have different names on each computer. As well as syncing work this makes it possible to sync e.g. internet bookmark files, or system config files where compatible.

Inside a locations-list file are locations of folders/files, one per line.
To copy a folder/file to a different name you can give the alternate name after a "|" delimiter.

Look at the example below and its accompanying diagram, usingLocationsListFile_MikeExample.png.

A user, Mike, synchronises his work computer (hostname employee297) with the removable drive.
The locations-list file is "syncLocationsOn_employee297" and he has written and saved two lines in it:
 - /home/reports
 - /home/My Documents|docs

First the program reads "/home/reports/" and synchronises "/home/reports" with "reports" on the removable drive.
Next the program reads "/home/My Documents|docs" and synchronises "/home/My Documents" with "docs" on the removable drive.

Mike also has a computer at home (hostname mikePC) and a laptop (hostname mikeLaptop).
Mike now plugs his removable drive into his laptop and synchronises with it.
For his laptop the locations-list file is syncLocationsOn_mikeLaptop and it contains
 - /home/work/reports
 - /home/work/docs
 - /home/personal/pictures

First the program reads "/home/work/reports" and synchronises that folder with "reports" on the removable drive.
Next the program reads "/home/work/docs" and synchronises that folder with "docs" on the removable drive.
Now his laptop and work PC are synchronised, and between them he's free to use a different directory tree and a different name for his documents folder.
Next the program reads "/home/personal/pictures" and synchronises that folder with "pictures" on the removable drive.

Mike now synchronises with his home PC.
The locations-list file is "syncLocationsOn_mikePC" and he put in it
 - /home/pictures

Which ensures that "/home/pictures" is kept in sync with the folder "/home/personal/pictures" on his laptop.



SOME TECHNICAL DETAILS
=======

Run with --help for a description of the option flags you can use.

Don't be dismayed at the script's approximately 1000 lines. The core functionality spans a bit less than half of that. Much of that length is due to all the branching it needs to handle every possible case. As for the rest of the script, most of it is user dialogs. There are about 200 lines of comments, and about 150 are simply storing and echoing messages to the user. The --help is 50 lines. Ugly regex is split across multiple lines for readablity, etc.

The program keeps two data/log files and a set of locations-list files. They go in the folder it uses on the removable drive.

The locations-list files are called syncLocationsOn_[HOSTNAME]. It's meant to be edited by the user, so the function "cleanCommentsAndWhitespace" exists to clean it up. The program finds the locations-list file for the current host and it uses a "while read line" loop to deal with each path in the file. If two paths point to files/folders with the same name (e.g. /home/user/Documents/PDFs/ and /home/user/Downloads/PDFs/) then one must be given an alternate name (using a | in its entry in the locations-list file) to avoid clashing in the removable drive directory.

The data to describe the state of syncs and updates is in syncStatus. It's definitely not meant to be edited by the user (though if needed the program can heal certain types of damage to this file). There are two types of line in syncStatus. One type has an entry for each item and each host, and records the times when each host most recently synced each item. It has the format:

[item name] [hostname] LASTSYNCDATE [date in unix time]

When an item is synced with a host this line is updated with the current time.
The other type has an entry for each item and lists hosts with the latest changes. It has the format:

[item name] UPTODATEHOSTS [hostname 1] [hostname 2] [(...etc.)]

If the removable drive version was just copied to the host, the host is added to the list of hosts that have the latest version.
If the host version was just copied to the removable drive, all other hosts are removed from the list and only the current host has the latest version.
The dates of synchronisations, the list of hosts with the latest version, and the modification times of files, can be combined to determine if a mistake has been made including if a file/folder has been forked. I think this is the minimum information necessary.

The log is kept in syncLog. The format is

[date],[time], [HOSTNAME], [path to source of copy], copied to, [path to dest of copy], rsync exit status=[number]

and it is capped at 5000 lines long.
It's not ever consulted by the program, it just exists. I don't think it will ever be needed, but may be useful if there's confusion caused by an unwriteable file or something. Or just if someone gets in a real mess and wants to know the history of how an updated version of something was distributed to their computers.

By default the rsync command sets the -b and --backup-dir options to keep two backups. The file/folder name is given a suffix "-removed-[date and time]~" (note the tilde at the end). These backups are not synchronised with anywhere else. There is no facility for restoring from a backup, it would have to be done manually. These are just a safety net; I've never used them.

When syncing modification times are preserved. I find that if my computers use ext4 and my removable drive uses FAT32 there is some funny-looking behaviour because it will synchronise mod times of files even if their contents are identical. It's best to use the same filesystem on your disks.


**Code overview**

**This is an approximate layout of the code**

*declare readonly variables esp. long messages*

*getter functions*

getPretend()

getVerbose()

getPermission()

*utility functions*

echoToLog()

echoTitle()

readableDate()

appendLineToSummary()

diffItems()

noRsync()

modTimeOf()

*functions for displaying help*

showHelp()

usage()

*functions for dealing with the locs-list*

cleanCommentsAndWhitespace()

addLocation()

listLocsListContents()

scanLocsList()

createLocsListTemplateDialog()

createLocsListTemplate()

*functions for dealing with various errors*

noSyncStatusFileDialog()

eraseItemFromStatusFileDialog()

eraseItemFromStatusFile()

chooseVersionDialog()

unexpectedAbsenceDialog()

*functions for performing the actual copying*

synchronise()

syncSourceToDest()

removeOldBackups()

writeToStatus()

merge()

mergeSourceToDest()

*core program and logic*

readOptions()

main(){

  *basic checking that files are ready*

  *"while read line" loop over locations in locations-list file*

    *read the line from the file*

    *retrieve data from syncStatus file*

    *retrieve data from disk*

    *logic based on non/existence of files/folders, their relative mod times, and their recorded sync status*

  *done*

}

