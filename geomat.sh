#!/bin/bash
SPLITBASEDIR="/customer"
CUSTOMER=$1
WORKDIR="$SPLITBASEDIR/$CUSTOMER/logs"
SLEEP=60
MINDUR=60

find /tmp/geo.*.sema -mmin +31 -exec rm -f {} \; > /dev/null 2>&1

test -r $WORKDIR
if [ $? -eq 0 ]; then
	TOFFSET=0
	while [ $TOFFSET -lt 86401 ]; do
	    NOW=$(date +%s)
	    TSTAMP=$(date -d @$(($NOW - $TOFFSET)) +%Y-%m-%d)
	    test -r $WORKDIR/access.$TSTAMP.log.gz
	    if [ $? -eq 0 ]; then
		MD5OLD=""
		SEMA="/tmp/geo.$CUSTOMER.$TSTAMP.sema"
		test -r $SEMA
		if [ $? -eq 0 ]; then
		    MD5OLD=$(cat $SEMA)
		fi
		MD5CUR=$(md5sum $WORKDIR/access.$TSTAMP.log.gz | awk '{print $1}')
		if [ "x$MD5OLD" != "x$MD5CUR" ]; then
		    echo $MD5CUR > $SEMA
		    zcat $WORKDIR/access.$TSTAMP.log.gz | \
		    (
			C_IP=""; C_DUR=""; C_MOUNT=""
			while read LINE; do
			    C_IP=$(echo "$LINE" | awk '{print $1}')
			    C_DUR=$(echo "${LINE##*\ }")
			    C_MOUNT=$(echo "$LINE" | awk '{print $7}')
			    C_TIME=$(echo "$LINE" | awk '{print $4}' | sed 's|\[||')
			    if [ "x$C_IP" == "x" ]; then continue; fi
			    if [ "x$C_DUR" == "x" ]; then continue; fi
			    if [ "x$C_MOUNT" == "x" ]; then continue; fi
			    if [ "x$C_TIME" == "x" ]; then continue; fi
			    if [ $C_DUR -lt $MINDUR ]; then continue; fi

			    A_TIME=($(echo "$C_TIME" | sed 's|\/|\ |g' | sed 's|\:|\ |g'))
			    C_T_YEAR=${A_TIME[2]}
			    C_T_MONTH=${A_TIME[1]}
			    C_T_DAY=${A_TIME[0]}
			    C_T_HOUR=${A_TIME[3]}
			    C_T_MIN=${A_TIME[4]}
			    C_T_SEC=${A_TIME[5]}
			    C_T_EPOCH=$(date -d "${C_T_MONTH} ${C_T_DAY} ${C_T_HOUR}:${C_T_MIN}:${C_T_SEC} ${C_T_YEAR} UTC" +%s)
			    C_T_E_STOP="$C_T_EPOCH"
			    C_T_E_START=$(($C_T_EPOCH - $C_DUR))
			    C_T_STOP="$(date -d @${C_T_E_STOP} +%Y-%m-%dT%H:%M:%SZ)"
			    C_T_START="$(date -d @${C_T_E_START} +%Y-%m-%dT%H:%M:%SZ)"
#			    echo "+ + + + +"
#			    echo "$LINE"
			    A_LATLON=($(geoiplookup $C_IP | grep 'City' | rev | awk '{print $3OFS$4}' | sed 's|\,||g' | rev))
			    C_LAT=${A_LATLON[0]}; C_LON=${A_LATLON[1]}
			    echo "$C_IP $C_DUR $C_MOUNT $C_LAT $C_LON $C_T_START $C_T_STOP"
#exit
			done
		    )
		fi
	    fi
	    TOFFSET=$(( $TOFFSET + 86400 ))
	done
fi
sleep $SLEEP
exit
