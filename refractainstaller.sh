#!/usr/bin/env bash
# refractainstaller.sh

###  run it as:  ./refractainstaller.sh | tee install_log.txt


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

# Choose locations to install OS and boot loader.
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


fs_type= 
install_dev=
grub_dev=

echo -n "
 Which partition would you like to use for the installation?
 (give the full device name, like /dev/sda1): "
read install_dev
[[ -b $install_dev ]] || { echo "$install_dev does not exist!" ; exit 1 ; }

echo -n "
 Where would you like the GRUB bootloader to be installed?
 (probably a drive, like /dev/sda): "
read grub_dev
[[ -b $grub_dev ]] || { echo "$grub_dev does not exist!" ; exit 1 ; }


# Choose filesystem type.
while true; do
    echo -n "
 What type of filesystem would you like on the partition?
 
 Choices (enter number):
    1) ext2
    2) ext3
    3) ext4
   "
    read ans
    case $ans in
      1) fs_type="ext2" ; break ;;
      2) fs_type="ext3" ; break ;;
      3) fs_type="ext4" ; break ;;
    esac
done


#just in case, cleanup first
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
    umount /target/
fi
if $(df | grep -q $install_dev) ; then
    umount $install_dev
fi
if [[ -d /target ]] ; then
    rm -rf /target
fi


#make mount point, format, adjust reserve and mount
echo -e "\n Creating filesystem...\n"
mkdir /target ;  check_exit 
mke2fs -t $fs_type $install_dev ; check_exit 
tune2fs -r 10000 $install_dev ; check_exit 
mount $install_dev /target ; check_exit 


#copy everything over except the things listed in the exclude list
echo -e "\n Copying system to new partition...\n"
rsync -a / /target/ --exclude-from="$rsync_excludes" ; check_exit 


#create swap
echo -e "\n Making a swap file...\n"
dd if=/dev/zero of=/target/swapfile bs=1048 count=256000 ; check_exit 
mkswap /target/swapfile ; check_exit 


#copy the real update-initramfs back in place
echo -e "\n Copying update-initramfs...\n"
if [[ -f /target/usr/sbin/update-initramfs.distrib ]] ; then
    cp /target/usr/sbin/update-initramfs.distrib /target/usr/sbin/update-initramfs
fi
if [[ /target/usr/sbin/update-initramfs.debian ]] ; then
    cp /target/usr/sbin/update-initramfs.debian /target/usr/sbin/update-initramfs
fi

#setup fstab
echo -e "\n Creating /etc/fstab...\n"
echo -e "proc\t\t/proc\tproc\tdefaults\t0\t0" > /target/etc/fstab
echo -e "/swapfile\tswap\tswap\tdefaults\t0\t0" >> /target/etc/fstab
echo -e "$install_dev\t/\t$fs_type\tdefaults,noatime\t0\t1" >> /target/etc/fstab
check_exit

#mount stuff so grub will behave
echo -e "\n Mounting tmpfs and proc...\n"
mount -t tmpfs --bind /dev/ /target/dev/ ; check_exit 
mount -t proc --bind /proc/ /target/proc/ ; check_exit 
mount -t sysfs --bind /sys/ /target/sys/ ; check_exit 


#setup grub
echo -e "\n Installing the boot loader...\n"
chroot /target grub-install $grub_dev ; check_exit 
chroot /target update-grub ; check_exit 


#cleanup
echo -e "\n Cleaning up...\n"
umount /target/proc/ ; check_exit 
umount /target/dev/ ; check_exit 
umount /target/sys/ ; check_exit 
umount /target ; check_exit 
if $(df | grep -q $install_dev) ; then
    umount $install_dev
    check_exit
fi
rm -rf /target ; check_exit 
echo -e "\n\t Done!\n\n You may now reboot into the new system.\n\n"