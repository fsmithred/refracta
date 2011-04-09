#!/usr/bin/env bash
# change-username.sh  (Refracta xfce/icewm version 2)
# Change user name from user to something else, for a live-build system
# that was installed with refractainstaller.
# Run once as user from $HOME with no arguments
# then once as root from /root with newname and oldname as arguments.
# Copyright fsmithred@gmail.com 2011
# License: GPL-3


newname="$1"
oldname="$2"

help_text="
    Usage:
    
        $0  <newname>  <oldname>
        "

# function to exit the script if there are errors
check_exit () {
[[ $? -eq 0 ]] || { echo "Exit due to error:  $?" ; exit 1 ; }
}



# check root
[[ $(id -un) = "root" ]] || { echo "You need to be root!" ; exit 1 ; }

# check that there are two arguments
if [[ $# -ne 2 ]] ; then
    echo "$help_text"
    exit 1
fi

# check that oldname exists
if ! $(grep -q $oldname /etc/passwd) ; then
    echo "  $oldname does not exist."
    exit 1
fi

# make sure that the user isn't logged in
if $(who | grep -q $oldname); then
    echo "
    $oldname is logged in and must log out before you can proceed.
    "
    exit 1
fi
echo "    Changing user name and group...
    "
sleep 2

# Change user name and group
usermod -l $newname $oldname ; check_exit
groupmod -n $newname $oldname ; check_exit
usermod -d /home/$newname -m $newname ; check_exit

# Show that it was done
echo "
    Checking that the name has been changed...
  "
sleep 2
if ! id $oldname  >/dev/null 2>&1 ; then
    echo "
    $oldname has been deleted.
    "
else
    echo "    Something is wrong. $oldname still exists"
    exit 1
fi
sleep 3
echo "
    Checking $newname's group memberships:
    "
if ! id $newname ; then
    exit 1
fi
sleep 3

# Ask to change newuser's password.
while true; do
    echo "
    Do you want to give $newname a new password?
    (yes or no)
    "
    read ans
    case $ans in
      [Yy]*) passwd $newname ; break ;;
      [Nn]*) break ;;
    esac
done


echo "
    This script will attempt to replace every instance of 
    /home/$oldname with /home/$newname in your user's config files.
  
    You may need to edit the properties of desktop icons for 
    terminal, file manager, browser and maybe text editor. 
    (Just reset the working directory.) 

    "
  
read -p  "    Press the ENTER key when you're ready to proceed."

for i in $(grep -r "/home/$oldname" /home/$newname/.config | awk -F":" ' { print $1 }')
do
    sed -i "s/\/home\/$oldname/\/home\/$newname/g" "$i"
    check_exit
done

:<<HOLD
# Edit /etc/gdm3/daemon.conf
while true; do
    echo "
    Edit /etc/gdm3/daemon.conf to disable graphical auto-login?
    If you don't do this, gdm3 will hang. If that happens, you can
    reboot in recovery mode and issue the command:
    update-rc.d -f gdm3 remove
    log out as root and log in as your user. Start the desktop with:
    startx

    Edit daemon.conf?  (yes or no)
    "
    read ans
    case $ans in
      [Yy]*) nano /etc/gdm3/daemon.conf ; break ;;
      [Nn]*) break ;;
    esac
done
HOLD

# Edit /etc/sudoers
while true; do
    echo "
    Edit /etc/sudoers?  (yes or no)
    You need to comment out the line that gives \"user\" absolute power,
    or you need to replace \"user\" with the new user name. 
    "
    read ans
    case $ans in
      [Yy]*) visudo ; break ;;
      [Nn]*) break ;;
    esac
done


# Disable sudo-mode for gksu
while true; do
echo "
    If you commented out the last line in /etc/sudoers in the last 
    step, answer \"yes\". However, if you changed the user name, then
    answer \"no\".
    
    Another way to ask this question - Do you want to disable sudo mode
    for gksu? If you answer \"yes\', then gksu will use root password.
    "
    read ans
    case $ans in
      [Yy]*) sed -i~ '/sudo-mode/s/true/false/' /home/"$newname"/.gconf/apps/gksu/%gconf.xml ; break ;;
      [Nn]*) break ;;
    esac
done

echo "
    Done!
    
    Restarting the xserver.   
    "
sleep 2
/etc/init.d/gdm restart

exit 0
