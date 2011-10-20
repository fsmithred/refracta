#!/usr/bin/env bash
#
# get-selections.sh
# This script creates package list files that can be used to restore
# or clone an installation with the set-selections.sh script or 
# manually, with the appropriate commands. (see footnotes)
#
# 'dpkg --get-selections'  lists all installed packages.
# 'aptitude search ~M'  lists packages that were automatically installed.
#  
# The list file names contain the date and time of creation. 


stamp=$(date +%Y%m%d_%s)

# You can change the directory where the lists are stored. Make sure
# that this variable is the same in both get-selections.sh and
# set-selections.sh. If you use "$(pwd)" the list files will be 
# in the same directory as the scripts.

list_dir="$(pwd)"


if [[ -z $list_dir ]]
then
    echo "
    You must set the list_dir variable to the
    directory you want to contain package lists.
    Exiting...
    " 
    exit 1
fi

if ! [[ -d $list_dir ]]
then
    echo "
        $list_dir does not exist.
        Exiting...
        "
    exit 1
fi

echo "
    Running dpkg --get-selections \"*\" >" "$list_dir"/package_selections_"$stamp"
    dpkg --get-selections "*" > "$list_dir"/package_selections_"$stamp"
    echo "    Done!
    "
echo "
    Now running aptitude -F '%p' search '~M' >" "$list_dir"/auto-packages_"$stamp"
    aptitude -F '%p' search '~M' > "$list_dir"/auto-packages_"$stamp"
    echo "    Done!
    "
exit 0
 


        
#    Then, on the new system:
# apt-get update
# dpkg --clear-selections
# dpkg --set-selections < package_selections_blah
# apt-get -u dselect-upgrade
#
#    after the download/install is complete
# aptitude markauto $(cat auto-packages_blah)


#  Notes:
#
# apt-get:    -u, --show-upgraded
#           Show upgraded packages; Print out a list of all packages that are
#           to be upgraded. Configuration Item: APT::Get::Show-Upgraded.
#
#             dselect-upgrade 
#           follows the changes made by dselect(1) to the Status field of available
#           packages, and performs the actions necessary to realize that state
#           (for instance, the removal of old and the installation of new
#           packages).

#
# dpkg  --clear-selections
#              Set  the requested state of every non-essential package to dein‐
#              stall.   This  is  intended  to  be  used   immediately   before
#              --set-selections, to deinstall any packages not in list given to
#              --set-selections.
#

# aptitude    markauto, unmarkauto
#                 Mark packages as automatically installed 
#                 or manually installed, respectively. 
#           
