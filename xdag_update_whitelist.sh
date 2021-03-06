#!/bin/bash

DL="`which wget`"
WHITELIST_SUFFIX=""

if [ -f /home/pool/scripts/CONFIG.sh ]; then
	. /home/pool/scripts/CONFIG.sh
fi

if [ $? -eq 0 ]; then
	"$DL" https://raw.githubusercontent.com/XDagger/xdag/master/client/netdb-white"$WHITELIST_SUFFIX".txt -O /var/www/pool/netdb-white.txt 2>/dev/null

	if [ $? -ne 0 ]; then
		echo "Wget call failed, not updating whitelist."
		exit 2
	fi
else
	DL="`which curl`"

	if [ $? -ne 0 ]; then
		echo "No suitable downloader found (wget or curl), not updating whitelist."
		exit 1
	fi

	"$DL" https://raw.githubusercontent.com/XDagger/xdag/master/client/netdb-white"$WHITELIST_SUFFIX".txt --output /var/www/pool/netdb-white.txt 2>/dev/null

	if [ $? -ne 0 ]; then
		echo "Curl call failed, not updating whitelist."
		exit 3
	fi
fi

grep -Pha "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]{1,5}$" /var/www/pool/netdb-white.txt > /var/www/pool/netdb-filtered.txt

LINES1="`wc -l /var/www/pool/netdb-white.txt | cut -d ' ' -f 1`"
LINES2="`wc -l /var/www/pool/netdb-filtered.txt | cut -d ' ' -f 1`"

if [ "$LINES1" == "0" ]; then
	rm /var/www/pool/netdb-white.txt /var/www/pool/netdb-filtered.txt
	echo "Wrong whitelist format (whitelist is empty), not updating whitelist."
	exit 4
fi

if [ "$LINES1" != "$LINES2" ]; then
	rm /var/www/pool/netdb-white.txt /var/www/pool/netdb-filtered.txt
	echo "Wrong whitelist format ($LINES1 vs $LINES2 lines), not updating whitelist."
	exit 4
fi

rm /var/www/pool/netdb-white.txt

while read -u 10 LINE; do
	BYTE1="`echo "$LINE" | tr ':' '.' | cut -d '.' -f 1`"
	BYTE2="`echo "$LINE" | tr ':' '.' | cut -d '.' -f 2`"
	BYTE3="`echo "$LINE" | tr ':' '.' | cut -d '.' -f 3`"
	BYTE4="`echo "$LINE" | tr ':' '.' | cut -d '.' -f 4`"
	PORT="`echo "$LINE" | tr ':' '.' | cut -d '.' -f 5`"
	IP="$BYTE1.$BYTE2.$BYTE3.$BYTE4"

	echo "$IP" | grep -E '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)' > /dev/null

	if [ $? -eq 0 ]; then
		rm /var/www/pool/netdb-filtered.txt
		echo "IP address in whitelist is private network - $IP, not updating whitelist.";
		exit 5
	fi

	if [ "$BYTE1" -gt 255 ]; then
		rm /var/www/pool/netdb-filtered.txt
		echo "IP address $IP invalid first byte, not updating whitelist."
		exit 6
	fi

	if [ "$BYTE2" -gt 255 ]; then
		rm /var/www/pool/netdb-filtered.txt
		echo "IP address $IP invalid second byte, not updating whitelist."
		exit 6
	fi

	if [ "$BYTE3" -gt 255 ]; then
		rm /var/www/pool/netdb-filtered.txt
		echo "IP address $IP invalid third byte, not updating whitelist."
		exit 6
	fi

	if [ "$BYTE4" -gt 255 ]; then
		rm /var/www/pool/netdb-filtered.txt
		echo "IP address $IP invalid fourth byte, not updating whitelist."
		exit 6
	fi

	if [ "$PORT" -lt 1 -o "$PORT" -gt 65535 ]; then
		rm /var/www/pool/netdb-filtered.txt
		echo "IP address $IP invalid port ($PORT), not updating whitelist."
		exit 6
	fi
done 10</var/www/pool/netdb-filtered.txt

if [ -f /home/pool/scripts/CONFIG.sh -a "$EUID" == "0" ]; then
	. /home/pool/scripts/CONFIG.sh

	IPT="`which iptables`"

	if [ $? -eq 0 -a "$CONFIGURE_IPTABLES" == "1" ]; then
		"$IPT" -F INPUT

		while read -u 10 LINE; do
			IP="`echo "$LINE" | cut -d ':' -f 1`"
			"$IPT" -A INPUT -p tcp --dport "$POOL_PORT" -s "$IP" -j ACCEPT
		done 10</var/www/pool/netdb-filtered.txt

		"$IPT" -A INPUT -p tcp --dport "$POOL_PORT" -j DROP
	fi
fi

if [ "$EUID" == "0" ]; then
	chown pool:pool /var/www/pool/netdb-filtered.txt
fi

mv /var/www/pool/netdb-filtered.txt /home/pool/xdag1/client/netdb-white"$WHITELIST_SUFFIX".txt
cp /home/pool/xdag1/client/netdb-white"$WHITELIST_SUFFIX".txt /home/pool/xdag2/client/netdb-white"$WHITELIST_SUFFIX".txt
