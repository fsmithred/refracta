#!/usr/bin/env bash
# refractainstaller3.sh
# Copyright 2011 fsmithred@gmail.com
# Licence: GPL-3
# This is free software with no warrantees. Use at your own risk.

# This script will install a refracta live-cd to a hard drive. It gives
# you the option to install the entire system to one partition or to
# install with /home on a separate partition. 

# NOTE: right now, errors are logged to error_log in the directory
# where the script is running. If this script gets put someplace like
# /usr/bin or other system directory, we need to put the error log
# someplace convenient for the user to find it, along with a message
# telling the user where it is.

# NOTE2: If you try to tee this to an install log, you won't see it
# when cryptsetup asks you to confirm with YES.

# TODO
# Review cleanup for encrypted partitions
# OK: Cleanup excludes? - Added tests for "- /home/*" and "- /boot/*" in
# case the script is run several times (so they don't get added every time.)
# tune2fs for /boot? note: default is 5% ( -m 5 )
# chroot /target_boot for grub-install?

error_log="error_log.txt"
exec 2>"$error_log"

rsync_excludes="/home/user/exclude.list"

# function to exit the script if there are errors
check_exit () {
[[ $? -eq 0 ]] || { echo "Exit due to error:  $?" ; exit 1 ; }
}

# Check that user is root.
[[ $(id -u) -eq 0 ]] || { echo -e "\t You need to be root!\n" ; exit 1 ; }

# Check that rsync excludes file exists, or create one.
if ! [[ -f  $rsync_excludes ]] ; then
    echo "
 There is no rsync excludes file, or its name does not match what
 this script expects. You should let the script create one, or if
 you have a custom exlcudes file, and you know what you're doing,
 you can exit the script and edit the rsync_excludes variable at 
 the top so that it matches the name and path of your custom file.

 Press ENTER to proceed or hit ctrl-c to exit. "
    read -p " "
    rsync_excludes="./exclude.list"
    echo " Creating rsync excludes file, $rsync_excludes
 "
    sleep 2
    cat > "$rsync_excludes" <<EOF
- /dev/*
- /cdrom/*
- /media/*
- /target
- /swapfile
- /mnt/*
- /sys/*
- /proc/*
- /tmp/*
- /live
- /boot/grub/grub.cfg
- /boot/grub/menu.lst
- /boot/grub/device.map
- /etc/udev/rules.d/70-persistent-cd.rules
- /etc/udev/rules.d/70-persistent-net.rules
- /etc/fstab
- /etc/mtab
- /home/snapshot/
EOF
check_exit
fi 



# Partition a disk
while true; do
    echo -n " 
 You need to have a partition ready for the installation. If you 
 haven't already done that, you can run the partition editor now.
 If you want a separate /home partition, you should create it at 
 this time, this script will ask you later if you've done that.
 
 Choices (enter number):
     1. GParted
     2. cfdisk
     3. No thanks, I already have a partition prepared. Continue.
     4. I'd like to exit the script now.
    "
    read ans
    case $ans in
      1) gparted ; break ;;
      2) cfdisk ; break ;;
      3) break ;;
      4) exit 0 ;;
    esac
done


# Ask to display partitions
while true; do
    echo -n "
 Would you like fdisk to show you what drives and partitions
 are available? (yes or no): "
    read ans
    case $ans in
      [Yy]*) fdisk -l ; break ;;
      [Nn]*) break ;;
    esac
done

echo "one"

# Leave these variables blank. You will be asked to provide values.
grub_dev=
boot_dev=
fs_type_boot=
install_dev=
fs_type_os=
encrypt_os=
home_dev=
fs_type_home=
encrypt_home=

# Select location for bootloader; if null, ask to verify or enter.
# If location is entered but does not exist, then exit with error.

    echo -n "

 Where would you like the GRUB bootloader to be installed?
 (probably a drive, like /dev/sda): "
    read grub_dev
    if [[ -z $grub_dev ]] ; then
        while true; do
            echo "
 No device was selected for a bootloader. Are you sure you want this?
 (yes or no)
 "
            read ans
            case $ans in
              [Yy]*) break ;;
              [Nn]*) echo "
 Enter a device for the bootloader
 "
                   read grub_dev
                   break ;;
            esac
        done
    fi

echo "two"
if [[ -n $grub_dev ]] ; then
    [[ -b $grub_dev ]] || { echo "$grub_dev does not exist!" ; exit 1 ; }
fi
echo "three"

# Enter device for /boot partition or skip. If one is entered, test it.
echo -n "

 If you created a separate partition for /boot, enter it here.
 To skip this, just hit the ENTER key.
 
 (give the full device name, like /dev/sda1): "
 
read boot_dev
echo "four"
echo "$boot_dev"
if ! [[ -z $boot_dev ]] && ! [[ -b $boot_dev ]] ; then
    echo " $boot_dev does not exist!
 You may continue and install without a separate boot partition,
 or you can hit ctrl-c to exit, then re-run the script, and
 be sure to create a partition for /boot.
    "
    boot_dev=
    echo "Press ENTER when you're ready to continue"
    read -p " "
fi
echo "five"
# Choose filesystem type for /boot if it exists.
if [[ -n $boot_dev ]] ; then
    while true; do
        echo -n "
    
 What type of filesystem would you like on $boot_dev?
 
 Choices (enter number):
    2) ext2 (recommended for /boot)
    3) ext3
    4) ext4
   "
        read ans
        case $ans in
          2) fs_type_boot="ext2" ; break ;;
          3) fs_type_boot="ext3" ; break ;;
          4) fs_type_boot="ext4" ; break ;;
        esac
    done
fi

echo -n "

 Which partition would you like to use for the installation
 of the operating system?
 
 (give the full device name, like /dev/sda1): "
read install_dev
[[ -b $install_dev ]] || { echo "$install_dev does not exist!" ; exit 1 ; }

# Choose filesystem type for OS.
while true; do
    echo -n "
    
 What type of filesystem would you like on $install_dev?
 
 Choices (enter number):
    2) ext2
    3) ext3
    4) ext4
   "
    read ans
    case $ans in
      2) fs_type_os="ext2" ; break ;;
      3) fs_type_os="ext3" ; break ;;
      4) fs_type_os="ext4" ; break ;;
    esac
done
echo "six"
# Decide if OS should be encrypted
while true; do
    echo -n "

 Do you want the operating system on an encrypted partition?
 (yes or no)
 "
    read ans
    case $ans in
      [Yy]*) encrypt_os="yes" ; break ;;
      [Nn]*) encrypt_os="no"  ; break ;;
    esac
done


echo -n "

  If you created a separate partition for /home, 
  enter the full device name. However, if you're 
  installing everything to one partition, you should
  leave this blank.

  /home partition (if one exists): "
read home_dev
if [[ -n $home_dev ]] && ! [[ -b $home_dev ]] ; then
    echo "
    $home_dev does not exist!
    You may continue and install everything to one partition,
    or you can hit ctrl-c to exit, then re-run the script, and
    be sure to create a partition for /home.
    "
    home_dev=
    echo "Press ENTER when you're ready to continue"
    read -p " "
fi

# Choose filesystem type for /home if needed
if [[ -n $home_dev ]] ; then
    while true; do
        echo -n "
        
 What type of filesystem would you like on $home_dev?
 
 Choices (enter number):
    2) ext2
    3) ext3
    4) ext4
   "
        read ans
        case $ans in
          2) fs_type_home="ext2" ; break ;;
          3) fs_type_home="ext3" ; break ;;
          4) fs_type_home="ext4" ; break ;;
        esac
    done
fi
echo "seven"
# Decide if /home should be encrypted
if [[ -n $home_dev ]] ; then
    echo "eight"
    while true; do
        echo -n "
        
 Do you want /home on an encrypted partition?
 (yes or no)
 "
    read ans
    case $ans in
      [Yy]*) encrypt_home="yes" ; break ;;
      [Nn]*) encrypt_home="no"  ; break ;;
    esac
    done
fi
 

# just in case, cleanup first
echo -e "\n Preparing for installation...\n"
if $(df | grep -q /target/proc/) ; then
    umount /target/proc/
fi

if $(df | grep -q /target/dev/) ; then
    umount /target/dev/
fi

if $(df | grep -q /target/sys/) ; then
    umount /target/sys/
fi

if $(df | grep -q /target) ; then
    umount -l /target/
fi

if $(df | grep -q $install_dev) ; then
    umount $install_dev
fi    

if $(df | grep "\/dev\/mapper\/root-fs") ; then
    umount /dev/mapper/root-fs
fi

if [[ -h /dev/mapper/root-fs ]] ; then
    cryptsetup luksClose /dev/mapper/root-fs
fi

if $(df | grep -q $home_dev) ; then
    umount $home_dev
fi

if $(df | grep -q "\/dev\/mapper\/home-fs") ; then
    umount /dev/mapper/home-fs
fi

if [[ -h /dev/mapper/home-fs ]] ; then
    cryptsetup luksClose home-fs
fi

if $(df | grep -q $boot_dev) ; then
    umount -l $boot_dev
fi

if [[ -d /target ]] ; then
    rm -rf /target
fi

if [[ -d /target_home ]] ; then
    rm -rf /target_home
fi

if [[ -d /target_boot ]] ; then
    rm -rf /target_boot
fi

# make mount point, format, adjust reserve and mount
echo -e "\n Creating filesystem on $install_dev...\n"
mkdir /target ;  check_exit
if [[ $encrypt_os = yes ]] ; then
    echo " You will need to create a passphrase."
    cryptsetup luksFormat "$install_dev"
    check_exit
    echo "Encrypted partition created. Opening it..."
    cryptsetup luksOpen "$install_dev" root-fs
    check_exit
    install_part="/dev/mapper/root-fs"
else
    install_part="$install_dev"
fi 
mke2fs -t $fs_type_os "$install_part" ; check_exit 
tune2fs -r 10000 "$install_part" ; check_exit 
mount "$install_part" /target ; check_exit 

# make mount point for separate home if needed
# and add /home/* to the excludes list
if [[ -n $home_dev ]] ; then
    echo "Creating filesystem on $home_dev..."
    mkdir /target_home ; check_exit
    if [[ $encrypt_home = yes ]]; then
        echo " You will need to create a passphrase."
        cryptsetup luksFormat "$home_dev"
        check_exit
        echo "Encrypted partition created. Opening it..."
        cryptsetup luksOpen "$home_dev" home-fs
        check_exit
        home_part="/dev/mapper/home-fs"
    else
        home_part=$home_dev
fi
    mke2fs -t $fs_type_home "$home_part" ; check_exit
    tune2fs -r 10000 "$home_part" ; check_exit
    mount "$home_part" /target_home ; check_exit
    if ! $(grep -q "\/home\/\*" "$rsync_excludes"); then
        echo "- /home/*" >> "$rsync_excludes"
    fi
fi

# make mount point for separate /boot if needed
# and add /boot/* to the excludes list
# allow default for reserved blocks
if [[ -n $boot_dev ]] ; then
    mkdir /target_boot ; check_exit
    mke2fs -t $fs_type_boot $boot_dev ; check_exit
    mount $boot_dev /target_boot
    if ! $(grep -q "\/boot\/\*" "$rsync_excludes"); then
        echo "- /boot/*" >> "$rsync_excludes"
    fi
fi


# copy everything over except the things listed in the exclude list
echo -e "\n Copying system to new partition...\n"
rsync -a / /target/ --exclude-from="$rsync_excludes" ; check_exit 

# copy separate /home if needed
if [[ -n $home_part ]] ; then
    echo -e "\n Copying home folders to new partition...\n"
    rsync -a /home/ /target_home/ --exclude=/home/snapshot ; check_exit
fi

# copy separate /boot if needed
if [[ -n $boot_dev ]] ; then
    echo -e "\n Copying files to boot partitions...\n"
    rsync -a /boot/ /target_boot/ ; check_exit
fi

# create swap
echo -e "\n Making a swap file...\n"
dd if=/dev/zero of=/target/swapfile bs=1048 count=256000 ; check_exit 
mkswap /target/swapfile ; check_exit 


# copy the real update-initramfs back in place
echo -e "\n Copying update-initramfs...\n"
if [[ -f /target/usr/sbin/update-initramfs.distrib ]] ; then
    cp /target/usr/sbin/update-initramfs.distrib /target/usr/sbin/update-initramfs
fi
if [[ /target/usr/sbin/update-initramfs.debian ]] ; then
    cp /target/usr/sbin/update-initramfs.debian /target/usr/sbin/update-initramfs
fi

# setup fstab
echo -e "\n Creating /etc/fstab...\n"
echo -e "proc\t\t/proc\tproc\tdefaults\t0\t0
/swapfile\tswap\tswap\tdefaults\t0\t0
$install_part\t/\t$fs_type_os\tdefaults,noatime\t0\t1" >> /target/etc/fstab
check_exit

# add entry for /home to fstab if needed
if [[ -n $home_part ]] ; then
    echo -e "\n Adding /home entry to fstab...\n"
    echo -e "$home_part\t/home\t$fs_type_home\tdefaults,noatime\t0\t2" >> /target/etc/fstab
    check_exit
fi

# add entry for /boot to fstab if needed
if [[ -n $boot_dev ]] ; then
    echo -e "\n Adding /boot entry to fstab...\n"
    echo -e "$boot_dev\t/boot\t$fs_type_boot\tdefaults,noatime,\t0\t1" >> /target/etc/fstab
    check_exit
fi

# Setup /etc/crypttab if needed
if [[ $encrypt_os = yes ]] ; then
    echo -e "\n Adding $install_part entry to crypttab...\n"
    echo -e "root-fs\t\t$install_dev\t\tnone\t\tluks" >> /target/etc/crypttab
fi

# Add entry for /home to crypttab if needed
if [[ $encrypt_home = yes ]] ; then
    echo -e "\n Adding $home_part entry to crypttab...\n"
    echo -e "home-fs\t\t$home_dev\t\tnone\t\tluks" >> /target/etc/crypttab
fi


# mount stuff so grub will behave
echo -e "\n Mounting tmpfs and proc...\n"
mount -t tmpfs --bind /dev/ /target/dev/ ; check_exit 
mount -t proc --bind /proc/ /target/proc/ ; check_exit 
mount -t sysfs --bind /sys/ /target/sys/ ; check_exit 


# setup grub
echo -e "\n Installing the boot loader...\n"
if [[ -n $boot_dev ]] ; then
    chroot /target mount $boot_dev /boot
    chroot /target grub-install $grub_dev
    if [[ $encrypt_os = yes ]] ; then
        chroot /target update-initramfs -u
    fi
else
    chroot /target grub-install $grub_dev ; check_exit
fi
echo "ten"
chroot /target update-grub ; check_exit
echo "eleven"
###chroot /target_boot update-grub ; check_exit

# cleanup
echo -e "\n Cleaning up...\n"
umount /target/proc/ ; check_exit 
umount /target/dev/ ; check_exit 
umount /target/sys/ ; check_exit 
umount -l /target ; check_exit
if $(df | grep -q $home_part) ; then
    umount $home_part ; check_exit
    if [[ $encrypt_home = yes ]] ; then
        cryptsetup luksClose "$home_part" ; check_exit
    fi
fi 

if [[ -d /target_boot ]] ; then
    umount /target_boot
    check_exit
fi

if $(df | grep -q $install_part) ; then
    umount $install_part
    check_exit
    if [[ $encrypt_os = yes ]] ; then
        cryptsetup luksClose "$install_part" ; check_exit
    fi
fi
# this shouldn't matter - we're running a live-cd
rm -rf /target ; check_exit 

echo -e "\n\t Done!\n\n You may now reboot into the new system.\n\n"
