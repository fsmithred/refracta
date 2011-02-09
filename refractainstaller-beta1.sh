#!/usr/bin/env bash
# refractainstaller.sh

###  run it as:  ./refractainstaller.sh 2>&1 | tee install_log.txt


error_log="error_log.txt"
exec 2>"$error_log"

rsync_excludes="/home/user/exclude.list"

#added by me, MT:
if  [[ -z  $rsync_excludes ]] &&  [[ -z  ./exclude_list ]] 
then
    rsync_excludes="./exclude.list"
    cat > "$rsync_excludes" <<-EOF
    /dev/*
    /cdrom/*
    /media/*
    /target
    /swapfile
    /mnt/*
    /sys/*
    /proc/*
    /tmp/*
    /live
    /boot/grub/grub.cfg
    /boot/grub/menu.lst
    /boot/grub/device.map
    /etc/udev/rules.d/70-persistent-cd.rules
    /etc/udev/rules.d/70-persistent-net.rules
    /etc/fstab
    /etc/mtab
    /home/snapshot/
EOF
else
	echo "file exists" 
fi 


exit 0

# Check that user is root.
[[ $(id -u) -eq 0 ]] || { echo -e "\t You need to be root!\n" ; exit 1 ; }


while true; do
    echo -n " You need to have a partition ready for the installation. If you 
 haven't already done that, you can run the partition editor now.
 
 Choices (enter number):
     1. GParted
     2. cfdisk
     3. No thanks, I already have a partition prepared.
    "
    read ans
    case $ans in
      1) gparted ; break ;;
      2) cfdisk ; break ;;
      3) break ;;
    esac
done

while true; do
    echo -n "
 Would you like fdisk to show you what drives and partitions
 are available? "
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
 Which partition would you like to use for the installation? "
read install_dev
[[ -b $install_dev ]] || { echo "$install_dev does not exist!" ; exit 1 ; }

echo -n "
 Where would you like the GRUB bootloader to be installed?
 (probably a drive, like /dev/sda) "
read grub_dev
[[ -b $grub_dev ]] || { echo "$grub_dev does not exist!" ; exit 1 ; }

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
mkdir /target    # [[ $(mkdir /target) ]] || { echo "an error occurred" ; exit 1 ; }
mke2fs -t $fs_type $install_dev
tune2fs -r 10000 $install_dev
mount $install_dev /target


#copy everything over except the things listed in the exclude list
echo -e "\n Copying system to new partition...\n"
rsync -a / /target/ --exclude-from="$rsync_excludes"


#create swap
echo -e "\n Making a swap file...\n"
dd if=/dev/zero of=/target/swapfile bs=1048 count=256000
mkswap /target/swapfile


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
echo -e "$install_dev\t/\text3\tdefaults,noatime\t0\t1" >> /target/etc/fstab


#mount stuff so grub will behave
echo -e "\n Mounting tmpfs and proc...\n"
mount -t tmpfs --bind /dev/ /target/dev/
mount -t proc --bind /proc/ /target/proc/
mount -t sysfs --bind /sys/ /target/sys/
#mount -t devpts --bind /dev/pts/ /target/dev/pts


#setup grub
echo -e "\n Installing the boot loader...\n"
chroot /target grub-install $grub_dev
chroot /target update-grub


#cleanup
echo -e "\n Cleaning up...\n"
umount /target/proc/
umount /target/dev/
umount /target/sys/
#umount /target/dev/pts/
umount /target
umount $install_dev
rm -rf /target
echo -e "\n\t Done!\n\n You may now reboot into the new system.\n\n"
