#!/bin/sh
# Root dir
cd
# Paths
TEMP_FILE=$(mktemp)
LOG_FILE="/root/autostart/fm350gl_sh.log"
# Start date for used time
START=$(date '+%Y-%m-%d %H:%M:%S')
# Logging
logger "Script fm350gl.sh started"
echo "-----------------------------------------------------------" >> "$TEMP_FILE"
echo "---$(date '+%Y-%m-%d %H:%M:%S')" >> "$TEMP_FILE"
# Activate generic driver
echo "0e8d 7127" > /sys/bus/usb-serial/drivers/generic/new_id
echo "---Installed driver, now waiting 10s" >> "$TEMP_FILE"
# Modem has problems with power management turned on and high data rates, so diable power saving 
echo -1 > /sys/module/usbcore/parameters/autosuspend 
sleep 10
# First loop for general connectivity
for i in 1 2 3 4 5 6 7 8 9 10; do
	timeout 5s /root/autostart/at_commander at >> "$TEMP_FILE"
	if tail -n 1 "$TEMP_FILE" | grep -q "OK";then
		echo "---AT command accepted" >> "$TEMP_FILE"
		break
	fi
	sleep 1  # Warte 1 Sekunde
done
# Second loop for PDP context setting
for i in 1 2 3 4; do
  timeout 5s /root/autostart/at_commander at+cgdcont=1,\"IP\",\"internet\" >> "$TEMP_FILE"
	if tail -n 1 "$TEMP_FILE" | grep -q "OK";then
		echo "---PDP context set" >> "$TEMP_FILE"
		break
	fi
	sleep 1
done 
# Third loop for PDP context activation
for i in 1 2 3 4; do 
	timeout 5s /root/autostart/at_commander at+cgact=1,1 >> "$TEMP_FILE"
	if tail -n 1 "$TEMP_FILE" | grep -q "+CGEV";then
		echo "---PDP activated" >> "$TEMP_FILE"
		break
	elif [ $i==5 ]; then
		echo "---PDP not activated, maybe already done" >> "$TEMP_FILE"
		break
	fi
	sleep 1
done 
# Fourth loop for getting IP address
for i in 1 2 3 4; do
	timeout 5s /root/autostart/at_commander at+cgpaddr=1 >> "$TEMP_FILE"
	if tail -n 1 "$TEMP_FILE" | grep -q "+CGPADDR:";then
		echo "---IP address sent" >> "$TEMP_FILE"
		break
	fi
	sleep 1
done
# Set IP address
ip=$(tail -n 2 "$TEMP_FILE" | awk -F'"' '{print $2}')	 

echo "---IP address: $ip" >> "$TEMP_FILE"

uci set network.FM350GL.ipaddr="$ip"
uci commit network
/etc/init.d/network reload

echo "---Setting routes for $ip" >> "$TEMP_FILE"
# Setting routes
/etc/init.d/network reload
sleep 10
ip r del default dev eth2
ip r add default via $ip dev eth2 metric 4
ip r add 212.87.49.38 via $ip dev eth2
#service network reload
#/etc/init.d/network restart

# Calculate time delta and end script
END=$(date '+%Y-%m-%d %H:%M:%S')
DELTA=$(($(date -d "$END" +%s) - $(date -d "$START" +%s)))

echo "---interface IP and routes set, removing temp file" >> "$TEMP_FILE"
echo "---$(date '+%Y-%m-%d %H:%M:%S'), time delta=$DELTA" >> "$TEMP_FILE"
echo "-----------------------------------------------------------" >> "$TEMP_FILE"
logger "Script fm350gl.sh ended"

cat "$TEMP_FILE" >> "$LOG_FILE"
rm "$TEMP_FILE"
