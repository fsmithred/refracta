#!/usr/bin/env bash
# mkunlive.sh
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

check_exit () {
if  [[ $? -ne 0 ]]
then
    echo "
    An error occured
    "
    echo
    exit 0
fi 
}

replace_inittab () {
echo "# /etc/inittab: init(8) configuration.
# inittabreplacement
# $Id: inittab,v 1.91 2002/01/25 13:35:21 miquels Exp $

# The default runlevel.
id:2:initdefault:

# Boot-time system configuration/initialization script.
# This is run first except when booting in emergency (-b) mode.
si::sysinit:/etc/init.d/rcS

# What to do in single-user mode.
~~:S:wait:/sbin/sulogin

# /etc/init.d executes the S and K scripts upon change
# of runlevel.
#
# Runlevel 0 is halt.
# Runlevel 1 is single-user.
# Runlevels 2-5 are multi-user.
# Runlevel 6 is reboot.

l0:0:wait:/etc/init.d/rc 0
l1:1:wait:/etc/init.d/rc 1
l2:2:wait:/etc/init.d/rc 2
l3:3:wait:/etc/init.d/rc 3
l4:4:wait:/etc/init.d/rc 4
l5:5:wait:/etc/init.d/rc 5
l6:6:wait:/etc/init.d/rc 6
# Normally not reached, but fallthrough in case of emergency.
z6:6:respawn:/sbin/sulogin

# What to do when CTRL-ALT-DEL is pressed.
ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

# Action on special keypress (ALT-UpArrow).
#kb::kbrequest:/bin/echo \"Keyboard Request--edit /etc/inittab to let this work.\"

# What to do when the power fails/returns.
pf::powerwait:/etc/init.d/powerfail start
pn::powerfailnow:/etc/init.d/powerfail now
po::powerokwait:/etc/init.d/powerfail stop

# /sbin/getty invocations for the runlevels.
#
# The \"id\" field MUST be the same as the last
# characters of the device (after \"tty\").
#
# Format:
#  <id>:<runlevels>:<action>:<process>
#
# Note that on most Debian systems tty7 is used by the X Window System,
# so if you want to add more getty's go ahead but skip tty7 if you run X.
#
#1:2345:respawn:/bin/login -f user </dev/tty1 >/dev/tty1 2>&1
#2:23:respawn:/bin/login -f user </dev/tty2 >/dev/tty2 2>&1
#3:23:respawn:/bin/login -f user </dev/tty3 >/dev/tty3 2>&1
#4:23:respawn:/bin/login -f user </dev/tty4 >/dev/tty4 2>&1
#5:23:respawn:/bin/login -f user </dev/tty5 >/dev/tty5 2>&1
#6:23:respawn:/bin/login -f user </dev/tty6 >/dev/tty6 2>&1
#
1:2345:respawn:/sbin/getty 38400 tty1
2:23:respawn:/sbin/getty 38400 tty2
3:23:respawn:/sbin/getty 38400 tty3
4:23:respawn:/sbin/getty 38400 tty4
5:23:respawn:/sbin/getty 38400 tty5
6:23:respawn:/sbin/getty 38400 tty6

# Example how to put a getty on a serial line (for a terminal)
#
#T0:23:respawn:/bin/login -f user </dev/tty >/dev/tty 2>&1
#T1:23:respawn:/bin/login -f user </dev/tty >/dev/tty 2>&1

# Example how to put a getty on a modem line.
#
#T3:23:respawn:/bin/login -f user </dev/tty >/dev/tty 2>&1

" > ./inittab.new
}


prepare_unlive () {          
sudo passwd
check_exit

# copy the script to /root if it's not already there
if ! [[ -f /root/${0##*/} ]] ; then
    echo "    /root/${0##*/} does not exist.
    Copying..."
    sleep 4
    sudo cp "$0" /root
    sudo chmod +x /root/${0##*/}
    check_exit
    sleep 6
fi

# make a backup copy of /etc/inittab if one doesn't exist
if ! [[ -f /root/inittab.old ]]; then
    echo "    /root/inittab.old does not exist.
    Backing up /etc/inittab"
    sleep 2
    sudo cp /etc/inittab /root/inittab.old
    check_exit
else
    echo "
    inittab was already backed up as /root/inittab.old
    "
    sleep 2
fi

# replace inittab if it wasn't already done
if $(grep -q inittabreplacement /etc/inittab) ; then
    echo "
    /etc/inittab was replaced previously. Leaving it alone.
    "
    sleep 2
else
    echo "    Replacing /etc/inittab to disable auto-login on tty.
    "
    sleep 2
    replace_inittab
    sudo cp ./inittab.new /etc/inittab
    rm ./inittab.new
    check_exit
fi

# drop to runlevel 1 to log out user from tty1-6
echo "
    Give root password when asked, then run this script from /root.
    "
sleep 4
sudo init 1
exit 0
}

# First run
# If not root, then do the following stuff:
if ! [[ $(id -un) = "root" ]] ; then
    echo "
   You're not root. This must be the first run of mkunlive. It will 
   create root password, copy script to /root, backup /etc/inittab
   to /root, and replace /etc/inittab to disable auto-login.
    
   Continue?    (y/n)
    "
    read ans
    while true; do
        case $ans in
          [Yy]*) prepare_unlive ;;
          [Nn]*) exit 0 ;;
        esac
    done
fi

# Second run
# If root, then do the following stuff:
if [[ $(id -un) = "root" ]] ; then
    echo "
    You are root. This must be the second run of this script.
    Create new user, edit /etc/sudoers, return to runlevel 2"
fi

# check runlevel
if ! $(runlevel | grep -q 1) ; then
    echo "    You need to drop to runlevel 1, then re-run this script."
    exit 1
fi

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

echo "    Changing user name and group...
    "
sleep 2

# Change user name and group
usermod -l $newname $oldname
groupmod -n $newname $oldname
usermod -d /home/$newname -m $newname
check_exit

# Show that it was done
echo "
  Checking that the name has been changed...
  "
sleep 2
if ! id $oldname  >/dev/null 2>&1 ; then
    echo "$oldname has been deleted."
else
    echo "Something is wrong. $oldname still exists"
fi
sleep 3
echo "$newname is in these groups:"
echo $(id $newname)
echo
sleep 6

# This might need to be added. I only had to do it when I changed
# the user name manually.
#echo "
#  Adding $newname to groups...
#  "
#sleep 1
#usermod -a -G dialout,cdrom,floppy,audio,video,plugdev,fuse $newname
#echo $(id $newname)
#echo
#sleep 3

echo "  You may need to edit the properties of desktop icons for 
  terminal, file manager, browser and maybe text editor. 
  (Just reset the working directory.) 
  
  This script will attempt to replace every instance of 
  /home/$oldname with /home/$newname in your user's config files.
    "
  
read -p  "  Press the ENTER key when you're ready to proceed."

for i in $(grep -r "/home/$oldname" /home/$newname/.config | awk -F":" ' { print $1 }')
do
    sed -i "s/\/home\/$oldname/\/home\/$newname/g" "$i"
    check_exit
done

# Edit /etc/gdm3/daemon.conf
echo "
    Edit /etc/gdm3/daemon.conf to disable graphical auto-login?
    If you don't do this, gdm3 will hang. If that happens, you can
    reboot in recovery mode and issue the command:
    update-rc.d -f gdm3 remove
    log out as root and log in as your user. Start the desktop with:
    startx
    
    Edit daemon.conf?  (yes or no)"
read ans
while true; do
    case $ans in
      [Yy]*) nano /etc/gdm3/daemon.conf ; break ;;
      [Nn]*) break ;;
    esac
done

# Edit /etc/sudoers
echo "
    Edit /etc/sudoers?  (yes or no)
    You need to comment out the line that gives \"user\" absolute power,
    or you need to replace \"user\" with the new user name. 
    "
read ans
while true; do
    case $ans in
      [Yy]*) visudo ; break ;;
      [Nn]*) break ;;
    esac
done

echo "
    Done!
    
    Returning to runlevel 2    
    "
sleep 2

init 2
exit 0
