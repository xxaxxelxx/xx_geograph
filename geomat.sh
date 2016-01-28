#!/bin/bash
SPLITBASEDIR="/customer"
CUSTOMER=$1
WORKDIR="$SPLITBASEDIR/$CUSTOMER/logs"
#SLEEP=$((3600 * 8))
SLEEP=$60
MINDUR=60
MAXAGE=366

find /tmp/geo.*.sema -mmin +31 -exec rm -f {} \; > /dev/null 2>&1

test -r $WORKDIR
if [ $? -eq 0 ]; then
    TOFFSET=$((86400 * 2))
    while [ $TOFFSET -lt $((86400 * 3)) ]; do
        find $WORKDIR -type f -mtime +${MAXAGE} -exec rm {} \;

        NOW=$(date +%s)
        TSTAMP=$(date -d @$(($NOW - $TOFFSET)) +%Y-%m-%d)

	FILE_KML=geoip.$TSTAMP.kml
	FILE_KMZ=geoip.$TSTAMP.kmz

        test -r $WORKDIR/access.$TSTAMP.log.gz
        if [ $? -eq 0 ]; then
	NOL_ACCESS_OLD=0
	SEMA="/tmp/geo.$CUSTOMER.$TSTAMP.sema"
	test -r $SEMA
	if [ $? -eq 0 ]; then
	    NOL_ACCESS_OLD=$(cat $SEMA)
	fi
	NOL_ACCESS=$(zcat $WORKDIR/access.$TSTAMP.log.gz | wc -l)
	if [ "x$NOL_ACCESS" != "x" ]; then 
	    echo $NOL_ACCESS > $SEMA
	fi
	test -r $WORKDIR/$FILE_KMZ
	if [ $? -ne 0 -a $NOL_ACCESS -eq $NOL_ACCESS_OLD ]; then
	    zcat $WORKDIR/access.$TSTAMP.log.gz | \
	    (
	    C_IP=""; C_DUR=""; C_MOUNT=""
	    rm -f /tmp/geo.$CUSTOMER.*.folder > /dev/null 2>&1
	    while read LINE; do
	        C_IP=$(echo "$LINE" | awk '{print $1}')
	        C_DUR=$(echo "${LINE##*\ }")
	        C_MOUNT=$(echo "$LINE" | awk '{print $7}' | sed 's|^/||')
	        C_TIME=$(echo "$LINE" | awk '{print $4}' | sed 's|\[||')
	        if [ "x$C_IP" == "x" ]; then continue; fi
	        if [ "x$C_DUR" == "x" ]; then continue; fi
	        [[ $C_DUR =~ ^[-+]?[0-9]+$ ]]; if [ $? -ne 0 ]; then continue; fi
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
	        A_LATLON=($(geoiplookup $C_IP | grep 'City' | iconv -f utf-8 -t ascii -c | rev 2>/dev/null | awk '{print $3OFS$4}' | sed 's|\,||g' | rev 2>/dev/null))
	        C_LAT=${A_LATLON[0]}; C_LON=${A_LATLON[1]}
	        if [ "x$C_LAT" == "x"  -o "x$C_LON" == "x" ]; then continue; fi
	        FOLDER_TMP="/tmp/geo.$CUSTOMER.$C_MOUNT.folder"
	        test -r $FOLDER_TMP
	        if [ $? -ne 0 ]; then
		echo "<Folder><name>$C_MOUNT</name><open>0</open>" > $FOLDER_TMP
	        fi
	        echo "<Placemark><name></name><styleUrl>#style_$CUSTOMER</styleUrl><Point><coordinates>${C_LON},${C_LAT}</coordinates></Point><TimeSpan><begin>$C_T_START</begin><end>$C_T_STOP</end></TimeSpan></Placemark>" >> $FOLDER_TMP
	    done
	    test -r $WORKDIR/$FILE_KML && rm -f $WORKDIR/$FILE_KML
	    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > $WORKDIR/$FILE_KML
	    echo "<kml xmlns=\"http://www.opengis.net/kml/2.2\">" >> $WORKDIR/$FILE_KML
	    echo "<Document>" >> $WORKDIR/$FILE_KML
	    echo "<name>$TSTAMP</name>" >> $WORKDIR/$FILE_KML
	    echo "<Style id=\"style_$CUSTOMER\"><IconStyle><scale>0.4</scale><Icon><href>https://storage.googleapis.com/support-kms-prod/SNP_2752125_en_v0</href></Icon></IconStyle></Style>" >> $WORKDIR/$FILE_KML
	    for FOLDER_FILE in /tmp/geo.$CUSTOMER.*.folder; do
	        test -r $FOLDER_FILE || continue
	        echo "</Folder>" >> $FOLDER_FILE
	        cat $FOLDER_FILE >> $WORKDIR/$FILE_KML
	        rm -f $FOLDER_FILE
	    done
	    echo "</Document></kml>" >> $WORKDIR/$FILE_KML
	    zip $WORKDIR/$FILE_KMZ $WORKDIR/$FILE_KML > /dev/null 2>&1 && rm -f $WORKDIR/$FILE_KML 
	    )
	fi
        fi
        TOFFSET=$(( $TOFFSET + 86400 ))
    done
fi
sleep $SLEEP
exit
