#!/bin/sh

cd

TEMP_FILE=$(mktemp)
LOG_FILE="/root/autostart/fm350gl_sh.log"
START=$(date '+%Y-%m-%d %H:%M:%S')

logger "Script fm350gl.sh started"
echo "-----------------------------------------------------------" >> "$TEMP_FILE"
echo "---$(date '+%Y-%m-%d %H:%M:%S')" >> "$TEMP_FILE"
echo "0e8d 7127" > /sys/bus/usb-serial/drivers/generic/new_id
echo "---Installed driver, now waiting 10s" >> "$TEMP_FILE"
sleep 10 

for i in {1..10}; do
	timeout 5s /root/autostart/at_commander at >> "$TEMP_FILE"
	if tail -n 1 "$TEMP_FILE" | grep -q "OK";then
		echo "---AT command accepted" >> "$TEMP_FILE"
		break
	fi
	sleep 1  # Warte 1 Sekunde
done

for i in  {1..5}; do
  timeout 5s /root/autostart/at_commander at+cgdcont=1,\"IP\",\"internet\" >> "$TEMP_FILE"
	if tail -n 1 "$TEMP_FILE" | grep -q "OK";then
		echo "---PDP context set" >> "$TEMP_FILE"
		break
	fi
	sleep 1
done 

for i in {1..5}; do 
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

for i in {1..5]; do
	timeout 5s /root/autostart/at_commander at+cgpaddr=1 >> "$TEMP_FILE"
	if tail -n 1 "$TEMP_FILE" | grep -q "+CGPADDR:";then
		echo "---IP address sent" >> "$TEMP_FILE"
		break
	fi
	sleep 1
done

ip=$(tail -n 2 "$TEMP_FILE" | awk -F'"' '{print $2}')	 

echo "---IP address: $ip" >> "$TEMP_FILE"

uci set network.FM350GL.ipaddr="$ip"
uci commit network
/etc/init.d/network reload

echo "---Setting routes for $ip" >> "$TEMP_FILE"

/etc/init.d/network reload
sleep 10
ip r del default dev eth2
ip r add default via $ip dev eth2 metric 4
ip r add 212.87.49.38 via $ip dev eth2
#service network reload
#/etc/init.d/network restart

END=$(date '+%Y-%m-%d %H:%M:%S')
DELTA=$(($(date -d "$END" +%s) - $(date -d "$START" +%s)))

echo "---interface IP and routes set, removing temp file" >> "$TEMP_FILE"
echo "---$(date '+%Y-%m-%d %H:%M:%S'), time delta=$DELTA" >> "$TEMP_FILE"
echo "-----------------------------------------------------------" >> "$TEMP_FILE"
logger "Script fm350gl.sh ended"

cat "$TEMP_FILE" >> "$LOG_FILE"
rm "$TEMP_FILE"
