#!/usr/bin/env bash

# authors: fsmithred and m. tornow

# set-selections.sh
# Run 'dpkg --set-selections' and 'aptitude markauto'
# using package list files created with get-selections.sh


# You can change the directory where the lists are stored. Make sure
# that this variable is the same in both get-selections.sh and
# set-selections.sh. If you use "$(pwd)" the list files will be 
# in the same directory as the scripts.

list_dir="$(pwd)"



if [[ $(id -u) -ne 0 ]]
then
    echo "
    You must be root to run this.
    "
    exit 0
fi

if [[ -z $list_dir ]]
then
    echo "
    You must set the list_dir variable to
    a directory that contains package lists.
    Exiting...
    " 
    exit 1
fi

if ! [[ -d $list_dir ]]
then
    echo "
    $list_dir directory does not exist.
    Exiting...
        "
    exit 1
fi

if [[ -z $(find "$list_dir" -type f -name "package_selections_*") ]]
then
    echo "
    $list_dir contains no package list files.
    Exiting...
          "
    exit 1
fi


# show the files in $list_dir
printf "\n File List
$(ls $list_dir)\n\n
 Choices listed by date/time stamp\n\n"


# get the date/time stamps from the package list files
# and present them as selections.
datetime=
index=0
for i in "$list_dir"/package_selections_*
do
	date_list[$index]="${i#*s_}"
	((index++))
done

PS3="
 make choice by number: "
select choice in "${date_list[@]}"
do
	datetime="$choice"
	break
done



# test to make sure the files you selected really exist.
if ! [[ -f "$list_dir"/package_selections_"$datetime" ]]
then
    echo -e "\n $list_dir"/package_selections_"$datetime" not found!
    echo -e " Exiting...\n"
    exit 1
fi

if ! [[ -f "$list_dir"/auto-packages_"$datetime" ]]
then
    echo -e "\n $list_dir"/auto-packages_"$datetime" not found!
    echo -e " Exiting...\n"
    exit 1
fi



# REAL_WORK
echo "
 Running apt-get update...
"
sleep 1
apt-get update


trap '' INT
echo "
 Running dpkg --clear-selections..."
sleep 1
dpkg --clear-selections


echo "
 Running dpkg --set-selections <" "$list_dir"/package_selections_"$datetime"...
echo
sleep 1
dpkg --set-selections < "$list_dir"/package_selections_"$datetime"
trap - INT


echo "
 Running apt-get -u dselect-upgrade...
 " 
sleep 1
apt-get -u dselect-upgrade


echo "
 Running aptitude markauto \$(cat" "$list_dir"/auto-packages_"$datetime"")..."
echo
sleep 1
aptitude markauto $(cat "$list_dir"/auto-packages_"$datetime")
echo "
    Done!. 
"

exit 0 
