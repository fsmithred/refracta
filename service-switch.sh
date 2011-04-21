#!/usr/bin/env bash
# service-switch.sh
# start/stop services


# Check that user is root.
#[[ $(id -u) -eq 0 ]] || { echo -e "\t You need to be root!\n" ; exit 1 ; }


show_switches () {
switch=$(zenity --list --title="Services" \
    --text="Start (restart) or stop services." \
    --checklist --column "Choose" --column "Num" --column "Option" \
     --width=520 --height=320  \
  FALSE 01 "Start SSH server" \
  FALSE 02 "Stop SSH server" \
  FALSE 03 "Start CUPS print server" \
  FALSE 04 "Stop CUPS print server" \
  FALSE 05 "Start Wicd network manager" \
  FALSE 06 "Stop Wicd network manager" \
  FALSE 07 "Start SAMBA file server" \
  FALSE 08 "Stop SAMBA file server")

if [[ $? = 1 ]]; then
    exit 0
fi
if $(echo $switch | grep -q 01); then
    /etc/init.d/ssh restart
fi
if $(echo $switch | grep -q 02); then
    /etc/init.d/ssh stop
fi
if $(echo $switch | grep -q 03); then
    /etc/init.d/cups restart
fi
if $(echo $switch | grep -q 04); then
    /etc/init.d/cups stop
fi
if $(echo $switch | grep -q 05); then
    /etc/init.d/wicd restart
fi
if $(echo $switch | grep -q 06); then
    /etc/init.d/wicd stop
fi
if $(echo $switch | grep -q 07); then
    /etc/init.d/samba restart
fi
if $(echo $switch | grep -q 08); then
    /etc/init.d/samba stop
fi
if $(echo $switch | grep -q xx); then
    exit 0
fi

keep_running
}

keep_running () {
	show_switches
}

keep_running
