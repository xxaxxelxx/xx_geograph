#!/bin/bash

set -e
#set -x

wget http://www.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz > /dev/null 2>&1
#if [ $? -eq 0 ]; then
#    mv -f GeoLiteCity.dat GeoLiteCity.dat.old
#    gunzip -f GeoLiteCity.dat.gz > /dev/null
#    if [ $? -eq 0 ]; then
#	mv -f GeoLiteCity.dat /usr/share/GeoIP/GeoIPCity.dat
#    fi
#fi

#./geomat.sh $@

bash
exit
